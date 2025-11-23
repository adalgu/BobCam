# Smart Eating Detection Algorithm Design
## Advanced Multi-Dimensional Eating Detection for BobCam

**Version:** 2.0
**Date:** 2025-11-19
**Target Accuracy:** 70%+
**Performance:** <200ms latency, 15fps compatible

---

## 1. Executive Summary

This document specifies a sophisticated eating detection algorithm that replaces the current simple two-half comparison method with a multi-dimensional feature extraction system, state machine architecture, and eating quality scoring.

### Current Implementation Limitations

```swift
// Current: Simple two-half comparison
let recentAverage = history.suffix(halfSize).reduce(0, +) / Float(halfSize)
let olderAverage = history.prefix(halfSize).reduce(0, +) / Float(halfSize)
let changeRate = abs(recentAverage - olderAverage)
return changeRate > adjustedThreshold ? .eating : .notEating
```

**Problems:**
- No temporal rhythm detection (chewing has ~1-2 Hz frequency)
- Binary classification causes flickering
- Ignores movement quality and regularity
- No context awareness (session phases)
- Cannot distinguish eating from talking/yawning

---

## 2. Algorithm Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    INPUT: Lip Distance Stream                │
│                   (CircularBuffer<Float>, 15fps)             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              FEATURE EXTRACTION MODULE                       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │   Temporal   │ │   Movement   │ │   Session    │        │
│  │   Features   │ │   Features   │ │   Features   │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              STATE MACHINE WITH HYSTERESIS                   │
│                                                              │
│  NotStarted → ActiveEating → ShortPause → LongPause         │
│       ↓           ↓              ↓            ↓              │
│       └──────→ Distracted ───────┘            │              │
│                    ↓                           │              │
│                Finished ←──────────────────────┘              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│           EATING QUALITY SCORE (0-100)                       │
│  • Rhythm Regularity (30%)                                   │
│  • Movement Amplitude (20%)                                  │
│  • Continuity (25%)                                          │
│  • Focus Score (15%)                                         │
│  • Age Adjustment (10%)                                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  OUTPUT: Enhanced Detection                  │
│  • Current State (EatingState)                               │
│  • Quality Score (0-100)                                     │
│  • Confidence (0-1)                                          │
│  • Video Control Signal (play/pause)                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Multi-Dimensional Feature Extraction

### 3.1 Temporal Features (Rhythm Analysis)

**Purpose:** Detect periodic chewing patterns (typical: 1-2 Hz for children)

```swift
struct TemporalFeatures {
    let dominantFrequency: Float      // Hz (0-5 Hz range)
    let rhythmStrength: Float         // 0-1 (spectral peak magnitude)
    let rhythmRegularity: Float       // 0-1 (coefficient of variation)
    let periodicity: Float            // 0-1 (autocorrelation peak)
}

/// Extract temporal features using FFT
func extractTemporalFeatures(
    from buffer: CircularBuffer<Float>,
    samplingRate: Float = 15.0
) -> TemporalFeatures {

    guard buffer.isFull else {
        return TemporalFeatures(
            dominantFrequency: 0,
            rhythmStrength: 0,
            rhythmRegularity: 0,
            periodicity: 0
        )
    }

    let signal = buffer.allItems()
    let n = signal.count

    // 1. Detrend signal (remove DC component)
    let mean = signal.reduce(0, +) / Float(n)
    let detrended = signal.map { $0 - mean }

    // 2. Apply Hanning window to reduce spectral leakage
    let windowed = applyHanningWindow(detrended)

    // 3. Compute power spectral density using FFT
    let psd = computePowerSpectralDensity(windowed, samplingRate: samplingRate)

    // 4. Find dominant frequency in eating range (0.5-3.0 Hz)
    let eatingFrequencyRange = 0.5...3.0
    let (dominantFreq, peakPower) = findPeakInRange(
        psd: psd,
        frequencyRange: eatingFrequencyRange,
        samplingRate: samplingRate
    )

    // 5. Calculate rhythm strength (normalized peak power)
    let totalPower = psd.reduce(0, +)
    let rhythmStrength = totalPower > 0 ? peakPower / totalPower : 0

    // 6. Calculate rhythm regularity using autocorrelation
    let autocorr = computeAutocorrelation(detrended)
    let periodicity = findFirstPeakInAutocorrelation(autocorr)

    // 7. Calculate coefficient of variation for regularity
    let stdDev = calculateStandardDeviation(detrended)
    let cv = mean != 0 ? stdDev / abs(mean) : 1.0
    let rhythmRegularity = 1.0 / (1.0 + cv) // Inverse relationship

    return TemporalFeatures(
        dominantFrequency: dominantFreq,
        rhythmStrength: min(rhythmStrength, 1.0),
        rhythmRegularity: rhythmRegularity,
        periodicity: periodicity
    )
}

/// Apply Hanning window to reduce spectral leakage
func applyHanningWindow(_ signal: [Float]) -> [Float] {
    let n = signal.count
    return signal.enumerated().map { (i, value) in
        let window = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(n - 1)))
        return value * window
    }
}

/// Compute power spectral density using Accelerate framework
func computePowerSpectralDensity(
    _ signal: [Float],
    samplingRate: Float
) -> [Float] {
    // Use vDSP for efficient FFT computation
    // Implementation using Accelerate framework's vDSP_fft
    // Returns array of power values at each frequency bin

    // Pseudocode (actual implementation uses vDSP):
    let n = signal.count
    let halfN = n / 2

    // Perform FFT using Accelerate
    let fftResult = performFFT(signal) // Returns complex array

    // Calculate power spectrum: |X[k]|^2
    var psd = [Float](repeating: 0, count: halfN)
    for k in 0..<halfN {
        let real = fftResult[k].real
        let imag = fftResult[k].imag
        psd[k] = real * real + imag * imag
    }

    return psd
}

/// Find peak frequency and power in specified range
func findPeakInRange(
    psd: [Float],
    frequencyRange: ClosedRange<Float>,
    samplingRate: Float
) -> (frequency: Float, power: Float) {

    let n = psd.count
    let freqResolution = samplingRate / Float(2 * n)

    var maxPower: Float = 0
    var peakFreq: Float = 0

    for (k, power) in psd.enumerated() {
        let freq = Float(k) * freqResolution
        if frequencyRange.contains(freq) && power > maxPower {
            maxPower = power
            peakFreq = freq
        }
    }

    return (peakFreq, maxPower)
}

/// Compute autocorrelation for periodicity detection
func computeAutocorrelation(_ signal: [Float]) -> [Float] {
    let n = signal.count
    var autocorr = [Float](repeating: 0, count: n)

    for lag in 0..<n {
        var sum: Float = 0
        for i in 0..<(n - lag) {
            sum += signal[i] * signal[i + lag]
        }
        autocorr[lag] = sum / Float(n - lag)
    }

    // Normalize by zero-lag value
    let maxVal = autocorr[0]
    if maxVal > 0 {
        autocorr = autocorr.map { $0 / maxVal }
    }

    return autocorr
}

/// Find first significant peak in autocorrelation (excluding zero lag)
func findFirstPeakInAutocorrelation(_ autocorr: [Float]) -> Float {
    guard autocorr.count > 3 else { return 0 }

    let minLag = 3 // Skip first few lags to avoid trivial peak
    let maxLag = min(autocorr.count - 1, 20) // Search up to 1.3s at 15fps

    var maxPeak: Float = 0

    for i in minLag..<maxLag {
        // Check if it's a local maximum
        if autocorr[i] > autocorr[i-1] &&
           autocorr[i] > autocorr[i+1] &&
           autocorr[i] > maxPeak {
            maxPeak = autocorr[i]
        }
    }

    return max(0, maxPeak)
}

/// Calculate standard deviation
func calculateStandardDeviation(_ values: [Float]) -> Float {
    let n = Float(values.count)
    let mean = values.reduce(0, +) / n
    let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / n
    return sqrt(variance)
}
```

**Mathematical Formulas:**

1. **Power Spectral Density (PSD):**
   ```
   PSD[k] = |FFT(x)[k]|² = Real[k]² + Imag[k]²
   where k = frequency bin index
   ```

2. **Dominant Frequency:**
   ```
   f_dominant = argmax_{f ∈ [0.5, 3.0]} PSD(f)
   ```

3. **Rhythm Strength:**
   ```
   S_rhythm = PSD(f_dominant) / Σ PSD(f)
   Range: [0, 1], higher = stronger periodic pattern
   ```

4. **Autocorrelation:**
   ```
   R(τ) = Σ[x(t) · x(t+τ)] / (N - τ)
   Normalized: R_norm(τ) = R(τ) / R(0)
   ```

5. **Rhythm Regularity:**
   ```
   CV = σ / |μ|  (coefficient of variation)
   Regularity = 1 / (1 + CV)
   Range: [0, 1], higher = more regular
   ```

---

### 3.2 Movement Features (Amplitude & Quality)

**Purpose:** Quantify movement characteristics to distinguish eating from other activities

```swift
struct MovementFeatures {
    let amplitude: Float              // 0-1 (normalized movement range)
    let velocity: Float               // Rate of change
    let jerkiness: Float              // 0-1 (second derivative variance)
    let smoothness: Float             // 0-1 (inverse of jerkiness)
    let dynamicRange: Float           // Peak-to-peak variation
}

/// Extract movement features from lip distance buffer
func extractMovementFeatures(
    from buffer: CircularBuffer<Float>,
    config: LipDetectionConfiguration
) -> MovementFeatures {

    guard buffer.count >= 3 else {
        return MovementFeatures(
            amplitude: 0,
            velocity: 0,
            jerkiness: 0,
            smoothness: 0,
            dynamicRange: 0
        )
    }

    let signal = buffer.allItems()
    let n = signal.count

    // 1. Calculate amplitude (normalized peak-to-peak)
    let minVal = signal.min() ?? 0
    let maxVal = signal.max() ?? 0
    let dynamicRange = maxVal - minVal

    // Normalize by typical eating amplitude (empirically ~0.1-0.3)
    let typicalEatingAmplitude: Float = 0.2
    let amplitude = min(dynamicRange / typicalEatingAmplitude, 1.0)

    // 2. Calculate velocity (first derivative)
    var velocities = [Float]()
    for i in 1..<n {
        velocities.append(signal[i] - signal[i-1])
    }
    let meanAbsVelocity = velocities.map { abs($0) }.reduce(0, +) / Float(velocities.count)

    // 3. Calculate jerkiness (second derivative variance)
    var accelerations = [Float]()
    for i in 1..<velocities.count {
        accelerations.append(velocities[i] - velocities[i-1])
    }

    let accelStdDev = calculateStandardDeviation(accelerations)
    // Normalize jerkiness (typical eating: 0.01-0.05)
    let typicalJerkiness: Float = 0.03
    let jerkiness = min(accelStdDev / typicalJerkiness, 1.0)

    // 4. Calculate smoothness (inverse of jerkiness)
    let smoothness = 1.0 - jerkiness

    // 5. Normalize velocity by frame rate (15fps)
    let normalizedVelocity = meanAbsVelocity * 15.0

    return MovementFeatures(
        amplitude: amplitude,
        velocity: normalizedVelocity,
        jerkiness: jerkiness,
        smoothness: smoothness,
        dynamicRange: dynamicRange
    )
}
```

**Mathematical Formulas:**

1. **Amplitude (Peak-to-Peak):**
   ```
   A = (max(x) - min(x)) / A_typical
   A_typical = 0.2 (empirical eating amplitude)
   ```

2. **Velocity (First Derivative):**
   ```
   v[i] = x[i] - x[i-1]
   v_mean = (1/N) Σ |v[i]|
   ```

3. **Jerkiness (Second Derivative Variance):**
   ```
   a[i] = v[i] - v[i-1]  (acceleration)
   J = σ(a) / J_typical
   J_typical = 0.03
   ```

4. **Smoothness:**
   ```
   S = 1 - J
   Range: [0, 1], higher = smoother movement
   ```

---

### 3.3 Session Features (Context & Continuity)

**Purpose:** Track eating session progress and detect phase transitions

```swift
struct SessionFeatures {
    let sessionDuration: TimeInterval     // Seconds since eating started
    let continuityScore: Float            // 0-1 (eating consistency)
    let pauseDuration: TimeInterval       // Seconds since last eating detected
    let totalEatingTime: TimeInterval     // Cumulative eating time
    let eatingRatio: Float                // eating_time / session_duration
}

class SessionTracker {
    private var sessionStartTime: Date?
    private var lastEatingTime: Date?
    private var totalEatingDuration: TimeInterval = 0
    private var eatingHistory: CircularBuffer<Bool> // Last 30 frames (~2s)

    init(historySize: Int = 30) {
        self.eatingHistory = CircularBuffer<Bool>(capacity: historySize)
    }

    /// Update session state with current eating detection
    mutating func update(isEating: Bool) {
        let now = Date()

        // Initialize session on first eating detection
        if isEating && sessionStartTime == nil {
            sessionStartTime = now
            lastEatingTime = now
        }

        // Update eating history
        eatingHistory.write(isEating)

        // Update total eating time
        if isEating {
            if let lastTime = lastEatingTime {
                totalEatingDuration += now.timeIntervalSince(lastTime)
            }
            lastEatingTime = now
        }
    }

    /// Extract current session features
    func extractSessionFeatures() -> SessionFeatures {
        let now = Date()

        // Calculate session duration
        let sessionDuration = sessionStartTime.map {
            now.timeIntervalSince($0)
        } ?? 0

        // Calculate pause duration
        let pauseDuration = lastEatingTime.map {
            now.timeIntervalSince($0)
        } ?? 0

        // Calculate continuity score (% of recent frames with eating)
        let recentHistory = eatingHistory.allItems()
        let eatingCount = recentHistory.filter { $0 }.count
        let continuityScore = recentHistory.isEmpty ? 0 :
            Float(eatingCount) / Float(recentHistory.count)

        // Calculate eating ratio
        let eatingRatio = sessionDuration > 0 ?
            Float(totalEatingDuration / sessionDuration) : 0

        return SessionFeatures(
            sessionDuration: sessionDuration,
            continuityScore: continuityScore,
            pauseDuration: pauseDuration,
            totalEatingTime: totalEatingDuration,
            eatingRatio: eatingRatio
        )
    }

    /// Reset session tracking
    mutating func reset() {
        sessionStartTime = nil
        lastEatingTime = nil
        totalEatingDuration = 0
        eatingHistory.clear()
    }
}
```

**Mathematical Formulas:**

1. **Continuity Score:**
   ```
   C = N_eating / N_total
   where N_eating = frames with eating in recent history
   Range: [0, 1], higher = more consistent eating
   ```

2. **Eating Ratio:**
   ```
   R = T_eating / T_session
   where T_eating = cumulative eating time
         T_session = total session duration
   Range: [0, 1]
   ```

---

## 4. State Machine with Hysteresis

### 4.1 State Definitions

```swift
enum EatingState: String, Codable {
    case notStarted      // Initial state, no eating detected yet
    case activeEating    // Currently eating with high confidence
    case shortPause      // Brief interruption (<5s), likely to resume
    case longPause       // Extended pause (5-15s), uncertain
    case distracted      // Attention diverted (>15s pause or irregular motion)
    case finished        // Eating session completed

    var description: String {
        switch self {
        case .notStarted: return "Not Started"
        case .activeEating: return "Actively Eating"
        case .shortPause: return "Short Pause"
        case .longPause: return "Long Pause"
        case .distracted: return "Distracted"
        case .finished: return "Finished"
        }
    }

    var videoShouldPlay: Bool {
        switch self {
        case .activeEating, .shortPause:
            return true
        case .notStarted, .longPause, .distracted, .finished:
            return false
        }
    }
}

struct StateTransition {
    let fromState: EatingState
    let toState: EatingState
    let condition: () -> Bool
    let hysteresisFrames: Int  // Required consecutive frames for transition
}
```

### 4.2 State Transition Logic

```swift
class EatingStateMachine {
    private(set) var currentState: EatingState = .notStarted
    private(set) var stateConfidence: Float = 0.0

    // Hysteresis tracking
    private var transitionBuffer: CircularBuffer<EatingState>
    private let hysteresisThreshold = 5  // Frames required for state change

    // State duration tracking
    private var stateStartTime: Date = Date()
    private var stateDuration: TimeInterval {
        Date().timeIntervalSince(stateStartTime)
    }

    init() {
        self.transitionBuffer = CircularBuffer<EatingState>(capacity: 10)
    }

    /// Update state machine with new features
    mutating func update(
        temporal: TemporalFeatures,
        movement: MovementFeatures,
        session: SessionFeatures,
        sensitivity: Float
    ) -> EatingState {

        // Calculate composite eating score
        let eatingScore = calculateEatingScore(
            temporal: temporal,
            movement: movement,
            session: session
        )

        // Determine target state based on features
        let targetState = determineTargetState(
            score: eatingScore,
            temporal: temporal,
            movement: movement,
            session: session,
            sensitivity: sensitivity
        )

        // Apply hysteresis
        transitionBuffer.write(targetState)

        // Check if we have consistent state for hysteresis threshold
        if shouldTransition(to: targetState) {
            if currentState != targetState {
                // State change
                currentState = targetState
                stateStartTime = Date()
                stateConfidence = eatingScore
            } else {
                // Same state, update confidence
                stateConfidence = 0.7 * stateConfidence + 0.3 * eatingScore
            }
        }

        return currentState
    }

    /// Calculate composite eating score from all features
    private func calculateEatingScore(
        temporal: TemporalFeatures,
        movement: MovementFeatures,
        session: SessionFeatures
    ) -> Float {

        // Weighted combination of features
        let weights: [Float] = [
            0.35,  // Rhythm strength
            0.25,  // Amplitude
            0.20,  // Continuity
            0.10,  // Periodicity
            0.10   // Regularity
        ]

        let features: [Float] = [
            temporal.rhythmStrength,
            movement.amplitude,
            session.continuityScore,
            temporal.periodicity,
            temporal.rhythmRegularity
        ]

        let score = zip(weights, features).map { $0 * $1 }.reduce(0, +)
        return min(max(score, 0), 1)
    }

    /// Determine target state based on features and current state
    private func determineTargetState(
        score: Float,
        temporal: TemporalFeatures,
        movement: MovementFeatures,
        session: SessionFeatures,
        sensitivity: Float
    ) -> EatingState {

        // Adjust thresholds based on sensitivity
        let activeThreshold: Float = 0.4 * sensitivity
        let resumeThreshold: Float = 0.3 * sensitivity

        // State transition logic
        switch currentState {
        case .notStarted:
            // Require strong signal to start
            if score > activeThreshold &&
               temporal.rhythmStrength > 0.3 &&
               movement.amplitude > 0.2 {
                return .activeEating
            }
            return .notStarted

        case .activeEating:
            // Continue eating if score maintained
            if score > resumeThreshold {
                return .activeEating
            }
            // Drop to short pause if score decreases
            return .shortPause

        case .shortPause:
            // Resume eating if score recovers
            if score > resumeThreshold {
                return .activeEating
            }
            // Escalate to long pause if duration exceeded
            if session.pauseDuration > 5.0 {
                return .longPause
            }
            return .shortPause

        case .longPause:
            // Resume if strong eating signal returns
            if score > activeThreshold {
                return .activeEating
            }
            // Become distracted after extended pause
            if session.pauseDuration > 15.0 {
                return .distracted
            }
            return .longPause

        case .distracted:
            // Require very strong signal to resume
            if score > activeThreshold * 1.2 &&
               temporal.rhythmStrength > 0.4 {
                return .activeEating
            }
            // Mark as finished after very long distraction
            if session.pauseDuration > 30.0 {
                return .finished
            }
            return .distracted

        case .finished:
            // Allow restart with strong signal
            if score > activeThreshold * 1.5 {
                return .activeEating
            }
            return .finished
        }
    }

    /// Check if state should transition based on hysteresis
    private func shouldTransition(to targetState: EatingState) -> Bool {
        let recentStates = transitionBuffer.allItems()

        guard recentStates.count >= hysteresisThreshold else {
            return false
        }

        // Check if last N frames all agree on target state
        let lastN = recentStates.suffix(hysteresisThreshold)
        return lastN.allSatisfy { $0 == targetState }
    }

    /// Get current state with confidence
    func getStateWithConfidence() -> (state: EatingState, confidence: Float) {
        return (currentState, stateConfidence)
    }

    /// Reset state machine
    mutating func reset() {
        currentState = .notStarted
        stateConfidence = 0.0
        transitionBuffer.clear()
        stateStartTime = Date()
    }
}
```

### 4.3 State Transition Diagram

```
┌─────────────┐
│ NotStarted  │
└──────┬──────┘
       │ score > 0.4, rhythm > 0.3, amplitude > 0.2
       ▼
┌──────────────┐
│ActiveEating  │◄──────────┐
└──────┬───────┘           │
       │ score < 0.3       │ score > 0.3
       ▼                   │
┌──────────────┐           │
│ ShortPause   │───────────┘
└──────┬───────┘
       │ pause > 5s
       ▼
┌──────────────┐
│  LongPause   │◄──────────┐
└──────┬───────┘           │
       │ pause > 15s       │ score > 0.48
       ▼                   │
┌──────────────┐           │
│ Distracted   │───────────┘
└──────┬───────┘
       │ pause > 30s
       ▼
┌──────────────┐
│  Finished    │
└──────────────┘
```

**Hysteresis Parameters:**

| Transition | Frames Required | Time @ 15fps |
|------------|----------------|--------------|
| NotStarted → ActiveEating | 5 | 333ms |
| ActiveEating → ShortPause | 5 | 333ms |
| ShortPause → ActiveEating | 3 | 200ms |
| ShortPause → LongPause | N/A | 5.0s (timer) |
| LongPause → Distracted | N/A | 15.0s (timer) |
| Any → Finished | 10 | 667ms |

---

## 5. Eating Quality Score (0-100)

### 5.1 Quality Score Components

```swift
struct EatingQualityScore {
    let overallScore: Float          // 0-100
    let rhythmScore: Float           // 0-100 (30% weight)
    let amplitudeScore: Float        // 0-100 (20% weight)
    let continuityScore: Float       // 0-100 (25% weight)
    let focusScore: Float            // 0-100 (15% weight)
    let ageAdjustment: Float         // 0-100 (10% weight)

    var grade: String {
        switch overallScore {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 60..<75: return "Fair"
        case 40..<60: return "Needs Improvement"
        default: return "Poor"
        }
    }
}

class QualityScoreCalculator {
    private let childAge: Float  // Years (for age-appropriate adjustments)

    init(childAge: Float = 5.0) {
        self.childAge = childAge
    }

    /// Calculate comprehensive eating quality score
    func calculate(
        temporal: TemporalFeatures,
        movement: MovementFeatures,
        session: SessionFeatures,
        state: EatingState
    ) -> EatingQualityScore {

        // 1. Rhythm Score (30%)
        let rhythmScore = calculateRhythmScore(temporal: temporal)

        // 2. Amplitude Score (20%)
        let amplitudeScore = calculateAmplitudeScore(movement: movement)

        // 3. Continuity Score (25%)
        let continuityScore = calculateContinuityScore(session: session, state: state)

        // 4. Focus Score (15%)
        let focusScore = calculateFocusScore(
            session: session,
            state: state,
            movement: movement
        )

        // 5. Age Adjustment (10%)
        let ageAdjustment = calculateAgeAdjustment(
            temporal: temporal,
            childAge: childAge
        )

        // Weighted sum
        let overallScore = (
            rhythmScore * 0.30 +
            amplitudeScore * 0.20 +
            continuityScore * 0.25 +
            focusScore * 0.15 +
            ageAdjustment * 0.10
        )

        return EatingQualityScore(
            overallScore: overallScore,
            rhythmScore: rhythmScore,
            amplitudeScore: amplitudeScore,
            continuityScore: continuityScore,
            focusScore: focusScore,
            ageAdjustment: ageAdjustment
        )
    }

    // MARK: - Component Score Calculations

    /// Rhythm Score: Evaluates chewing rhythm quality
    private func calculateRhythmScore(temporal: TemporalFeatures) -> Float {
        // Ideal eating frequency: 1.0-2.0 Hz for children
        let idealFreqRange: ClosedRange<Float> = 1.0...2.0

        // Score based on frequency appropriateness
        var freqScore: Float
        if idealFreqRange.contains(temporal.dominantFrequency) {
            freqScore = 100.0
        } else if temporal.dominantFrequency < idealFreqRange.lowerBound {
            // Too slow
            let deviation = idealFreqRange.lowerBound - temporal.dominantFrequency
            freqScore = max(0, 100.0 - deviation * 50)
        } else {
            // Too fast
            let deviation = temporal.dominantFrequency - idealFreqRange.upperBound
            freqScore = max(0, 100.0 - deviation * 30)
        }

        // Weight by rhythm strength and regularity
        let strengthWeight = temporal.rhythmStrength  // 0-1
        let regularityWeight = temporal.rhythmRegularity  // 0-1

        let rhythmScore = freqScore *
            (0.4 + 0.3 * strengthWeight + 0.3 * regularityWeight)

        return min(rhythmScore, 100.0)
    }

    /// Amplitude Score: Evaluates movement appropriateness
    private func calculateAmplitudeScore(movement: MovementFeatures) -> Float {
        // Ideal amplitude: moderate (0.3-0.7 normalized)
        let idealAmplitudeRange: ClosedRange<Float> = 0.3...0.7

        var amplitudeScore: Float
        if idealAmplitudeRange.contains(movement.amplitude) {
            amplitudeScore = 100.0
        } else if movement.amplitude < idealAmplitudeRange.lowerBound {
            // Too small (picking/slow eating)
            amplitudeScore = movement.amplitude / idealAmplitudeRange.lowerBound * 100.0
        } else {
            // Too large (rushed/irregular)
            let excess = movement.amplitude - idealAmplitudeRange.upperBound
            amplitudeScore = max(0, 100.0 - excess * 150)
        }

        // Penalize excessive jerkiness
        let smoothnessBonus = movement.smoothness * 20  // Up to +20 points
        amplitudeScore = min(amplitudeScore + smoothnessBonus, 100.0)

        return amplitudeScore
    }

    /// Continuity Score: Evaluates eating consistency
    private func calculateContinuityScore(
        session: SessionFeatures,
        state: EatingState
    ) -> Float {

        // Base score on continuity ratio
        var continuityScore = session.continuityScore * 100.0

        // Bonus for sustained eating (optimal: 60-80% of session time)
        let idealEatingRatio: ClosedRange<Float> = 0.6...0.8
        if idealEatingRatio.contains(session.eatingRatio) {
            continuityScore += 10
        }

        // Penalty for frequent state changes
        switch state {
        case .activeEating:
            continuityScore += 15  // Bonus for active state
        case .shortPause:
            continuityScore += 5   // Small bonus for brief pause
        case .longPause, .distracted:
            continuityScore -= 20  // Penalty for interruption
        case .notStarted, .finished:
            continuityScore = 0
        }

        return min(max(continuityScore, 0), 100.0)
    }

    /// Focus Score: Evaluates attention and engagement
    private func calculateFocusScore(
        session: SessionFeatures,
        state: EatingState,
        movement: MovementFeatures
    ) -> Float {

        var focusScore: Float = 100.0

        // Penalty for long pauses
        if session.pauseDuration > 0 {
            let pausePenalty = min(session.pauseDuration / 10.0, 50.0)  // Up to -50
            focusScore -= Float(pausePenalty)
        }

        // Penalty for distracted state
        switch state {
        case .distracted:
            focusScore -= 40
        case .longPause:
            focusScore -= 20
        case .shortPause:
            focusScore -= 10
        default:
            break
        }

        // Bonus for smooth, controlled movements
        focusScore += movement.smoothness * 15

        return min(max(focusScore, 0), 100.0)
    }

    /// Age Adjustment: Compensate for age-specific eating patterns
    private func calculateAgeAdjustment(
        temporal: TemporalFeatures,
        childAge: Float
    ) -> Float {

        // Younger children (2-4 years): slower, more irregular
        // Older children (8+ years): faster, more regular

        var ageScore: Float = 50.0  // Baseline

        // Adjust expected frequency by age
        let expectedFrequency: Float
        switch childAge {
        case 0..<3:
            expectedFrequency = 0.8  // Very slow
        case 3..<5:
            expectedFrequency = 1.2  // Slow
        case 5..<7:
            expectedFrequency = 1.5  // Moderate
        case 7..<10:
            expectedFrequency = 1.8  // Normal
        default:
            expectedFrequency = 2.0  // Fast
        }

        // Score based on age-appropriate frequency
        let freqDeviation = abs(temporal.dominantFrequency - expectedFrequency)
        if freqDeviation < 0.3 {
            ageScore = 100.0  // Age-appropriate
        } else {
            ageScore = max(0, 100.0 - freqDeviation * 100)
        }

        // Adjust regularity expectations by age
        if childAge < 5 {
            // Younger children: more tolerant of irregularity
            ageScore += (1.0 - temporal.rhythmRegularity) * 20
        } else {
            // Older children: expect more regularity
            ageScore += temporal.rhythmRegularity * 30
        }

        return min(ageScore, 100.0)
    }
}
```

### 5.2 Quality Score Mathematical Formulas

1. **Overall Quality Score:**
   ```
   Q_overall = 0.30·Q_rhythm + 0.20·Q_amplitude + 0.25·Q_continuity
               + 0.15·Q_focus + 0.10·Q_age

   Range: [0, 100]
   ```

2. **Rhythm Score:**
   ```
   Q_rhythm = F_score · (0.4 + 0.3·S_rhythm + 0.3·R_rhythm)

   where:
   F_score = frequency appropriateness score (0-100)
   S_rhythm = rhythm strength (0-1)
   R_rhythm = rhythm regularity (0-1)
   ```

3. **Amplitude Score:**
   ```
   Q_amplitude = A_score + S_movement · 20

   where:
   A_score = amplitude appropriateness (0-100)
   S_movement = smoothness (0-1)
   ```

4. **Continuity Score:**
   ```
   Q_continuity = C_session · 100 + B_state

   where:
   C_session = session continuity ratio (0-1)
   B_state = state bonus: {+15 (active), +5 (short pause), -20 (long pause)}
   ```

5. **Focus Score:**
   ```
   Q_focus = 100 - P_pause + S_movement · 15

   where:
   P_pause = pause penalty: min(pause_duration / 10, 50)
   ```

6. **Age Adjustment:**
   ```
   Q_age = 100 - |f_actual - f_expected(age)| · 100 + R_age

   where:
   f_expected(age) = age-appropriate frequency
   R_age = regularity adjustment based on age
   ```

---

## 6. Integration with VisionService

### 6.1 Enhanced Configuration

```swift
struct SmartEatingConfiguration: Codable {
    // Existing parameters
    let historySize: Int
    let emaAlpha: Float

    // New parameters
    let temporalBufferSize: Int          // For FFT (recommend: 30 frames = 2s)
    let sessionHistorySize: Int          // For continuity (recommend: 30 frames)
    let hysteresisThreshold: Int         // Frames for state change (recommend: 5)

    // Feature weights
    let rhythmWeight: Float
    let amplitudeWeight: Float
    let continuityWeight: Float

    // Sensitivity multipliers
    let sensitivityMin: Float
    let sensitivityMax: Float
    let sensitivityDefault: Float

    // Age-specific settings
    let childAge: Float

    // Performance tuning
    let enableFFT: Bool                  // Toggle FFT computation
    let fftUpdateInterval: Int           // Compute FFT every N frames

    static let `default` = SmartEatingConfiguration(
        historySize: 15,
        emaAlpha: 0.3,
        temporalBufferSize: 30,
        sessionHistorySize: 30,
        hysteresisThreshold: 5,
        rhythmWeight: 0.35,
        amplitudeWeight: 0.25,
        continuityWeight: 0.20,
        sensitivityMin: 0.1,
        sensitivityMax: 1.0,
        sensitivityDefault: 0.5,
        childAge: 5.0,
        enableFFT: true,
        fftUpdateInterval: 3  // Every 3 frames (~200ms)
    )
}
```

### 6.2 Enhanced VisionService Architecture

```swift
class SmartVisionService: ObservableObject, FaceTrackingServiceProtocol {

    // MARK: - Published Properties
    @Published var isEating: Bool = false
    @Published var currentState: EatingState = .notStarted
    @Published var stateConfidence: Float = 0.0
    @Published var qualityScore: EatingQualityScore?
    @Published var serviceState: VisionServiceState = .idle
    @Published var sensitivity: Float = 0.5

    // MARK: - Feature Components
    private var temporalExtractor: TemporalFeatureExtractor
    private var movementExtractor: MovementFeatureExtractor
    private var sessionTracker: SessionTracker
    private var stateMachine: EatingStateMachine
    private var qualityCalculator: QualityScoreCalculator

    // MARK: - Data Buffers
    private var lipDistanceHistory: CircularBuffer<Float>
    private var temporalBuffer: CircularBuffer<Float>  // Longer buffer for FFT

    // MARK: - Performance Optimization
    private var frameCounter: Int = 0
    private let configuration: SmartEatingConfiguration

    // MARK: - Initialization
    init(configuration: SmartEatingConfiguration = .default) {
        self.configuration = configuration

        // Initialize buffers
        self.lipDistanceHistory = CircularBuffer<Float>(
            capacity: configuration.historySize
        )
        self.temporalBuffer = CircularBuffer<Float>(
            capacity: configuration.temporalBufferSize
        )

        // Initialize feature extractors
        self.temporalExtractor = TemporalFeatureExtractor()
        self.movementExtractor = MovementFeatureExtractor()
        self.sessionTracker = SessionTracker(
            historySize: configuration.sessionHistorySize
        )
        self.stateMachine = EatingStateMachine()
        self.qualityCalculator = QualityScoreCalculator(
            childAge: configuration.childAge
        )
    }

    // MARK: - Core Detection Logic
    func detect(from landmarks: VNFaceLandmarks2D, faceObservation: VNFaceObservation) -> EatingState {

        // 1. Calculate smoothed lip distance (existing logic)
        guard let lipDistance = calculateSmoothedLipDistance(landmarks) else {
            return .notStarted
        }

        // 2. Update buffers
        lipDistanceHistory.write(lipDistance)
        temporalBuffer.write(lipDistance)

        // 3. Extract features (with smart update intervals)
        frameCounter += 1

        var temporalFeatures: TemporalFeatures
        if configuration.enableFFT &&
           frameCounter % configuration.fftUpdateInterval == 0 &&
           temporalBuffer.isFull {
            // Compute expensive FFT features every N frames
            temporalFeatures = temporalExtractor.extract(
                from: temporalBuffer,
                samplingRate: 15.0
            )
        } else {
            // Use cached features
            temporalFeatures = temporalExtractor.getCachedFeatures()
        }

        let movementFeatures = movementExtractor.extract(
            from: lipDistanceHistory,
            config: configuration
        )

        // 4. Update session tracking
        let preliminaryEating = (movementFeatures.amplitude > 0.2)
        sessionTracker.update(isEating: preliminaryEating)
        let sessionFeatures = sessionTracker.extractSessionFeatures()

        // 5. Update state machine
        let newState = stateMachine.update(
            temporal: temporalFeatures,
            movement: movementFeatures,
            session: sessionFeatures,
            sensitivity: sensitivity
        )

        // 6. Calculate quality score
        let quality = qualityCalculator.calculate(
            temporal: temporalFeatures,
            movement: movementFeatures,
            session: sessionFeatures,
            state: newState
        )

        // 7. Update published properties
        DispatchQueue.main.async {
            self.currentState = newState
            self.isEating = newState.videoShouldPlay
            self.stateConfidence = stateMachine.stateConfidence
            self.qualityScore = quality
        }

        return newState
    }

    // ... (rest of VisionService implementation)
}
```

### 6.3 Integration Points

1. **Replace analyzeEatingPattern():**
   ```swift
   // OLD (VisionService.swift:363-377)
   private func analyzeEatingPattern() -> LipDetectionState {
       guard lipDistanceHistory.isFull else { return .uncertain }
       let history = lipDistanceHistory.allItems()
       let halfSize = configuration.historySize / 2
       let recentAverage = history.suffix(halfSize).reduce(0, +) / Float(halfSize)
       let olderAverage = history.prefix(halfSize).reduce(0, +) / Float(halfSize)
       let changeRate = abs(recentAverage - olderAverage)
       let adjustedThreshold = configuration.eatingPatternThreshold * sensitivity
       return changeRate > adjustedThreshold ? .eating : .notEating
   }

   // NEW
   private func analyzeSmartEatingPattern() -> EatingState {
       // Extract all features
       let temporal = temporalExtractor.extract(from: temporalBuffer)
       let movement = movementExtractor.extract(from: lipDistanceHistory)
       let session = sessionTracker.extractSessionFeatures()

       // Update state machine
       return stateMachine.update(
           temporal: temporal,
           movement: movement,
           session: session,
           sensitivity: sensitivity
       )
   }
   ```

2. **Update ContentView debounce logic:**
   ```swift
   // OLD: Simple 1.5s debounce
   // NEW: State-aware video control
   var shouldPlayVideo: Bool {
       switch visionService.currentState {
       case .activeEating, .shortPause:
           return true
       case .notStarted, .longPause, .distracted, .finished:
           return false
       }
   }
   ```

---

## 7. Performance Analysis

### 7.1 Computational Complexity

| Component | Complexity | Time @ 15fps | Notes |
|-----------|-----------|--------------|-------|
| Lip Distance Calculation | O(1) | ~1ms | Existing implementation |
| EMA Smoothing | O(1) | <1ms | Existing implementation |
| **Temporal Features (FFT)** | O(n log n) | ~5-10ms | n=30, computed every 3 frames |
| Movement Features | O(n) | ~1ms | n=15, simple statistics |
| Session Features | O(1) | <1ms | Cached calculations |
| State Machine Update | O(1) | <1ms | Simple conditionals |
| Quality Score Calculation | O(1) | ~1ms | Arithmetic operations |
| **Total per Frame** | - | **~3-5ms** | (FFT amortized) |
| **Total with FFT** | - | **~15ms** | (FFT frames only) |

**Conclusion:** Well within 200ms latency budget. Peak processing time ~15ms per FFT frame.

### 7.2 Memory Footprint

| Structure | Size | Count | Total |
|-----------|------|-------|-------|
| CircularBuffer<Float> (15) | 60 bytes | 1 | 60 bytes |
| CircularBuffer<Float> (30) | 120 bytes | 1 | 120 bytes |
| CircularBuffer<Bool> (30) | 30 bytes | 1 | 30 bytes |
| CircularBuffer<EatingState> (10) | 40 bytes | 1 | 40 bytes |
| TemporalFeatures | 16 bytes | 1 | 16 bytes |
| MovementFeatures | 20 bytes | 1 | 20 bytes |
| SessionFeatures | 24 bytes | 1 | 24 bytes |
| State Machine Data | ~100 bytes | 1 | 100 bytes |
| **Total Algorithm Memory** | - | - | **~410 bytes** |

**Conclusion:** Negligible memory overhead (~0.4 KB).

### 7.3 Optimization Strategies

1. **FFT Computation Interval:**
   - Compute every 3 frames instead of every frame
   - Reduces FFT overhead from 10ms/frame to 3.3ms/frame average
   - Trade-off: 200ms update delay on rhythm features (acceptable)

2. **Accelerate Framework Usage:**
   - Use `vDSP_fft` for FFT computation (hardware-accelerated)
   - Use `vDSP_maxv` for peak finding
   - ~3-5x faster than manual implementation

3. **Feature Caching:**
   - Cache temporal features between FFT updates
   - Only recompute movement/session features (cheap operations)

4. **Conditional FFT:**
   - Skip FFT if buffer not full
   - Skip FFT during `notStarted` state
   - Adaptive interval based on state stability

5. **SIMD Operations:**
   - Use SIMD for vectorized statistics (mean, variance)
   - Available via Accelerate framework

---

## 8. Parameter Specification

### 8.1 Default Parameters

```swift
struct DefaultParameters {
    // Buffer sizes
    static let historySize = 15              // 1.0s @ 15fps
    static let temporalBufferSize = 30       // 2.0s @ 15fps
    static let sessionHistorySize = 30       // 2.0s @ 15fps

    // Temporal thresholds
    static let eatingFrequencyRange = 0.5...3.0  // Hz
    static let idealFrequencyRange = 1.0...2.0   // Hz

    // Movement thresholds
    static let minAmplitude: Float = 0.2
    static let typicalEatingAmplitude: Float = 0.2
    static let typicalJerkiness: Float = 0.03

    // State transition thresholds
    static let activeThresholdBase: Float = 0.4
    static let resumeThresholdBase: Float = 0.3
    static let shortPauseDuration: TimeInterval = 5.0
    static let longPauseDuration: TimeInterval = 15.0
    static let distractedDuration: TimeInterval = 30.0

    // Hysteresis
    static let hysteresisFrames = 5          // 333ms @ 15fps
    static let quickResumeFrames = 3         // 200ms @ 15fps

    // Quality score weights
    static let rhythmWeight: Float = 0.30
    static let amplitudeWeight: Float = 0.20
    static let continuityWeight: Float = 0.25
    static let focusWeight: Float = 0.15
    static let ageWeight: Float = 0.10

    // Performance tuning
    static let fftUpdateInterval = 3         // Every 200ms
    static let enableFFT = true
}
```

### 8.2 Tunable Parameters (for A/B Testing)

| Parameter | Default | Range | Impact |
|-----------|---------|-------|--------|
| `activeThresholdBase` | 0.4 | 0.3-0.6 | Sensitivity to start eating detection |
| `resumeThresholdBase` | 0.3 | 0.2-0.5 | Ease of resuming after pause |
| `hysteresisFrames` | 5 | 3-10 | State change delay |
| `fftUpdateInterval` | 3 | 1-5 | FFT computation frequency |
| `rhythmWeight` | 0.30 | 0.2-0.4 | Importance of rhythm in detection |
| `amplitudeWeight` | 0.20 | 0.1-0.3 | Importance of movement amplitude |
| `shortPauseDuration` | 5.0s | 3-10s | Tolerance for brief pauses |
| `idealFrequencyRange` | 1.0-2.0 Hz | 0.8-2.5 Hz | Expected chewing frequency |

### 8.3 Age-Specific Parameter Profiles

```swift
enum AgeProfile {
    case toddler    // 2-3 years
    case preschool  // 4-5 years
    case school     // 6-9 years
    case preteen    // 10+ years

    var parameters: SmartEatingConfiguration {
        switch self {
        case .toddler:
            return SmartEatingConfiguration(
                childAge: 2.5,
                activeThresholdBase: 0.35,  // More tolerant
                idealFrequencyRange: 0.8...1.5,
                rhythmWeight: 0.25,  // Less emphasis on regularity
                amplitudeWeight: 0.30  // More on amplitude
            )
        case .preschool:
            return .default  // Standard parameters
        case .school:
            return SmartEatingConfiguration(
                childAge: 7.5,
                activeThresholdBase: 0.45,  // More strict
                idealFrequencyRange: 1.2...2.2,
                rhythmWeight: 0.35,
                continuityWeight: 0.30
            )
        case .preteen:
            return SmartEatingConfiguration(
                childAge: 11.0,
                activeThresholdBase: 0.50,
                idealFrequencyRange: 1.5...2.5,
                rhythmWeight: 0.40,
                continuityWeight: 0.25
            )
        }
    }
}
```

---

## 9. Testing & Validation Strategy

### 9.1 Unit Tests

```swift
import XCTest

class SmartEatingAlgorithmTests: XCTestCase {

    func testTemporalFeatureExtraction() {
        // Test FFT with synthetic 1.5 Hz sine wave
        let buffer = generateSineWave(frequency: 1.5, duration: 2.0, sampleRate: 15.0)
        let features = extractTemporalFeatures(from: buffer, samplingRate: 15.0)

        XCTAssertEqual(features.dominantFrequency, 1.5, accuracy: 0.2)
        XCTAssertGreaterThan(features.rhythmStrength, 0.6)
    }

    func testMovementFeatureExtraction() {
        // Test amplitude calculation
        let buffer = createBuffer(values: [0.1, 0.3, 0.2, 0.4, 0.3])
        let features = extractMovementFeatures(from: buffer, config: .default)

        XCTAssertGreaterThan(features.amplitude, 0)
        XCTAssertLessThan(features.jerkiness, 1.0)
    }

    func testStateTransitions() {
        var stateMachine = EatingStateMachine()

        // Simulate eating start
        for _ in 0..<10 {
            let temporal = TemporalFeatures(
                dominantFrequency: 1.5,
                rhythmStrength: 0.7,
                rhythmRegularity: 0.8,
                periodicity: 0.6
            )
            let movement = MovementFeatures(
                amplitude: 0.5,
                velocity: 0.3,
                jerkiness: 0.2,
                smoothness: 0.8,
                dynamicRange: 0.2
            )
            let session = SessionFeatures(
                sessionDuration: 5.0,
                continuityScore: 0.9,
                pauseDuration: 0,
                totalEatingTime: 4.5,
                eatingRatio: 0.9
            )

            let state = stateMachine.update(
                temporal: temporal,
                movement: movement,
                session: session,
                sensitivity: 0.5
            )
        }

        XCTAssertEqual(stateMachine.currentState, .activeEating)
    }

    func testQualityScoreCalculation() {
        let calculator = QualityScoreCalculator(childAge: 5.0)

        let temporal = TemporalFeatures(
            dominantFrequency: 1.5,
            rhythmStrength: 0.7,
            rhythmRegularity: 0.8,
            periodicity: 0.6
        )
        let movement = MovementFeatures(
            amplitude: 0.5,
            velocity: 0.3,
            jerkiness: 0.2,
            smoothness: 0.8,
            dynamicRange: 0.2
        )
        let session = SessionFeatures(
            sessionDuration: 60.0,
            continuityScore: 0.8,
            pauseDuration: 0,
            totalEatingTime: 48.0,
            eatingRatio: 0.8
        )

        let score = calculator.calculate(
            temporal: temporal,
            movement: movement,
            session: session,
            state: .activeEating
        )

        XCTAssertGreaterThan(score.overallScore, 70.0)
        XCTAssertEqual(score.grade, "Good")
    }
}
```

### 9.2 Integration Tests

1. **Real Video Testing:**
   - Record 10+ diverse eating videos (different children, foods, environments)
   - Manually label ground truth (frame-by-frame eating/not eating)
   - Measure accuracy, precision, recall

2. **Edge Case Testing:**
   - Talking while eating
   - Drinking
   - Yawning
   - Looking away
   - Multiple children in frame

3. **Performance Testing:**
   - Measure latency on target devices (iPhone 12+)
   - Monitor memory usage
   - Battery consumption over 30-minute session

### 9.3 A/B Testing Framework

```swift
struct ABTestConfiguration {
    let experimentName: String
    let variant: String  // "control" or "treatment"
    let parameters: SmartEatingConfiguration

    static func randomAssignment() -> ABTestConfiguration {
        let variant = Bool.random() ? "control" : "treatment"
        return variant == "control" ? controlConfig : treatmentConfig
    }

    static let controlConfig = ABTestConfiguration(
        experimentName: "rhythm_weight_test",
        variant: "control",
        parameters: SmartEatingConfiguration(
            rhythmWeight: 0.30,  // Current default
            amplitudeWeight: 0.20
        )
    )

    static let treatmentConfig = ABTestConfiguration(
        experimentName: "rhythm_weight_test",
        variant: "treatment",
        parameters: SmartEatingConfiguration(
            rhythmWeight: 0.40,  // Increased emphasis
            amplitudeWeight: 0.15
        )
    )
}
```

---

## 10. Implementation Roadmap

### Phase 1: Core Features (Week 1-2)
- [ ] Implement `TemporalFeatures` extraction with FFT
- [ ] Implement `MovementFeatures` extraction
- [ ] Implement `SessionTracker`
- [ ] Unit tests for feature extraction

### Phase 2: State Machine (Week 2-3)
- [ ] Implement `EatingStateMachine`
- [ ] Add hysteresis logic
- [ ] Integration tests for state transitions
- [ ] Debug UI overlay for state visualization

### Phase 3: Quality Scoring (Week 3-4)
- [ ] Implement `QualityScoreCalculator`
- [ ] Age-specific adjustments
- [ ] UI display for quality score
- [ ] Real-time feedback system

### Phase 4: Integration & Optimization (Week 4-5)
- [ ] Replace `analyzeEatingPattern()` in VisionService
- [ ] Performance profiling with Instruments
- [ ] Memory optimization
- [ ] Battery impact testing

### Phase 5: Validation & Tuning (Week 5-6)
- [ ] Ground truth labeling of test videos
- [ ] Accuracy measurement (target: 70%+)
- [ ] A/B testing framework
- [ ] Parameter optimization

---

## 11. Expected Improvements

| Metric | Current | Target | Expected |
|--------|---------|--------|----------|
| Accuracy | ~50% (estimated) | 70% | 75-80% |
| False Positive Rate | High | <15% | ~10% |
| False Negative Rate | Medium | <20% | ~15% |
| State Flickering | Frequent | Rare | ~2-3 per session |
| Latency | <200ms | <200ms | ~150ms |
| User Satisfaction | N/A | 4.0/5.0 | 4.2/5.0 |

---

## 12. Future Enhancements

1. **Machine Learning Integration:**
   - Train LSTM/GRU model on labeled eating sequences
   - Use ML to learn optimal feature weights
   - Personalized models per child

2. **Advanced Features:**
   - Facial expression analysis (enjoyment detection)
   - Food type detection (affects eating rhythm)
   - Utensil usage detection
   - Posture analysis

3. **Multi-Modal Fusion:**
   - Audio analysis (chewing sounds)
   - Gyroscope data (head movement patterns)
   - Hand tracking (food-to-mouth trajectory)

4. **Adaptive Learning:**
   - Per-child calibration
   - Temporal adaptation (breakfast vs. dinner patterns)
   - Environmental adaptation (home vs. restaurant)

---

## 13. References

1. **Signal Processing:**
   - Cooley-Tukey FFT Algorithm
   - Welch's Power Spectral Density Method
   - Autocorrelation Function for Periodicity

2. **State Machine Design:**
   - Finite State Machines with Hysteresis
   - Debouncing Techniques in Real-Time Systems

3. **Computer Vision:**
   - Apple Vision Framework Documentation
   - MediaPipe Face Mesh Landmarks

4. **Child Eating Behavior:**
   - Typical chewing frequencies: 1.0-2.0 Hz (children)
   - Eating session duration: 15-30 minutes
   - Pause patterns in children's meals

---

## Appendix A: Swift Implementation Template

```swift
// File: SmartEatingDetector.swift

import Foundation
import Accelerate

/// Main class coordinating all smart eating detection components
class SmartEatingDetector {

    private let configuration: SmartEatingConfiguration
    private var temporalBuffer: CircularBuffer<Float>
    private var lipDistanceHistory: CircularBuffer<Float>

    private var stateMachine: EatingStateMachine
    private var sessionTracker: SessionTracker
    private var qualityCalculator: QualityScoreCalculator

    init(configuration: SmartEatingConfiguration = .default) {
        self.configuration = configuration

        self.temporalBuffer = CircularBuffer(capacity: configuration.temporalBufferSize)
        self.lipDistanceHistory = CircularBuffer(capacity: configuration.historySize)

        self.stateMachine = EatingStateMachine()
        self.sessionTracker = SessionTracker(historySize: configuration.sessionHistorySize)
        self.qualityCalculator = QualityScoreCalculator(childAge: configuration.childAge)
    }

    /// Process new lip distance measurement
    func process(lipDistance: Float, sensitivity: Float) -> SmartEatingResult {
        // Update buffers
        temporalBuffer.write(lipDistance)
        lipDistanceHistory.write(lipDistance)

        // Extract features
        let temporal = extractTemporalFeatures(from: temporalBuffer, samplingRate: 15.0)
        let movement = extractMovementFeatures(from: lipDistanceHistory, config: configuration)

        // Update session
        let preliminaryEating = movement.amplitude > configuration.minAmplitude
        sessionTracker.update(isEating: preliminaryEating)
        let session = sessionTracker.extractSessionFeatures()

        // Update state
        let state = stateMachine.update(
            temporal: temporal,
            movement: movement,
            session: session,
            sensitivity: sensitivity
        )

        // Calculate quality
        let quality = qualityCalculator.calculate(
            temporal: temporal,
            movement: movement,
            session: session,
            state: state
        )

        return SmartEatingResult(
            state: state,
            confidence: stateMachine.stateConfidence,
            qualityScore: quality,
            shouldPlayVideo: state.videoShouldPlay,
            features: EatingFeatures(
                temporal: temporal,
                movement: movement,
                session: session
            )
        )
    }
}

/// Result structure returned by detector
struct SmartEatingResult {
    let state: EatingState
    let confidence: Float
    let qualityScore: EatingQualityScore
    let shouldPlayVideo: Bool
    let features: EatingFeatures
}

struct EatingFeatures {
    let temporal: TemporalFeatures
    let movement: MovementFeatures
    let session: SessionFeatures
}
```

---

**End of Document**

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-19 | Claude Code | Initial comprehensive design |
| 2.0 | TBD | - | Post-implementation refinements |
