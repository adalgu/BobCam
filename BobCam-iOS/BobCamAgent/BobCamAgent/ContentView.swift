import SwiftUI
import Vision
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject private var cameraService = CameraService()
    @StateObject private var visionService = VisionService()
    @StateObject private var multiModalService = MultiModalEatingDetectionService()
    @StateObject private var videoService = VideoService()
    @StateObject private var videoSelectionService: VideoSelectionService
    @State private var showingSettings = false
    @AppStorage("showFeedbackBanner") private var showFeedbackBanner: Bool = true
    @AppStorage("useMultiModalDetection") private var useMultiModalDetection: Bool = false
    @State private var feedbackState: FeedbackBannerView.FeedbackState = .neutral

    init() {
        let videoService = VideoService()
        _videoService = StateObject(wrappedValue: videoService)
        _videoSelectionService = StateObject(wrappedValue: VideoSelectionService(videoService: videoService))
    }

    // Current detection service (선택된 감지 서비스)
    private var currentDetectionService: any FaceTrackingServiceProtocol {
          useMultiModalDetection ? multiModalService : visionService
        }
    
    // Debounced publisher to stabilize feedback banner updates
    private var debouncedEatingPublisher: AnyPublisher<Bool, Never> {
          if useMultiModalDetection {
              return multiModalService.$isEating
                  .removeDuplicates()
                  .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
                  .eraseToAnyPublisher()
          } else {
              return visionService.$isEating
                  .removeDuplicates()
                  .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
                  .eraseToAnyPublisher()
          }
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
            ZStack {
                // Full screen video player background
                VideoPlayerView(
                    videoService: videoService,
                    videoSelectionService: videoSelectionService
                )
                .ignoresSafeArea()
                .onAppear {
                    cameraService.startSession()
                    setupDetectionService()
                }
                .onDisappear {
                    stopAllDetectionServices()
                    cameraService.stopSession()
                }
                .onChange(of: useMultiModalDetection) { _ in
                    // A/B 테스트: 감지 모드 변경 시 서비스 전환
                    stopAllDetectionServices()
                    setupDetectionService()
                }
                
                // Character overlay layer
                CharacterOverlayView(
                    isEating: currentDetectionService.isEating,
                    isVideoPlaying: videoService.playbackState == .playing
                )
                
                // Mini camera view (top-right corner)
                MiniCameraView(cameraService: cameraService)
                
                // Game stats view (top center)
                GameStatsView(
                    isEating: currentDetectionService.isEating,
                    isVideoPlaying: videoService.playbackState == .playing
                )
                
                // Parent controls overlay
                ParentControlsView(
                    videoService: videoService,
                    videoSelectionService: videoSelectionService,
                    visionService: visionService
                )
                
                // Legacy feedback banner (if still enabled)
                if showFeedbackBanner {
                    VStack {
                        Spacer()
                        FeedbackBannerView(
                            state: feedbackState,
                            text: localizedMessage
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 80) // Above status bar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.25), value: feedbackState)
                    }
                }
                
                // Status bar (bottom)
                VStack {
                    Spacer()
                    StatusBar(
                        isEating: currentDetectionService.isEating,
                        visionService: visionService,
                        videoService: videoService,
                        videoSelectionService: videoSelectionService,
                        sensitivity: useMultiModalDetection ? $multiModalService.sensitivity : $visionService.sensitivity
                    )
                    .padding()
                }
                
                // Settings button (top-right, below mini camera)
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Spacer()
                                .frame(height: 180) // Space for mini camera
                            
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
                        }
                    }
                    .padding()
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .onReceive(visionService.$isEating) { isEating in
            // 기존 립 감지 결과에 따른 비디오 제어
            if !useMultiModalDetection {
                if isEating {
                    videoService.playVideo()
                } else {
                    videoService.pauseVideo()
                }
            }
        }
        // .onReceive(multiModalService.$isEating) { isEating in
        //     // 멀티모달 감지 결과에 따른 비디오 제어
        //     if useMultiModalDetection {
        //         if isEating {
        //             videoService.playVideo()
        //         } else {
        //             videoService.pauseVideo()
        //         }
        //     }
        // }
        .onReceive(debouncedEatingPublisher) { isEating in
            feedbackState = isEating ? .eating : .notEating
        }
        .onReceive(visionService.$isFaceDetected) { isFaceDetected in
            cameraService.updateFaceDetectionStatus(isFaceDetected)
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
        if useMultiModalDetection {
            print("[ContentView] 멀티모달 감지 모드 시작")
            cameraService.delegate = multiModalService
            multiModalService.startTracking()
        } else {
            print("[ContentView] 기본 립 트래킹 모드 시작")
            cameraService.delegate = visionService
            visionService.startTracking()
        }
    }
    
    private func stopAllDetectionServices() {
        print("[ContentView] 모든 감지 서비스 중지")
        visionService.stopTracking()
        multiModalService.stopTracking()
        cameraService.delegate = nil
    }
}

#Preview {
    ContentView()
}
