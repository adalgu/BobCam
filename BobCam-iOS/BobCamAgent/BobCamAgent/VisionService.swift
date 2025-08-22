import Combine
import CoreGraphics
import CoreVideo
import Foundation
import UIKit
import Vision

// MARK: - Configuration and State
struct LipDetectionConfiguration: Codable {
    let historySize: Int
    let minMovementThreshold: Float
    let eatingPatternThreshold: Float
    let varianceThreshold: Float
    let emaAlpha: Float // EMA smoothing factor

    static let `default` = LipDetectionConfiguration(
        historySize: 15,
        minMovementThreshold: 0.05,
        eatingPatternThreshold: 0.15,
        varianceThreshold: 0.001,
        emaAlpha: 0.3
    )
}

enum LipDetectionState {
    case eating
    case notEating
    case uncertain
}

// MARK: - 개선된 Configuration 및 에러 처리

enum VisionServiceState: Equatable {
    case idle
    case running
    case paused
    case failed(Error)

    static func == (lhs: VisionServiceState, rhs: VisionServiceState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.running, .running):
            return true
        case (.paused, .paused):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

enum VisionServiceError: LocalizedError {
    case visionRequestFailed(Error)
    case landmarksNotAvailable
    case configurationInvalid

    var errorDescription: String? {
        switch self {
        case .visionRequestFailed(let error):
            return "얼굴 인식 처리 실패: \(error.localizedDescription)"
        case .landmarksNotAvailable:
            return "얼굴 특징점을 감지할 수 없습니다"
        case .configurationInvalid:
            return "립 트래킹 설정이 올바르지 않습니다"
        }
    }
}

// MARK: - 프로토콜 정의 (O3 제안: 모델 불가지론적 설계)
protocol FaceTrackingServiceProtocol: ObservableObject {
    var isEating: Bool { get }
    var serviceState: VisionServiceState { get }
    var sensitivity: Float { get set }
    func processFrame(_ pixelBuffer: CVPixelBuffer)
    func startTracking()
    func stopTracking()
    func reset()
}

// MARK: - 개선된 Vision Service
class VisionService: ObservableObject, FaceTrackingServiceProtocol {

    // MARK: - Published Properties
    @Published var isEating: Bool = false
    @Published var serviceState: VisionServiceState = .idle
    @Published var sensitivity: Float = 0.5

    // MARK: - Performance Monitoring
    @Published var jitter: Double = 0.0
    @Published var processingTimeMs: Double = 0.0
    @Published var fps: Double = 0.0
    @Published var memoryMB: Double = 0.0
    @Published var peakMemoryMB: Double = 0.0

    // MARK: - Debug Support
    @Published var debugLandmarks: VNFaceLandmarks2D?
    @Published var debugFaceObservation: VNFaceObservation?

    // MARK: - Private Properties
    private let visionQueue = DispatchQueue(label: "com.bobcam.vision", qos: .userInteractive)
    let configuration: LipDetectionConfiguration
    private var lipDistanceHistory: CircularBuffer<Float>
    private var lastSmoothedPoint: CGPoint?
    private var metricsCalculator = MetricsCalculator()
    private var isProcessing = false
    private var lastFrameCompletedTime: CFTimeInterval = 0
    private var previousFaceBoundingBox: CGRect?
    private let roiMargin: CGFloat = 0.2

    // O3 제안: VNSequenceRequestHandler 재사용으로 성능 최적화
    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()

    // 프레임 스로틀링을 위한 내부 제어 (Expert Analysis 제안)
    private var lastProcessedTime: CFTimeInterval = 0
    private var frameInterval: CFTimeInterval = 1.0 / 15.0  // 15fps (dynamic)
    private let minInterval: CFTimeInterval = 1.0 / 20.0    // 20 fps upper bound
    private let maxInterval: CFTimeInterval = 1.0 / 10.0    // 10 fps lower bound

    private lazy var faceDetectionRequest: VNDetectFaceLandmarksRequest = {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }
            self.handleVisionRequestUpdate(request: request, error: error)
        }

        // 성능 최적화 설정
        request.preferBackgroundProcessing = false
        request.usesCPUOnly = false

        return request
    }()

    private var isTracking = false
    private var consecutiveErrors = 0
    private let maxConsecutiveErrors = 3

    // MARK: - Initialization
    init(configuration: LipDetectionConfiguration = .default) {
        self.configuration = configuration
        self.lipDistanceHistory = CircularBuffer<Float>(capacity: configuration.historySize)
    }

    // MARK: - Public Methods
    func startTracking() {
        serviceState = .running
        isTracking = true
        consecutiveErrors = 0
    }

    func stopTracking() {
        serviceState = .paused
        isTracking = false
        resetAlgorithmState()
    }

    func reset() {
        serviceState = .idle
        isTracking = false
        isEating = false
        consecutiveErrors = 0
        resetAlgorithmState()
    }

    // MARK: - Debug Methods

    /// Update stored landmarks for debug visualization
    func updateDebugLandmarks(_ landmarks: VNFaceLandmarks2D?, faceObservation: VNFaceObservation?) {
        self.debugLandmarks = landmarks
        self.debugFaceObservation = faceObservation
    }

    /// Get current landmarks for debug overlay
    func getCurrentLandmarksForDebug() -> (VNFaceLandmarks2D?, VNFaceObservation?) {
        return (debugLandmarks, debugFaceObservation)
    }

    func detect(from landmarks: VNFaceLandmarks2D, faceObservation: VNFaceObservation) -> LipDetectionState {
        guard let lipDistance = calculateSmoothedLipDistance(landmarks) else {
            return .uncertain
        }

        lipDistanceHistory.write(lipDistance)
        let state = analyzeEatingPattern()
        let currentJitter = metricsCalculator.calculateJitter(currentBox: faceObservation.boundingBox)

        DispatchQueue.main.async {
            self.jitter = currentJitter
        }

        return state
    }

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isTracking, serviceState == .running else { return }

        // Internal frame throttling (~15fps target, dynamically tuned)
        let now = CACurrentMediaTime()
        guard now - lastProcessedTime >= frameInterval else { return }
        lastProcessedTime = now

        // Frame dropping: if a previous frame is still processing, drop this one
        guard !isProcessing else { return }
        isProcessing = true

        // Configure ROI based on the last known face bounding box (expanded with margin)
        if let lastBox = previousFaceBoundingBox {
            faceDetectionRequest.regionOfInterest = expandedROI(from: lastBox, margin: roiMargin)
        } else {
            faceDetectionRequest.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        visionQueue.async { [weak self] in
            guard let self = self else { return }
            let start = CACurrentMediaTime()
            var procMs: Double = 0.0
            defer { self.isProcessing = false }

            do {
                try self.sequenceRequestHandler.perform([self.faceDetectionRequest], on: pixelBuffer)
                let end = CACurrentMediaTime()
                procMs = (end - start) * 1000.0

                // Memory profiling
                let mem = self.reportMemoryUsage() ?? self.memoryMB

                // Effective FPS measured between completed frames
                let fpsVal: Double = self.lastFrameCompletedTime > 0 ? 1.0 / (end - self.lastFrameCompletedTime) : 0.0
                self.lastFrameCompletedTime = end

                // Dynamic frame interval tuning (bounds: 10–20 FPS)
                if procMs > 100.0 {
                    self.frameInterval = min(self.frameInterval + 0.010, self.maxInterval) // +10ms
                } else if procMs < 50.0 {
                    self.frameInterval = max(self.frameInterval - 0.005, self.minInterval) // -5ms
                }

                // Structured performance log
                let ts = Date().timeIntervalSince1970
                let roi = self.faceDetectionRequest.regionOfInterest
                print(String(format: "[PERF] ts=%.3f memMB=%.2f procMs=%.1f fps=%.1f frameInterval=%.3f roi=%.2f,%.2f,%.2f,%.2f",
                              ts, mem, procMs, fpsVal, self.frameInterval,
                              roi.origin.x, roi.origin.y, roi.size.width, roi.size.height))

                // Publish metrics on main thread
                DispatchQueue.main.async {
                    self.consecutiveErrors = 0
                    self.processingTimeMs = procMs
                    self.fps = fpsVal
                    self.memoryMB = mem
                    if mem > self.peakMemoryMB { self.peakMemoryMB = mem }
                }

            } catch {
                let end = CACurrentMediaTime()
                procMs = (end - start) * 1000.0
                print("Vision request failed: \(error)")
                DispatchQueue.main.async {
                    self.processingTimeMs = procMs
                    self.handleVisionError(VisionServiceError.visionRequestFailed(error))
                }
            }
        }
    }

    // MARK: - Private Methods (개선된 에러 처리)
    private func handleVisionRequestUpdate(request: VNRequest, error: Error?) {
        guard error == nil else {
            print("Vision request error: \(String(describing: error))")
            return
        }

        guard let results = request.results as? [VNFaceObservation] else {
            DispatchQueue.main.async {
                self.isEating = false
                self.updateDebugLandmarks(nil, faceObservation: nil)
            }
            return
        }

        guard let firstFace = results.first,
              let landmarks = firstFace.landmarks else {
            DispatchQueue.main.async {
                self.isEating = false
                self.updateDebugLandmarks(nil, faceObservation: nil)
            }
            return
        }

        // --- Core Logic Integration ---
        guard let lipDistance = calculateSmoothedLipDistance(landmarks) else {
            return
        }

        lipDistanceHistory.write(lipDistance)
        let state = analyzeEatingPattern()
        let currentJitter = metricsCalculator.calculateJitter(currentBox: firstFace.boundingBox)
        // --- End Core Logic ---
        self.previousFaceBoundingBox = firstFace.boundingBox

        DispatchQueue.main.async {
            self.isEating = (state == .eating)
            self.jitter = currentJitter
            self.updateDebugLandmarks(landmarks, faceObservation: firstFace)
        }
    }

    private func handleVisionError(_ error: VisionServiceError) {
        consecutiveErrors += 1

        if consecutiveErrors >= maxConsecutiveErrors {
            serviceState = .failed(error)
            isTracking = false
            print("Vision service failed after \(maxConsecutiveErrors) consecutive errors")
        } else {
            // 재시도 로직 - 1초 후 자동 복구 시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, self.consecutiveErrors < self.maxConsecutiveErrors else { return }
                print("Attempting vision service recovery (attempt \(self.consecutiveErrors))")
            }
        }
    }

    // MARK: - Algorithm Logic
    private func resetAlgorithmState() {
        lipDistanceHistory.clear()
        lastSmoothedPoint = nil
    }

    private func calculateSmoothedLipDistance(_ landmarks: VNFaceLandmarks2D) -> Float? {
        guard let outerLips = landmarks.outerLips,
              let topCenter = getAveragePoint(from: outerLips, indices: [9, 10, 11]),
              let bottomCenter = getAveragePoint(from: outerLips, indices: [0, 1, 2])
        else {
            return nil
        }

        let currentPoint = CGPoint(
            x: (topCenter.x + bottomCenter.x) / 2,
            y: (topCenter.y + bottomCenter.y) / 2
        )
        let smoothedPoint = applyEMA(to: currentPoint)
        self.lastSmoothedPoint = smoothedPoint

        let deltaX = topCenter.x - bottomCenter.x
        let deltaY = topCenter.y - bottomCenter.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

        return Float(distance)
    }

    private func applyEMA(to point: CGPoint) -> CGPoint {
        guard let lastPoint = lastSmoothedPoint else {
            return point
        }
        let alpha = CGFloat(configuration.emaAlpha)
        let smoothedX = alpha * point.x + (1 - alpha) * lastPoint.x
        let smoothedY = alpha * point.y + (1 - alpha) * lastPoint.y
        return CGPoint(x: smoothedX, y: smoothedY)
    }

    private func analyzeEatingPattern() -> LipDetectionState {
        guard lipDistanceHistory.isFull else {
            return .uncertain
        }

        let history = lipDistanceHistory.allItems()
        let halfSize = configuration.historySize / 2

        let recentAverage = history.suffix(halfSize).reduce(0, +) / Float(halfSize)
        let olderAverage = history.prefix(halfSize).reduce(0, +) / Float(halfSize)
        let changeRate = abs(recentAverage - olderAverage)

        let adjustedThreshold = configuration.eatingPatternThreshold * sensitivity

        return changeRate > adjustedThreshold ? .eating : .notEating
    }

    private func getAveragePoint(from region: VNFaceLandmarkRegion2D, indices: [Int]) -> CGPoint? {
        let points = region.normalizedPoints
        guard !indices.contains(where: { $0 >= points.count }) else { return nil }

        let sum = indices.reduce(CGPoint.zero) { result, index in
            let point = points[index]
            return CGPoint(x: result.x + point.x, y: result.y + point.y)
        }

        return CGPoint(x: sum.x / CGFloat(indices.count), y: sum.y / CGFloat(indices.count))
    }

    private func expandedROI(from rect: CGRect, margin: CGFloat) -> CGRect {
        let x = max(0.0, rect.origin.x - rect.size.width * margin)
        let y = max(0.0, rect.origin.y - rect.size.height * margin)
        let w = min(1.0, rect.size.width * (1.0 + 2.0 * margin))
        let h = min(1.0, rect.size.height * (1.0 + 2.0 * margin))
        let clamped = CGRect(x: x, y: y, width: w, height: h)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        return clamped
    }

    private func reportMemoryUsage() -> Double? {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMegabytes = Double(taskInfo.resident_size) / 1024 / 1024
            return usedMegabytes
        } else {
            print("Error with task_info(): " +
                  (String(cString: mach_error_string(kerr), encoding: .ascii) ?? "unknown error"))
            return nil
        }
    }
}

// MARK: - Camera Service Delegate
extension VisionService: CameraServiceDelegate {
    func didReceiveFrame(_ pixelBuffer: CVPixelBuffer) {
        processFrame(pixelBuffer)
    }

    func didEncounterCameraError(_ error: CameraServiceError) {
        print("CameraService encountered an error: \(error.localizedDescription)")
        // Optionally, update the service state to failed
        // self.serviceState = .failed(error)
    }
}
