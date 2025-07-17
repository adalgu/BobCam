import Foundation
import Vision
import Combine
import CoreVideo
import UIKit

// MARK: - 개선된 Configuration 및 에러 처리
struct LipDetectionConfiguration {
    let historySize: Int
    let minMovementThreshold: Float
    let eatingPatternThreshold: Float
    let varianceThreshold: Float
    
    static let `default` = LipDetectionConfiguration(
        historySize: 10,
        minMovementThreshold: 0.05,
        eatingPatternThreshold: 0.15,
        varianceThreshold: 0.001
    )
}

enum VisionServiceState {
    case idle
    case running
    case paused
    case failed(Error)
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
            lipMovementDetector.updateSensitivity(sensitivity)
        }
    }
    
    // MARK: - Private Properties
    private let visionQueue = DispatchQueue(label: "com.bobcam.vision", qos: .userInteractive)
    private let configuration: LipDetectionConfiguration
    
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
    
    private let lipMovementDetector: LipMovementDetector
    private var isTracking = false
    private var consecutiveErrors = 0
    private let maxConsecutiveErrors = 3
    
    // MARK: - Initialization
    init(configuration: LipDetectionConfiguration = .default) {
        self.configuration = configuration
        self.lipMovementDetector = LipMovementDetector(configuration: configuration)
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
        lipMovementDetector.reset()
    }
    
    func reset() {
        serviceState = .idle
        isTracking = false
        isEating = false
        consecutiveErrors = 0
        lipMovementDetector.reset()
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
            }
            return
        }
        
        // 단일 얼굴만 처리 (성능 최적화)
        guard let firstFace = results.first,
              let landmarks = firstFace.landmarks else {
            DispatchQueue.main.async {
                self.isEating = false
            }
            return
        }
        
        // 립 움직임 감지
        let eatingDetected = lipMovementDetector.detectEatingMotion(from: landmarks)
        
        DispatchQueue.main.async {
            self.isEating = eatingDetected
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

// MARK: - 개선된 립 움직임 감지 알고리즘
class LipMovementDetector {
    
    // MARK: - Properties
    private let configuration: LipDetectionConfiguration
    private var lipDistanceHistory: [Float] = []
    private var sensitivity: Float = 0.5
    
    // MARK: - Initialization
    init(configuration: LipDetectionConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    func detectEatingMotion(from landmarks: VNFaceLandmarks2D) -> Bool {
        guard let lipDistance = calculateSafeLipDistance(landmarks) else {
            return false
        }
        
        updateHistory(with: lipDistance)
        return analyzeEatingPattern()
    }
    
    func updateSensitivity(_ newSensitivity: Float) {
        sensitivity = max(0.1, min(1.0, newSensitivity)) // 범위 제한
    }
    
    func reset() {
        lipDistanceHistory.removeAll()
    }
    
    // MARK: - Private Methods (Expert Analysis 개선사항 반영)
    
    /// 안전한 립 거리 계산 - 하드코딩된 인덱스 의존성 제거
    private func calculateSafeLipDistance(_ landmarks: VNFaceLandmarks2D) -> Float? {
        guard let outerLips = landmarks.outerLips else {
            return nil
        }
        
        let points = outerLips.normalizedPoints
        guard points.count >= 12 else { // 최소 요구 포인트 수
            return nil
        }
        
        // 더 안전한 상하 입술 포인트 계산
        let sortedByY = points.sorted { $0.y < $1.y }
        let topPoints = Array(sortedByY.prefix(3))
        let bottomPoints = Array(sortedByY.suffix(3))
        
        let topCenter = topPoints.reduce(CGPoint.zero) { result, point in
            CGPoint(x: result.x + point.x, y: result.y + point.y)
        }
        let bottomCenter = bottomPoints.reduce(CGPoint.zero) { result, point in
            CGPoint(x: result.x + point.x, y: result.y + point.y)
        }
        
        let avgTop = CGPoint(x: topCenter.x / 3, y: topCenter.y / 3)
        let avgBottom = CGPoint(x: bottomCenter.x / 3, y: bottomCenter.y / 3)
        
        let distance = sqrt(pow(avgTop.x - avgBottom.x, 2) + 
                           pow(avgTop.y - avgBottom.y, 2))
        return Float(distance)
    }
    
    private func updateHistory(with distance: Float) {
        lipDistanceHistory.append(distance)
        
        // 설정 가능한 히스토리 크기 사용
        if lipDistanceHistory.count > configuration.historySize {
            lipDistanceHistory.removeFirst()
        }
    }
    
    private func analyzeEatingPattern() -> Bool {
        guard lipDistanceHistory.count >= configuration.historySize else {
            return false
        }
        
        let halfSize = configuration.historySize / 2
        let recentAverage = Array(lipDistanceHistory.suffix(halfSize)).reduce(0, +) / Float(halfSize)
        let olderAverage = Array(lipDistanceHistory.prefix(halfSize)).reduce(0, +) / Float(halfSize)
        let changeRate = abs(recentAverage - olderAverage)
        
        // 민감도를 반영한 임계값 조정
        let adjustedThreshold = configuration.eatingPatternThreshold * sensitivity
        
        let hasEatingPattern = changeRate > adjustedThreshold && 
                               detectRhythmicMovement()
        
        return hasEatingPattern
    }
    
    private func detectRhythmicMovement() -> Bool {
        guard lipDistanceHistory.count >= 6 else { return false }
        
        let recent = Array(lipDistanceHistory.suffix(6))
        let variance = calculateVariance(recent)
        
        // 설정 가능한 분산 임계값 사용
        return variance > configuration.varianceThreshold
    }
    
    private func calculateVariance(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Float(values.count)
    }
}
}

// MARK: - Camera Service Delegate
extension VisionService: CameraServiceDelegate {
    func didReceiveFrame(_ pixelBuffer: CVPixelBuffer) {
        processFrame(pixelBuffer)
    }
}
