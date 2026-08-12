# Phase 2: 피드백 시스템 구현

## 목표
"먹는 행동" 감지 결과에 따라 영상을 제어하고, 넛지와 칭찬 UI를 표시하는 피드백 시스템을 구현합니다.

## 사전 조건
- Phase 1 완료 (VisionService, CameraService, VideoService)
- 입술 움직임 및 손/얼굴 근접 감지 동작 확인

## 참고 문서
- SPEC: `/Users/macmini/study/01-active/BobCam/dev/docs/SPEC.md` (섹션 2.2, 2.3, 2.4)

---

## Task 1: FeedbackState 모델 정의

### 1.1 상태 정의

```swift
// Models/FeedbackState.swift
import Foundation

enum FeedbackState: Equatable {
    /// 영상 재생 중 (먹는 중)
    case playing

    /// 먹는 행동 대기 중 (카운트다운)
    case waiting(secondsRemaining: Int)

    /// 넛지 표시 중
    case nudging

    /// 칭찬 표시 중
    case praising

    /// 부모가 일시정지함
    case pausedByParent

    /// 부모가 강제 재생함
    case forcedByParent

    var isVideoPlaying: Bool {
        switch self {
        case .playing, .forcedByParent:
            return true
        default:
            return false
        }
    }
}
```

### 1.2 전환 규칙

```
                    ┌──────────────┐
                    │   playing    │◄─────────────────┐
                    └──────────────┘                  │
                           │                          │
                    먹기 멈춤                      먹기 시작
                           ▼                          │
                    ┌──────────────┐                  │
                    │   waiting    │──────────────────┤
                    │ (countdown)  │   먹기 시작      │
                    └──────────────┘                  │
                           │                          │
                    시간 초과                         │
                           ▼                          │
                    ┌──────────────┐                  │
                    │   nudging    │──────────────────┘
                    └──────────────┘
                           │
                    먹기 시작
                           ▼
                    ┌──────────────┐
                    │   praising   │──── 2초 후 ────► playing
                    └──────────────┘

    부모 제어:
    - 일시정지 버튼 → pausedByParent
    - 강제재생 버튼 → forcedByParent (일정 시간 후 playing으로)
```

---

## Task 2: FeedbackService 구현

### 2.1 Protocol 정의

```swift
// Services/Protocols/FeedbackServiceProtocol.swift
import Foundation
import Combine

protocol FeedbackServiceProtocol: ObservableObject {
    var currentState: FeedbackState { get }
    var nudgeMessage: String { get }
    var waitTimeSeconds: Int { get set }

    func startMonitoring()
    func stopMonitoring()
    func updateEatingState(_ isEating: Bool)
    func pauseByParent()
    func resumeFromParent()
    func forcePlayByParent()
}
```

### 2.2 FeedbackService 구현

```swift
// Services/FeedbackService.swift
import Foundation
import Combine

final class FeedbackService: ObservableObject, FeedbackServiceProtocol {
    // MARK: - Published Properties
    @Published private(set) var currentState: FeedbackState = .playing
    @Published var nudgeMessage: String = "밥 먹자!"

    // MARK: - Settings
    var waitTimeSeconds: Int = 5  // Default: 5 seconds

    // MARK: - Private Properties
    private var isMonitoring = false
    private var waitTimer: Timer?
    private var praiseTimer: Timer?
    private var forcePlayTimer: Timer?
    private var currentWaitSeconds: Int = 0
    private var pauseCount: Int = 0  // For statistics

    private let nudgeMessages = ["밥 먹자!", "냠냠!", "한 입 더!"]

    // MARK: - Callbacks for VideoService
    var onShouldPlay: (() -> Void)?
    var onShouldPause: (() -> Void)?
    var onShouldFadeOut: ((TimeInterval) -> Void)?
    var onShouldFadeIn: ((TimeInterval) -> Void)?

    // MARK: - Protocol Methods
    func startMonitoring() {
        isMonitoring = true
        currentState = .playing
        onShouldPlay?()
    }

    func stopMonitoring() {
        isMonitoring = false
        invalidateAllTimers()
        currentState = .playing
    }

    func updateEatingState(_ isEating: Bool) {
        guard isMonitoring else { return }

        // Ignore during parent-controlled states
        if case .pausedByParent = currentState { return }
        if case .forcedByParent = currentState { return }

        if isEating {
            handleEatingDetected()
        } else {
            handleNotEating()
        }
    }

    func pauseByParent() {
        invalidateAllTimers()
        currentState = .pausedByParent
        onShouldPause?()
    }

    func resumeFromParent() {
        currentState = .playing
        onShouldPlay?()
    }

    func forcePlayByParent() {
        invalidateAllTimers()
        currentState = .forcedByParent
        onShouldPlay?()

        // Auto-resume monitoring after 30 seconds
        forcePlayTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentState = .playing
            }
        }
    }

    // MARK: - Private Methods
    private func handleEatingDetected() {
        switch currentState {
        case .waiting:
            // Cancel waiting, back to playing
            invalidateWaitTimer()
            currentState = .playing

        case .nudging:
            // Show praise then resume
            showPraise()

        case .praising, .playing, .pausedByParent, .forcedByParent:
            // No action needed
            break
        }
    }

    private func handleNotEating() {
        switch currentState {
        case .playing:
            // Start countdown
            startWaitCountdown()

        case .waiting, .nudging, .praising, .pausedByParent, .forcedByParent:
            // Already in appropriate state
            break
        }
    }

    private func startWaitCountdown() {
        currentWaitSeconds = waitTimeSeconds
        currentState = .waiting(secondsRemaining: currentWaitSeconds)

        waitTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickWaitTimer()
        }
    }

    private func tickWaitTimer() {
        currentWaitSeconds -= 1

        if currentWaitSeconds <= 0 {
            // Time's up, show nudge
            invalidateWaitTimer()
            showNudge()
        } else {
            currentState = .waiting(secondsRemaining: currentWaitSeconds)
        }
    }

    private func showNudge() {
        pauseCount += 1
        nudgeMessage = nudgeMessages.randomElement() ?? "밥 먹자!"
        currentState = .nudging

        // Fade out video based on pause count
        if pauseCount <= 2 {
            onShouldFadeOut?(0.5)  // First few times: gentle
        } else {
            onShouldPause?()  // After that: immediate
        }
    }

    private func showPraise() {
        currentState = .praising

        // Show praise for 2 seconds then resume
        praiseTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentState = .playing
                self?.onShouldFadeIn?(0.3)
            }
        }
    }

    private func invalidateAllTimers() {
        invalidateWaitTimer()
        praiseTimer?.invalidate()
        praiseTimer = nil
        forcePlayTimer?.invalidate()
        forcePlayTimer = nil
    }

    private func invalidateWaitTimer() {
        waitTimer?.invalidate()
        waitTimer = nil
    }

    deinit {
        invalidateAllTimers()
    }
}
```

---

## Task 3: 넛지 UI 구현

### 3.1 NudgeOverlay

```swift
// Views/Components/NudgeOverlay.swift
import SwiftUI
import AVFoundation

struct NudgeOverlay: View {
    let message: String
    let cameraService: CameraService

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Camera Preview
                CameraPreviewView(cameraService: cameraService)
                    .frame(width: 280, height: 280)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.yellow, lineWidth: 4)
                    )
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                // Message
                Text(message)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let previewLayer = cameraService.previewLayer {
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = cameraService.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}
```

### 3.2 PraiseOverlay

```swift
// Views/Components/PraiseOverlay.swift
import SwiftUI

struct PraiseOverlay: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    let praiseMessages = ["잘하고 있어!", "최고야!", "멋져!"]

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Praise message
            Text(praiseMessages.randomElement() ?? "잘하고 있어!")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .green.opacity(0.8), radius: 20, x: 0, y: 0)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.2
                opacity = 1
            }

            // Shrink slightly after pop
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.2)) {
                    scale = 1.0
                }
            }
        }
    }
}
```

---

## Task 4: 부모 제어 바 구현

### 4.1 ParentControlBar

```swift
// Views/Components/ParentControlBar.swift
import SwiftUI

struct ParentControlBar: View {
    @ObservedObject var feedbackService: FeedbackService
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Pause/Resume Button
            Button(action: togglePause) {
                HStack {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    Text(isPaused ? "재개" : "일시정지")
                        .font(.subheadline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(20)
            }

            // Force Play Button
            Button(action: forcePlay) {
                HStack {
                    Image(systemName: "forward.fill")
                    Text("강제재생")
                        .font(.subheadline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.8))
                .cornerRadius(20)
            }
            .disabled(feedbackService.currentState == .forcedByParent)
            .opacity(feedbackService.currentState == .forcedByParent ? 0.5 : 1)

            Spacer()

            // Settings Button
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(Color.gray.opacity(0.6)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.black.opacity(0.7), .clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var isPaused: Bool {
        if case .pausedByParent = feedbackService.currentState {
            return true
        }
        return false
    }

    private func togglePause() {
        if isPaused {
            feedbackService.resumeFromParent()
        } else {
            feedbackService.pauseByParent()
        }
    }

    private func forcePlay() {
        feedbackService.forcePlayByParent()
    }
}
```

---

## Task 5: MainView 업데이트

### 5.1 통합된 MainView

```swift
// Views/MainView.swift
import SwiftUI
import AVFoundation
import Combine

struct MainView: View {
    @StateObject private var visionService = VisionService()
    @StateObject private var cameraService = CameraService()
    @StateObject private var videoService = VideoService()
    @StateObject private var feedbackService = FeedbackService()

    @State private var showSettings = false
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        ZStack {
            // Video Player (base layer)
            VideoPlayerView(player: videoService.player)
                .ignoresSafeArea()
                .opacity(shouldShowVideo ? 1 : 0)

            // Nudge Overlay
            if case .nudging = feedbackService.currentState {
                NudgeOverlay(
                    message: feedbackService.nudgeMessage,
                    cameraService: cameraService
                )
                .transition(.opacity)
            }

            // Praise Overlay
            if case .praising = feedbackService.currentState {
                PraiseOverlay()
                    .transition(.scale.combined(with: .opacity))
            }

            // Waiting indicator (optional)
            if case .waiting(let seconds) = feedbackService.currentState {
                VStack {
                    Spacer()
                    Text("\(seconds)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding()
                        .background(Circle().fill(Color.black.opacity(0.5)))
                    Spacer().frame(height: 100)
                }
            }

            // Parent Control Bar
            VStack {
                ParentControlBar(feedbackService: feedbackService) {
                    showSettings = true
                }
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: feedbackService.currentState)
        .onAppear {
            setupServices()
            loadDefaultVideo()
        }
        .onDisappear {
            cleanupServices()
        }
        .sheet(isPresented: $showSettings) {
            SettingsPlaceholderView()  // Phase 3에서 구현
        }
        .onReceive(visionService.$isEating) { isEating in
            feedbackService.updateEatingState(isEating)
        }
    }

    // MARK: - Computed Properties
    private var shouldShowVideo: Bool {
        feedbackService.currentState.isVideoPlaying
    }

    // MARK: - Setup
    private func setupServices() {
        // Setup camera delegate
        let frameProcessor = FrameProcessor(visionService: visionService)
        cameraService.setFrameDelegate(frameProcessor)

        // Setup feedback callbacks
        feedbackService.onShouldPlay = { [weak videoService] in
            videoService?.play()
        }
        feedbackService.onShouldPause = { [weak videoService] in
            videoService?.pause()
        }
        feedbackService.onShouldFadeOut = { [weak videoService] duration in
            videoService?.fadeOut(duration: duration, completion: nil)
        }
        feedbackService.onShouldFadeIn = { [weak videoService] duration in
            videoService?.fadeIn(duration: duration, completion: nil)
        }

        // Start services
        cameraService.startCapture()
        visionService.startProcessing()
        feedbackService.startMonitoring()
    }

    private func cleanupServices() {
        feedbackService.stopMonitoring()
        visionService.stopProcessing()
        cameraService.stopCapture()
    }

    private func loadDefaultVideo() {
        // Load sample video for testing
        if let url = Bundle.main.url(forResource: "sample", withExtension: "mp4") {
            videoService.loadVideo(from: .local(url: url))
            videoService.play()
        }
    }
}

// MARK: - Settings Placeholder
struct SettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Text("설정 화면 (Phase 3에서 구현)")
                .navigationTitle("설정")
                .navigationBarItems(trailing: Button("닫기") {
                    dismiss()
                })
        }
    }
}
```

---

## Task 6: 터치 제한 시스템

### 6.1 TouchBlockingView

```swift
// Views/Components/TouchBlockingView.swift
import SwiftUI

struct TouchBlockingView<Content: View>: View {
    let content: Content
    let allowedZones: [CGRect]  // 터치 허용 영역 (부모 컨트롤 바 등)

    @State private var touchLocation: CGPoint = .zero

    init(allowedZones: [CGRect] = [], @ViewBuilder content: () -> Content) {
        self.allowedZones = allowedZones
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            content
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            touchLocation = value.location
                        }
                        .onEnded { value in
                            // Check if touch is in allowed zone
                            let isAllowed = allowedZones.contains { zone in
                                zone.contains(value.location)
                            }

                            if !isAllowed {
                                // Block the touch - do nothing
                                print("Touch blocked at: \(value.location)")
                            }
                        }
                )
        }
    }
}

// Usage modifier
extension View {
    func blockChildTouches(exceptIn zones: [CGRect] = []) -> some View {
        TouchBlockingView(allowedZones: zones) {
            self
        }
    }
}
```

### 6.2 적용된 MainView

```swift
// 기존 MainView에 터치 제한 적용
// ParentControlBar 영역만 터치 허용

struct MainView: View {
    // ... 기존 코드 ...

    @State private var controlBarFrame: CGRect = .zero

    var body: some View {
        ZStack {
            // ... 기존 내용 ...

            // Parent Control Bar with frame tracking
            VStack {
                ParentControlBar(feedbackService: feedbackService) {
                    showSettings = true
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ControlBarFrameKey.self,
                            value: geo.frame(in: .global)
                        )
                    }
                )
                Spacer()
            }
        }
        .blockChildTouches(exceptIn: [controlBarFrame])
        .onPreferenceChange(ControlBarFrameKey.self) { frame in
            controlBarFrame = frame
        }
        // ... 나머지 코드 ...
    }
}

// Preference Key for frame tracking
struct ControlBarFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
```

---

## Task 7: 통합 테스트

### 7.1 테스트 체크리스트

**상태 전환 테스트**
- [ ] 앱 시작 → playing 상태
- [ ] 먹기 멈춤 → waiting(5) → waiting(4) → ... → nudging
- [ ] nudging 상태에서 먹기 시작 → praising → playing
- [ ] 일시정지 버튼 → pausedByParent
- [ ] 재개 버튼 → playing
- [ ] 강제재생 버튼 → forcedByParent → 30초 후 playing

**UI 테스트**
- [ ] 넛지 화면에 카메라 프리뷰 표시
- [ ] 넛지 메시지 애니메이션 동작
- [ ] 칭찬 메시지 팝업 애니메이션
- [ ] 대기 카운트다운 표시
- [ ] 부모 컨트롤 바 버튼 동작

**터치 제한 테스트**
- [ ] 영상 영역 터치 → 반응 없음
- [ ] 컨트롤 바 터치 → 정상 동작

### 7.2 성능 확인
- [ ] 상태 전환 시 UI 끊김 없음
- [ ] 애니메이션 부드럽게 동작
- [ ] 메모리 사용량 안정적

---

## 완료 기준

- [ ] FeedbackService: 상태 전환 로직 정상 동작
- [ ] NudgeOverlay: 카메라 + 메시지 표시
- [ ] PraiseOverlay: 칭찬 애니메이션 표시
- [ ] ParentControlBar: 일시정지/강제재생 동작
- [ ] 터치 제한: 부모 컨트롤 영역만 터치 가능
- [ ] 상태 전환 시 영상 제어 연동

---

**다음 단계**: `03_PHASE3_SETTINGS.md` - 설정 및 통계 기능 구현
