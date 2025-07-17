import SwiftUI
import Vision
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraService = CameraService()
    @StateObject private var visionService = VisionService()
    @StateObject private var videoService = VideoService()
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 카메라 피드 (좌측 40%)
                CameraView(cameraService: cameraService)
                    .frame(width: geometry.size.width * 0.4)
                    .onAppear {
                        cameraService.startSession()
                        cameraService.delegate = visionService
                    }
                
                // 비디오 플레이어 (우측 60%)
                VideoPlayerView(videoService: videoService)
                    .frame(width: geometry.size.width * 0.6)
            }
            .overlay(alignment: .bottom) {
                StatusBar(
                    isEating: visionService.isEating,
                    sensitivity: $visionService.sensitivity
                )
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
    }
}

#Preview {
    ContentView()
}
