# Smart Eating Detection Algorithm - Quick Reference Guide

## TL;DR

Replace the simple two-half comparison with a multi-dimensional algorithm featuring:
- **Temporal rhythm analysis** (FFT-based, 1-2 Hz chewing detection)
- **Movement quality scoring** (amplitude, smoothness, jerkiness)
- **State machine** (6 states with hysteresis)
- **Quality score** (0-100, weighted by 5 factors)

**Expected Accuracy:** 70-80% (vs. current ~50%)
**Performance:** <200ms latency, 15fps compatible
**Memory:** ~410 bytes overhead

---

## Current vs. New Algorithm

### Current (Simple)
```swift
// Two-half comparison
recentAvg = last 7.5 frames average
olderAvg = first 7.5 frames average
changeRate = abs(recentAvg - olderAvg)
isEating = changeRate > threshold * sensitivity
```

**Problems:**
- No rhythm detection
- Binary flickering
- Talks/yawns = false positives
- No context awareness

### New (Smart)
```swift
// Multi-dimensional analysis
temporal = FFT(30 frames) → {frequency, strength, regularity}
movement = Stats(15 frames) → {amplitude, velocity, smoothness}
session = Track() → {continuity, pauses, duration}
state = StateMachine(temporal, movement, session)
quality = Score(all features) → 0-100
```

**Benefits:**
- 1-2 Hz rhythm detection
- 6 states with smooth transitions
- Distinguishes eating from other activities
- Real-time quality feedback

---

## Key Components

### 1. Temporal Features (FFT)
```swift
struct TemporalFeatures {
    dominantFrequency: Float    // 0-5 Hz (ideal: 1-2 Hz)
    rhythmStrength: Float       // 0-1 (spectral peak magnitude)
    rhythmRegularity: Float     // 0-1 (low CV = regular)
    periodicity: Float          // 0-1 (autocorrelation)
}

// Computation: Every 3 frames (~200ms) to save CPU
// Method: vDSP_fft (Accelerate framework)
// Time: ~10ms per FFT
```

### 2. Movement Features
```swift
struct MovementFeatures {
    amplitude: Float      // 0-1 (normalized by 0.2 typical)
    velocity: Float       // Frame-to-frame change rate
    jerkiness: Float      // 0-1 (2nd derivative variance)
    smoothness: Float     // 0-1 (inverse jerkiness)
    dynamicRange: Float   // Peak-to-peak variation
}

// Computation: Every frame
// Time: ~1ms
```

### 3. Session Features
```swift
struct SessionFeatures {
    sessionDuration: TimeInterval      // Since eating started
    continuityScore: Float             // 0-1 (% eating frames)
    pauseDuration: TimeInterval        // Since last eating
    totalEatingTime: TimeInterval      // Cumulative
    eatingRatio: Float                 // eating/session
}

// Computation: Every frame
// Time: <1ms (cached)
```

### 4. State Machine (6 States)
```
NotStarted ──┐
             │ Strong signal (score>0.4, rhythm>0.3, amp>0.2)
             ▼
        ActiveEating ◄─────┐
             │             │ Resume (score>0.3)
             │ Weak signal │
             ▼             │
        ShortPause ────────┘
             │ 5s pause
             ▼
        LongPause
             │ 15s pause
             ▼
        Distracted
             │ 30s pause
             ▼
         Finished
```

**Hysteresis:** 5 frames (333ms) required for state change → prevents flickering

### 5. Quality Score (0-100)
```swift
overallScore =
    0.30 * rhythmScore +       // Ideal: 1-2 Hz, strong, regular
    0.20 * amplitudeScore +    // Ideal: 0.3-0.7, smooth
    0.25 * continuityScore +   // High % eating, few pauses
    0.15 * focusScore +        // No long pauses, smooth motion
    0.10 * ageAdjustment       // Age-appropriate patterns

Grades:
90-100: Excellent
75-89:  Good
60-74:  Fair
40-59:  Needs Improvement
0-39:   Poor
```

---

## Implementation Checklist

### Step 1: Add New Data Structures (1 day)
```swift
// In VisionService.swift or new SmartEatingDetector.swift

private var temporalBuffer: CircularBuffer<Float>  // 30 frames
private var stateMachine: EatingStateMachine
private var sessionTracker: SessionTracker
private var qualityCalculator: QualityScoreCalculator
private var frameCounter: Int = 0
```

### Step 2: Implement Feature Extraction (2-3 days)
```swift
// TemporalFeatureExtractor.swift
func extractTemporalFeatures(from buffer: CircularBuffer<Float>) -> TemporalFeatures {
    // 1. Detrend signal
    // 2. Apply Hanning window
    // 3. Compute FFT (use vDSP)
    // 4. Find peak in 0.5-3.0 Hz range
    // 5. Calculate autocorrelation
    // 6. Return features
}

// MovementFeatureExtractor.swift
func extractMovementFeatures(from buffer: CircularBuffer<Float>) -> MovementFeatures {
    // 1. Calculate amplitude (max - min)
    // 2. Calculate velocity (first derivative)
    // 3. Calculate jerkiness (second derivative stddev)
    // 4. Return features
}
```

### Step 3: Implement State Machine (2 days)
```swift
// EatingStateMachine.swift
class EatingStateMachine {
    private(set) var currentState: EatingState = .notStarted
    private var transitionBuffer: CircularBuffer<EatingState>

    func update(temporal, movement, session, sensitivity) -> EatingState {
        let score = calculateEatingScore(temporal, movement, session)
        let targetState = determineTargetState(score, ...)

        if shouldTransition(to: targetState) {  // Hysteresis check
            currentState = targetState
        }
        return currentState
    }
}
```

### Step 4: Implement Quality Scoring (1 day)
```swift
// QualityScoreCalculator.swift
class QualityScoreCalculator {
    func calculate(temporal, movement, session, state) -> EatingQualityScore {
        let rhythmScore = calculateRhythmScore(temporal)
        let amplitudeScore = calculateAmplitudeScore(movement)
        let continuityScore = calculateContinuityScore(session, state)
        let focusScore = calculateFocusScore(session, state, movement)
        let ageAdjustment = calculateAgeAdjustment(temporal, childAge)

        let overall = 0.30*rhythmScore + 0.20*amplitudeScore +
                      0.25*continuityScore + 0.15*focusScore + 0.10*ageAdjustment

        return EatingQualityScore(overallScore: overall, ...)
    }
}
```

### Step 5: Integration (1 day)
```swift
// Replace analyzeEatingPattern() in VisionService.swift
private func analyzeSmartEatingPattern() -> EatingState {
    // Update buffers
    temporalBuffer.write(lipDistance)

    // Extract features (FFT every 3 frames)
    frameCounter += 1
    if frameCounter % 3 == 0 && temporalBuffer.isFull {
        temporal = extractTemporalFeatures(from: temporalBuffer)
    }
    movement = extractMovementFeatures(from: lipDistanceHistory)
    session = sessionTracker.extractSessionFeatures()

    // Update state
    let state = stateMachine.update(temporal, movement, session, sensitivity)
    let quality = qualityCalculator.calculate(temporal, movement, session, state)

    // Publish results
    DispatchQueue.main.async {
        self.currentState = state
        self.isEating = state.videoShouldPlay
        self.qualityScore = quality
    }

    return state
}
```

### Step 6: UI Updates (1 day)
```swift
// ContentView.swift - Replace debounce logic
var shouldPlayVideo: Bool {
    visionService.currentState.videoShouldPlay
}

// StatusBar.swift - Add quality display
Text("Quality: \(qualityScore?.grade ?? "N/A") (\(Int(qualityScore?.overallScore ?? 0)))")
```

### Step 7: Testing & Validation (3-4 days)
- [ ] Unit tests for all feature extractors
- [ ] Integration tests for state machine
- [ ] Real video testing with ground truth labels
- [ ] Performance profiling (Instruments)
- [ ] A/B testing framework

---

## Performance Budget

| Operation | Time (ms) | Frequency | Avg Cost |
|-----------|-----------|-----------|----------|
| Lip distance calc | 1 | Every frame | 1 ms |
| Movement features | 1 | Every frame | 1 ms |
| Session features | <1 | Every frame | <1 ms |
| FFT computation | 10 | Every 3 frames | 3.3 ms |
| State machine | <1 | Every frame | <1 ms |
| Quality calc | 1 | Every frame | 1 ms |
| **Total Average** | - | - | **~7-8 ms** |

**Peak (FFT frame):** ~15ms
**Latency Budget:** 200ms
**Margin:** ~185ms (plenty of headroom)

---

## Critical Parameters

### Must Tune for 70% Accuracy
```swift
// Detection thresholds
activeThresholdBase: Float = 0.4      // Try: 0.3-0.6
resumeThresholdBase: Float = 0.3      // Try: 0.2-0.5

// Rhythm expectations
idealFrequencyRange = 1.0...2.0       // Try: 0.8-2.5 Hz
minRhythmStrength: Float = 0.3        // Try: 0.2-0.5

// Movement thresholds
minAmplitude: Float = 0.2             // Try: 0.15-0.3
typicalEatingAmplitude: Float = 0.2   // Try: 0.15-0.25

// State transitions
hysteresisFrames: Int = 5             // Try: 3-10
shortPauseDuration: TimeInterval = 5  // Try: 3-10s

// Feature weights
rhythmWeight: Float = 0.30            // Try: 0.25-0.40
amplitudeWeight: Float = 0.20         // Try: 0.15-0.30
continuityWeight: Float = 0.25        // Try: 0.20-0.30
```

### A/B Testing Targets
1. **Rhythm Weight:** 0.30 vs. 0.40
2. **Hysteresis Frames:** 5 vs. 3 vs. 7
3. **FFT Update Interval:** 3 vs. 5 frames
4. **Active Threshold:** 0.4 vs. 0.35 vs. 0.45

---

## Debug UI Overlay

```swift
// Add to StatusBar or debug overlay
VStack(alignment: .leading) {
    Text("State: \(state.description)")
    Text("Confidence: \(String(format: "%.1f%%", confidence * 100))")
    Text("Quality: \(qualityScore.grade) (\(Int(qualityScore.overallScore)))")

    Divider()

    Text("Rhythm: \(String(format: "%.1f Hz", temporal.dominantFrequency))")
    Text("Strength: \(String(format: "%.2f", temporal.rhythmStrength))")
    Text("Amplitude: \(String(format: "%.2f", movement.amplitude))")
    Text("Continuity: \(String(format: "%.1f%%", session.continuityScore * 100))")
}
```

---

## Common Issues & Solutions

### Issue 1: High False Positive Rate (talking detected as eating)
**Solution:** Increase `minRhythmStrength` threshold (0.3 → 0.4)
**Reason:** Talking lacks the regular 1-2 Hz chewing rhythm

### Issue 2: High False Negative Rate (eating not detected)
**Solution:** Decrease `activeThresholdBase` (0.4 → 0.35)
**Reason:** Some children eat more slowly or with smaller movements

### Issue 3: State flickering
**Solution:** Increase `hysteresisFrames` (5 → 7)
**Reason:** More frames required for state change = smoother transitions

### Issue 4: FFT performance issues
**Solution:** Increase `fftUpdateInterval` (3 → 5)
**Reason:** Less frequent FFT = lower CPU usage (trade-off: slower rhythm updates)

### Issue 5: Quality score always low
**Solution:** Check age-specific parameters and weight balance
**Reason:** May need age profile adjustments or different weight distribution

---

## Next Steps

1. **Week 1-2:** Implement feature extraction (temporal + movement)
2. **Week 2-3:** Implement state machine with hysteresis
3. **Week 3-4:** Add quality scoring system
4. **Week 4-5:** Integration and performance optimization
5. **Week 5-6:** Validation with real videos, parameter tuning

**Target Milestone:** 70%+ accuracy on diverse test videos by end of Week 6

---

## References

- **Full Design:** `/home/user/BobCam/docs/SmartEatingDetectionAlgorithm.md`
- **Current Implementation:** `/home/user/BobCam/BobCam-iOS/BobCamAgent/BobCamAgent/VisionService.swift`
- **Architecture Plan:** `/home/user/BobCam/iOS-Architecture-Plan.md`
- **Apple Accelerate:** https://developer.apple.com/documentation/accelerate
- **Vision Framework:** https://developer.apple.com/documentation/vision
