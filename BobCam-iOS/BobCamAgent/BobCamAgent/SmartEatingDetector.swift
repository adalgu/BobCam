//
//  SmartEatingDetector.swift
//  BobCamAgent
//
//  Advanced eating detection algorithm with multi-dimensional feature extraction,
//  state machine, and quality scoring.
//
//  Design: /home/user/BobCam/docs/SmartEatingDetectionAlgorithm.md
//

import Foundation
import Accelerate

// MARK: - Configuration

struct SmartEatingConfiguration: Codable {
    // Buffer sizes
    let historySize: Int
    let temporalBufferSize: Int
    let sessionHistorySize: Int

    // EMA smoothing
    let emaAlpha: Float

    // Hysteresis
    let hysteresisThreshold: Int

    // Feature weights
    let rhythmWeight: Float
    let amplitudeWeight: Float
    let continuityWeight: Float
    let focusWeight: Float
    let ageWeight: Float

    // Thresholds
    let activeThresholdBase: Float
    let resumeThresholdBase: Float
    let minAmplitude: Float
    let minRhythmStrength: Float

    // State transition durations
    let shortPauseDuration: TimeInterval
    let longPauseDuration: TimeInterval
    let distractedDuration: TimeInterval

    // Performance tuning
    let enableFFT: Bool
    let fftUpdateInterval: Int

    // Age-specific
    let childAge: Float

    static let `default` = SmartEatingConfiguration(
        historySize: 15,
        temporalBufferSize: 30,
        sessionHistorySize: 30,
        emaAlpha: 0.3,
        hysteresisThreshold: 5,
        rhythmWeight: 0.30,
        amplitudeWeight: 0.20,
        continuityWeight: 0.25,
        focusWeight: 0.15,
        ageWeight: 0.10,
        activeThresholdBase: 0.4,
        resumeThresholdBase: 0.3,
        minAmplitude: 0.2,
        minRhythmStrength: 0.3,
        shortPauseDuration: 5.0,
        longPauseDuration: 15.0,
        distractedDuration: 30.0,
        enableFFT: true,
        fftUpdateInterval: 3,
        childAge: 5.0
    )
}

// MARK: - Eating State

enum EatingState: String, Codable {
    case notStarted
    case activeEating
    case shortPause
    case longPause
    case distracted
    case finished

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

// MARK: - Feature Structures

struct TemporalFeatures {
    let dominantFrequency: Float      // Hz (0-5 Hz range)
    let rhythmStrength: Float         // 0-1 (spectral peak magnitude)
    let rhythmRegularity: Float       // 0-1 (coefficient of variation)
    let periodicity: Float            // 0-1 (autocorrelation peak)

    static let zero = TemporalFeatures(
        dominantFrequency: 0,
        rhythmStrength: 0,
        rhythmRegularity: 0,
        periodicity: 0
    )
}

struct MovementFeatures {
    let amplitude: Float              // 0-1 (normalized movement range)
    let velocity: Float               // Rate of change
    let jerkiness: Float              // 0-1 (second derivative variance)
    let smoothness: Float             // 0-1 (inverse of jerkiness)
    let dynamicRange: Float           // Peak-to-peak variation

    static let zero = MovementFeatures(
        amplitude: 0,
        velocity: 0,
        jerkiness: 0,
        smoothness: 0,
        dynamicRange: 0
    )
}

struct SessionFeatures {
    let sessionDuration: TimeInterval
    let continuityScore: Float
    let pauseDuration: TimeInterval
    let totalEatingTime: TimeInterval
    let eatingRatio: Float

    static let zero = SessionFeatures(
        sessionDuration: 0,
        continuityScore: 0,
        pauseDuration: 0,
        totalEatingTime: 0,
        eatingRatio: 0
    )
}

// MARK: - Quality Score

struct EatingQualityScore {
    let overallScore: Float          // 0-100
    let rhythmScore: Float           // 0-100
    let amplitudeScore: Float        // 0-100
    let continuityScore: Float       // 0-100
    let focusScore: Float            // 0-100
    let ageAdjustment: Float         // 0-100

    var grade: String {
        switch overallScore {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 60..<75: return "Fair"
        case 40..<60: return "Needs Improvement"
        default: return "Poor"
        }
    }

    static let zero = EatingQualityScore(
        overallScore: 0,
        rhythmScore: 0,
        amplitudeScore: 0,
        continuityScore: 0,
        focusScore: 0,
        ageAdjustment: 0
    )
}

// MARK: - Temporal Feature Extractor

class TemporalFeatureExtractor {
    private var cachedFeatures: TemporalFeatures = .zero
    private let samplingRate: Float = 15.0

    func extract(from buffer: CircularBuffer<Float>) -> TemporalFeatures {
        guard buffer.isFull else {
            return .zero
        }

        let signal = buffer.allItems()

        // 1. Detrend signal
        let mean = signal.reduce(0, +) / Float(signal.count)
        let detrended = signal.map { $0 - mean }

        // 2. Apply Hanning window
        let windowed = applyHanningWindow(detrended)

        // 3. Compute power spectral density
        let psd = computePowerSpectralDensity(windowed)

        // 4. Find dominant frequency in eating range (0.5-3.0 Hz)
        let (dominantFreq, peakPower) = findPeakInRange(psd: psd, frequencyRange: 0.5...3.0)

        // 5. Calculate rhythm strength
        let totalPower = psd.reduce(0, +)
        let rhythmStrength = totalPower > 0 ? min(peakPower / totalPower, 1.0) : 0

        // 6. Calculate autocorrelation
        let autocorr = computeAutocorrelation(detrended)
        let periodicity = findFirstPeakInAutocorrelation(autocorr)

        // 7. Calculate rhythm regularity
        let stdDev = calculateStandardDeviation(detrended)
        let cv = mean != 0 ? stdDev / abs(mean) : 1.0
        let rhythmRegularity = 1.0 / (1.0 + cv)

        let features = TemporalFeatures(
            dominantFrequency: dominantFreq,
            rhythmStrength: rhythmStrength,
            rhythmRegularity: rhythmRegularity,
            periodicity: periodicity
        )

        cachedFeatures = features
        return features
    }

    func getCachedFeatures() -> TemporalFeatures {
        return cachedFeatures
    }

    // MARK: - Private Helpers

    private func applyHanningWindow(_ signal: [Float]) -> [Float] {
        let n = signal.count
        return signal.enumerated().map { (i, value) in
            let window = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(n - 1)))
            return value * window
        }
    }

    private func computePowerSpectralDensity(_ signal: [Float]) -> [Float] {
        // TODO: Implement using vDSP_fft from Accelerate framework
        // For now, return placeholder
        let n = signal.count / 2
        return [Float](repeating: 0, count: n)

        /* Implementation outline:
        let n = signal.count
        let log2n = vDSP_Length(log2(Float(n)))

        // Setup FFT
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Perform FFT using vDSP
        // Calculate power spectrum: |X[k]|^2
        // Return PSD array

        vDSP_destroy_fftsetup(fftSetup)
        */
    }

    private func findPeakInRange(psd: [Float], frequencyRange: ClosedRange<Float>) -> (frequency: Float, power: Float) {
        let freqResolution = samplingRate / Float(2 * psd.count)

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

    private func computeAutocorrelation(_ signal: [Float]) -> [Float] {
        let n = signal.count
        var autocorr = [Float](repeating: 0, count: n)

        for lag in 0..<n {
            var sum: Float = 0
            for i in 0..<(n - lag) {
                sum += signal[i] * signal[i + lag]
            }
            autocorr[lag] = sum / Float(n - lag)
        }

        // Normalize
        let maxVal = autocorr[0]
        if maxVal > 0 {
            autocorr = autocorr.map { $0 / maxVal }
        }

        return autocorr
    }

    private func findFirstPeakInAutocorrelation(_ autocorr: [Float]) -> Float {
        guard autocorr.count > 3 else { return 0 }

        let minLag = 3
        let maxLag = min(autocorr.count - 1, 20)

        var maxPeak: Float = 0

        for i in minLag..<maxLag {
            if autocorr[i] > autocorr[i-1] &&
               autocorr[i] > autocorr[i+1] &&
               autocorr[i] > maxPeak {
                maxPeak = autocorr[i]
            }
        }

        return max(0, maxPeak)
    }

    private func calculateStandardDeviation(_ values: [Float]) -> Float {
        let n = Float(values.count)
        let mean = values.reduce(0, +) / n
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / n
        return sqrt(variance)
    }
}

// MARK: - Movement Feature Extractor

class MovementFeatureExtractor {
    func extract(from buffer: CircularBuffer<Float>, config: SmartEatingConfiguration) -> MovementFeatures {
        guard buffer.count >= 3 else {
            return .zero
        }

        let signal = buffer.allItems()
        let n = signal.count

        // 1. Calculate amplitude
        let minVal = signal.min() ?? 0
        let maxVal = signal.max() ?? 0
        let dynamicRange = maxVal - minVal
        let amplitude = min(dynamicRange / 0.2, 1.0)  // Normalize by typical eating amplitude

        // 2. Calculate velocity
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
        let jerkiness = min(accelStdDev / 0.03, 1.0)  // Normalize

        // 4. Calculate smoothness
        let smoothness = 1.0 - jerkiness

        // 5. Normalize velocity
        let normalizedVelocity = meanAbsVelocity * 15.0

        return MovementFeatures(
            amplitude: amplitude,
            velocity: normalizedVelocity,
            jerkiness: jerkiness,
            smoothness: smoothness,
            dynamicRange: dynamicRange
        )
    }

    private func calculateStandardDeviation(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        let n = Float(values.count)
        let mean = values.reduce(0, +) / n
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / n
        return sqrt(variance)
    }
}

// MARK: - Session Tracker

class SessionTracker {
    private var sessionStartTime: Date?
    private var lastEatingTime: Date?
    private var totalEatingDuration: TimeInterval = 0
    private var eatingHistory: CircularBuffer<Bool>

    init(historySize: Int = 30) {
        self.eatingHistory = CircularBuffer<Bool>(capacity: historySize)
    }

    func update(isEating: Bool) {
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

    func extractSessionFeatures() -> SessionFeatures {
        let now = Date()

        let sessionDuration = sessionStartTime.map {
            now.timeIntervalSince($0)
        } ?? 0

        let pauseDuration = lastEatingTime.map {
            now.timeIntervalSince($0)
        } ?? 0

        let recentHistory = eatingHistory.allItems()
        let eatingCount = recentHistory.filter { $0 }.count
        let continuityScore = recentHistory.isEmpty ? 0 :
            Float(eatingCount) / Float(recentHistory.count)

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

    func reset() {
        sessionStartTime = nil
        lastEatingTime = nil
        totalEatingDuration = 0
        eatingHistory.clear()
    }
}

// MARK: - Eating State Machine

class EatingStateMachine {
    private(set) var currentState: EatingState = .notStarted
    private(set) var stateConfidence: Float = 0.0

    private var transitionBuffer: CircularBuffer<EatingState>
    private let hysteresisThreshold = 5

    private var stateStartTime: Date = Date()
    private var stateDuration: TimeInterval {
        Date().timeIntervalSince(stateStartTime)
    }

    init() {
        self.transitionBuffer = CircularBuffer<EatingState>(capacity: 10)
    }

    func update(
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

        // Determine target state
        let targetState = determineTargetState(
            score: eatingScore,
            temporal: temporal,
            movement: movement,
            session: session,
            sensitivity: sensitivity
        )

        // Apply hysteresis
        transitionBuffer.write(targetState)

        if shouldTransition(to: targetState) {
            if currentState != targetState {
                currentState = targetState
                stateStartTime = Date()
                stateConfidence = eatingScore
            } else {
                // EMA update of confidence
                stateConfidence = 0.7 * stateConfidence + 0.3 * eatingScore
            }
        }

        return currentState
    }

    private func calculateEatingScore(
        temporal: TemporalFeatures,
        movement: MovementFeatures,
        session: SessionFeatures
    ) -> Float {

        let weights: [Float] = [0.35, 0.25, 0.20, 0.10, 0.10]
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

    private func determineTargetState(
        score: Float,
        temporal: TemporalFeatures,
        movement: MovementFeatures,
        session: SessionFeatures,
        sensitivity: Float
    ) -> EatingState {

        let activeThreshold = 0.4 * sensitivity
        let resumeThreshold = 0.3 * sensitivity

        switch currentState {
        case .notStarted:
            if score > activeThreshold &&
               temporal.rhythmStrength > 0.3 &&
               movement.amplitude > 0.2 {
                return .activeEating
            }
            return .notStarted

        case .activeEating:
            if score > resumeThreshold {
                return .activeEating
            }
            return .shortPause

        case .shortPause:
            if score > resumeThreshold {
                return .activeEating
            }
            if session.pauseDuration > 5.0 {
                return .longPause
            }
            return .shortPause

        case .longPause:
            if score > activeThreshold {
                return .activeEating
            }
            if session.pauseDuration > 15.0 {
                return .distracted
            }
            return .longPause

        case .distracted:
            if score > activeThreshold * 1.2 &&
               temporal.rhythmStrength > 0.4 {
                return .activeEating
            }
            if session.pauseDuration > 30.0 {
                return .finished
            }
            return .distracted

        case .finished:
            if score > activeThreshold * 1.5 {
                return .activeEating
            }
            return .finished
        }
    }

    private func shouldTransition(to targetState: EatingState) -> Bool {
        let recentStates = transitionBuffer.allItems()

        guard recentStates.count >= hysteresisThreshold else {
            return false
        }

        let lastN = recentStates.suffix(hysteresisThreshold)
        return lastN.allSatisfy { $0 == targetState }
    }

    func reset() {
        currentState = .notStarted
        stateConfidence = 0.0
        transitionBuffer.clear()
        stateStartTime = Date()
    }
}

// MARK: - Quality Score Calculator

class QualityScoreCalculator {
    private let childAge: Float

    init(childAge: Float = 5.0) {
        self.childAge = childAge
    }

    func calculate(
        temporal: TemporalFeatures,
        movement: MovementFeatures,
        session: SessionFeatures,
        state: EatingState
    ) -> EatingQualityScore {

        let rhythmScore = calculateRhythmScore(temporal: temporal)
        let amplitudeScore = calculateAmplitudeScore(movement: movement)
        let continuityScore = calculateContinuityScore(session: session, state: state)
        let focusScore = calculateFocusScore(session: session, state: state, movement: movement)
        let ageAdjustment = calculateAgeAdjustment(temporal: temporal, childAge: childAge)

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

    private func calculateRhythmScore(temporal: TemporalFeatures) -> Float {
        let idealFreqRange: ClosedRange<Float> = 1.0...2.0

        var freqScore: Float
        if idealFreqRange.contains(temporal.dominantFrequency) {
            freqScore = 100.0
        } else if temporal.dominantFrequency < idealFreqRange.lowerBound {
            let deviation = idealFreqRange.lowerBound - temporal.dominantFrequency
            freqScore = max(0, 100.0 - deviation * 50)
        } else {
            let deviation = temporal.dominantFrequency - idealFreqRange.upperBound
            freqScore = max(0, 100.0 - deviation * 30)
        }

        let rhythmScore = freqScore *
            (0.4 + 0.3 * temporal.rhythmStrength + 0.3 * temporal.rhythmRegularity)

        return min(rhythmScore, 100.0)
    }

    private func calculateAmplitudeScore(movement: MovementFeatures) -> Float {
        let idealAmplitudeRange: ClosedRange<Float> = 0.3...0.7

        var amplitudeScore: Float
        if idealAmplitudeRange.contains(movement.amplitude) {
            amplitudeScore = 100.0
        } else if movement.amplitude < idealAmplitudeRange.lowerBound {
            amplitudeScore = movement.amplitude / idealAmplitudeRange.lowerBound * 100.0
        } else {
            let excess = movement.amplitude - idealAmplitudeRange.upperBound
            amplitudeScore = max(0, 100.0 - excess * 150)
        }

        amplitudeScore = min(amplitudeScore + movement.smoothness * 20, 100.0)
        return amplitudeScore
    }

    private func calculateContinuityScore(session: SessionFeatures, state: EatingState) -> Float {
        var continuityScore = session.continuityScore * 100.0

        switch state {
        case .activeEating:
            continuityScore += 15
        case .shortPause:
            continuityScore += 5
        case .longPause, .distracted:
            continuityScore -= 20
        case .notStarted, .finished:
            continuityScore = 0
        }

        return min(max(continuityScore, 0), 100.0)
    }

    private func calculateFocusScore(
        session: SessionFeatures,
        state: EatingState,
        movement: MovementFeatures
    ) -> Float {
        var focusScore: Float = 100.0

        if session.pauseDuration > 0 {
            let pausePenalty = min(session.pauseDuration / 10.0, 50.0)
            focusScore -= Float(pausePenalty)
        }

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

        focusScore += movement.smoothness * 15

        return min(max(focusScore, 0), 100.0)
    }

    private func calculateAgeAdjustment(temporal: TemporalFeatures, childAge: Float) -> Float {
        let expectedFrequency: Float
        switch childAge {
        case 0..<3:
            expectedFrequency = 0.8
        case 3..<5:
            expectedFrequency = 1.2
        case 5..<7:
            expectedFrequency = 1.5
        case 7..<10:
            expectedFrequency = 1.8
        default:
            expectedFrequency = 2.0
        }

        let freqDeviation = abs(temporal.dominantFrequency - expectedFrequency)
        var ageScore: Float

        if freqDeviation < 0.3 {
            ageScore = 100.0
        } else {
            ageScore = max(0, 100.0 - freqDeviation * 100)
        }

        if childAge < 5 {
            ageScore += (1.0 - temporal.rhythmRegularity) * 20
        } else {
            ageScore += temporal.rhythmRegularity * 30
        }

        return min(ageScore, 100.0)
    }
}

// MARK: - Main Smart Eating Detector

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

class SmartEatingDetector {
    private let configuration: SmartEatingConfiguration
    private var temporalBuffer: CircularBuffer<Float>
    private var lipDistanceHistory: CircularBuffer<Float>

    private var temporalExtractor: TemporalFeatureExtractor
    private var movementExtractor: MovementFeatureExtractor
    private var sessionTracker: SessionTracker
    private var stateMachine: EatingStateMachine
    private var qualityCalculator: QualityScoreCalculator

    private var frameCounter: Int = 0

    init(configuration: SmartEatingConfiguration = .default) {
        self.configuration = configuration

        self.temporalBuffer = CircularBuffer(capacity: configuration.temporalBufferSize)
        self.lipDistanceHistory = CircularBuffer(capacity: configuration.historySize)

        self.temporalExtractor = TemporalFeatureExtractor()
        self.movementExtractor = MovementFeatureExtractor()
        self.sessionTracker = SessionTracker(historySize: configuration.sessionHistorySize)
        self.stateMachine = EatingStateMachine()
        self.qualityCalculator = QualityScoreCalculator(childAge: configuration.childAge)
    }

    /// Process new lip distance measurement
    func process(lipDistance: Float, sensitivity: Float) -> SmartEatingResult {
        // Update buffers
        temporalBuffer.write(lipDistance)
        lipDistanceHistory.write(lipDistance)

        // Extract features (FFT computed intermittently)
        frameCounter += 1

        var temporal: TemporalFeatures
        if configuration.enableFFT &&
           frameCounter % configuration.fftUpdateInterval == 0 &&
           temporalBuffer.isFull {
            temporal = temporalExtractor.extract(from: temporalBuffer)
        } else {
            temporal = temporalExtractor.getCachedFeatures()
        }

        let movement = movementExtractor.extract(
            from: lipDistanceHistory,
            config: configuration
        )

        // Update session
        let preliminaryEating = movement.amplitude > configuration.minAmplitude
        sessionTracker.update(isEating: preliminaryEating)
        let session = sessionTracker.extractSessionFeatures()

        // Update state machine
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

    /// Reset all state
    func reset() {
        temporalBuffer.clear()
        lipDistanceHistory.clear()
        sessionTracker.reset()
        stateMachine.reset()
        frameCounter = 0
    }
}
