# Phase 1: 핵심 기능 개발

## 목표
입술 움직임과 손/얼굴 근접 감지를 통해 "먹는 행동"을 인식하고, 영상을 제어하는 핵심 기능을 구현합니다.

## 사전 준비

### 참고 문서
- SPEC: `/Users/macmini/study/01-active/BobCam/dev/docs/SPEC.md`
- 기존 코드 (참고용): `BobCamAgent/VisionService.swift`, `BobCamAgent/CameraService.swift`

### 기존 코드 정리
기존 `BobCamAgent/` 폴더의 파일들을 `BobCamAgent/Legacy/`로 이동하고 새로 시작합니다.

```bash
# 기존 파일 백업 (선택사항)
mkdir -p BobCamAgent/Legacy
mv BobCamAgent/*.swift BobCamAgent/Legacy/ 2>/dev/null || true
```

---

## Task 1: 프로젝트 구조 설정

### 1.1 폴더 구조 생성

```
BobCamAgent/
├── App/
│   └── BobCamAgentApp.swift
├── Views/
│   └── MainView.swift
├── Services/
│   ├── Protocols/
│   │   ├── VisionServiceProtocol.swift
│   │   ├── CameraServiceProtocol.swift
│   │   └── VideoServiceProtocol.swift
│   ├── VisionService.swift
│   ├── CameraService.swift
│   └── VideoService.swift
├── Models/
│   ├── EatingState.swift
│   └── DetectionResult.swift
└── Utilities/
    └── Constants.swift
```

### 1.2 Constants.swift 작성

```swift
import Foundation

enum Constants {
    enum Vision {
        static let processingFPS: Int = 15
        static let frameSkipCount: Int = 4  // 60fps에서 15fps로
        static let lipMovementThreshold: Double = 0.02
        static let handFaceDistanceRatio: Double = 1.5
    }

    enum Timing {
        static let defaultWaitSeconds: Int = 5
        static let minWaitSeconds: Int = 1
        static let maxWaitSeconds: Int = 30
    }

    enum Camera {
        static let sessionPreset = AVCaptureSession.Preset.hd1280x720
        static let position = AVCaptureDevice.Position.front
    }
}
```

### 1.3 기본 앱 엔트리 포인트

```swift
// BobCamAgentApp.swift
import SwiftUI

@main
struct BobCamAgentApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
```

---

## Task 2: VisionService 구현

### 2.1 Protocol 정의

```swift
// Services/Protocols/VisionServiceProtocol.swift
import Foundation
import CoreVideo

protocol VisionServiceProtocol: ObservableObject {
    /// 현재 먹는 중인지 (입술 움직임 OR 손이 얼굴 근처)
    var isEating: Bool { get }

    /// 얼굴이 감지되었는지
    var faceDetected: Bool { get }

    /// 손이 얼굴 근처에 있는지
    var handNearFace: Bool { get }

    /// 입술 움직임 정도 (0.0 ~ 1.0)
    var lipMovement: Double { get }

    /// 처리 시작
    func startProcessing()

    /// 처리 중지
    func stopProcessing()

    /// 프레임 처리
    func processFrame(_ pixelBuffer: CVPixelBuffer)
}
```

### 2.2 VisionService 구현

```swift
// Services/VisionService.swift
import Foundation
import Vision
import CoreVideo
import Combine

final class VisionService: NSObject, VisionServiceProtocol {
    // MARK: - Published Properties
    @Published private(set) var isEating: Bool = false
    @Published private(set) var faceDetected: Bool = false
    @Published private(set) var handNearFace: Bool = false
    @Published private(set) var lipMovement: Double = 0.0

    // MARK: - Private Properties
    private var isProcessing: Bool = false
    private var frameCount: Int = 0
    private let processingQueue = DispatchQueue(label: "vision.processing", qos: .userInteractive)

    // Vision requests
    private lazy var faceRequest: VNDetectFaceLandmarksRequest = {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleFaceDetection(request: request, error: error)
        }
        request.revision = VNDetectFaceLandmarksRequestRevision3
        return request
    }()

    private lazy var handRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest { [weak self] request, error in
            self?.handleHandDetection(request: request, error: error)
        }
        request.maximumHandCount = 2
        return request
    }()

    // Lip movement tracking
    private var previousLipDistance: Double = 0.0
    private var lipMovementHistory: [Double] = []
    private let historySize = 10

    // Face bounding box for hand proximity
    private var lastFaceBounds: CGRect = .zero

    // MARK: - Protocol Methods
    func startProcessing() {
        isProcessing = true
        frameCount = 0
    }

    func stopProcessing() {
        isProcessing = false
        resetState()
    }

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isProcessing else { return }

        // Frame skipping for 15fps processing
        frameCount += 1
        guard frameCount % Constants.Vision.frameSkipCount == 0 else { return }

        processingQueue.async { [weak self] in
            self?.performVisionRequests(on: pixelBuffer)
        }
    }

    // MARK: - Private Methods
    private func performVisionRequests(on pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([faceRequest, handRequest])
        } catch {
            print("Vision request failed: \(error)")
        }
    }

    private func handleFaceDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNFaceObservation],
              let face = observations.first else {
            DispatchQueue.main.async { [weak self] in
                self?.faceDetected = false
                self?.lipMovement = 0.0
            }
            return
        }

        // Store face bounds for hand proximity check
        lastFaceBounds = face.boundingBox

        // Calculate lip movement
        if let landmarks = face.landmarks,
           let outerLips = landmarks.outerLips,
           let innerLips = landmarks.innerLips {

            let movement = calculateLipMovement(outerLips: outerLips, innerLips: innerLips)

            DispatchQueue.main.async { [weak self] in
                self?.faceDetected = true
                self?.lipMovement = movement
                self?.updateEatingState()
            }
        }
    }

    private func handleHandDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNHumanHandPoseObservation],
              !observations.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.handNearFace = false
                self?.updateEatingState()
            }
            return
        }

        // Check if any hand is near face
        let isNear = observations.contains { observation in
            isHandNearFace(observation)
        }

        DispatchQueue.main.async { [weak self] in
            self?.handNearFace = isNear
            self?.updateEatingState()
        }
    }

    private func calculateLipMovement(outerLips: VNFaceLandmarkRegion2D, innerLips: VNFaceLandmarkRegion2D) -> Double {
        // Calculate vertical distance between upper and lower lip
        let outerPoints = outerLips.normalizedPoints
        let innerPoints = innerLips.normalizedPoints

        guard outerPoints.count >= 6, innerPoints.count >= 5 else { return 0.0 }

        // Top and bottom points of lips
        let topPoint = outerPoints[3]  // Upper lip center
        let bottomPoint = outerPoints[9]  // Lower lip center

        let currentDistance = abs(topPoint.y - bottomPoint.y)

        // Calculate movement as change from previous frame
        let movement = abs(currentDistance - previousLipDistance)
        previousLipDistance = currentDistance

        // Add to history for smoothing
        lipMovementHistory.append(movement)
        if lipMovementHistory.count > historySize {
            lipMovementHistory.removeFirst()
        }

        // Return smoothed average
        let average = lipMovementHistory.reduce(0, +) / Double(lipMovementHistory.count)

        // Normalize to 0-1 range
        return min(1.0, average / Constants.Vision.lipMovementThreshold)
    }

    private func isHandNearFace(_ hand: VNHumanHandPoseObservation) -> Bool {
        guard lastFaceBounds != .zero else { return false }

        do {
            // Get wrist point as hand position reference
            let wristPoint = try hand.recognizedPoint(.wrist)

            guard wristPoint.confidence > 0.3 else { return false }

            let handPosition = wristPoint.location

            // Expand face bounds by ratio
            let expandedBounds = lastFaceBounds.insetBy(
                dx: -lastFaceBounds.width * (Constants.Vision.handFaceDistanceRatio - 1) / 2,
                dy: -lastFaceBounds.height * (Constants.Vision.handFaceDistanceRatio - 1) / 2
            )

            return expandedBounds.contains(handPosition)
        } catch {
            return false
        }
    }

    private func updateEatingState() {
        // Eating = lip movement detected OR hand near face
        let isLipMoving = lipMovement > 0.3  // 30% threshold
        isEating = isLipMoving || handNearFace
    }

    private func resetState() {
        DispatchQueue.main.async { [weak self] in
            self?.isEating = false
            self?.faceDetected = false
            self?.handNearFace = false
            self?.lipMovement = 0.0
        }
        previousLipDistance = 0.0
        lipMovementHistory.removeAll()
        lastFaceBounds = .zero
    }
}
```

---

## Task 3: CameraService 구현

### 3.1 Protocol 정의

```swift
// Services/Protocols/CameraServiceProtocol.swift
import Foundation
import AVFoundation

protocol CameraServiceProtocol: ObservableObject {
    var isRunning: Bool { get }
    var previewLayer: AVCaptureVideoPreviewLayer? { get }

    func startCapture()
    func stopCapture()
    func setFrameDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate)
}
```

### 3.2 CameraService 구현

```swift
// Services/CameraService.swift
import Foundation
import AVFoundation
import Combine

final class CameraService: NSObject, CameraServiceProtocol {
    // MARK: - Published Properties
    @Published private(set) var isRunning: Bool = false

    // MARK: - Properties
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private weak var frameDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?

    // MARK: - Initialization
    override init() {
        super.init()
        setupSession()
    }

    // MARK: - Protocol Methods
    func startCapture() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    func stopCapture() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func setFrameDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        frameDelegate = delegate
        videoOutput.setSampleBufferDelegate(delegate, queue: sessionQueue)
    }

    // MARK: - Private Methods
    private func setupSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = Constants.Camera.sessionPreset

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: Constants.Camera.position
        ) else {
            print("Failed to get front camera")
            captureSession.commitConfiguration()
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)

            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            print("Failed to create video input: \(error)")
            captureSession.commitConfiguration()
            return
        }

        // Add video output
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Set video orientation
        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90  // Portrait orientation
            connection.isVideoMirrored = true   // Mirror for front camera
        }

        captureSession.commitConfiguration()

        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
    }
}
```

---

## Task 4: VideoService 구현

### 4.1 Protocol 정의

```swift
// Services/Protocols/VideoServiceProtocol.swift
import Foundation
import AVFoundation

enum VideoSource {
    case youtube(url: URL)
    case photoLibrary(url: URL)
    case local(url: URL)
}

protocol VideoServiceProtocol: ObservableObject {
    var isPlaying: Bool { get }
    var currentSource: VideoSource? { get }
    var player: AVPlayer? { get }

    func loadVideo(from source: VideoSource)
    func play()
    func pause()
    func fadeOut(duration: TimeInterval, completion: (() -> Void)?)
    func fadeIn(duration: TimeInterval, completion: (() -> Void)?)
}
```

### 4.2 VideoService 구현

```swift
// Services/VideoService.swift
import Foundation
import AVFoundation
import Combine

final class VideoService: NSObject, VideoServiceProtocol {
    // MARK: - Published Properties
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentSource: VideoSource?

    // MARK: - Properties
    private(set) var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var timeObserver: Any?

    // MARK: - Protocol Methods
    func loadVideo(from source: VideoSource) {
        currentSource = source

        switch source {
        case .youtube(let url):
            // YouTube은 WebView로 처리 (Phase 3에서 구현)
            print("YouTube URL: \(url) - WebView implementation pending")

        case .photoLibrary(let url), .local(let url):
            setupPlayer(with: url)
        }
    }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func fadeOut(duration: TimeInterval, completion: (() -> Void)?) {
        guard let player = player else {
            completion?()
            return
        }

        let originalVolume = player.volume
        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = originalVolume / Float(steps)

        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak player] in
                player?.volume = originalVolume - (volumeStep * Float(i + 1))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.pause()
            self?.player?.volume = originalVolume
            completion?()
        }
    }

    func fadeIn(duration: TimeInterval, completion: (() -> Void)?) {
        guard let player = player else {
            completion?()
            return
        }

        let targetVolume: Float = 1.0
        player.volume = 0
        play()

        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = targetVolume / Float(steps)

        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak player] in
                player?.volume = volumeStep * Float(i + 1)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion?()
        }
    }

    // MARK: - Private Methods
    private func setupPlayer(with url: URL) {
        // Clean up previous player
        cleanupPlayer()

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Loop video
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        player?.seek(to: .zero)
        if isPlaying {
            player?.play()
        }
    }

    private func cleanupPlayer() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
        player = nil
    }

    deinit {
        cleanupPlayer()
    }
}
```

---

## Task 5: 기본 MainView 구현

```swift
// Views/MainView.swift
import SwiftUI
import AVFoundation

struct MainView: View {
    @StateObject private var visionService = VisionService()
    @StateObject private var cameraService = CameraService()
    @StateObject private var videoService = VideoService()

    @State private var showDebugInfo = true  // Debug mode for Phase 1

    var body: some View {
        ZStack {
            // Video Player
            VideoPlayerView(player: videoService.player)
                .ignoresSafeArea()

            // Debug Overlay (Phase 1 only)
            if showDebugInfo {
                VStack {
                    debugPanel
                    Spacer()
                    controlPanel
                }
                .padding()
            }
        }
        .onAppear {
            setupServices()
        }
        .onDisappear {
            cleanupServices()
        }
    }

    // MARK: - Debug Panel
    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Info")
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                Circle()
                    .fill(visionService.faceDetected ? .green : .red)
                    .frame(width: 12, height: 12)
                Text("Face: \(visionService.faceDetected ? "Detected" : "Not found")")
            }

            HStack {
                Circle()
                    .fill(visionService.handNearFace ? .green : .gray)
                    .frame(width: 12, height: 12)
                Text("Hand near face: \(visionService.handNearFace ? "Yes" : "No")")
            }

            Text("Lip movement: \(String(format: "%.2f", visionService.lipMovement))")

            HStack {
                Circle()
                    .fill(visionService.isEating ? .green : .orange)
                    .frame(width: 12, height: 12)
                Text("Eating: \(visionService.isEating ? "Yes" : "No")")
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
        .foregroundColor(.white)
        .font(.system(.body, design: .monospaced))
    }

    // MARK: - Control Panel
    private var controlPanel: some View {
        HStack(spacing: 20) {
            Button(action: {
                if videoService.isPlaying {
                    videoService.pause()
                } else {
                    videoService.play()
                }
            }) {
                Image(systemName: videoService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(Circle().fill(Color.blue))
            }

            Button(action: loadSampleVideo) {
                Image(systemName: "film")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(Circle().fill(Color.green))
            }
        }
    }

    // MARK: - Setup
    private func setupServices() {
        // Setup camera delegate
        cameraService.setFrameDelegate(FrameProcessor(visionService: visionService))

        // Start services
        cameraService.startCapture()
        visionService.startProcessing()
    }

    private func cleanupServices() {
        visionService.stopProcessing()
        cameraService.stopCapture()
    }

    private func loadSampleVideo() {
        // For testing, use a sample video from bundle or documents
        if let url = Bundle.main.url(forResource: "sample", withExtension: "mp4") {
            videoService.loadVideo(from: .local(url: url))
            videoService.play()
        }
    }
}

// MARK: - Frame Processor
final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private weak var visionService: VisionService?

    init(visionService: VisionService) {
        self.visionService = visionService
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        visionService?.processFrame(pixelBuffer)
    }
}

// MARK: - Video Player View
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerView = uiView as? PlayerUIView {
            playerView.player = player
        }
    }
}

final class PlayerUIView: UIView {
    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
```

---

## Task 6: 통합 테스트

### 6.1 빌드 및 실행 테스트

```bash
# Xcode에서 빌드
xcodebuild -workspace BobCamAgent.xcworkspace \
  -scheme BobCamAgent \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build
```

### 6.2 테스트 체크리스트

- [ ] 앱 실행 시 카메라 권한 요청
- [ ] 카메라 프리뷰 없이 백그라운드 처리
- [ ] Debug Panel에 얼굴 감지 상태 표시
- [ ] 입술 움직임 값 실시간 업데이트
- [ ] 손이 얼굴 근처에 오면 handNearFace = true
- [ ] 영상 재생/정지 버튼 동작
- [ ] 콘솔에 에러 없음

### 6.3 성능 확인

- [ ] 프레임 드롭 없이 15fps 처리
- [ ] 메모리 사용량 안정적 (< 150MB)
- [ ] CPU 사용량 적정 (< 30%)

---

## 완료 기준

- [ ] VisionService: 입술 움직임 감지 동작
- [ ] VisionService: 손/얼굴 근접 감지 동작
- [ ] CameraService: 프레임 캡처 및 전달
- [ ] VideoService: 로컬 영상 재생/정지
- [ ] MainView: Debug 정보 표시
- [ ] 빌드 성공 및 시뮬레이터 실행

---

**다음 단계**: `02_PHASE2_FEEDBACK.md` - 피드백 시스템 구현
