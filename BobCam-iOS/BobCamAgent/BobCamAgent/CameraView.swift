import SwiftUI
import AVFoundation
import WebKit

// MARK: - Camera View (UIViewRepresentable)
struct CameraView: UIViewRepresentable {
    let cameraService: CameraService

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        // AVCaptureVideoPreviewLayer 설정
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraService.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds

        // 전면 카메라 미러링
        if let connection = previewLayer.connection,
           connection.isVideoMirroringSupported {
            connection.isVideoMirrored = true
        }

        view.layer.addSublayer(previewLayer)
        view.tag = 999 // previewLayer 식별용

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 프레임 업데이트 시 프리뷰 레이어 크기 조정
        if let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: View {
    @ObservedObject var videoService: VideoService
    @ObservedObject var videoSelectionService: VideoSelectionService
    @StateObject private var youTubePlayerController = YouTubePlayerController()

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // 백그라운드
                Color.black

                // 비디오 플레이어 - 로컬 또는 YouTube
                Group {
                    switch videoSelectionService.selectedVideoType {
                    case .local:
                        // AVPlayer for local videos
                        if let player = videoService.avPlayer {
                            VideoPlayer(player: player)
                                .opacity(videoService.playerOpacity)
                                .animation(.easeInOut(duration: 0.5), value: videoService.playerOpacity)
                        } else {
                            videoPlaceholder
                        }
                    case .youtube(let youTubeVideo):
                        // WKWebView for YouTube videos
                        if videoService.isNetworkAvailable {
                            YouTubePlayerView(
                                youTubeVideo: youTubeVideo,
                                playerState: $youTubePlayerController.playerState,
                                isReady: $youTubePlayerController.isReady
                            )
                            .opacity(videoService.playerOpacity)
                            .animation(.easeInOut(duration: 0.5), value: videoService.playerOpacity)
                        } else {
                            networkUnavailableView
                        }
                    case .none:
                        videoPlaceholder
                    }
                }

                // 로딩 인디케이터
                if videoService.playbackState == .loading {
                    loadingView
                }

                // 에러 표시
                if case .failed(let error) = videoService.playbackState {
                    errorView(error)
                }

                // 상단 좌측 비디오 선택 버튼 (비디오가 로드되어 있을 때)
                if hasLoadedVideo {
                    VStack {
                        HStack {
                            VideoSelectionButton(selectionService: videoSelectionService)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            videoService.setYouTubePlayerController(youTubePlayerController)
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasLoadedVideo: Bool {
        switch videoSelectionService.selectedVideoType {
        case .local:
            return videoService.avPlayer != nil
        case .youtube:
            return videoService.isNetworkAvailable
        case .none:
            return false
        }
    }
    
    // MARK: - Subviews
    
    private var videoPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("비디오를 선택해주세요")
                .foregroundColor(.gray)
                .font(.headline)

            VideoSelectionButton(selectionService: videoSelectionService)
        }
    }
    
    private var networkUnavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("네트워크 연결 필요")
                .foregroundColor(.orange)
                .font(.headline)

            Text("YouTube 비디오 재생을 위해 인터넷 연결을 확인해주세요")
                .foregroundColor(.gray)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VideoSelectionButton(selectionService: videoSelectionService)
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)

            Text(loadingText)
                .foregroundColor(.white)
                .font(.caption)
                .padding(.top, 8)
        }
    }
    
    private var loadingText: String {
        switch videoSelectionService.selectedVideoType {
        case .local:
            return "비디오 로딩 중..."
        case .youtube:
            return "YouTube 비디오 로딩 중..."
        case .none:
            return "로딩 중..."
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.red)

            Text("재생 오류")
                .foregroundColor(.red)
                .font(.headline)

            Text(error.localizedDescription)
                .foregroundColor(.gray)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VideoSelectionButton(selectionService: videoSelectionService)
        }
    }
}

// MARK: - Custom Video Player (AVKit 기반)
struct VideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> VideoPlayerUIView {
        let view = VideoPlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: VideoPlayerUIView, context: Context) {
        uiView.player = player
    }
}

class VideoPlayerUIView: UIView {

    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        playerLayer.videoGravity = .resizeAspectFill
    }
}
