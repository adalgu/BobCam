# Smart Eating Detection: Metrics Calculation Specification

**Version**: 1.0
**Date**: 2025-11-19
**Status**: Technical Specification
**Audience**: iOS Developers, Algorithm Engineers

---

## 1. Data Structures

### 1.1 Core Data Types

```swift
// Time-series data point for each frame
struct FrameAnalysis {
    let timestamp: TimeInterval
    let isEating: Bool  // Binary eating/not-eating from current system
    let lipDistance: Double  // Distance between upper/lower lips (pixels)
    let lipDistanceRate: Double  // Rate of change of lip distance (pixels/frame)
    let confidence: Double  // 0.0-1.0 confidence score from Vision Framework
}

// Aggregated data for a meal session
struct MealSession {
    let sessionID: UUID
    let mealType: String  // "breakfast", "lunch", "snack", "dinner"
    let startTime: Date
    let endTime: Date
    let foodTypeHint: String?  // Parent-provided: "soft", "hard", "mixed", nil
    let childAge: UInt8  // 2-8 years

    let frames: [FrameAnalysis]  // All frame-by-frame data

    // Calculated metrics
    var continuityScore: Double = 0.0  // 0-100
    var rhythmScore: Double = 0.0      // 0-100
    var speedScore: Double = 0.0       // 0-100
    var durationScore: Double = 0.0    // 0-100
    var swallowScore: Double = 0.0     // 0-100
    var engagementScore: Double = 0.0  // 0-100

    var mealScore: Double { computeMealScore() }
    var bannedPattern: BannedPattern? = nil
    var earnedBadges: [Badge] = []
}

// Temporal data for rolling analysis
struct CircularBufferAnalysis {
    let windowSize: Int  // Typically 15 frames (1 second at 15fps)
    let slidingWindows: [FrameWindow]
}

struct FrameWindow {
    let frames: [FrameAnalysis]
    let windowIndex: Int
    let avgLipDistance: Double
    let lipDistanceVariance: Double
}
```

---

## 2. Metric Calculation Algorithms

### 2.1 Metric 1: Eating Continuity (20% weight)

**Definition**: Percentage of meal time with active eating motion

```swift
func calculateContinuity(meal: MealSession) -> Double {
    let eatingFrames = meal.frames.filter { $0.isEating }.count
    let totalFrames = meal.frames.count

    guard totalFrames > 0 else { return 0.0 }

    let continuityPercent = Double(eatingFrames) / Double(totalFrames) * 100.0
    return min(continuityPercent, 100.0)  // Cap at 100%
}

// Continuous eating period detection
func detectContinuousEatingPeriods(meal: MealSession) -> [EatingPeriod] {
    var periods: [EatingPeriod] = []
    var currentPeriod: EatingPeriod? = nil

    for frame in meal.frames {
        if frame.isEating {
            if currentPeriod == nil {
                currentPeriod = EatingPeriod(
                    startIndex: meal.frames.firstIndex(of: frame) ?? 0,
                    startTime: frame.timestamp
                )
            }
            currentPeriod?.endTime = frame.timestamp
        } else {
            if let period = currentPeriod {
                periods.append(period)
                currentPeriod = nil
            }
        }
    }

    if let period = currentPeriod {
        periods.append(period)
    }

    return periods
}

// Target ranges by age
let CONTINUITY_TARGETS: [UInt8: ClosedRange<Double>] = [
    2: 70...85,   // Age 2
    3: 70...85,   // Age 3
    4: 75...90,   // Age 4
    5: 75...90,   // Age 5
    6: 80...95,   // Age 6
    7: 80...95,   // Age 7
    8: 80...95    // Age 8
]

// Score normalization
func normalizeContinuityScore(
    percent: Double,
    childAge: UInt8
) -> Double {
    guard let targetRange = CONTINUITY_TARGETS[childAge] else {
        return 0.0  // Invalid age
    }

    if percent >= targetRange.upperBound {
        return 100.0  // Excellent
    } else if percent >= targetRange.lowerBound {
        // Linear interpolation within range
        let normalized = (percent - targetRange.lowerBound) /
                        (targetRange.upperBound - targetRange.lowerBound)
        return 70.0 + (normalized * 30.0)  // 70-100 range
    } else if percent >= targetRange.lowerBound * 0.7 {
        // Below range but close
        return 40.0 + ((percent - targetRange.lowerBound * 0.7) /
                      (targetRange.lowerBound - targetRange.lowerBound * 0.7) * 30.0)
    } else {
        // Well below range
        return max(0.0, (percent / (targetRange.lowerBound * 0.7)) * 40.0)
    }
}
```

**Implementation Notes**:
- Use existing `isEating` binary output from current VisionService
- Frame rate: 15 fps (1 frame = 67ms)
- Window: entire meal session
- No smoothing needed (already comes from current system)

---

### 2.2 Metric 2: Eating Rhythm Consistency (20% weight)

**Definition**: Regularity of chewing intervals (lower variance = better)

```swift
struct ChewPeak {
    let frameIndex: Int
    let timestamp: TimeInterval
    let lipDistanceRate: Double  // Peak value
}

func detectChewPeaks(
    frames: [FrameAnalysis],
    windowSize: Int = 7  // 7 frames = ~467ms window
) -> [ChewPeak] {
    var peaks: [ChewPeak] = []

    for i in windowSize...(frames.count - windowSize) {
        let center = frames[i].lipDistanceRate
        let leftMin = frames[(i-windowSize)...i-1].min(by: { $0.lipDistanceRate < $1.lipDistanceRate })?.lipDistanceRate ?? center
        let rightMin = frames[(i+1)...(i+windowSize)].min(by: { $0.lipDistanceRate < $1.lipDistanceRate })?.lipDistanceRate ?? center

        // Peak detection: local maximum
        if center > leftMin && center > rightMin && center > 0.05 {  // Threshold to avoid noise
            peaks.append(ChewPeak(
                frameIndex: i,
                timestamp: frames[i].timestamp,
                lipDistanceRate: center
            ))
        }
    }

    return peaks
}

func calculateChewIntervals(peaks: [ChewPeak]) -> [TimeInterval] {
    var intervals: [TimeInterval] = []

    for i in 0..<(peaks.count - 1) {
        let interval = peaks[i + 1].timestamp - peaks[i].timestamp
        intervals.append(interval)
    }

    return intervals
}

func calculateCoefficientOfVariation(values: [Double]) -> Double {
    guard values.count > 1 else { return 0.0 }

    let mean = values.reduce(0.0, +) / Double(values.count)
    guard mean > 0 else { return 0.0 }

    let variance = values.reduce(0.0) { sum, val in
        sum + pow(val - mean, 2)
    } / Double(values.count)

    let stdDev = sqrt(variance)
    return stdDev / mean  // Coefficient of Variation
}

func calculateRhythmScore(
    frames: [FrameAnalysis],
    childAge: UInt8
) -> Double {
    let peaks = detectChewPeaks(frames: frames)
    guard peaks.count > 3 else { return 50.0 }  // Not enough data

    let intervals = calculateChewIntervals(peaks: peaks)
    let cv = calculateCoefficientOfVariation(values: intervals)

    // Score formula from requirements
    let rhythmScore = min(100.0, 100.0 - (cv * 50.0))

    // Age-based expectations
    let ageTargets: [UInt8: ClosedRange<Double>] = [
        2: 0.30...0.50,  // Age 2: CV 30-50% acceptable
        3: 0.25...0.45,  // Age 3: CV 25-45% good
        4: 0.20...0.35,  // Age 4-5: CV 20-35%
        5: 0.20...0.35,
        6: 0.15...0.30,  // Age 6-8: CV 15-30% (more consistent)
        7: 0.15...0.30,
        8: 0.15...0.30
    ]

    guard let targetRange = ageTargets[childAge] else {
        return rhythmScore
    }

    // Adjust score based on age expectations
    if cv <= targetRange.lowerBound {
        return 100.0  // Excellent
    } else if cv <= targetRange.upperBound {
        let normalized = (cv - targetRange.lowerBound) /
                        (targetRange.upperBound - targetRange.lowerBound)
        return 90.0 - (normalized * 20.0)  // 90-70 range
    } else {
        return max(0.0, 70.0 - ((cv - targetRange.upperBound) * 30.0))
    }
}

// Detailed rhythm analysis for debugging
struct RhythmAnalysis {
    let peaks: [ChewPeak]
    let intervals: [TimeInterval]
    let meanInterval: TimeInterval
    let stdDeviation: TimeInterval
    let coefficientOfVariation: Double
    let estimatedChewsPerMinute: Double

    var interpretation: String {
        let chewsPerMin = estimatedChewsPerMinute
        switch coefficientOfVariation {
        case 0..<0.20: return "Excellent rhythm (\(String(format: "%.1f", chewsPerMin)) chews/min)"
        case 0.20..<0.35: return "Good rhythm (\(String(format: "%.1f", chewsPerMin)) chews/min)"
        case 0.35..<0.50: return "Fair rhythm (\(String(format: "%.1f", chewsPerMin)) chews/min)"
        default: return "Irregular rhythm (\(String(format: "%.1f", chewsPerMin)) chews/min)"
        }
    }
}
```

**Implementation Notes**:
- Requires peak detection in lip movement rate data
- Interval calculation: time between consecutive chew peaks
- Coefficient of Variation = StdDev / Mean (normalized variance)
- Typical chew rhythm: 0.8-1.5 seconds between peaks (0.67-1.25 Hz)

---

### 2.3 Metric 3: Appropriate Eating Speed (15% weight)

```swift
struct SpeedAnalysis {
    let peaksPerMinute: Double
    let ageOptimalRange: ClosedRange<Double>
    let isWithinRange: Bool
    let deviation: Double  // % from optimal
}

func calculateEatingSpeed(
    frames: [FrameAnalysis],
    childAge: UInt8
) -> Double {
    let peaks = detectChewPeaks(frames: frames)
    guard peaks.count > 2 else { return 50.0 }

    let mealDurationMinutes = (frames.last?.timestamp ?? 0) - (frames.first?.timestamp ?? 0)
    guard mealDurationMinutes > 0 else { return 50.0 }

    let chewsPerMinute = Double(peaks.count) / (mealDurationMinutes / 60.0)

    // Age-appropriate targets
    let speedTargets: [UInt8: (min: Double, optimal: Double, max: Double)] = [
        2: (min: 25, optimal: 35, max: 45),
        3: (min: 25, optimal: 35, max: 45),
        4: (min: 35, optimal: 45, max: 55),
        5: (min: 35, optimal: 45, max: 55),
        6: (min: 40, optimal: 50, max: 60),
        7: (min: 40, optimal: 50, max: 60),
        8: (min: 40, optimal: 50, max: 60)
    ]

    guard let target = speedTargets[childAge] else { return 0.0 }

    // Score calculation
    if chewsPerMinute >= target.min && chewsPerMinute <= target.max {
        // Within range: scale 60-100
        let normalized = (chewsPerMinute - target.min) / (target.max - target.min)
        return 60.0 + (normalized * 40.0)  // 60-100 range
    } else if chewsPerMinute > target.max {
        // Too fast: penalize
        let overage = (chewsPerMinute - target.max) / target.max
        return max(0.0, 60.0 - (overage * 40.0))  // Extra penalty for choking risk
    } else {
        // Too slow
        let underage = (target.min - chewsPerMinute) / target.min
        return max(0.0, 60.0 - (underage * 30.0))  // Smaller penalty
    }
}

// Analysis structure
func analyzeSpeed(
    frames: [FrameAnalysis],
    childAge: UInt8
) -> SpeedAnalysis {
    let peaks = detectChewPeaks(frames: frames)
    let mealDurationMinutes = (frames.last?.timestamp ?? 0) - (frames.first?.timestamp ?? 0)
    let chewsPerMinute = Double(peaks.count) / max(mealDurationMinutes / 60.0, 0.01)

    let speedTargets: [UInt8: (min: Double, optimal: Double, max: Double)] = [
        2: (min: 25, optimal: 35, max: 45),
        3: (min: 25, optimal: 35, max: 45),
        4: (min: 35, optimal: 45, max: 55),
        5: (min: 35, optimal: 45, max: 55),
        6: (min: 40, optimal: 50, max: 60),
        7: (min: 40, optimal: 50, max: 60),
        8: (min: 40, optimal: 50, max: 60)
    ]

    guard let target = speedTargets[childAge] else {
        return SpeedAnalysis(
            peaksPerMinute: chewsPerMinute,
            ageOptimalRange: 40...60,
            isWithinRange: false,
            deviation: 0.0
        )
    }

    let isWithinRange = chewsPerMinute >= target.min && chewsPerMinute <= target.max
    let deviation = ((chewsPerMinute - target.optimal) / target.optimal) * 100.0

    return SpeedAnalysis(
        peaksPerMinute: chewsPerMinute,
        ageOptimalRange: target.min...target.max,
        isWithinRange: isWithinRange,
        deviation: deviation
    )
}
```

**Implementation Notes**:
- Uses same peak detection as Rhythm metric
- Speed = peaks per minute over total meal duration
- Non-linear penalty: too fast > choking risk
- Too slow < physical difficulty (less penalizing)

---

### 2.4 Metric 4: Session Duration Appropriateness (15% weight)

```swift
enum FoodQuantity {
    case snack      // < 50g
    case smallMeal  // 50-100g
    case mediumMeal // 100-200g
    case largeMeal  // 200g+

    func optimalDurationRange(childAge: UInt8) -> ClosedRange<TimeInterval> {
        let ageFactorYounger = childAge <= 3

        switch self {
        case .snack:
            return ageFactorYounger ? 180...480 : 120...360     // 3-8 min vs 2-6 min
        case .smallMeal:
            return ageFactorYounger ? 360...720 : 300...600     // 6-12 min vs 5-10 min
        case .mediumMeal:
            return ageFactorYounger ? 480...900 : 600...1200    // 8-15 min vs 10-20 min
        case .largeMeal:
            return ageFactorYounger ? 720...1500 : 900...1800   // 12-25 min vs 15-30 min
        }
    }
}

func calculateDurationScore(
    mealDuration: TimeInterval,
    foodQuantity: FoodQuantity,
    childAge: UInt8
) -> Double {
    let optimalRange = foodQuantity.optimalDurationRange(childAge: childAge)
    let midpoint = (optimalRange.lowerBound + optimalRange.upperBound) / 2

    if mealDuration >= optimalRange.lowerBound && mealDuration <= optimalRange.upperBound {
        // Within optimal range: 75-100
        let normalized = (mealDuration - optimalRange.lowerBound) /
                        (optimalRange.upperBound - optimalRange.lowerBound)
        return 75.0 + (normalized * 25.0)
    } else if mealDuration < optimalRange.lowerBound {
        // Too short: potential insufficient intake
        let deviation = (optimalRange.lowerBound - mealDuration) / optimalRange.lowerBound
        return max(0.0, 75.0 - (deviation * 50.0))  // Heavy penalty
    } else {
        // Too long: fatigue or disengagement
        let deviation = (mealDuration - optimalRange.upperBound) / optimalRange.upperBound
        return max(0.0, 75.0 - (deviation * 35.0))  // Moderate penalty
    }
}

// Smart detection: infer food quantity from meal type hints
func inferFoodQuantity(mealType: String, foodTypeHint: String?) -> FoodQuantity {
    switch mealType.lowercased() {
    case "snack":
        return .snack
    case "breakfast", "lunch", "dinner":
        // Use parent hint if provided
        if let hint = foodTypeHint?.lowercased() {
            if hint.contains("large") { return .largeMeal }
            else if hint.contains("medium") { return .mediumMeal }
            else if hint.contains("small") { return .smallMeal }
        }
        // Default for meal type
        return .mediumMeal
    default:
        return .mediumMeal
    }
}
```

**Implementation Notes**:
- Parent can optionally provide food quantity hint
- System can infer from meal type (breakfast ≠ snack)
- Duration = endTime - startTime of meal
- Penalty for too-short meals > too-long meals (nutritional concern)

---

### 2.5 Metric 5: Swallowing Synchronization (10% weight)

**Challenge**: Vision Framework doesn't directly detect swallowing. Options:

#### Option A: Pattern-Based (High Confidence)
```swift
func estimateSwallowingSync(
    frames: [FrameAnalysis],
    peaks: [ChewPeak]
) -> Double {
    // Heuristic: After each chew peak, expect brief pause (swallow)
    // Then resume movement

    var properSwallows = 0

    for i in 0..<(peaks.count - 1) {
        let chewEndIdx = peaks[i].frameIndex
        let nextChewStartIdx = peaks[i + 1].frameIndex

        let pauseWindow = frames[chewEndIdx..<min(chewEndIdx + 5, nextChewStartIdx)]

        // Check for reduced movement (pause = swallow indicator)
        let avgMovement = pauseWindow.reduce(0.0) { $0 + abs($1.lipDistanceRate) } / Double(pauseWindow.count)

        if avgMovement < 0.05 {  // Threshold for pause
            properSwallows += 1
        }
    }

    let syncPercent = Double(properSwallows) / Double(peaks.count) * 100.0
    return min(syncPercent, 100.0)
}
```

#### Option B: Conservative Default
```swift
// If swallowing detection unreliable, default to 100%
// Avoids false negatives for struggling children
func getSwallowScore(frames: [FrameAnalysis]) -> Double {
    // Returns 100 if indeterminate (safe default)
    // Only reduces score if clear abnormality detected

    let peaks = detectChewPeaks(frames: frames)
    guard peaks.count > 3 else { return 100.0 }

    // Only penalize if extreme patterns detected
    let suspiciousPatterns = detectSuspiciousSwallowing(frames: frames, peaks: peaks)

    if suspiciousPatterns > peaks.count / 2 {
        // More than 50% of chews lack swallow pattern
        return 60.0
    }

    return 100.0
}

func detectSuspiciousSwallowing(
    frames: [FrameAnalysis],
    peaks: [ChewPeak]
) -> Int {
    // Detect: chewing without pause/swallow pattern
    var suspiciousCount = 0

    for i in 0..<(peaks.count - 1) {
        let interval = peaks[i + 1].timestamp - peaks[i].timestamp

        // Normal interval: 0.8-1.5 seconds
        // If too short (< 0.6s), might indicate no swallowing
        if interval < 0.6 {
            suspiciousCount += 1
        }
    }

    return suspiciousCount
}
```

**Recommendation**: Use Option B (conservative) for Phase 2. Implement Option A in Phase 3 with additional validation.

---

### 2.6 Metric 6: Engagement Consistency (10% weight)

```swift
struct PauseEvent {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let duration: TimeInterval

    var isLongPause: Bool {
        return duration > 10.0  // > 10 seconds
    }
}

func detectPauses(frames: [FrameAnalysis]) -> [PauseEvent] {
    var pauses: [PauseEvent] = []
    var pauseStart: TimeInterval? = nil

    for frame in frames {
        if !frame.isEating {
            if pauseStart == nil {
                pauseStart = frame.timestamp
            }
        } else {
            if let startTime = pauseStart {
                pauses.append(PauseEvent(
                    startTime: startTime,
                    endTime: frame.timestamp,
                    duration: frame.timestamp - startTime
                ))
                pauseStart = nil
            }
        }
    }

    if let startTime = pauseStart {
        pauses.append(PauseEvent(
            startTime: startTime,
            endTime: frames.last?.timestamp ?? startTime,
            duration: (frames.last?.timestamp ?? startTime) - startTime
        ))
    }

    return pauses
}

func calculateEngagementScore(meal: MealSession) -> Double {
    let pauses = detectPauses(frames: meal.frames)
    let longPauses = pauses.filter { $0.isLongPause }.count

    // Score formula from requirements
    let engagementScore = max(0.0, 100.0 - Double(longPauses) * 5.0)

    return min(engagementScore, 100.0)
}

// Detailed analysis
struct EngagementAnalysis {
    let totalPauses: Int
    let longPauses: Int  // > 10 seconds
    let shortPauses: Int  // < 10 seconds
    let meanPauseDuration: TimeInterval
    let longestPauseDuration: TimeInterval

    var engagement: String {
        switch longPauses {
        case 0:
            return "Excellent (no distractions)"
        case 1...2:
            return "Good (minimal distraction)"
        case 3...4:
            return "Fair (moderate distraction)"
        default:
            return "Poor (highly distracted)"
        }
    }
}
```

**Implementation Notes**:
- Uses existing `isEating` binary detection
- Long pause threshold: 10 seconds
- Each long pause: -5 points
- Maximum score remains 100

---

## 3. Meal Score Calculation

```swift
func computeMealScore(meal: MealSession) -> Double {
    let continuity = calculateContinuity(meal: meal)
    let rhythm = calculateRhythmScore(frames: meal.frames, childAge: meal.childAge)
    let speed = calculateEatingSpeed(frames: meal.frames, childAge: meal.childAge)
    let duration = calculateDurationScore(
        mealDuration: meal.endTime.timeIntervalSince(meal.startTime),
        foodQuantity: inferFoodQuantity(mealType: meal.mealType, foodTypeHint: meal.foodTypeHint),
        childAge: meal.childAge
    )
    let swallow = getSwallowScore(frames: meal.frames)
    let engagement = calculateEngagementScore(meal: meal)

    // Weighted average
    let baseScore = (
        continuity * 0.20 +
        rhythm * 0.20 +
        speed * 0.15 +
        duration * 0.15 +
        swallow * 0.10 +
        engagement * 0.10
    )

    // Add bonuses
    var bonusPoints = 0.0

    // Complete meal (no long pauses)
    if detectPauses(frames: meal.frames).filter({ $0.isLongPause }).isEmpty {
        bonusPoints += 5.0
    }

    // First meal of day (parent must track this context)
    // [Handled at application level]

    // Consistency streak bonuses
    // [Handled at application level]

    let finalScore = min(baseScore + bonusPoints, 100.0)
    return finalScore
}

// Score tier classification
enum MealScoreTier {
    case outstanding  // 85-100
    case excellent    // 70-84
    case good         // 55-69
    case fair         // 40-54
    case needsHelp    // 25-39
    case struggling   // 0-24

    static func fromScore(_ score: Double) -> MealScoreTier {
        switch score {
        case 85...100:
            return .outstanding
        case 70..<85:
            return .excellent
        case 55..<70:
            return .good
        case 40..<55:
            return .fair
        case 25..<40:
            return .needsHelp
        default:
            return .struggling
        }
    }

    var label: String {
        switch self {
        case .outstanding: return "Star Meal"
        case .excellent: return "Great Meal"
        case .good: return "Good Meal"
        case .fair: return "Learning Meal"
        case .needsHelp: return "Challenging Meal"
        case .struggling: return "Difficult Meal"
        }
    }
}
```

---

## 4. Weekly & Monthly Aggregation

```swift
struct WeeklyMetrics {
    let weekStart: Date
    let weekEnd: Date
    let mealsTracked: Int
    let mealsRequired: Int  // Typically 18-21 for 3 meals/day
    let averageMealScore: Double
    let consistencyBonus: Double
    let improvementBonus: Double

    var weeklyScore: Double {
        let completionPercent = Double(mealsTracked) / Double(mealsRequired)
        return (
            averageMealScore * 0.60 +
            consistencyBonus * 0.20 +
            improvementBonus * 0.20
        ) * completionPercent
    }

    // 0-500 scale for weekly
    var weeklyScoreNormalized: Double {
        return (weeklyScore / 100.0) * 500.0
    }
}

func calculateWeeklyMetrics(
    meals: [MealSession],
    previousWeekScore: Double?
) -> WeeklyMetrics {
    guard meals.count > 0 else {
        return WeeklyMetrics(
            weekStart: Date(),
            weekEnd: Date(),
            mealsTracked: 0,
            mealsRequired: 21,
            averageMealScore: 0,
            consistencyBonus: 0,
            improvementBonus: 0
        )
    }

    let avgScore = meals.reduce(0.0) { $0 + $1.mealScore } / Double(meals.count)

    // Consistency bonus
    let consistencyBonus: Double
    switch meals.count {
    case 18...: consistencyBonus = 20.0  // 7 days × 3 meals
    case 15..<18: consistencyBonus = 15.0
    case 9..<15: consistencyBonus = 10.0
    default: consistencyBonus = 5.0
    }

    // Improvement bonus
    let improvementBonus: Double
    if let prevScore = previousWeekScore {
        let improvement = avgScore - prevScore
        return max(0.0, min(20.0, improvement * 10.0))  // 0-20 point bonus
    }
    return 0.0

    let weekStart = meals.map { $0.startTime }.min() ?? Date()
    let weekEnd = meals.map { $0.endTime }.max() ?? Date()

    return WeeklyMetrics(
        weekStart: weekStart,
        weekEnd: weekEnd,
        mealsTracked: meals.count,
        mealsRequired: 21,
        averageMealScore: avgScore,
        consistencyBonus: consistencyBonus,
        improvementBonus: improvementBonus
    )
}

struct MonthlyMetrics {
    let monthYear: DateComponents  // Year, Month
    let weeks: [WeeklyMetrics]

    var monthlyScore: Double {
        let avgWeekly = weeks.reduce(0.0) { $0 + $1.weeklyScore } / Double(weeks.count)
        return avgWeekly
    }
}
```

---

## 5. Pattern Detection

### 5.1 Badge Earning Logic

```swift
enum Badge: Hashable {
    // Weekly badges
    case focusMaster
    case rhythmMaster
    case speedOptimizer
    case consistentPerformer

    // Monthly badges
    case improvementChampion
    case allStarEater
    case perfectWeek

    // Milestone badges
    case thirtyDayLegend
    case masterOfEating
    case healthyHabitsHero
    case personalRecord

    var pointsAwarded: Double {
        switch self {
        case .focusMaster: return 25
        case .rhythmMaster: return 20
        case .speedOptimizer: return 15
        case .consistentPerformer: return 50
        case .improvementChampion: return 40
        case .allStarEater: return 35
        case .perfectWeek: return 60
        case .thirtyDayLegend: return 100
        case .masterOfEating: return 150
        case .healthyHabitsHero: return 200
        case .personalRecord: return 75
        }
    }
}

func checkBadgeEarnings(
    meal: MealSession,
    recentMeals: [MealSession],
    weeklyData: WeeklyMetrics,
    previousBadges: Set<Badge>
) -> [Badge] {
    var earnedBadges: [Badge] = []

    // Focus Master: 3+ consecutive meals with high continuity & engagement
    let last3Meals = recentMeals.suffix(3)
    if last3Meals.count >= 3 {
        let avgContinuity = last3Meals.map { calculateContinuity(meal: $0) }.reduce(0, +) / 3.0
        let avgEngagement = last3Meals.map { calculateEngagementScore(meal: $0) }.reduce(0, +) / 3.0

        if avgContinuity > 80 && avgEngagement > 85 && !previousBadges.contains(.focusMaster) {
            earnedBadges.append(.focusMaster)
        }
    }

    // Rhythm Master: Single meal with excellent rhythm
    let rhythmScore = calculateRhythmScore(frames: meal.frames, childAge: meal.childAge)
    if rhythmScore > 85 && !previousBadges.contains(.rhythmMaster) {
        earnedBadges.append(.rhythmMaster)
    }

    // [Additional badge logic for other badges...]

    return earnedBadges
}
```

### 5.2 Concerning Pattern Detection

```swift
enum ConcerningPattern: Hashable {
    case frequentPauser
    case rhythmIrregularity
    case eatingSpeedExtreme(direction: SpeedDirection)
    case mealAbandonment
    case inconsistentPerformance

    enum SpeedDirection {
        case tooFast
        case tooSlow
    }
}

func detectConcerningPatterns(
    meal: MealSession,
    recentMeals: [MealSession]
) -> [ConcerningPattern] {
    var patterns: [ConcerningPattern] = []

    // Pattern 1: Frequent Pauser
    let engagement = calculateEngagementScore(meal: meal)
    let pauseCount = detectPauses(frames: meal.frames).filter { $0.isLongPause }.count

    if engagement < 60 && pauseCount >= 4 {
        patterns.append(.frequentPauser)
    }

    // Pattern 2: Rhythm Irregularity
    let rhythm = calculateRhythmScore(frames: meal.frames, childAge: meal.childAge)
    if rhythm < 50 {
        patterns.append(.rhythmIrregularity)
    }

    // Pattern 3: Eating Speed Extremes
    let speed = calculateEatingSpeed(frames: meal.frames, childAge: meal.childAge)
    if speed < 40 {
        patterns.append(.eatingSpeedExtreme(direction: .tooSlow))
    } else if speed < 35 {
        patterns.append(.eatingSpeedExtreme(direction: .tooFast))
    }

    // Pattern 4: Meal Abandonment
    let continuity = calculateContinuity(meal: meal)
    let duration = meal.endTime.timeIntervalSince(meal.startTime)
    if continuity < 30 && duration < 120 {
        patterns.append(.mealAbandonment)
    }

    // Pattern 5: Inconsistent Performer (requires recent meal history)
    let recentScores = recentMeals.map { $0.mealScore }
    let variance = calculateVariance(recentScores)
    if variance > 300 {  // High variance
        patterns.append(.inconsistentPerformance)
    }

    return patterns
}
```

---

## 6. Implementation Checklist

### Phase 2 Required Components

- [ ] `CircularBuffer` utility (already may exist)
- [ ] Peak detection algorithm
- [ ] Coefficient of Variation calculation
- [ ] Age-based target ranges (hardcoded data structure)
- [ ] Metric 1: Continuity (uses existing isEating)
- [ ] Metric 2: Rhythm (peak detection + CV)
- [ ] Metric 3: Speed (peak frequency)
- [ ] Metric 4: Duration (timestamp math)
- [ ] Metric 5: Swallowing (conservative default or pattern-based)
- [ ] Metric 6: Engagement (pause detection)
- [ ] Meal Score calculation (weighted average)
- [ ] Score tier classification
- [ ] Weekly/Monthly aggregation
- [ ] Basic badge detection

### Phase 3 Enhancements

- [ ] Advanced pattern detection
- [ ] Concerning pattern flagging with alerts
- [ ] Detailed analytics reporting
- [ ] Badge system expansion
- [ ] Intervention recommendations

### Phase 4+ Features

- [ ] Predictive modeling
- [ ] Metrics 7A-C (food adaptation, bite size, distraction)
- [ ] ML-based personalization

---

## 7. Testing Requirements

```swift
// Unit test template
func testContinuityCalculation() {
    // Arrange: Create meal with 80% eating frames
    let eating = Array(repeating: FrameAnalysis(..., isEating: true), count: 80)
    let notEating = Array(repeating: FrameAnalysis(..., isEating: false), count: 20)
    let meal = MealSession(frames: eating + notEating, childAge: 4)

    // Act
    let continuity = calculateContinuity(meal: meal)

    // Assert
    XCTAssertEqual(continuity, 80.0, accuracy: 0.1)
}

// Integration test with real video data
func testMetricsWithSampleVideo() {
    // Load sample eating video
    // Extract frames with current VisionService
    // Calculate all metrics
    // Verify scores are reasonable and correlate
}
```

---

## References

- **Pediatric Feeding**: Gesell Institute developmental norms
- **Biometrics**: Coefficient of Variation (statistical measure)
- **Validation**: Real-world video dataset with ground truth labels
- **Age Norms**: CDC pediatric development guidelines

---

**Document Version**: 1.0
**Last Updated**: 2025-11-19
**Status**: Ready for Phase 2 Implementation
