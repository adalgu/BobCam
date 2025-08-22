import SwiftUI
import AVFoundation

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

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // 백그라운드
                Color.black

                // 비디오 플레이어
                if let player = videoService.avPlayer {
                    VideoPlayer(player: player)
                        .opacity(videoService.playerOpacity)
                        .animation(.easeInOut(duration: 0.5), value: videoService.playerOpacity)
                } else {
                    // 플레이스홀더
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

                // 로딩 인디케이터
                if videoService.playbackState == .loading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)

                        Text("비디오 로딩 중...")
                            .foregroundColor(.white)
                            .font(.caption)
                            .padding(.top, 8)
                    }
                }

                // 에러 표시
                if case .failed(let error) = videoService.playbackState {
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

                // 상단 좌측 비디오 선택 버튼 (비디오가 재생 중일 때)
                if videoService.avPlayer != nil {
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
