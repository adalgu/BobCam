import SwiftUI
import Vision
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject private var cameraService = CameraService()
    @StateObject private var visionService = VisionService()
    @StateObject private var videoService = VideoService()
    @StateObject private var videoSelectionService: VideoSelectionService
    @StateObject private var debugSettings = DebugSettings()
    @State private var showingSettings = false
    @AppStorage("showFeedbackBanner") private var showFeedbackBanner: Bool = true
    @State private var feedbackState: FeedbackBannerView.FeedbackState = .neutral

    init() {
        let videoService = VideoService()
        _videoService = StateObject(wrappedValue: videoService)
        _videoSelectionService = StateObject(wrappedValue: VideoSelectionService(videoService: videoService))
    }

    // Debounced publisher to stabilize feedback banner updates
    private var debouncedEatingPublisher: AnyPublisher<Bool, Never> {
        visionService.$isEating
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
                // 카메라 피드 (상단 40%) + 피드백 배너를 카메라 영역 하단에 배치
                ZStack(alignment: .bottom) {
                    GeometryReader { cameraGeometry in
                        ZStack {
                            CameraView(
                                cameraService: cameraService,
                                visionService: visionService,
                                debugSettings: debugSettings
                            )
                            .onAppear {
                                cameraService.startSession()
                                cameraService.delegate = visionService
                                visionService.startTracking()
                            }
                            .onDisappear {
                                visionService.stopTracking()
                                cameraService.stopSession()
                            }
                            
                            // Landmarks overlay for lip tracking visualization
                            LandmarksOverlayView(
                                visionService: visionService,
                                debugSettings: debugSettings,
                                cameraFrame: cameraGeometry.frame(in: .local)
                            )
                        }
                    }

                    if showFeedbackBanner {
                        FeedbackBannerView(
                            state: feedbackState,
                            text: localizedMessage
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                        .animation(.easeInOut(duration: 0.25), value: feedbackState)
                    }
                }
                .frame(height: geometry.size.height * 0.4)
                .frame(maxWidth: .infinity)
                .clipped()
                // 비디오 플레이어 (하단 60%)
                VideoPlayerView(
                    videoService: videoService,
                    videoSelectionService: videoSelectionService
                )
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height * 0.6)
            }
            .overlay(alignment: .bottom) {
                StatusBar(
                    isEating: visionService.isEating,
                    visionService: visionService,
                    videoService: videoService,
                    videoSelectionService: videoSelectionService,
                    sensitivity: $visionService.sensitivity
                )
                .padding()
            }
            .overlay(alignment: .topTrailing) {
                // 설정 버튼
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding()
            }
        }
        .ignoresSafeArea()
        .onReceive(visionService.$isEating) { isEating in
            // 립 감지 결과에 따른 비디오 제어
            if isEating {
                videoService.playVideo()
            } else {
                videoService.pauseVideo()
            }
        }
        .onReceive(debouncedEatingPublisher) { isEating in
            feedbackState = isEating ? .eating : .notEating
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                videoSelectionService: videoSelectionService,
                videoService: videoService,
                visionService: visionService,
                debugSettings: debugSettings,
                isPresented: $showingSettings
            )
        }
    }
}

#Preview {
    ContentView()
}
