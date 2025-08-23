import Vision
import Combine
import CoreGraphics
import CoreVideo
import Foundation
import UIKit

// MARK: - Multi-Modal Detection Configuration
struct MultiModalConfiguration: Codable {
    // 기존 립 트래킹 설정
    let lipConfig: LipDetectionConfiguration
    
    // 손 포즈 감지 설정
    let handDetectionEnabled: Bool
    let handConfidenceThreshold: Float
    let handToMouthDistanceThreshold: Float
    
    // 도구 감지 설정
    let utensilDetectionEnabled: Bool
    let utensilConfidenceThreshold: Float
    
    // 신호 융합 설정
    let lipWeight: Float
    let handWeight: Float
    let utensilWeight: Float
    let fusionThreshold: Float
    
    // 성능 설정
    let handDetectionFPS: Int  // 손 감지 프레임레이트 (7-10fps)
    let utensilDetectionFPS: Int  // 도구 감지 프레임레이트 (3-5fps)
    
    static let `default` = MultiModalConfiguration(
        lipConfig: .default,
        handDetectionEnabled: true,
        handConfidenceThreshold: 0.3,
        handToMouthDistanceThreshold: 0.15, // 정규화된 좌표계에서 15cm 정도
        utensilDetectionEnabled: true,
        utensilConfidenceThreshold: 0.5,
        lipWeight: 0.4,
        handWeight: 0.4,
        utensilWeight: 0.2,
        fusionThreshold: 0.6,
        handDetectionFPS: 8,
        utensilDetectionFPS: 4
    )
}

// MARK: - Enhanced Detection States
enum EatingDetectionState {
    case eating(confidence: Float)
    case notEating(confidence: Float)
    case uncertain(reason: String)
}

enum EatingSignal {
    case lipMovement(confidence: Float, distance: Float)
    case handToMouth(confidence: Float, distance: Float, detected: Bool)
    case utensilDetected(confidence: Float, position: CGPoint?, detected: Bool)
}

// MARK: - Multi-Modal Eating Detection Service
class MultiModalEatingDetectionService: ObservableObject, FaceTrackingServiceProtocol, CameraServiceDelegate {
    
    // MARK: - Published Properties (FaceTrackingServiceProtocol 준수)
    @Published var isEating: Bool = false
    @Published var serviceState: VisionServiceState = .idle
    @Published var sensitivity: Float = 0.5
    
    // MARK: - Enhanced Published Properties
    @Published var eatingState: EatingDetectionState = .uncertain(reason: "초기화 중")
    @Published var currentSignals: [EatingSignal] = []
    @Published var lipConfidence: Float = 0.0
    @Published var handConfidence: Float = 0.0
    @Published var utensilConfidence: Float = 0.0
    @Published var fusedConfidence: Float = 0.0
    @Published var smoothedFusedConfidence: Float = 0.0
    
    // MARK: - Performance Monitoring
    @Published var processingTimeMs: Double = 0.0
    @Published var fps: Double = 0.0
    @Published var memoryMB: Double = 0.0
    
    // MARK: - Debug Properties
    @Published var debugHandPose: VNHumanHandPoseObservation?
    @Published var debugFaceObservation: VNFaceObservation?
    @Published var debugObjects: [VNRecognizedObjectObservation] = []
    
    // MARK: - Private Properties
    private let visionQueue = DispatchQueue(label: "com.bobcam.multimodal.vision", qos: .userInteractive)
    private let configuration: MultiModalConfiguration
    private var isProcessing = false
    private var isTracking = false
    
    // Vision Request Handlers
    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    // Frame Rate Control
    private var lastLipProcessedTime: CFTimeInterval = 0
    private var lastHandProcessedTime: CFTimeInterval = 0
    private var lastUtensilProcessedTime: CFTimeInterval = 0
    
    private var lipFrameInterval: CFTimeInterval = 1.0 / 15.0  // 15fps for lip tracking
    private var handFrameInterval: CFTimeInterval  // Will be calculated from config
    private var utensilFrameInterval: CFTimeInterval  // Will be calculated from config
    
    // Core Detection Components
    private var lipDetectionService: VisionService
    private var signalHistory: CircularBuffer<[EatingSignal]>
    
    // Vision Requests
    private lazy var faceDetectionRequest: VNDetectFaceLandmarksRequest = {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleFaceDetectionResults(request: request, error: error)
        }
        request.preferBackgroundProcessing = false
        request.usesCPUOnly = false
        return request
    }()
    
    private lazy var handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest { [weak self] request, error in
            self?.handleHandPoseResults(request: request, error: error)
        }
        request.maximumHandCount = 2 // 양손 감지
        return request
    }()
    
    /*
    private lazy var objectRecognitionRequest: VNRecognizeObjectsRequest = {
        let request = VNRecognizeObjectsRequest { [weak self] request, error in
            self?.handleObjectRecognitionResults(request: request, error: error)
        }
        return request
    }()
    */
    
    // MARK: - Initialization
    init(configuration: MultiModalConfiguration = .default) {
        self.configuration = configuration
        self.handFrameInterval = 1.0 / Double(configuration.handDetectionFPS)
        self.utensilFrameInterval = 1.0 / Double(configuration.utensilDetectionFPS)
        
        // 기존 립 감지 서비스 초기화
        self.lipDetectionService = VisionService(configuration: configuration.lipConfig)
        
        // 신호 히스토리 버퍼 (1초분량 = 15프레임)
        self.signalHistory = CircularBuffer<[EatingSignal]>(capacity: 15)
        
        setupBindings()
    }
    
    // MARK: - Private Setup
    private func setupBindings() {
        // 립 감지 서비스의 결과를 구독
        lipDetectionService.$isEating
            .sink { [weak self] _ in
                // 립 감지 결과는 신호 융합에서 처리됨
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - FaceTrackingServiceProtocol Implementation
    func startTracking() {
        serviceState = .running
        isTracking = true
        lipDetectionService.startTracking()
        print("[MultiModal] 멀티모달 감지 시작")
    }
    
    func stopTracking() {
        serviceState = .paused
        isTracking = false
        lipDetectionService.stopTracking()
        resetState()
        print("[MultiModal] 멀티모달 감지 중지")
    }
    
    func reset() {
        serviceState = .idle
        isTracking = false
        isEating = false
        lipDetectionService.reset()
        resetState()
        print("[MultiModal] 멀티모달 감지 초기화")
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isTracking, serviceState == .running else { return }
        guard !isProcessing else { return } // Frame dropping for performance
        
        isProcessing = true
        let startTime = CACurrentMediaTime()
        
        visionQueue.async { [weak self] in
            self?.processFrameMultiModal(pixelBuffer, startTime: startTime)
        }
    }

    func didReceiveFrame(_ pixelBuffer: CVPixelBuffer) {
        processFrame(pixelBuffer)
    }

    func didEncounterCameraError(_ error: CameraServiceError) {
        DispatchQueue.main.async {
            self.serviceState = .failed(VisionServiceError.cameraError(error))
        }
    }
    
    // MARK: - Multi-Modal Frame Processing
    private func processFrameMultiModal(_ pixelBuffer: CVPixelBuffer, startTime: CFTimeInterval) {
        defer { isProcessing = false }
        
        let now = CACurrentMediaTime()
        var requestsToProcess: [VNRequest] = []
        
        // 1. 립 트래킹 (15fps)
        if now - lastLipProcessedTime >= lipFrameInterval {
            requestsToProcess.append(faceDetectionRequest)
            lastLipProcessedTime = now
        }
        
        // 2. 손 포즈 감지 (8fps)
        if configuration.handDetectionEnabled && now - lastHandProcessedTime >= handFrameInterval {
            requestsToProcess.append(handPoseRequest)
            lastHandProcessedTime = now
        }
        
        /*
        // 3. 도구 감지 (4fps)
        if configuration.utensilDetectionEnabled && now - lastUtensilProcessedTime >= utensilFrameInterval {
            requestsToProcess.append(objectRecognitionRequest)
            lastUtensilProcessedTime = now
        }
        */
        
        // Vision requests 실행
        if !requestsToProcess.isEmpty {
            do {
                try sequenceRequestHandler.perform(requestsToProcess, on: pixelBuffer)
                
                // 성능 메트릭 계산
                let endTime = CACurrentMediaTime()
                let processingTime = (endTime - startTime) * 1000.0
                
                DispatchQueue.main.async {
                    self.processingTimeMs = processingTime
                    self.fps = 1.0 / (endTime - startTime)
                }
                
            } catch {
                print("[MultiModal] Vision request 실패: \(error)")
                DispatchQueue.main.async {
                    self.serviceState = .failed(VisionServiceError.visionRequestFailed(error))
                }
            }
        }
    }
    
    // MARK: - Vision Results Handlers
    private func handleFaceDetectionResults(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNFaceObservation],
              let faceObservation = results.first,
              let landmarks = faceObservation.landmarks else {
            return
        }
        
        // 립 감지 결과 계산
        let lipState = lipDetectionService.detect(from: landmarks, faceObservation: faceObservation)
        let lipConfidence = calculateLipConfidence(from: lipState)
        
        let lipSignal = EatingSignal.lipMovement(
            confidence: lipConfidence,
            distance: calculateLipDistance(landmarks) ?? 0.0
        )
        
        DispatchQueue.main.async {
            self.lipConfidence = lipConfidence
            self.debugFaceObservation = faceObservation
        }
        
        updateSignalFusion(with: lipSignal)
    }
    
    private func handleHandPoseResults(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNHumanHandPoseObservation] else {
            return
        }
        
        var bestHandSignal: EatingSignal?
        var maxConfidence: Float = 0.0
        
        for handObservation in results {
            if let handSignal = processHandObservation(handObservation) {
                switch handSignal {
                case .handToMouth(let confidence, _, _):
                    if confidence > maxConfidence {
                        maxConfidence = confidence
                        bestHandSignal = handSignal
                    }
                default:
                    break
                }
            }
        }
        
        let finalSignal = bestHandSignal ?? EatingSignal.handToMouth(
            confidence: 0.0,
            distance: 1.0,
            detected: false
        )
        
        DispatchQueue.main.async {
            self.handConfidence = maxConfidence
            self.debugHandPose = results.first
        }
        
        updateSignalFusion(with: finalSignal)
    }
    
    /*
    private func handleObjectRecognitionResults(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNRecognizedObjectObservation] else {
            
            // 도구가 감지되지 않은 경우
            let noUtensilSignal = EatingSignal.utensilDetected(
                confidence: 0.0,
                position: nil,
                detected: false
            )
            updateSignalFusion(with: noUtensilSignal)
            return
        }
        
        // 숟가락, 젓가락, 포크 등을 찾기
        let utensilLabels = ["spoon", "fork", "chopstick", "utensil"]
        var bestUtensil: VNRecognizedObjectObservation?
        var maxConfidence: Float = 0.0
        
        for observation in results {
            let topLabel = observation.labels.first
            if let label = topLabel,
               utensilLabels.contains(where: { label.identifier.lowercased().contains($0) }),
               label.confidence > configuration.utensilConfidenceThreshold,
               label.confidence > maxConfidence {
                maxConfidence = label.confidence
                bestUtensil = observation
            }
        }
        
        let utensilSignal: EatingSignal
        if let utensil = bestUtensil {
            let center = CGPoint(
                x: utensil.boundingBox.midX,
                y: utensil.boundingBox.midY
            )
            utensilSignal = EatingSignal.utensilDetected(
                confidence: maxConfidence,
                position: center,
                detected: true
            )
        } else {
            utensilSignal = EatingSignal.utensilDetected(
                confidence: 0.0,
                position: nil,
                detected: false
            )
        }
        
        DispatchQueue.main.async {
            self.utensilConfidence = maxConfidence
            self.debugObjects = results
        }
        
        updateSignalFusion(with: utensilSignal)
    }
    */
    
    // MARK: - Signal Processing
    private func processHandObservation(_ handObservation: VNHumanHandPoseObservation) -> EatingSignal? {
        do {
            // 주요 손가락 및 손목 포인트 획득
            let wristPoint = try handObservation.recognizedPoint(.wrist)
            let thumbTip = try handObservation.recognizedPoint(.thumbTip)
            let indexTip = try handObservation.recognizedPoint(.indexTip)
            
            // 신뢰도 검사
            guard wristPoint.confidence > configuration.handConfidenceThreshold,
                  thumbTip.confidence > configuration.handConfidenceThreshold else {
                return nil
            }
            
            // 손-입 근접성 계산 (얼굴 영역과의 거리)
            let handCenter = CGPoint(
                x: (wristPoint.location.x + thumbTip.location.x + indexTip.location.x) / 3,
                y: (wristPoint.location.y + thumbTip.location.y + indexTip.location.y) / 3
            )
            
            // 얼굴 중심 추정 (이전 얼굴 감지 결과 사용)
            let faceCenter = CGPoint(x: 0.5, y: 0.5) // 기본값, 실제로는 debugFaceObservation 사용
            if let face = debugFaceObservation {
                let actualFaceCenter = CGPoint(
                    x: face.boundingBox.midX,
                    y: face.boundingBox.midY
                )
            }
            
            let distance = Float(sqrt(
                pow(handCenter.x - faceCenter.x, 2) +
                pow(handCenter.y - faceCenter.y, 2)
            ))
            
            let isNearMouth = distance < configuration.handToMouthDistanceThreshold
            let confidence = max(0.0, 1.0 - Float(distance / configuration.handToMouthDistanceThreshold))
            
            return EatingSignal.handToMouth(
                confidence: confidence,
                distance: Float(distance),
                detected: isNearMouth
            )
            
        } catch {
            print("[MultiModal] 손 포즈 처리 오류: \(error)")
            return nil
        }
    }
    
    private func updateSignalFusion(with newSignal: EatingSignal) {
        // 현재 신호 업데이트
        var updatedSignals = currentSignals
        
        // 같은 타입의 기존 신호 제거하고 새 신호 추가
        switch newSignal {
        case .lipMovement:
            updatedSignals.removeAll { signal in
                if case .lipMovement = signal { return true }
                return false
            }
        case .handToMouth:
            updatedSignals.removeAll { signal in
                if case .handToMouth = signal { return true }
                return false
            }
        case .utensilDetected:
            updatedSignals.removeAll { signal in
                if case .utensilDetected = signal { return true }
                return false
            }
        }
        
        updatedSignals.append(newSignal)
        
        // 신호 히스토리 업데이트
        signalHistory.write(updatedSignals)
        
        // 융합 알고리즘 실행
        let fusedResult = fuseSignals(updatedSignals)
        
        DispatchQueue.main.async {
            self.currentSignals = updatedSignals
            self.eatingState = fusedResult
            self.isEating = {
                switch fusedResult {
                case .eating: return true
                default: return false
                }
            }()
            
            switch fusedResult {
            case .eating(let confidence), .notEating(let confidence):
                self.fusedConfidence = confidence
            case .uncertain:
                self.fusedConfidence = 0.0
            }
            self.smoothedFusedConfidence = (0.2 * self.fusedConfidence) + (0.8 * self.smoothedFusedConfidence)
        }
    }
    
    // MARK: - Signal Fusion Algorithm
    private func fuseSignals(_ signals: [EatingSignal]) -> EatingDetectionState {
        var lipScore: Float = 0.0
        var handScore: Float = 0.0
        var utensilScore: Float = 0.0
        
        // 각 신호 타입별 점수 계산
        for signal in signals {
            switch signal {
            case .lipMovement(let confidence, _):
                lipScore = confidence
            case .handToMouth(let confidence, _, let detected):
                handScore = detected ? confidence : 0.0
            case .utensilDetected(let confidence, _, let detected):
                utensilScore = detected ? confidence : 0.0
            }
        }
        
        // 가중 평균 계산
        let totalWeight = configuration.lipWeight + configuration.handWeight + configuration.utensilWeight
        var weightedScore = (
            lipScore * configuration.lipWeight +
            handScore * configuration.handWeight +
            utensilScore * configuration.utensilWeight
        ) / totalWeight

        // 신호 간 상호작용 보너스
        if handScore > 0.5 && lipScore > 0.5 {
            weightedScore *= 1.2 // 손과 입이 동시에 활성화되면 20% 보너스
        }
        
        // 민감도 적용
        let adjustedThreshold = configuration.fusionThreshold * (1.0 - sensitivity + 0.5)
        let finalScore = weightedScore * (0.5 + sensitivity)
        
        // 최종 상태 결정
        if self.smoothedFusedConfidence >= adjustedThreshold {
            return .eating(confidence: finalScore)
        } else if finalScore >= adjustedThreshold * 0.5 {
            return .notEating(confidence: 1.0 - finalScore)
        } else {
            return .uncertain(reason: "신호 강도 부족 (score: \(String(format: "%.2f", finalScore)))")
        }
    }
    
    // MARK: - Helper Methods
    private func calculateLipConfidence(from state: LipDetectionState) -> Float {
        switch state {
        case .eating:
            return 0.8 // 립 트래킹 단독으로는 높은 신뢰도 제공 어려움
        case .notEating:
            return 0.2
        case .uncertain:
            return 0.0
        }
    }
    
    private func calculateLipDistance(_ landmarks: VNFaceLandmarks2D) -> Float? {
        guard let outerLips = landmarks.outerLips,
              outerLips.pointCount > 11 else { return nil }
        
        let points = outerLips.normalizedPoints
        let topCenter = points[9]  // 상단 중앙
        let bottomCenter = points[0]  // 하단 중앙
        
        let deltaY = topCenter.y - bottomCenter.y
        return Float(abs(deltaY))
    }
    
    private func resetState() {
        signalHistory.clear()
        currentSignals.removeAll()
        eatingState = .uncertain(reason: "재설정됨")
        lipConfidence = 0.0
        handConfidence = 0.0
        utensilConfidence = 0.0
        fusedConfidence = 0.0
    }
}

// MARK: - Debug and Monitoring Extensions
extension MultiModalEatingDetectionService {
    
    func getDetailedStatus() -> String {
        let signals = currentSignals.map { signal in
            switch signal {
            case .lipMovement(let conf, let dist):
                return "Lip: \(String(format: "%.2f", conf)) (dist: \(String(format: "%.3f", dist)))"
            case .handToMouth(let conf, let dist, let detected):
                return "Hand: \(String(format: "%.2f", conf)) (dist: \(String(format: "%.3f", dist)), detected: \(detected))"
            case .utensilDetected(let conf, _, let detected):
                return "Utensil: \(String(format: "%.2f", conf)) (detected: \(detected))"
            }
        }.joined(separator: ", ")
        
        let stateDesc = switch eatingState {
        case .eating(let conf):
            "EATING (\(String(format: "%.2f", conf)))"
        case .notEating(let conf):
            "NOT_EATING (\(String(format: "%.2f", conf)))"
        case .uncertain(let reason):
            "UNCERTAIN (\(reason))"
        }
        
        return "[\(stateDesc)] Signals: [\(signals)]"
    }
    
    func getPerformanceMetrics() -> [String: Any] {
        return [
            "processing_time_ms": processingTimeMs,
            "fps": fps,
            "memory_mb": memoryMB,
            "lip_confidence": lipConfidence,
            "hand_confidence": handConfidence,
            "utensil_confidence": utensilConfidence,
            "fused_confidence": fusedConfidence,
            "signal_count": currentSignals.count,
            "service_state": "\(serviceState)"
        ]
    }
}