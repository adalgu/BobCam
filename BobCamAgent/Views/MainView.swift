import SwiftUI
import AVFoundation
import Combine
import Photos

struct MainView: View {
    @StateObject private var visionService = VisionService()
    @StateObject private var cameraService = CameraService()
    @StateObject private var videoService = VideoService()
    @StateObject private var feedbackService = FeedbackService()
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var statsService = StatisticsService.shared

    @State private var showVideoSelection = true
    @State private var showSettings = false
    @State private var controlBarFrame: CGRect = .zero
    @State private var isYouTubeVideo = false
    @State private var youtubeURL: URL?
    @State private var youtubeIsPlaying = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isYouTubeVideo, let url = youtubeURL {
                YouTubePlayerView(url: url, isPlaying: $youtubeIsPlaying)
                    .ignoresSafeArea()
                    .opacity(shouldShowVideo ? 1 : 0)
            } else {
                VideoPlayerView(player: videoService.player)
                    .ignoresSafeArea()
                    .opacity(shouldShowVideo ? 1 : 0)
            }

            if case .nudging = feedbackService.currentState {
                NudgeOverlay(
                    message: feedbackService.nudgeMessage,
                    cameraService: cameraService
                )
                .transition(.opacity)
            }

            if case .praising = feedbackService.currentState {
                PraiseOverlay()
                    .transition(.scale.combined(with: .opacity))
            }

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
        .animation(.easeInOut(duration: 0.3), value: feedbackService.currentState)
        .onAppear {
            applySettings()
        }
        .onDisappear {
            endMealSession()
        }
        .onChange(of: settingsManager.settings) { _ in
            applySettings()
        }
        .onReceive(visionService.$isEating) { isEating in
            feedbackService.updateEatingState(isEating)

            if isEating {
                statsService.recordPlaybackStart()
            } else if case .nudging = feedbackService.currentState {
                statsService.recordPlaybackPause()
            }
        }
        .sheet(isPresented: $showVideoSelection, onDismiss: {
            if videoService.currentSource == nil && !isYouTubeVideo {
                showVideoSelection = true
            }
        }) {
            VideoSelectionView { source in
                loadVideo(source)
                startMealSession()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var shouldShowVideo: Bool {
        feedbackService.currentState.isVideoPlaying
    }

    private func loadVideo(_ source: VideoSource) {
        switch source {
        case .youtube(let url):
            isYouTubeVideo = true
            youtubeURL = url

        case .photoLibrary(let url):
            isYouTubeVideo = false
            videoService.loadVideo(from: .local(url: url))
            videoService.play()

        case .local(let url):
            isYouTubeVideo = false
            videoService.loadVideo(from: .local(url: url))
            videoService.play()
        }
    }

    private func startMealSession() {
        statsService.startSession()
        setupServices()
        feedbackService.startMonitoring()
    }

    private func endMealSession() {
        feedbackService.stopMonitoring()
        cleanupServices()
        statsService.endSession()
    }

    private func setupServices() {
        let frameProcessor = FrameProcessor(visionService: visionService)
        cameraService.setFrameDelegate(frameProcessor)

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

        cameraService.startCapture()
        visionService.startProcessing()
    }

    private func cleanupServices() {
        visionService.stopProcessing()
        cameraService.stopCapture()
    }

    private func applySettings() {
        let settings = settingsManager.settings
        feedbackService.waitTimeSeconds = settings.waitTimeSeconds
    }
}

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
