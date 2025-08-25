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

    // MARK: - Initialization
    init() {
        setupAudioSession()
        startNetworkMonitoring()
        setupYouTubePlayerObservation()
    }

    deinit {
        cleanupPlayer()
        cancellables.removeAll()
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

    /// Load video file (backward compatibility)
    func loadVideo(from url: URL) {
        loadVideo(.local(url))
    }

    /// Start video playback
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

    /// Pause video playback
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

    /// Stop video and return to start
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

    /// Clean up player resources
    func cleanupPlayer() {
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

        // Simple asset creation without complex security handling
        let asset = AVAsset(url: url)
        
        // Create player item and player
        playerItem = AVPlayerItem(asset: asset)
        guard let playerItem = playerItem else {
            playbackState = .failed(VideoServiceError.playerInitializationFailed)
            return
        }

        // Create player and looper
        player = AVQueuePlayer(playerItem: playerItem)
        guard let player = player else {
            playbackState = .failed(VideoServiceError.playerInitializationFailed)
            return
        }

        playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        
        // Set up basic observation
        setupPlayerObservation()
        
        // Wait for asset to load - status will be updated via observation
        // Don't immediately check status as asset loading is asynchronous
        print("[VideoService] 🎬 Local video loading started for URL: \(url.lastPathComponent)")
    }

    private func playLocalVideo() {
        guard let player = player,
              let playerItem = playerItem,
              playerItem.status == .readyToPlay else {
            return
        }
        
        player.play()
        isPlaying = true
        playbackState = .playing
    }

    private func pauseLocalVideo() {
        guard let player = player else { return }
        
        player.pause()
        isPlaying = false
        playbackState = .paused
    }

    private func stopLocalVideo() {
        guard let player = player else { return }

        player.pause()
        player.seek(to: .zero)
        isPlaying = false
        playbackState = .ready
    }

    // MARK: - Private Methods - YouTube Video

    private func loadYouTubeVideo(_ youTubeVideo: YouTubeVideo) {
        // Check network availability for YouTube
        guard isNetworkAvailable else {
            playbackState = .failed(VideoServiceError.youTubeLoadFailed("Network unavailable"))
            return
        }
        
        // Basic child safety check
        guard ChildSafetyFilter.isChildSafe(youTubeVideo) else {
            playbackState = .failed(VideoServiceError.youTubeLoadFailed(youTubeVideo.videoId))
            return
        }
        
        // Clean up local player
        cleanupLocalPlayer()
        
        // Set current video in YouTube controller
        let controller = youTubePlayerControllerReference ?? youTubePlayerController
        controller.currentVideo = youTubeVideo
        playbackState = .ready
    }

    private func playYouTubeVideo() {
        let controller = youTubePlayerControllerReference ?? youTubePlayerController
        guard controller.isReady else { return }
        
        controller.play()
        isPlaying = true
        playbackState = .playing
    }

    private func pauseYouTubeVideo() {
        let controller = youTubePlayerControllerReference ?? youTubePlayerController
        guard controller.isReady else { return }
        
        controller.pause()
        isPlaying = false
        playbackState = .paused
    }

    private func stopYouTubeVideo() {
        let controller = youTubePlayerControllerReference ?? youTubePlayerController
        guard controller.isReady else { return }
        
        controller.stop()
        controller.seekToStart()
        isPlaying = false
        playbackState = .ready
    }

    // MARK: - Setup Methods

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            // Silently fail, not critical
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
            youTubePlayerController.seekToStart()
            youTubePlayerController.play()
        case .cued:
            playbackState = .ready
        case .unstarted:
            playbackState = .idle
        }
    }

    private func setupPlayerObservation() {
        guard let playerItem = playerItem else { return }

        // Observe player item status
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                print("[VideoService] 🎬 Player item status changed: \(status.debugDescription)")
                switch status {
                case .readyToPlay:
                    print("[VideoService] 🎬 Video ready to play!")
                    self?.playbackState = .ready
                case .failed:
                    print("[VideoService] ⚠️ Video failed to load: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                    if let error = playerItem.error {
                        self?.playbackState = .failed(VideoServiceError.playbackFailed(error))
                    } else {
                        self?.playbackState = .failed(VideoServiceError.playerInitializationFailed)
                    }
                case .unknown:
                    print("[VideoService] 🔄 Video loading...")
                    self?.playbackState = .loading
                @unknown default:
                    print("[VideoService] ⚠️ Unknown player item status")
                    break
                }
            }
            .store(in: &cancellables)

        // Observe player status for local videos only
        player?.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard case .local = self?.currentVideoType else { return }
                
                switch status {
                case .playing:
                    self?.isPlaying = true
                    if case .failed = self?.playbackState {
                        // Don't override failed state
                    } else {
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
    }

    private func cleanupLocalPlayer() {
        player?.pause()
        playerLooper = nil
        playerItem = nil
        player = nil
    }

}

// MARK: - Debug Extensions
extension AVPlayerItem.Status {
    var debugDescription: String {
        switch self {
        case .unknown:
            return "unknown"
        case .readyToPlay:
            return "readyToPlay"
        case .failed:
            return "failed"
        @unknown default:
            return "unknown_case"
        }
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

