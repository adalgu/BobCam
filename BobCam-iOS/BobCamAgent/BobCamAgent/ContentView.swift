import SwiftUI
import Vision
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject private var cameraService = CameraService()
    @StateObject private var visionService = VisionService()
    @StateObject private var videoService = VideoService()
    @StateObject private var videoSelectionService: VideoSelectionService
    @State private var showingSettings = false
    @AppStorage("showFeedbackBanner") private var showFeedbackBanner: Bool = true
    @State private var feedbackState: FeedbackBannerView.FeedbackState = .neutral
    @State private var currentDetectionStatus: String = "분석 중..."
    @State private var showDebugInfo: Bool = true  // 디버그 정보 표시
    @State private var lipMovementValue: Double = 0.0
    @State private var detectionConfidence: Double = 0.0
    @State private var frameProcessingRate: Int = 0
    @State private var consecutiveEatingFrames: Int = 0
    @State private var manualOverride: Bool = false // 수동 제어 상태 추가

    init() {
        let videoService = VideoService()
        _videoService = StateObject(wrappedValue: videoService)
        _videoSelectionService = StateObject(wrappedValue: VideoSelectionService(videoService: videoService))
    }

    // Debounced publisher to stabilize feedback banner updates
    private var debouncedEatingPublisher: AnyPublisher<Bool, Never> {
        return visionService.$isEating
            .removeDuplicates()
            .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }

    // Localized message derived from current feedback state
    private var localizedMessage: String {
        switch feedbackState {
        case .eating:
            return NSLocalizedString("eating_positive",
                                     tableName: nil,
                                     bundle: .main,
                                     value: "좋아요 잘 먹고 있어요.",
                                     comment: "Positive feedback when eating detected")
        case .notEating:
            return NSLocalizedString("eating_prompt",
                                     tableName: nil,
                                     bundle: .main,
                                     value: "밥 더 먹어요.",
                                     comment: "Prompt when not eating detected")
        case .neutral:
            return NSLocalizedString("analyzing",
                                     tableName: nil,
                                     bundle: .main,
                                     value: "분석 중…",
                                     comment: "Neutral analyzing state")
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 상단 카메라 (40%)
                ZStack {
                    CameraView(cameraService: cameraService)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .frame(width: geometry.size.width, height: geometry.size.height * 0.4)

                // 🌟 중간 상태바 (새로 추가된 부분!)
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    getStatusBackgroundColor().opacity(0.8),
                                    getStatusBackgroundColor()
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(maxWidth: .infinity)
                    
                    HStack(spacing: 12) {
                        // 상태 아이콘
                        Image(systemName: getStatusIcon())
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        // 상태 메시지
                        Text(currentDetectionStatus)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        
                        Spacer(minLength: 8)
                        
                        // 디버그 정보 (오른쪽)
                        if showDebugInfo {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(frameProcessingRate)fps")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                Text("신뢰도: \(Int(detectionConfidence * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
                .frame(width: geometry.size.width, height: 60)

                // 하단 비디오 (나머지 공간)
                ZStack(alignment: .bottom) {
                    VideoPlayerView(
                        videoService: videoService,
                        videoSelectionService: videoSelectionService
                    )
                    .environmentObject(visionService)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 📱 컨트롤 패널 추가 (하단 오버레이)
                    StatusBar(
                        isEating: visionService.isEating,
                        visionService: visionService,
                        videoService: videoService,
                        videoSelectionService: videoSelectionService,
                        sensitivity: $visionService.sensitivity,
                        manualOverride: $manualOverride
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .frame(width: geometry.size.width, height: geometry.size.height - (geometry.size.height * 0.4) - 60)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .onAppear {
            cameraService.startSession()
            setupDetectionService()
        }
        .onDisappear {
            stopAllDetectionServices()
            cameraService.stopSession()
        }
        .onReceive(visionService.$isEating) { isEating in
            // 립 감지 결과에 따른 비디오 제어 (수동 Override가 비활성화일 때만)
            print("[ContentView] 🎬 식사 상태 변화 감지: \(isEating ? "식사 중" : "식사 안함"), 수동제어: \(manualOverride), 현재 비디오 상태: \(videoService.playbackState)")
            if !manualOverride {
                if isEating {
                    print("[ContentView] 🎬 식사 중 → 비디오 재생 요청")
                    if videoService.currentVideoType != nil && videoService.playbackState == .ready {
                        videoService.playVideo()
                        print("[ContentView] 🎬 비디오 재생 요청 후 상태: \(videoService.playbackState)")
                    } else if videoService.currentVideoType == nil {
                        print("[ContentView] ⚠️ 경고: 비디오가 로드되지 않았습니다! 비디오를 먼저 선택해주세요")
                    } else {
                        print("[ContentView] ⚠️ 경고: 비디오가 재생 준비되지 않음. 현재 상태: \(videoService.playbackState)")
                    }
                } else {
                    print("[ContentView] 🎬 식사 안함 → 비디오 일시정지 요청")
                    if videoService.currentVideoType != nil && videoService.playbackState == .playing {
                        videoService.pauseVideo()
                        print("[ContentView] 🎬 비디오 일시정지 요청 후 상태: \(videoService.playbackState)")
                    } else {
                        print("[ContentView] 🎬 비디오가 없거나 재생중이 아니어서 일시정지 요청 생략")
                    }
                }
            } else {
                print("[ContentView] 🎬 수동 제어 모드로 인해 비디오 제어 건너뜀")
            }
        }
        // 수동 Override 상태에 따른 비디오 제어
        .onChange(of: manualOverride) { isManualActive in
            if isManualActive {
                // 수동 제어 활성화 → 비디오 재생
                videoService.playVideo()
            } else {
                // 수동 제어 비활성화 → 자동 감지 모드로 복귀
                if visionService.isEating {
                    videoService.playVideo()
                } else {
                    videoService.pauseVideo()
                }
            }
        }
        .onReceive(debouncedEatingPublisher) { isEating in
            feedbackState = isEating ? .eating : .notEating
        }
        .onReceive(visionService.$isFaceDetected) { isFaceDetected in
            cameraService.updateFaceDetectionStatus(isFaceDetected)
            updateDetectionStatus()
        }
        .onReceive(visionService.$isEating) { _ in
            updateDetectionStatus()
        }
        .onReceive(visionService.$serviceState) { _ in
            updateDetectionStatus()
        }
        // Update debug metrics in real-time
        .onReceive(visionService.$currentLipDistance) { newValue in
            lipMovementValue = Double(newValue)
        }
        .onReceive(visionService.$detectionConfidence) { newValue in
            detectionConfidence = Double(newValue)
        }
        .onReceive(visionService.$consecutiveEatingFrames) { newValue in
            consecutiveEatingFrames = newValue
        }
        .onReceive(visionService.$fps) { newValue in
            frameProcessingRate = Int(newValue)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                videoSelectionService: videoSelectionService,
                videoService: videoService,
                visionService: visionService,
                isPresented: $showingSettings
            )
        }
    }
    
    // MARK: - Helper Methods
    private func setupDetectionService() {
        print("[ContentView] 립 트래킹 모드 시작")
        cameraService.delegate = visionService
        visionService.startTracking()
    }
    
    private func stopAllDetectionServices() {
        print("[ContentView] 감지 서비스 중지")
        visionService.stopTracking()
        cameraService.delegate = nil
    }
    
    private func updateDetectionStatus() {
        let visionServiceState = visionService.serviceState
        let isFaceDetected = visionService.isFaceDetected
        let isEating = visionService.isEating
        
        // 서비스 상태 우선 체크
        switch visionServiceState {
        case .failed, .cameraError:
            currentDetectionStatus = "감지 오류가 발생했습니다"
            return
        case .idle, .paused:
            currentDetectionStatus = "얼굴을 분석하고 있어요..."
            return
        case .running:
            break // 계속 진행
        }
        
        // 얼굴 감지 상태 체크
        if !isFaceDetected {
            currentDetectionStatus = "얼굴을 카메라 앞에 위치해주세요"
            return
        }
        
        // 식사 감지 상태 체크 (수동 Override 고려)
        if manualOverride {
            currentDetectionStatus = "수동 제어 중 🎮"
        } else if isEating {
            // 끈기있는 식사 모드인지 확인해서 표시
            let eatingFrames = visionService.consecutiveEatingFrames
            if eatingFrames > 30 { // 2초 이상 지속된 경우
                currentDetectionStatus = "끈기있게 식사 중! 계속해요 🍽️✨"
            } else {
                currentDetectionStatus = "식사 중! 잘하고 있어요 🍽️"
            }
        } else {
            currentDetectionStatus = "밥을 더 먹어보세요 😊"
        }
    }
    
    private func getStatusIcon() -> String {
        if currentDetectionStatus.contains("수동 제어") {
            return "hand.raised.circle.fill"
        } else if currentDetectionStatus.contains("식사 중") {
            return "checkmark.circle.fill"
        } else if currentDetectionStatus.contains("밥을 더 먹어") {
            return "exclamationmark.circle.fill"
        } else if currentDetectionStatus.contains("분석") {
            return "magnifyingglass.circle.fill"
        } else if currentDetectionStatus.contains("얼굴을") {
            return "person.circle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    private func getStatusBackgroundColor() -> Color {
        if currentDetectionStatus.contains("수동 제어") {
            return .purple
        } else if currentDetectionStatus.contains("식사 중") {
            return .green
        } else if currentDetectionStatus.contains("밥을 더 먹어") {
            return .orange
        } else if currentDetectionStatus.contains("분석") {
            return .blue
        } else if currentDetectionStatus.contains("얼굴을") {
            return .gray
        } else {
            return .red
        }
    }
}

#Preview {
    ContentView()
}