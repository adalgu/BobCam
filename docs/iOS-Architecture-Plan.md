# BobCam iOS 아키텍처 설계

## 🏗️ 전체 시스템 아키텍처

### 고수준 아키텍처 다이어그램
```
┌─────────────────────────────────────────────────────────────┐
│                     BobCam iOS App                          │
├─────────────────────────────────────────────────────────────┤
│  SwiftUI Presentation Layer                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │   Camera View   │  │  Video Player   │  │ Settings UI │  │
│  │                 │  │                 │  │            │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Business Logic Layer (MVVM + Combine)                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │ CameraViewModel │  │ VideoViewModel  │  │ AppSettings │  │
│  │                 │  │                 │  │   Manager   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Core Service Layer                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │ Vision Service  │  │  Video Service  │  │ Data Store  │  │
│  │ (Face Tracking) │  │  (AVFoundation) │  │ (UserDef.)  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Hardware Abstraction Layer                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │   Camera API    │  │   Neural Engine │  │  Metal GPU  │  │
│  │(AVCaptureSession│  │   (Core ML)     │  │             │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 핵심 컴포넌트 설계

### 1. Vision Service (얼굴 및 립 트래킹)

#### 클래스 구조
```swift
protocol FaceTrackingDelegate: AnyObject {
    func didDetectFace(_ landmarks: [VNFaceLandmarks2D])
    func didDetectEatingMotion(_ isEating: Bool)
    func didEncounterError(_ error: VisionServiceError)
}

class VisionService: ObservableObject {
    // MARK: - Properties
    private let visionQueue = DispatchQueue(label: "com.bobcam.vision", qos: .userInteractive)
    private var faceDetectionRequest: VNDetectFaceLandmarksRequest
    private var lipMovementDetector: LipMovementDetector
    
    weak var delegate: FaceTrackingDelegate?
    
    // MARK: - Configuration
    struct Configuration {
        let processingFrameRate: Int = 20  // 20fps로 처리
        let detectionConfidenceThreshold: Float = 0.8
        let maxFacesCount: Int = 1  // 단일 얼굴만 처리
    }
    
    // MARK: - Public Methods
    func processFrame(_ pixelBuffer: CVPixelBuffer)
    func startTracking()
    func stopTracking()
    func updateSensitivity(_ sensitivity: Float)
}
```

#### 립 모빙먼트 감지 알고리즘
```swift
class LipMovementDetector {
    // MARK: - Constants
    private static let historySize = 10
    private static let minMovementThreshold: Float = 0.05
    private static let eatingPatternThreshold: Float = 0.15
    
    // MARK: - Properties
    private var lipDistanceHistory: [Float] = []
    private var isCurrentlyEating: Bool = false
    private var lastEatingStateChange: Date = Date()
    
    // MARK: - Core Algorithm (Python에서 포팅)
    func detectEatingMotion(from landmarks: VNFaceLandmarks2D) -> Bool {
        guard let lipLandmarks = landmarks.outerLips else { return false }
        
        let lipDistance = calculateLipDistance(lipLandmarks)
        updateHistory(with: lipDistance)
        
        return analyzeEatingPattern()
    }
    
    private func calculateLipDistance(_ landmarks: VNFaceLandmarkRegion2D) -> Float {
        let points = landmarks.normalizedPoints
        
        // 상하 입술 거리 계산 (기존 Python 알고리즘 포팅)
        let upperLip = points[13]  // 윗입술 중앙
        let lowerLip = points[19]  // 아랫입술 중앙
        
        let distance = sqrt(pow(upperLip.x - lowerLip.x, 2) + pow(upperLip.y - lowerLip.y, 2))
        return Float(distance)
    }
    
    private func analyzeEatingPattern() -> Bool {
        guard lipDistanceHistory.count >= Self.historySize else { return false }
        
        // 변화율 분석
        let recentAverage = lipDistanceHistory.suffix(5).reduce(0, +) / 5
        let olderAverage = lipDistanceHistory.prefix(5).reduce(0, +) / 5
        let changeRate = abs(recentAverage - olderAverage)
        
        // 주기적 패턴 감지
        let hasEatingPattern = changeRate > Self.eatingPatternThreshold && 
                               detectRhythmicMovement()
        
        return hasEatingPattern
    }
}
```

### 2. Camera Service (카메라 관리)

#### 실시간 카메라 처리
```swift
class CameraService: NSObject, ObservableObject {
    // MARK: - Properties
    private let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.bobcam.camera")
    
    @Published var isSessionRunning = false
    @Published var captureDevice: AVCaptureDevice?
    
    var visionService: VisionService?
    
    // MARK: - Configuration
    func configureSession() {
        sessionQueue.async {
            self.configureCaptureSession()
        }
    }
    
    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        
        // 4K 해상도 설정하되 처리는 720p로
        captureSession.sessionPreset = .hd1280x720
        
        // 전면 카메라 설정
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                       for: .video, 
                                                       position: .front) else {
            return
        }
        
        // 60fps 설정 (Neural Engine 최적화)
        do {
            try frontCamera.lockForConfiguration()
            frontCamera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
            frontCamera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
            frontCamera.unlockForConfiguration()
        } catch {
            print("카메라 설정 실패: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, 
                      didOutput sampleBuffer: CMSampleBuffer, 
                      from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Vision Service로 프레임 전달 (20fps로 스로틀링)
        if shouldProcessFrame() {
            visionService?.processFrame(pixelBuffer)
        }
    }
    
    private func shouldProcessFrame() -> Bool {
        // 20fps 처리를 위한 프레임 스킵 로직
        // 60fps 입력에서 20fps 처리 = 3프레임마다 1번
        return frameCounter % 3 == 0
    }
}
```

### 3. Video Service (비디오 재생 관리)

#### AVPlayer 기반 비디오 컨트롤
```swift
class VideoService: ObservableObject {
    // MARK: - Properties
    private var player: AVPlayer?
    private var playerLooper: AVPlayerLooper?
    
    @Published var isPlaying: Bool = false
    @Published var currentVideoURL: URL?
    @Published var playbackState: PlaybackState = .stopped
    
    enum PlaybackState {
        case stopped, playing, paused, loading
    }
    
    // MARK: - Video Control
    func loadVideo(from url: URL) {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        player = AVPlayer(playerItem: playerItem)
        
        // 무한 반복 설정
        playerLooper = AVPlayerLooper(player: player!, templateItem: playerItem)
        
        currentVideoURL = url
        playbackState = .stopped
    }
    
    func playVideo() {
        guard let player = player else { return }
        
        player.play()
        isPlaying = true
        playbackState = .playing
        
        // 부드러운 페이드 인 효과
        animateVideoOpacity(to: 1.0)
    }
    
    func pauseVideo() {
        guard let player = player else { return }
        
        // 부드러운 페이드 아웃 효과
        animateVideoOpacity(to: 0.3) {
            player.pause()
            self.isPlaying = false
            self.playbackState = .paused
        }
    }
    
    private func animateVideoOpacity(to value: Double, completion: (() -> Void)? = nil) {
        withAnimation(.easeInOut(duration: 0.5)) {
            // SwiftUI에서 opacity 애니메이션 처리
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion?()
        }
    }
}
```

### 4. App State Management (상태 관리)

#### Combine을 활용한 반응형 상태 관리
```swift
class AppStateManager: ObservableObject {
    // MARK: - Published States
    @Published var eatingState: EatingState = .notEating
    @Published var appMode: AppMode = .monitoring
    @Published var settings: AppSettings = AppSettings()
    
    // MARK: - Services
    private let visionService: VisionService
    private let videoService: VideoService
    private let cameraService: CameraService
    
    // MARK: - Combine Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    enum EatingState {
        case notEating, startedEating, eating, stoppedEating
    }
    
    enum AppMode {
        case monitoring, paused, settings
    }
    
    init() {
        self.visionService = VisionService()
        self.videoService = VideoService()
        self.cameraService = CameraService()
        
        setupBindings()
    }
    
    private func setupBindings() {
        // 립 트래킹 결과에 따른 비디오 제어
        visionService.$isEating
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isEating in
                self?.handleEatingStateChange(isEating)
            }
            .store(in: &cancellables)
        
        // 설정 변경에 따른 서비스 업데이트
        settings.$sensitivity
            .sink { [weak self] sensitivity in
                self?.visionService.updateSensitivity(sensitivity)
            }
            .store(in: &cancellables)
    }
    
    private func handleEatingStateChange(_ isEating: Bool) {
        if isEating && eatingState == .notEating {
            eatingState = .startedEating
            videoService.playVideo()
        } else if !isEating && (eatingState == .eating || eatingState == .startedEating) {
            eatingState = .stoppedEating
            videoService.pauseVideo()
        }
        
        // 상태 업데이트
        eatingState = isEating ? .eating : .notEating
    }
}
```

---

## 🚀 성능 최적화 전략

### 1. Neural Engine 활용
```swift
// Core ML 모델 최적화 설정
let configuration = MLModelConfiguration()
configuration.computeUnits = .cpuAndNeuralEngine  // Neural Engine 우선 사용
configuration.allowLowPrecisionAccumulationOnGPU = true

// 모델 로딩 최적화
class ModelManager {
    private static let shared = ModelManager()
    private var faceModel: VNCoreMLModel?
    
    func loadOptimizedModel() async {
        do {
            let model = try await MLModel(contentsOf: modelURL, configuration: configuration)
            faceModel = try VNCoreMLModel(for: model)
        } catch {
            print("모델 로딩 실패: \(error)")
        }
    }
}
```

### 2. 메모리 최적화
```swift
class MemoryManager {
    private static let pixelBufferPool = CVPixelBufferPool()
    
    // 메모리 풀을 활용한 효율적 메모리 관리
    static func getReusablePixelBuffer() -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
        return status == kCVReturnSuccess ? pixelBuffer : nil
    }
    
    // 자동 메모리 해제
    func performMemoryCleanup() {
        autoreleasepool {
            // 임시 객체들 정리
        }
    }
}
```

### 3. 배터리 효율성
```swift
class PowerManager: ObservableObject {
    @Published var powerMode: PowerMode = .normal
    
    enum PowerMode {
        case lowPower, normal, highPerformance
    }
    
    func adaptToPowerState() {
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        switch (batteryLevel, batteryState) {
        case (0.0...0.2, .unplugged):
            powerMode = .lowPower
            reduceFPS(to: 15)
        case (0.2...0.5, .unplugged):
            powerMode = .normal
            reduceFPS(to: 20)
        default:
            powerMode = .highPerformance
            reduceFPS(to: 30)
        }
    }
    
    private func reduceFPS(to fps: Int) {
        // 프레임 처리 빈도 조정
        NotificationCenter.default.post(name: .fpsChanged, object: fps)
    }
}
```

---

## 🎨 SwiftUI UI 아키텍처

### 1. Main App Structure
```swift
@main
struct BobCamApp: App {
    @StateObject private var appState = AppStateManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)  // 아이들 눈에 편안한 다크 모드
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 카메라 피드 (좌측)
                CameraView()
                    .frame(width: geometry.size.width * 0.4)
                
                // 비디오 플레이어 (우측)
                VideoPlayerView()
                    .frame(width: geometry.size.width * 0.6)
            }
            .overlay(alignment: .bottom) {
                StatusBar()
                    .padding()
            }
        }
        .ignoresSafeArea()
    }
}
```

### 2. Camera View Component
```swift
struct CameraView: UIViewRepresentable {
    @EnvironmentObject var appState: AppStateManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // AVCaptureVideoPreviewLayer 설정
        let previewLayer = AVCaptureVideoPreviewLayer(session: appState.cameraService.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 프레임 업데이트 시 필요한 처리
    }
}
```

### 3. 접근성 지원
```swift
extension ContentView {
    private var accessibilitySupport: some View {
        VStack {
            // VoiceOver 지원
            Text("카메라 피드")
                .accessibilityLabel("실시간 카메라 화면")
                .accessibilityHint("아이의 얼굴을 인식하여 식사 상태를 감지합니다")
            
            Text("비디오 플레이어")
                .accessibilityLabel("비디오 재생 화면")
                .accessibilityValue(appState.videoService.isPlaying ? "재생 중" : "일시정지")
        }
        .accessibilityElement(children: .contain)
    }
}
```

---

## 📊 데이터 모델 및 저장소

### 1. Core Data Models
```swift
// 사용 통계 저장
@objc(UsageSession)
class UsageSession: NSManagedObject {
    @NSManaged var startTime: Date
    @NSManaged var endTime: Date?
    @NSManaged var totalEatingTime: TimeInterval
    @NSManaged var detectionAccuracy: Float
    @NSManaged var videoWatched: String?
}

// 앱 설정 저장
struct AppSettings: Codable {
    var sensitivity: Float = 0.5
    var selectedVideoURL: URL?
    var enableHapticFeedback: Bool = true
    var enableSoundEffects: Bool = false
    var parentalControlsEnabled: Bool = true
    
    // UserDefaults와 동기화
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "AppSettings")
        }
    }
    
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "AppSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }
}
```

---

## 🔧 테스트 가능한 아키텍처

### 1. Protocol-Oriented Design
```swift
protocol FaceTrackingServiceProtocol {
    func processFrame(_ pixelBuffer: CVPixelBuffer)
    func startTracking()
    func stopTracking()
}

protocol VideoServiceProtocol {
    func loadVideo(from url: URL)
    func playVideo()
    func pauseVideo()
}

// 의존성 주입을 통한 테스트 용이성
class AppStateManager {
    private let faceTrackingService: FaceTrackingServiceProtocol
    private let videoService: VideoServiceProtocol
    
    init(faceTrackingService: FaceTrackingServiceProtocol = VisionService(),
         videoService: VideoServiceProtocol = VideoService()) {
        self.faceTrackingService = faceTrackingService
        self.videoService = videoService
    }
}
```

### 2. 단위 테스트 지원
```swift
// Mock 객체를 통한 테스트
class MockVisionService: FaceTrackingServiceProtocol {
    var isTrackingStarted = false
    var processedFrameCount = 0
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        processedFrameCount += 1
    }
    
    func startTracking() {
        isTrackingStarted = true
    }
    
    func stopTracking() {
        isTrackingStarted = false
    }
}
```

---

## 🚨 에러 처리 및 복구

### 1. 포괄적인 에러 처리
```swift
enum BobCamError: LocalizedError {
    case cameraPermissionDenied
    case cameraNotAvailable
    case visionProcessingFailed(Error)
    case videoLoadingFailed(URL)
    case neuralEngineNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "카메라 권한이 필요합니다. 설정에서 권한을 허용해주세요."
        case .cameraNotAvailable:
            return "카메라를 사용할 수 없습니다."
        case .visionProcessingFailed(let error):
            return "얼굴 인식 처리 중 오류가 발생했습니다: \(error.localizedDescription)"
        case .videoLoadingFailed(let url):
            return "비디오를 불러올 수 없습니다: \(url.lastPathComponent)"
        case .neuralEngineNotAvailable:
            return "Neural Engine을 사용할 수 없습니다. 성능이 제한될 수 있습니다."
        }
    }
}

// 에러 복구 메커니즘
class ErrorRecoveryManager {
    func handleError(_ error: BobCamError) {
        switch error {
        case .cameraPermissionDenied:
            requestCameraPermission()
        case .cameraNotAvailable:
            showCameraUnavailableAlert()
        case .visionProcessingFailed:
            restartVisionService()
        case .videoLoadingFailed:
            selectAlternativeVideo()
        case .neuralEngineNotAvailable:
            fallbackToCPUProcessing()
        }
    }
}
```

---

*마지막 업데이트: $(date)*
*관련 문서: iOS-Development-TODO.md, AI-Workflow-Strategy.md*