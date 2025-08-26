import Combine
import CoreGraphics
import CoreVideo
import Foundation
import UIKit
import Vision

// MARK: - Performance-Optimized Vision Service
/// Optimized vision service with <200ms detection-to-action latency
final class PerformanceOptimizedVisionService: ObservableObject, FaceTrackingServiceProtocol {
    
    // MARK: - Published Properties (Minimized for Performance)
    @Published var isEating: Bool = false
    @Published var serviceState: VisionServiceState = .idle
    @Published var sensitivity: Float = 0.5
    
    // MARK: - Performance Metrics (Batch Updated)
    struct PerformanceMetrics {
        var jitter: Double = 0.0
        var processingTimeMs: Double = 0.0
        var fps: Double = 0.0
        var memoryMB: Double = 0.0
        var detectionLatencyMs: Double = 0.0
        var actionLatencyMs: Double = 0.0
    }
    
    @Published var metrics = PerformanceMetrics()
    
    // MARK: - Direct Action Pipeline
    var onEatingStateChanged: ((Bool) -> Void)?
    
    // MARK: - Private Properties
    private let visionQueue = DispatchQueue(label: "com.bobcam.vision.optimized", 
                                           qos: .userInteractive,
                                           attributes: .concurrent)
    private let configuration: LipDetectionConfiguration
    private var lipDistanceHistory: CircularBuffer<Float>
    private var lastSmoothedPoint: CGPoint?
    private var metricsCalculator = MetricsCalculator()
    
    // Thread-safe state management
    private let stateQueue = DispatchQueue(label: "com.bobcam.vision.state", qos: .userInteractive)
    private var _isProcessing = false
    private var isProcessing: Bool {
        get { stateQueue.sync { _isProcessing } }
        set { stateQueue.async(flags: .barrier) { self._isProcessing = newValue } }
    }
    
    // Performance optimization
    private var lastProcessedTime: CFTimeInterval = 0
    private let targetFPS: Double = 15.0
    private lazy var frameInterval: CFTimeInterval = 1.0 / targetFPS
    private var lastFrameCompletedTime: CFTimeInterval = 0
    private var previousFaceBoundingBox: CGRect?
    private let roiMargin: CGFloat = 0.2
    
    // Reusable Vision components
    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    private lazy var faceDetectionRequest: VNDetectFaceLandmarksRequest = {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleVisionRequestUpdate(request: request, error: error)
        }
        request.preferBackgroundProcessing = false
        request.usesCPUOnly = false
        return request
    }()
    
    // Eating state management with hysteresis
    private var eatingStateBuffer = CircularBuffer<Bool>(capacity: 5)
    private var lastEatingState: Bool = false
    private var stateChangeTimestamp: CFTimeInterval = 0
    
    // Combine subjects for reactive pipeline
    private let eatingStateSubject = PassthroughSubject<Bool, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(configuration: LipDetectionConfiguration = .default) {
        self.configuration = configuration
        self.lipDistanceHistory = CircularBuffer<Float>(capacity: configuration.historySize)
        setupReactivePipeline()
    }
    
    // MARK: - Setup Reactive Pipeline
    private func setupReactivePipeline() {
        // Direct eating state pipeline with minimal latency
        eatingStateSubject
            .removeDuplicates()
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] isEating in
                guard let self = self else { return }
                
                let now = CACurrentMediaTime()
                let latency = (now - self.stateChangeTimestamp) * 1000
                
                // Update state
                self.isEating = isEating
                
                // Direct callback for immediate action
                self.onEatingStateChanged?(isEating)
                
                // Update metrics
                self.metrics.actionLatencyMs = latency
                
                print("[🚀 Performance] Eating state changed to \(isEating) - Latency: \(String(format: "%.1f", latency))ms")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func startTracking() {
        serviceState = .running
    }
    
    func stopTracking() {
        serviceState = .paused
        resetAlgorithmState()
    }
    
    func reset() {
        serviceState = .idle
        isEating = false
        resetAlgorithmState()
    }
    
    // MARK: - High-Performance Frame Processing
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard serviceState == .running else { return }
        
        // Adaptive frame rate control
        let now = CACurrentMediaTime()
        guard now - lastProcessedTime >= frameInterval else { return }
        
        // Non-blocking processing check
        guard !isProcessing else { return }
        isProcessing = true
        
        let processingStartTime = now
        lastProcessedTime = now
        
        // Configure ROI for optimized processing
        if let lastBox = previousFaceBoundingBox {
            faceDetectionRequest.regionOfInterest = expandedROI(from: lastBox, margin: roiMargin)
        }
        
        // Async processing on vision queue
        visionQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }
            
            do {
                // Execute vision request
                try self.sequenceRequestHandler.perform([self.faceDetectionRequest], on: pixelBuffer)
                
                // Calculate processing metrics
                let processingEndTime = CACurrentMediaTime()
                let processingTime = (processingEndTime - processingStartTime) * 1000
                let fps = self.lastFrameCompletedTime > 0 ? 1.0 / (processingEndTime - self.lastFrameCompletedTime) : 0
                self.lastFrameCompletedTime = processingEndTime
                
                // Batch update metrics
                DispatchQueue.main.async {
                    self.metrics.processingTimeMs = processingTime
                    self.metrics.fps = fps
                    self.metrics.detectionLatencyMs = processingTime
                }
                
                // Adaptive frame rate adjustment
                self.adjustFrameRate(basedOn: processingTime)
                
            } catch {
                print("[Performance] Vision request failed: \(error)")
            }
        }
    }
    
    // MARK: - Vision Request Handler (Optimized)
    private func handleVisionRequestUpdate(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNFaceObservation],
              let firstFace = results.first,
              let landmarks = firstFace.landmarks else {
            updateEatingState(false)
            return
        }
        
        // Update ROI for next frame
        previousFaceBoundingBox = firstFace.boundingBox
        
        // Fast lip distance calculation
        guard let lipDistance = calculateOptimizedLipDistance(landmarks) else {
            updateEatingState(false)
            return
        }
        
        // Update history
        lipDistanceHistory.write(lipDistance)
        
        // Fast eating detection
        let isCurrentlyEating = analyzeOptimizedEatingPattern()
        
        // Update eating state with hysteresis
        updateEatingState(isCurrentlyEating)
        
        // Calculate jitter
        let jitter = metricsCalculator.calculateJitter(currentBox: firstFace.boundingBox)
        
        // Batch metric update
        DispatchQueue.main.async { [weak self] in
            self?.metrics.jitter = jitter
        }
    }
    
    // MARK: - Optimized Eating Detection
    private func analyzeOptimizedEatingPattern() -> Bool {
        guard lipDistanceHistory.isFull else { return false }
        
        let history = lipDistanceHistory.allItems()
        
        // Fast moving average calculation
        let halfSize = configuration.historySize / 2
        var recentSum: Float = 0
        var olderSum: Float = 0
        
        // Unrolled loop for better performance
        for i in 0..<halfSize {
            olderSum += history[i]
        }
        for i in halfSize..<history.count {
            recentSum += history[i]
        }
        
        let recentAverage = recentSum / Float(halfSize)
        let olderAverage = olderSum / Float(halfSize)
        let changeRate = abs(recentAverage - olderAverage)
        let adjustedThreshold = configuration.eatingPatternThreshold * sensitivity
        
        // Simplified detection logic for speed
        return changeRate > adjustedThreshold && 
               analyzeFastContinuousMovement(history) >= 2
    }
    
    // MARK: - Fast Movement Analysis
    private func analyzeFastContinuousMovement(_ history: [Float]) -> Int {
        var continuousCount = 0
        var maxContinuous = 0
        let threshold = configuration.minMovementThreshold
        
        for i in 1..<history.count {
            if abs(history[i] - history[i-1]) > threshold {
                continuousCount += 1
                maxContinuous = max(maxContinuous, continuousCount)
            } else {
                continuousCount = 0
            }
        }
        
        return maxContinuous
    }
    
    // MARK: - Optimized Lip Distance Calculation
    private func calculateOptimizedLipDistance(_ landmarks: VNFaceLandmarks2D) -> Float? {
        guard let outerLips = landmarks.outerLips else { return nil }
        
        let points = outerLips.normalizedPoints
        guard points.count > 11 else { return nil }
        
        // Direct access for performance
        let topCenter = CGPoint(
            x: (points[9].x + points[10].x + points[11].x) / 3,
            y: (points[9].y + points[10].y + points[11].y) / 3
        )
        let bottomCenter = CGPoint(
            x: (points[0].x + points[1].x + points[2].x) / 3,
            y: (points[0].y + points[1].y + points[2].y) / 3
        )
        
        // Fast distance calculation
        let deltaX = topCenter.x - bottomCenter.x
        let deltaY = topCenter.y - bottomCenter.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    
    // MARK: - State Management with Hysteresis
    private func updateEatingState(_ isEating: Bool) {
        eatingStateBuffer.write(isEating)
        
        // Count recent eating detections
        let recentStates = eatingStateBuffer.allItems()
        let eatingCount = recentStates.filter { $0 }.count
        
        // Hysteresis logic: require majority for state change
        let threshold = eatingStateBuffer.capacity / 2
        let newState = eatingCount > threshold
        
        // Only trigger change if state actually changed
        if newState != lastEatingState {
            lastEatingState = newState
            stateChangeTimestamp = CACurrentMediaTime()
            eatingStateSubject.send(newState)
        }
    }
    
    // MARK: - Frame Rate Adaptation
    private func adjustFrameRate(basedOn processingTime: Double) {
        if processingTime > 100 {
            // Slow down if processing is taking too long
            frameInterval = min(frameInterval * 1.1, 1.0 / 10.0)
        } else if processingTime < 50 {
            // Speed up if we have headroom
            frameInterval = max(frameInterval * 0.95, 1.0 / 20.0)
        }
    }
    
    // MARK: - Helper Methods
    private func expandedROI(from rect: CGRect, margin: CGFloat) -> CGRect {
        let x = max(0.0, rect.origin.x - rect.size.width * margin)
        let y = max(0.0, rect.origin.y - rect.size.height * margin)
        let w = min(1.0, rect.size.width * (1.0 + 2.0 * margin))
        let h = min(1.0, rect.size.height * (1.0 + 2.0 * margin))
        return CGRect(x: x, y: y, width: w, height: h)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    
    private func resetAlgorithmState() {
        lipDistanceHistory.clear()
        lastSmoothedPoint = nil
        eatingStateBuffer.clear()
        lastEatingState = false
    }
}

// MARK: - Camera Service Delegate
extension PerformanceOptimizedVisionService: CameraServiceDelegate {
    func didReceiveFrame(_ pixelBuffer: CVPixelBuffer) {
        processFrame(pixelBuffer)
    }
    
    func didEncounterCameraError(_ error: CameraServiceError) {
        serviceState = .cameraError(error)
    }
    
    func didUpdateFaceDetection(_ isDetecting: Bool) {
        // Handled internally
    }
}