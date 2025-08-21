import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Video Selection Integration Test View
struct VideoSelectionIntegrationTest: View {
    @StateObject private var videoService = VideoService()
    @StateObject private var videoSelectionService: VideoSelectionService
    
    init() {
        let videoService = VideoService()
        _videoService = StateObject(wrappedValue: videoService)
        _videoSelectionService = StateObject(wrappedValue: VideoSelectionService(videoService: videoService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Video Selection Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                // Video Preview Card
                VideoPreviewCard(
                    selectionService: videoSelectionService,
                    videoService: videoService
                )
                .padding()
                
                // Selection Button
                VideoSelectionButton(selectionService: videoSelectionService)
                
                // Video Player Preview
                if let player = videoService.avPlayer {
                    VideoPlayer(player: player)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            Text("No Video Loaded")
                                .foregroundColor(.gray)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
                
                // Control Buttons
                HStack(spacing: 20) {
                    Button("Play") {
                        videoService.playVideo()
                    }
                    .disabled(videoService.playbackState != .ready && videoService.playbackState != .paused)
                    
                    Button("Pause") {
                        videoService.pauseVideo()
                    }
                    .disabled(videoService.playbackState != .playing)
                    
                    Button("Reset to Default") {
                        videoSelectionService.resetToDefaultVideo()
                    }
                }
                .padding()
                
                Spacer()
            }
        }
    }
}

// MARK: - Test Helper Extensions
extension VideoSelectionIntegrationTest {
    
    /// Test default video loading
    private func testDefaultVideoLoading() {
        videoSelectionService.resetToDefaultVideo()
    }
    
    /// Test video selection flow
    private func testVideoSelection() {
        videoSelectionService.selectVideo()
    }
    
    /// Test video persistence
    private func testVideoPersistence() {
        // This would be tested by restarting the app
        print("Selected video URL: \(videoSelectionService.selectedVideoURL?.absoluteString ?? "None")")
        print("Has selected video: \(videoSelectionService.hasSelectedVideo)")
    }
}

// MARK: - Preview
#Preview {
    VideoSelectionIntegrationTest()
}