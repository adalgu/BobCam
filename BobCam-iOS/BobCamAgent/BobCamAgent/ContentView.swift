import SwiftUI
import Vision
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraService = CameraService()
    @StateObject private var visionService = VisionService()
    @StateObject private var videoService = VideoService()
    @StateObject private var videoSelectionService: VideoSelectionService
    @State private var showingSettings = false

    init() {
        let videoService = VideoService()
        _videoService = StateObject(wrappedValue: videoService)
        _videoSelectionService = StateObject(wrappedValue: VideoSelectionService(videoService: videoService))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 카메라 피드 (상단 40%)
                CameraView(cameraService: cameraService)
                    .frame(height: geometry.size.height * 0.4)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .onAppear {
                        cameraService.startSession()
                        cameraService.delegate = visionService
                        visionService.startTracking()
                    }
                    .onDisappear {
                        visionService.stopTracking()
                        cameraService.stopSession()
                    }

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
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                videoSelectionService: videoSelectionService,
                videoService: videoService,
                visionService: visionService,
                isPresented: $showingSettings
            )
        }
    }
}

#Preview {
    ContentView()
}
