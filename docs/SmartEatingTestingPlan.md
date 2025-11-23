# Smart Eating Detection - Testing & Validation Plan

## Overview

This document outlines the comprehensive testing strategy to validate the Smart Eating Detection algorithm and achieve the target 70%+ accuracy.

---

## 1. Unit Testing

### 1.1 Temporal Feature Extraction

**File:** `SmartEatingDetectorTests.swift`

```swift
class TemporalFeatureTests: XCTestCase {

    // Test 1: Synthetic sine wave detection
    func testSineWaveFrequencyDetection() {
        // Generate 1.5 Hz sine wave (typical chewing frequency)
        let buffer = generateSineWave(
            frequency: 1.5,
            duration: 2.0,
            sampleRate: 15.0,
            amplitude: 0.2
        )

        let extractor = TemporalFeatureExtractor()
        let features = extractor.extract(from: buffer)

        // Assertions
        XCTAssertEqual(features.dominantFrequency, 1.5, accuracy: 0.2,
                      "Should detect 1.5 Hz frequency")
        XCTAssertGreaterThan(features.rhythmStrength, 0.6,
                           "Strong periodic signal should have high rhythm strength")
        XCTAssertGreaterThan(features.periodicity, 0.7,
                           "Regular sine wave should have high autocorrelation")
    }

    // Test 2: Noisy signal handling
    func testNoisySignalRejection() {
        let buffer = generateWhiteNoise(duration: 2.0, sampleRate: 15.0)

        let extractor = TemporalFeatureExtractor()
        let features = extractor.extract(from: buffer)

        XCTAssertLessThan(features.rhythmStrength, 0.3,
                         "White noise should have low rhythm strength")
        XCTAssertLessThan(features.periodicity, 0.3,
                         "White noise should have low autocorrelation")
    }

    // Test 3: Multi-frequency signal (eating + talking)
    func testMultiFrequencySignal() {
        // Mix 1.5 Hz (eating) + 3.5 Hz (talking) components
        let buffer = generateMixedSignal(
            frequencies: [1.5, 3.5],
            amplitudes: [0.3, 0.1],
            duration: 2.0,
            sampleRate: 15.0
        )

        let extractor = TemporalFeatureExtractor()
        let features = extractor.extract(from: buffer)

        // Should detect dominant eating frequency
        XCTAssertEqual(features.dominantFrequency, 1.5, accuracy: 0.3)
    }

    // Test 4: Frequency range boundaries
    func testFrequencyRangeBoundaries() {
        let testCases: [(Float, Bool)] = [
            (0.3, false),  // Too slow (not eating)
            (0.8, true),   // Slow eating (toddler)
            (1.5, true),   // Normal eating
            (2.2, true),   // Fast eating
            (3.5, false)   // Too fast (talking/yawning)
        ]

        for (freq, shouldDetect) in testCases {
            let buffer = generateSineWave(frequency: freq, duration: 2.0, sampleRate: 15.0)
            let extractor = TemporalFeatureExtractor()
            let features = extractor.extract(from: buffer)

            if shouldDetect {
                XCTAssertGreaterThan(features.rhythmStrength, 0.5,
                                   "Frequency \(freq) Hz should be detected as eating")
            }
        }
    }
}
```

### 1.2 Movement Feature Extraction

```swift
class MovementFeatureTests: XCTestCase {

    // Test 1: Amplitude calculation
    func testAmplitudeCalculation() {
        let values: [Float] = [0.1, 0.3, 0.2, 0.4, 0.3, 0.15, 0.35]
        let buffer = createCircularBuffer(values: values)

        let extractor = MovementFeatureExtractor()
        let features = extractor.extract(from: buffer, config: .default)

        let expectedRange = 0.4 - 0.1  // 0.3
        let expectedAmplitude = expectedRange / 0.2  // Normalize by typical
        XCTAssertEqual(features.amplitude, expectedAmplitude, accuracy: 0.1)
    }

    // Test 2: Jerkiness detection
    func testJerkinessDetection() {
        // Smooth signal
        let smoothValues: [Float] = [0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4]
        let smoothBuffer = createCircularBuffer(values: smoothValues)

        // Jerky signal
        let jerkyValues: [Float] = [0.1, 0.3, 0.15, 0.35, 0.2, 0.4, 0.25]
        let jerkyBuffer = createCircularBuffer(values: jerkyValues)

        let extractor = MovementFeatureExtractor()
        let smoothFeatures = extractor.extract(from: smoothBuffer, config: .default)
        let jerkyFeatures = extractor.extract(from: jerkyBuffer, config: .default)

        XCTAssertGreaterThan(smoothFeatures.smoothness, jerkyFeatures.smoothness,
                           "Smooth signal should have higher smoothness score")
        XCTAssertLessThan(smoothFeatures.jerkiness, jerkyFeatures.jerkiness,
                         "Smooth signal should have lower jerkiness")
    }

    // Test 3: Velocity calculation
    func testVelocityCalculation() {
        // Fast changing signal
        let fastValues: [Float] = [0.1, 0.3, 0.1, 0.3, 0.1, 0.3]
        let fastBuffer = createCircularBuffer(values: fastValues)

        // Slow changing signal
        let slowValues: [Float] = [0.1, 0.12, 0.14, 0.16, 0.18, 0.20]
        let slowBuffer = createCircularBuffer(values: slowValues)

        let extractor = MovementFeatureExtractor()
        let fastFeatures = extractor.extract(from: fastBuffer, config: .default)
        let slowFeatures = extractor.extract(from: slowBuffer, config: .default)

        XCTAssertGreaterThan(fastFeatures.velocity, slowFeatures.velocity,
                           "Fast changing signal should have higher velocity")
    }
}
```

### 1.3 State Machine Logic

```swift
class StateMachineTests: XCTestCase {

    // Test 1: Initial state transition
    func testNotStartedToActiveEating() {
        var stateMachine = EatingStateMachine()

        // Provide strong eating signals
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
            sessionDuration: 2.0,
            continuityScore: 0.9,
            pauseDuration: 0,
            totalEatingTime: 1.8,
            eatingRatio: 0.9
        )

        // Feed enough frames for hysteresis
        for _ in 0..<10 {
            let state = stateMachine.update(
                temporal: temporal,
                movement: movement,
                session: session,
                sensitivity: 0.5
            )
        }

        XCTAssertEqual(stateMachine.currentState, .activeEating,
                      "Strong consistent signal should transition to active eating")
    }

    // Test 2: Pause detection
    func testActiveEatingToShortPause() {
        var stateMachine = EatingStateMachine()

        // Start with active eating
        let eatingTemporal = TemporalFeatures(
            dominantFrequency: 1.5,
            rhythmStrength: 0.7,
            rhythmRegularity: 0.8,
            periodicity: 0.6
        )
        let eatingMovement = MovementFeatures(amplitude: 0.5, velocity: 0.3, jerkiness: 0.2, smoothness: 0.8, dynamicRange: 0.2)
        let eatingSession = SessionFeatures(sessionDuration: 5.0, continuityScore: 0.9, pauseDuration: 0, totalEatingTime: 4.5, eatingRatio: 0.9)

        for _ in 0..<10 {
            _ = stateMachine.update(temporal: eatingTemporal, movement: eatingMovement, session: eatingSession, sensitivity: 0.5)
        }

        // Now provide weak signal (pause)
        let pauseTemporal = TemporalFeatures(dominantFrequency: 0.5, rhythmStrength: 0.1, rhythmRegularity: 0.3, periodicity: 0.2)
        let pauseMovement = MovementFeatures(amplitude: 0.1, velocity: 0.05, jerkiness: 0.1, smoothness: 0.9, dynamicRange: 0.05)
        let pauseSession = SessionFeatures(sessionDuration: 7.0, continuityScore: 0.5, pauseDuration: 2.0, totalEatingTime: 4.5, eatingRatio: 0.64)

        for _ in 0..<10 {
            _ = stateMachine.update(temporal: pauseTemporal, movement: pauseMovement, session: pauseSession, sensitivity: 0.5)
        }

        XCTAssertEqual(stateMachine.currentState, .shortPause,
                      "Weak signal after eating should transition to short pause")
    }

    // Test 3: Hysteresis prevents flickering
    func testHysteresisPreventsFlickering() {
        var stateMachine = EatingStateMachine()

        let eatingFeatures = (
            TemporalFeatures(dominantFrequency: 1.5, rhythmStrength: 0.7, rhythmRegularity: 0.8, periodicity: 0.6),
            MovementFeatures(amplitude: 0.5, velocity: 0.3, jerkiness: 0.2, smoothness: 0.8, dynamicRange: 0.2),
            SessionFeatures(sessionDuration: 5.0, continuityScore: 0.9, pauseDuration: 0, totalEatingTime: 4.5, eatingRatio: 0.9)
        )

        let pauseFeatures = (
            TemporalFeatures(dominantFrequency: 0.5, rhythmStrength: 0.1, rhythmRegularity: 0.3, periodicity: 0.2),
            MovementFeatures(amplitude: 0.1, velocity: 0.05, jerkiness: 0.1, smoothness: 0.9, dynamicRange: 0.05),
            SessionFeatures(sessionDuration: 6.0, continuityScore: 0.5, pauseDuration: 1.0, totalEatingTime: 4.5, eatingRatio: 0.75)
        )

        // Alternating signals
        let states = [
            eatingFeatures, eatingFeatures, pauseFeatures, eatingFeatures,
            pauseFeatures, eatingFeatures, eatingFeatures
        ]

        var stateChanges = 0
        var previousState = stateMachine.currentState

        for (temporal, movement, session) in states {
            let newState = stateMachine.update(
                temporal: temporal,
                movement: movement,
                session: session,
                sensitivity: 0.5
            )
            if newState != previousState {
                stateChanges += 1
            }
            previousState = newState
        }

        // With hysteresis, state changes should be < 3
        XCTAssertLessThan(stateChanges, 3,
                         "Hysteresis should prevent frequent state changes")
    }
}
```

### 1.4 Quality Score Calculation

```swift
class QualityScoreTests: XCTestCase {

    // Test 1: Excellent eating score
    func testExcellentEatingScore() {
        let calculator = QualityScoreCalculator(childAge: 5.0)

        let temporal = TemporalFeatures(
            dominantFrequency: 1.5,  // Ideal
            rhythmStrength: 0.8,     // Strong
            rhythmRegularity: 0.9,   // Very regular
            periodicity: 0.8
        )
        let movement = MovementFeatures(
            amplitude: 0.5,          // Ideal range
            velocity: 0.3,
            jerkiness: 0.1,          // Very smooth
            smoothness: 0.9,
            dynamicRange: 0.2
        )
        let session = SessionFeatures(
            sessionDuration: 60.0,
            continuityScore: 0.9,    // Highly continuous
            pauseDuration: 0,
            totalEatingTime: 54.0,
            eatingRatio: 0.9
        )

        let score = calculator.calculate(
            temporal: temporal,
            movement: movement,
            session: session,
            state: .activeEating
        )

        XCTAssertGreaterThan(score.overallScore, 85.0,
                           "Ideal eating patterns should score >85")
        XCTAssertEqual(score.grade, "Excellent")
    }

    // Test 2: Poor eating score
    func testPoorEatingScore() {
        let calculator = QualityScoreCalculator(childAge: 5.0)

        let temporal = TemporalFeatures(
            dominantFrequency: 0.3,  // Too slow
            rhythmStrength: 0.2,     // Weak
            rhythmRegularity: 0.3,   // Irregular
            periodicity: 0.2
        )
        let movement = MovementFeatures(
            amplitude: 0.1,          // Too small
            velocity: 0.1,
            jerkiness: 0.7,          // Very jerky
            smoothness: 0.3,
            dynamicRange: 0.05
        )
        let session = SessionFeatures(
            sessionDuration: 60.0,
            continuityScore: 0.3,    // Discontinuous
            pauseDuration: 30.0,     // Long pause
            totalEatingTime: 18.0,
            eatingRatio: 0.3
        )

        let score = calculator.calculate(
            temporal: temporal,
            movement: movement,
            session: session,
            state: .distracted
        )

        XCTAssertLessThan(score.overallScore, 40.0,
                         "Poor eating patterns should score <40")
        XCTAssertEqual(score.grade, "Poor")
    }

    // Test 3: Age-appropriate adjustments
    func testAgeAdjustments() {
        let toddlerCalculator = QualityScoreCalculator(childAge: 2.5)
        let schoolCalculator = QualityScoreCalculator(childAge: 8.0)

        // Slower frequency (0.8 Hz)
        let slowTemporal = TemporalFeatures(
            dominantFrequency: 0.8,
            rhythmStrength: 0.6,
            rhythmRegularity: 0.5,
            periodicity: 0.5
        )
        let movement = MovementFeatures(
            amplitude: 0.4,
            velocity: 0.2,
            jerkiness: 0.3,
            smoothness: 0.7,
            dynamicRange: 0.15
        )
        let session = SessionFeatures(
            sessionDuration: 60.0,
            continuityScore: 0.7,
            pauseDuration: 5.0,
            totalEatingTime: 42.0,
            eatingRatio: 0.7
        )

        let toddlerScore = toddlerCalculator.calculate(
            temporal: slowTemporal,
            movement: movement,
            session: session,
            state: .activeEating
        )

        let schoolScore = schoolCalculator.calculate(
            temporal: slowTemporal,
            movement: movement,
            session: session,
            state: .activeEating
        )

        XCTAssertGreaterThan(toddlerScore.overallScore, schoolScore.overallScore,
                           "Slow eating should score higher for toddlers than school-age children")
    }
}
```

---

## 2. Integration Testing

### 2.1 End-to-End Detection Pipeline

```swift
class IntegrationTests: XCTestCase {

    func testFullDetectionPipeline() {
        let detector = SmartEatingDetector(configuration: .default)

        // Simulate 2 seconds of eating (30 frames @ 15fps)
        let eatingPattern = generateRealisticEatingPattern(
            frequency: 1.5,
            duration: 2.0,
            sampleRate: 15.0
        )

        var results: [SmartEatingResult] = []

        for lipDistance in eatingPattern {
            let result = detector.process(lipDistance: lipDistance, sensitivity: 0.5)
            results.append(result)
        }

        // After 30 frames, should detect active eating
        let finalResult = results.last!

        XCTAssertEqual(finalResult.state, .activeEating,
                      "Realistic eating pattern should be detected as active eating")
        XCTAssertGreaterThan(finalResult.confidence, 0.6,
                           "Confidence should be >0.6 for clear eating pattern")
        XCTAssertTrue(finalResult.shouldPlayVideo,
                     "Video should play during active eating")
    }

    func testTransitionFromEatingToPause() {
        let detector = SmartEatingDetector(configuration: .default)

        // Feed eating pattern
        let eatingPattern = generateRealisticEatingPattern(frequency: 1.5, duration: 2.0, sampleRate: 15.0)
        for lipDistance in eatingPattern {
            _ = detector.process(lipDistance: lipDistance, sensitivity: 0.5)
        }

        // Feed pause pattern (no movement)
        let pausePattern = [Float](repeating: 0.15, count: 30)  // 2s of static
        var pauseResults: [SmartEatingResult] = []

        for lipDistance in pausePattern {
            let result = detector.process(lipDistance: lipDistance, sensitivity: 0.5)
            pauseResults.append(result)
        }

        // Should transition to pause state
        let finalState = pauseResults.last!.state
        XCTAssertTrue([.shortPause, .longPause].contains(finalState),
                     "Should transition to pause state after eating stops")
    }
}
```

---

## 3. Real Video Testing

### 3.1 Ground Truth Labeling

**Tool:** Custom video labeling application

```swift
struct GroundTruthLabel {
    let frameNumber: Int
    let timestamp: TimeInterval
    let isEating: Bool
    let confidence: Int  // 1-5 (1=uncertain, 5=certain)
    let notes: String?
}

class VideoLabeler {
    func labelVideo(url: URL) -> [GroundTruthLabel] {
        // Manual frame-by-frame labeling
        // Export to JSON for validation
    }
}
```

**Labeling Protocol:**
1. Watch video at 0.25x speed
2. Mark each second as "eating" or "not eating"
3. Note confidence level (1-5)
4. Record any ambiguous cases

**Minimum Dataset:**
- 10 diverse eating videos
- 5-10 minutes each
- Different children (ages 3-8)
- Various foods (solid, soft, liquid)
- Different environments (home, restaurant, outdoor)

### 3.2 Accuracy Metrics

```swift
struct AccuracyMetrics {
    let accuracy: Float          // (TP + TN) / Total
    let precision: Float         // TP / (TP + FP)
    let recall: Float            // TP / (TP + FN)
    let f1Score: Float           // 2 * (precision * recall) / (precision + recall)
    let falsePositiveRate: Float // FP / (FP + TN)
    let falseNegativeRate: Float // FN / (FN + TP)

    let confusionMatrix: ConfusionMatrix
}

struct ConfusionMatrix {
    let truePositives: Int
    let trueNegatives: Int
    let falsePositives: Int
    let falseNegatives: Int

    var total: Int {
        truePositives + trueNegatives + falsePositives + falseNegatives
    }
}

func calculateAccuracy(
    predictions: [Bool],
    groundTruth: [Bool]
) -> AccuracyMetrics {

    var tp = 0, tn = 0, fp = 0, fn = 0

    for (predicted, actual) in zip(predictions, groundTruth) {
        switch (predicted, actual) {
        case (true, true):   tp += 1
        case (false, false): tn += 1
        case (true, false):  fp += 1
        case (false, true):  fn += 1
        }
    }

    let total = Float(tp + tn + fp + fn)
    let accuracy = Float(tp + tn) / total
    let precision = Float(tp) / Float(tp + fp)
    let recall = Float(tp) / Float(tp + fn)
    let f1 = 2 * (precision * recall) / (precision + recall)

    return AccuracyMetrics(
        accuracy: accuracy,
        precision: precision,
        recall: recall,
        f1Score: f1,
        falsePositiveRate: Float(fp) / Float(fp + tn),
        falseNegativeRate: Float(fn) / Float(fn + tp),
        confusionMatrix: ConfusionMatrix(
            truePositives: tp,
            trueNegatives: tn,
            falsePositives: fp,
            falseNegatives: fn
        )
    )
}
```

### 3.3 Test Cases

| Video | Description | Expected Accuracy | Notes |
|-------|-------------|-------------------|-------|
| test_01.mp4 | 5yo, spaghetti, home | >75% | Baseline eating |
| test_02.mp4 | 3yo, applesauce, daycare | >65% | Younger child, messier |
| test_03.mp4 | 7yo, sandwich, school | >80% | Older, more regular |
| test_04.mp4 | 4yo, chicken nuggets, restaurant | >70% | Distractions present |
| test_05.mp4 | 6yo, cereal, morning | >75% | Liquid component |
| test_06_talk.mp4 | 5yo, talking while eating | >60% | Challenging (talking) |
| test_07_distracted.mp4 | 4yo, watching TV | >65% | Distraction test |
| test_08_drinking.mp4 | 5yo, drinking water | >50% | Edge case (should NOT detect) |
| test_09_yawning.mp4 | 6yo, yawning | >70% | False positive test |
| test_10_multi.mp4 | Multiple children | >70% | Multi-face handling |

**Target Overall Accuracy:** 70%+ across all videos

---

## 4. Performance Testing

### 4.1 Latency Measurement

```swift
class PerformanceTests: XCTestCase {

    func testProcessingLatency() {
        let detector = SmartEatingDetector(configuration: .default)

        // Pre-fill buffer
        for _ in 0..<30 {
            _ = detector.process(lipDistance: 0.15, sensitivity: 0.5)
        }

        // Measure 100 iterations
        var latencies: [TimeInterval] = []

        for _ in 0..<100 {
            let start = CACurrentMediaTime()
            _ = detector.process(lipDistance: 0.2, sensitivity: 0.5)
            let end = CACurrentMediaTime()

            latencies.append((end - start) * 1000)  // ms
        }

        let avgLatency = latencies.reduce(0, +) / Double(latencies.count)
        let maxLatency = latencies.max() ?? 0
        let p95Latency = latencies.sorted()[95]

        print("Avg Latency: \(avgLatency) ms")
        print("Max Latency: \(maxLatency) ms")
        print("P95 Latency: \(p95Latency) ms")

        XCTAssertLessThan(avgLatency, 10.0,
                         "Average latency should be <10ms")
        XCTAssertLessThan(p95Latency, 20.0,
                         "P95 latency should be <20ms (including FFT frames)")
    }

    func testFFTLatency() {
        let detector = SmartEatingDetector(configuration: .default)

        // Fill buffer completely
        for _ in 0..<30 {
            _ = detector.process(lipDistance: 0.15, sensitivity: 0.5)
        }

        // Force FFT computation
        let start = CACurrentMediaTime()
        _ = detector.process(lipDistance: 0.2, sensitivity: 0.5)
        let end = CACurrentMediaTime()

        let fftLatency = (end - start) * 1000

        print("FFT Latency: \(fftLatency) ms")

        XCTAssertLessThan(fftLatency, 15.0,
                         "FFT computation should be <15ms")
    }
}
```

### 4.2 Memory Usage

```swift
func testMemoryUsage() {
    let detector = SmartEatingDetector(configuration: .default)

    let initialMemory = reportMemoryUsage()

    // Process 1000 frames
    for i in 0..<1000 {
        let lipDistance = Float.random(in: 0.1...0.3)
        _ = detector.process(lipDistance: lipDistance, sensitivity: 0.5)
    }

    let finalMemory = reportMemoryUsage()
    let memoryIncrease = finalMemory - initialMemory

    print("Memory increase: \(memoryIncrease) MB")

    XCTAssertLessThan(memoryIncrease, 1.0,
                     "Memory increase should be <1MB after 1000 frames")
}
```

### 4.3 Battery Impact

**Test Setup:**
- Device: iPhone 12 (baseline)
- Duration: 30 minutes continuous use
- Measurement: Battery drain percentage

**Acceptance Criteria:**
- Battery drain < 10% over 30 minutes
- CPU usage < 30% average
- No thermal throttling

---

## 5. A/B Testing Framework

### 5.1 Experiment Configuration

```swift
struct ABTestExperiment: Codable {
    let experimentID: String
    let name: String
    let variants: [String: SmartEatingConfiguration]
    let userAssignment: [String: String]  // UserID -> Variant

    func getConfigurationForUser(_ userID: String) -> SmartEatingConfiguration {
        let variant = userAssignment[userID] ?? randomAssignment()
        return variants[variant] ?? .default
    }

    private func randomAssignment() -> String {
        let keys = Array(variants.keys)
        return keys.randomElement() ?? "control"
    }
}
```

### 5.2 Experiment 1: Rhythm Weight Optimization

**Hypothesis:** Increasing rhythm weight from 0.30 to 0.40 will improve accuracy by better distinguishing eating from talking.

```swift
let rhythmWeightExperiment = ABTestExperiment(
    experimentID: "exp_001_rhythm_weight",
    name: "Rhythm Weight Optimization",
    variants: [
        "control": SmartEatingConfiguration(
            rhythmWeight: 0.30,
            amplitudeWeight: 0.20,
            continuityWeight: 0.25
        ),
        "treatment": SmartEatingConfiguration(
            rhythmWeight: 0.40,
            amplitudeWeight: 0.15,
            continuityWeight: 0.25
        )
    ],
    userAssignment: [:]  // Random 50/50 split
)
```

**Metrics to Track:**
- Accuracy (primary)
- False positive rate (talking detected as eating)
- User satisfaction (survey)

**Success Criteria:** Treatment accuracy > Control accuracy by 5%+

### 5.3 Experiment 2: Hysteresis Tuning

**Hypothesis:** Reducing hysteresis from 5 to 3 frames will make detection more responsive without increasing flicker.

```swift
let hysteresisExperiment = ABTestExperiment(
    experimentID: "exp_002_hysteresis",
    name: "Hysteresis Optimization",
    variants: [
        "control": SmartEatingConfiguration(hysteresisThreshold: 5),
        "treatment_a": SmartEatingConfiguration(hysteresisThreshold: 3),
        "treatment_b": SmartEatingConfiguration(hysteresisThreshold: 7)
    ],
    userAssignment: [:]
)
```

**Metrics to Track:**
- State transition count (flicker metric)
- User-perceived responsiveness (survey)
- Accuracy

**Success Criteria:** <5% increase in flicker, >10% improvement in responsiveness

---

## 6. Validation Checklist

### Pre-Release Validation

- [ ] **Unit Tests:** All tests passing (>90% coverage)
- [ ] **Integration Tests:** End-to-end pipeline validated
- [ ] **Real Video Tests:** 70%+ accuracy on test set
- [ ] **Performance Tests:**
  - [ ] Latency < 10ms average, <20ms P95
  - [ ] Memory overhead < 1MB
  - [ ] Battery drain < 10% per 30min
- [ ] **Edge Case Tests:**
  - [ ] Talking while eating: <20% false positive rate
  - [ ] Drinking: <10% false positive rate
  - [ ] Yawning: <15% false positive rate
  - [ ] Multiple children: Detects primary child
- [ ] **A/B Test Results:** At least 2 experiments completed
- [ ] **User Testing:** 5+ parent feedback sessions

### Success Criteria Summary

| Metric | Target | Minimum Acceptable |
|--------|--------|--------------------|
| Overall Accuracy | 75% | 70% |
| Precision | 75% | 65% |
| Recall | 80% | 70% |
| F1 Score | 0.75 | 0.70 |
| False Positive Rate | <15% | <20% |
| Avg Latency | <8ms | <10ms |
| Memory Overhead | <500KB | <1MB |
| User Satisfaction | 4.2/5.0 | 4.0/5.0 |

---

## 7. Continuous Monitoring

### Production Metrics Dashboard

```swift
struct ProductionMetrics: Codable {
    let timestamp: Date
    let sessionID: String
    let userID: String

    // Detection metrics
    let avgConfidence: Float
    let stateTransitionCount: Int
    let avgQualityScore: Float

    // Performance metrics
    let avgLatency: Double
    let maxLatency: Double
    let memoryUsage: Double

    // User behavior
    let sessionDuration: TimeInterval
    let totalEatingTime: TimeInterval
    let manualOverrides: Int
}

class MetricsCollector {
    func logMetrics(_ metrics: ProductionMetrics) {
        // Send to analytics backend
        // Privacy-preserving aggregation
    }

    func generateWeeklyReport() -> MetricsReport {
        // Aggregate metrics
        // Identify anomalies
        // Generate alerts
    }
}
```

---

## 8. Test Data Generation Utilities

### Synthetic Signal Generator

```swift
class TestSignalGenerator {

    /// Generate realistic eating pattern
    static func generateRealisticEatingPattern(
        frequency: Float,
        duration: TimeInterval,
        sampleRate: Float,
        noiseLevel: Float = 0.1
    ) -> [Float] {

        let numSamples = Int(duration * Double(sampleRate))
        var pattern = [Float]()

        for i in 0..<numSamples {
            let t = Float(i) / sampleRate

            // Primary chewing component
            let chewing = 0.15 * sin(2 * Float.pi * frequency * t)

            // Secondary harmonics
            let harmonic2 = 0.05 * sin(2 * Float.pi * frequency * 2 * t)

            // Noise
            let noise = Float.random(in: -noiseLevel...noiseLevel)

            // Baseline offset
            let baseline: Float = 0.2

            let value = baseline + chewing + harmonic2 + noise
            pattern.append(value)
        }

        return pattern
    }

    /// Generate talking pattern (higher frequency, irregular)
    static func generateTalkingPattern(duration: TimeInterval, sampleRate: Float) -> [Float] {
        let numSamples = Int(duration * Double(sampleRate))
        var pattern = [Float]()

        for i in 0..<numSamples {
            let t = Float(i) / sampleRate

            // Irregular frequency modulation
            let freq = 3.0 + 1.0 * sin(0.5 * t)
            let talking = 0.12 * sin(2 * Float.pi * freq * t)

            let baseline: Float = 0.18
            pattern.append(baseline + talking)
        }

        return pattern
    }

    /// Generate pause pattern (static with minimal noise)
    static func generatePausePattern(duration: TimeInterval, sampleRate: Float) -> [Float] {
        let numSamples = Int(duration * Double(sampleRate))
        return [Float](repeating: 0.15, count: numSamples)
    }
}
```

---

## 9. Timeline & Milestones

### Week 1-2: Implementation
- [ ] Implement all feature extractors
- [ ] Unit tests for each component
- [ ] Basic integration tests

### Week 2-3: Testing Infrastructure
- [ ] Set up video labeling tool
- [ ] Label 10+ test videos
- [ ] Implement accuracy calculation framework

### Week 3-4: Validation & Tuning
- [ ] Run real video tests
- [ ] Identify accuracy gaps
- [ ] Parameter tuning iterations
- [ ] A/B test framework setup

### Week 4-5: Optimization
- [ ] Performance profiling
- [ ] Memory optimization
- [ ] Battery impact testing
- [ ] Edge case handling

### Week 5-6: Pre-Release
- [ ] User testing sessions
- [ ] Final accuracy validation
- [ ] Documentation updates
- [ ] Deployment preparation

**Target Completion:** End of Week 6

---

## References

- Full Algorithm Design: `/home/user/BobCam/docs/SmartEatingDetectionAlgorithm.md`
- Quick Reference: `/home/user/BobCam/docs/SmartEatingQuickReference.md`
- Implementation: `/home/user/BobCam/BobCam-iOS/BobCamAgent/BobCamAgent/SmartEatingDetector.swift`
