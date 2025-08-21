import Foundation
import Vision
import Combine
import CoreVideo
import UIKit
import CoreGraphics

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
    @Published var sensitivity: Float = 0.5 {
        didSet {
            optimizedLipDetectionService.updateSensitivity(sensitivity)
        }
    }
    
    // MARK: - Performance Monitoring
    @Published var currentAccuracy: AccuracyMetrics?
    @Published var currentPerformance: PerformanceMetrics?
    
    // MARK: - Debug Support
    @Published var debugLandmarks: VNFaceLandmarks2D?
    @Published var debugFaceObservation: VNFaceObservation?
    
    // MARK: - Private Properties
    private let visionQueue = DispatchQueue(label: "com.bobcam.vision", qos: .userInteractive)
    let configuration: LipDetectionConfiguration
    
    // O3 제안: VNSequenceRequestHandler 재사용으로 성능 최적화
    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    // 프레임 스로틀링을 위한 내부 제어 (Expert Analysis 제안)
    private var lastProcessedTime: CFTimeInterval = 0
    private let frameInterval: CFTimeInterval = 1.0 / 15.0  // 15fps
    
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
    
    // Phase 2: 새로운 OptimizedLipDetectionService 사용
    private let optimizedLipDetectionService: OptimizedLipDetectionService
    private var isTracking = false
    private var consecutiveErrors = 0
    private let maxConsecutiveErrors = 3
    
    // MARK: - Initialization
    init(configuration: LipDetectionConfiguration = .default) {
        self.configuration = configuration
        self.optimizedLipDetectionService = OptimizedLipDetectionService(configuration: configuration)
        
        // 모니터링 델리게이트 설정
        setupMonitoringDelegates()
    }
    
    private func setupMonitoringDelegates() {
        // Performance 모니터링 설정
        if let performanceService = optimizedLipDetectionService.performanceMonitor as? PerformanceMonitorService {
            performanceService.delegate = self
        }
        
        // Accuracy 모니터링 설정
        if let accuracyService = optimizedLipDetectionService.accuracyMonitor as? AccuracyMonitorService {
            accuracyService.delegate = self
        }
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
        optimizedLipDetectionService.reset()
    }
    
    func reset() {
        serviceState = .idle
        isTracking = false
        isEating = false
        consecutiveErrors = 0
        optimizedLipDetectionService.reset()
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
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isTracking, serviceState == .running else { return }
        
        // Expert Analysis 제안: 내부 프레임 스로틀링
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastProcessedTime >= frameInterval else { return }
        lastProcessedTime = currentTime
        
        // O3 제안: 백그라운드 큐에서 Vision 처리
        visionQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                // VNSequenceRequestHandler 재사용으로 메모리 효율성 향상
                try self.sequenceRequestHandler.perform([self.faceDetectionRequest], 
                                                        on: pixelBuffer)
                
                // 성공 시 에러 카운터 리셋
                DispatchQueue.main.async {
                    self.consecutiveErrors = 0
                }
                
            } catch {
                print("Vision request failed: \(error)")
                DispatchQueue.main.async {
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
                // Clear debug landmarks when no face detected
                self.updateDebugLandmarks(nil, faceObservation: nil)
            }
            return
        }
        
        // 단일 얼굴만 처리 (성능 최적화)
        guard let firstFace = results.first,
              let landmarks = firstFace.landmarks else {
            DispatchQueue.main.async {
                self.isEating = false
                self.updateDebugLandmarks(nil, faceObservation: nil)
            }
            return
        }
        
        // Phase 2: OptimizedLipDetectionService 사용
        let detectionState = optimizedLipDetectionService.detect(from: landmarks, faceObservation: firstFace)
        
        DispatchQueue.main.async {
            self.isEating = (detectionState == .eating)
            // Update debug landmarks for visualization
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
}

// MARK: - Performance Monitoring Delegates
extension VisionService: PerformanceMonitorDelegate {
    func didUpdatePerformance(metrics: PerformanceMetrics) {
        DispatchQueue.main.async {
            self.currentPerformance = metrics
        }
    }
}

extension VisionService: AccuracyMonitorDelegate {
    func didUpdateAccuracy(metrics: AccuracyMetrics) {
        DispatchQueue.main.async {
            self.currentAccuracy = metrics
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
