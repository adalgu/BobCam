import Foundation
import AVFoundation
import Combine
import SwiftUI
import Network

// MARK: - Video Service Errors
enum VideoServiceError: LocalizedError {
    case videoLoadFailed(URL)
    case playerInitializationFailed
    case playbackFailed(Error)
    case youTubeLoadFailed(String)
    case networkUnavailable
    case unsupportedVideoType

    var errorDescription: String? {
        switch self {
        case .videoLoadFailed(let url):
            return "비디오를 불러올 수 없습니다: \(url.lastPathComponent)"
        case .playerInitializationFailed:
            return "비디오 플레이어를 초기화할 수 없습니다"
        case .playbackFailed(let error):
            return "비디오 재생 오류: \(error.localizedDescription)"
        case .youTubeLoadFailed(let videoId):
            return "YouTube 비디오를 불러올 수 없습니다: \(videoId)"
        case .networkUnavailable:
            return "네트워크 연결을 확인해주세요"
        case .unsupportedVideoType:
            return "지원하지 않는 비디오 형식입니다"
        }
    }
}

// MARK: - Playback State
enum PlaybackState: Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case failed(Error)

    static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.ready, .ready),
             (.playing, .playing), (.paused, .paused):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

// MARK: - Video Service
class VideoService: ObservableObject {

    // MARK: - Published Properties
    @Published var playbackState: PlaybackState = .idle
    @Published var isPlaying: Bool = false
    @Published var currentVideoType: VideoType?
    @Published var playerOpacity: Double = 1.0
    @Published var isNetworkAvailable: Bool = true

    // MARK: - Private Properties
    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var playerItem: AVPlayerItem?
    
    // YouTube player controller
    @Published var youTubePlayerController = YouTubePlayerController()
    private var youTubePlayerControllerReference: YouTubePlayerController?
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")

    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // 페이드 애니메이션 관련
    private var fadeWorkItem: DispatchWorkItem?

    // MARK: - Configuration
    struct Configuration {
        static let fadeAnimationDuration: Double = 0.5
        static let preferredPeakBitRate: Double = 2_000_000 // 2Mbps
        static let preferredForwardBufferDuration: TimeInterval = 1.0
    }

    // MARK: - Initialization
    init() {
        setupAudioSession()
        startNetworkMonitoring()
        setupYouTubePlayerObservation()
    }

    deinit {
        cleanupPlayer()
        networkMonitor.cancel()
    }

    // MARK: - Public Methods

    /// Load video of any supported type
    func loadVideo(_ videoType: VideoType) {
        currentVideoType = videoType
        playbackState = .loading
        
        switch videoType {
        case .local(let url):
            loadLocalVideo(from: url)
        case .youtube(let youTubeVideo):
            loadYouTubeVideo(youTubeVideo)
        }
    }

    /// 비디오 파일 로드 (backward compatibility)
    func loadVideo(from url: URL) {
        loadVideo(.local(url))
    }

    /// 비디오 재생 시작
    func playVideo() {
        guard playbackState == .ready || playbackState == .paused else {
            return
        }
        
        switch currentVideoType {
        case .local:
            playLocalVideo()
        case .youtube:
            playYouTubeVideo()
        case .none:
            break
        }
    }

    /// 비디오 일시정지
    func pauseVideo() {
        guard playbackState == .playing else {
            return
        }
        
        switch currentVideoType {
        case .local:
            pauseLocalVideo()
        case .youtube:
            pauseYouTubeVideo()
        case .none:
            break
        }
    }

    /// 비디오 정지 및 처음으로 되돌리기
    func stopVideo() {
        switch currentVideoType {
        case .local:
            stopLocalVideo()
        case .youtube:
            stopYouTubeVideo()
        case .none:
            break
        }
    }

    /// 리소스 정리
    func cleanupPlayer() {
        fadeWorkItem?.cancel()

        player?.pause()
        playerLooper = nil
        playerItem = nil
        player = nil

        cancellables.removeAll()

        isPlaying = false
        playbackState = .idle
        playerOpacity = 1.0
        currentVideoType = nil
    }
    
    /// Set external YouTube player controller
    func setYouTubePlayerController(_ controller: YouTubePlayerController) {
        youTubePlayerControllerReference = controller
        setupYouTubePlayerObservation()
    }

    // MARK: - Private Methods - Local Video

    private func loadLocalVideo(from url: URL) {
        cleanupPlayer()

        // AVAsset 생성 및 검증
        let asset = AVAsset(url: url)

        // 비동기로 asset 로드 가능성 확인
        Task {
            do {
                let isPlayable = try await asset.load(.isPlayable)
                let duration = try await asset.load(.duration)

                guard isPlayable, duration.seconds > 0 else {
                    await MainActor.run {
                        self.playbackState = .failed(VideoServiceError.videoLoadFailed(url))
                    }
                    return
                }

                await MainActor.run {
                    self.createPlayerWithAsset(asset)
                }

            } catch {
                await MainActor.run {
                    self.playbackState = .failed(VideoServiceError.videoLoadFailed(url))
                }
            }
        }
    }

    private func playLocalVideo() {
        guard let player = player else { return }

        // 부드러운 페이드 인 효과
        fadeIn {
            player.play()
            self.isPlaying = true
            self.playbackState = .playing
        }
    }

    private func pauseLocalVideo() {
        guard let player = player else { return }

        // 부드러운 페이드 아웃 효과
        fadeOut {
            player.pause()
            self.isPlaying = false
            self.playbackState = .paused
        }
    }

    private func stopLocalVideo() {
        guard let player = player else { return }

        player.pause()
        player.seek(to: .zero)

        isPlaying = false
        playbackState = .ready
        playerOpacity = 1.0
    }

    // MARK: - Private Methods - YouTube Video

    private func loadYouTubeVideo(_ youTubeVideo: YouTubeVideo) {
        // Check network availability for YouTube
        guard isNetworkAvailable else {
            playbackState = .failed(VideoServiceError.networkUnavailable)
            return
        }
        
        // Check child safety
        guard ChildSafetyFilter.isChildSafe(youTubeVideo) else {
            playbackState = .failed(VideoServiceError.playbackFailed(YouTubePlayerError.restrictedContent))
            return
        }
        
        // Clean up local player
        cleanupLocalPlayer()
        
        // Set current video in YouTube controller
        let controller = youTubePlayerControllerReference ?? youTubePlayerController
        controller.currentVideo = youTubeVideo
        
        // The actual loading will happen when the YouTubePlayerView is created
        // For now, we set the state to ready to indicate we're prepared to load
        playbackState = .ready
    }

    private func playYouTubeVideo() {
        let controller = youTubePlayerControllerReference ?? youTubePlayerController
        guard controller.isReady else { return }
        
        fadeIn {
            controller.play()
            self.isPlaying = true
            self.playbackState = .playing
        }
    }

    private func pauseYouTubeVideo() {
        let controller = youTubePlayerControllerReference ?? youTubePlayerController
        guard controller.isReady else { return }
        
        fadeOut {
            controller.pause()
            self.isPlaying = false
            self.playbackState = .paused
        }
    }

    private func stopYouTubeVideo() {
        let controller = youTubePlayerControllerReference ?? youTubePlayerController
        guard controller.isReady else { return }
        
        controller.stop()
        controller.seekToStart()
        
        isPlaying = false
        playbackState = .ready
        playerOpacity = 1.0
    }

    // MARK: - Setup Methods

    private func setupAudioSession() {
        do {
            // 비디오 재생을 위한 오디오 세션 설정
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            print("오디오 세션 설정 실패: \(error)")
        }
    }

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
                
                // If network becomes unavailable and we're playing YouTube, pause
                if path.status != .satisfied,
                   case .youtube = self?.currentVideoType,
                   self?.playbackState == .playing {
                    self?.pauseVideo()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    private func setupYouTubePlayerObservation() {
        // Observe YouTube player state changes
        let controllerToObserve = youTubePlayerControllerReference ?? youTubePlayerController
        controllerToObserve.$playerState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleYouTubePlayerStateChange(state)
            }
            .store(in: &cancellables)
    }

    private func handleYouTubePlayerStateChange(_ state: YouTubePlayerState) {
        guard case .youtube = currentVideoType else { return }
        
        switch state {
        case .playing:
            isPlaying = true
            playbackState = .playing
        case .paused:
            isPlaying = false
            playbackState = .paused
        case .buffering:
            playbackState = .loading
        case .ended:
            // For looping, restart the video
            youTubePlayerController.seekToStart()
            youTubePlayerController.play()
        case .cued:
            playbackState = .ready
        case .unstarted:
            playbackState = .idle
        }
    }

    // MARK: - Local Player Setup

    private func createPlayerWithAsset(_ asset: AVAsset) {
        // AVPlayerItem 생성 및 최적화
        playerItem = AVPlayerItem(asset: asset)

        guard let playerItem = playerItem else {
            playbackState = .failed(VideoServiceError.playerInitializationFailed)
            return
        }

        // 성능 최적화 설정
        playerItem.preferredPeakBitRate = Configuration.preferredPeakBitRate
        playerItem.preferredForwardBufferDuration = Configuration.preferredForwardBufferDuration

        // AVPlayer 생성
        player = AVQueuePlayer(playerItem: playerItem)

        guard let player = player else {
            playbackState = .failed(VideoServiceError.playerInitializationFailed)
            return
        }

        // 무한 반복을 위한 AVPlayerLooper 설정
        playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)

        // 플레이어 상태 관찰 설정
        setupPlayerObservation()

        playbackState = .ready
    }

    private func setupPlayerObservation() {
        guard let playerItem = playerItem else { return }

        // 플레이어 아이템 상태 관찰
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.playbackState = .ready
                case .failed:
                    if let error = playerItem.error {
                        self?.playbackState = .failed(VideoServiceError.playbackFailed(error))
                    }
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)

        // 플레이어 재생 상태 관찰
        player?.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard case .local = self?.currentVideoType else { return }
                
                switch status {
                case .playing:
                    self?.isPlaying = true
                    if self?.playbackState != .failed(VideoServiceError.playbackFailed(NSError())) {
                        self?.playbackState = .playing
                    }
                case .paused:
                    self?.isPlaying = false
                    if self?.playbackState == .playing {
                        self?.playbackState = .paused
                    }
                case .waitingToPlayAtSpecifiedRate:
                    break
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)

        // 플레이어 에러 관찰
        player?.publisher(for: \.error)
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.playbackState = .failed(VideoServiceError.playbackFailed(error))
            }
            .store(in: &cancellables)
    }

    private func cleanupLocalPlayer() {
        player?.pause()
        playerLooper = nil
        playerItem = nil
        player = nil
    }

    // MARK: - 애니메이션 메서드

    private func fadeIn(completion: @escaping () -> Void) {
        fadeWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: Configuration.fadeAnimationDuration)) {
                self?.playerOpacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Configuration.fadeAnimationDuration) {
                completion()
            }
        }

        fadeWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func fadeOut(completion: @escaping () -> Void) {
        fadeWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: Configuration.fadeAnimationDuration)) {
                self?.playerOpacity = 0.3
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Configuration.fadeAnimationDuration) {
                completion()
            }
        }

        fadeWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }
}

// MARK: - SwiftUI Integration Helper
extension VideoService {
    var avPlayer: AVQueuePlayer? {
        return player
    }

    func getPlayerForUI() -> AVQueuePlayer? {
        return player
    }
    
    var currentVideoURL: URL? {
        switch currentVideoType {
        case .local(let url):
            return url
        case .youtube:
            return nil
        case .none:
            return nil
        }
    }
}

