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
        print("[VideoService] 🎬 Initializing VideoService")
        setupAudioSession()
        startNetworkMonitoring()
        setupYouTubePlayerObservation()
        print("[VideoService] ✅ VideoService initialization completed")
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
        print("[VideoService] ▶️ Play video requested - Current state: \(playbackState)")
        print("[VideoService] 📹 Current video type: \(currentVideoType?.debugDescription ?? "none")")
        
        guard playbackState == .ready || playbackState == .paused else {
            print("[VideoService] ⚠️ Cannot play video - invalid state: \(playbackState)")
            return
        }
        
        switch currentVideoType {
        case .local:
            print("[VideoService] 📹 Playing local video...")
            playLocalVideo()
        case .youtube:
            print("[VideoService] 🔴 Playing YouTube video...")
            playYouTubeVideo()
        case .none:
            print("[VideoService] ❌ No video type set")
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
        
        print("[VideoService] 🎬 Starting video load from URL: \(url)")
        print("[VideoService] 🔍 File exists at path: \(FileManager.default.fileExists(atPath: url.path))")
        
        // Verify file accessibility before creating asset
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("[VideoService] ❌ File not found at path: \(url.path)")
            playbackState = .failed(VideoServiceError.videoLoadFailed(url))
            return
        }
        
        // Create asset with explicit loading
        let asset = AVAsset(url: url)
        print("[VideoService] 📦 AVAsset created for URL: \(url.lastPathComponent)")
        
        // Load asset properties asynchronously before creating player item
        Task {
            do {
                // Load essential properties
                let duration = try await asset.load(.duration)
                let isPlayable = try await asset.load(.isPlayable)
                
                await MainActor.run {
                    print("[VideoService] ✅ Asset loaded - Duration: \(duration.seconds)s, Playable: \(isPlayable)")
                    
                    guard isPlayable && duration.seconds > 0 else {
                        print("[VideoService] ❌ Asset not playable or has invalid duration")
                        self.playbackState = .failed(VideoServiceError.videoLoadFailed(url))
                        return
                    }
                    
                    // Create player item and player on main thread
                    self.createPlayerComponents(with: asset, url: url)
                }
            } catch {
                await MainActor.run {
                    print("[VideoService] ❌ Asset loading failed: \(error.localizedDescription)")
                    self.playbackState = .failed(VideoServiceError.playbackFailed(error))
                }
            }
        }
    }
    
    private func createPlayerComponents(with asset: AVAsset, url: URL) {
        // Create player item and player
        playerItem = AVPlayerItem(asset: asset)
        guard let playerItem = playerItem else {
            print("[VideoService] ❌ Failed to create AVPlayerItem")
            playbackState = .failed(VideoServiceError.playerInitializationFailed)
            return
        }
        
        print("[VideoService] 📱 AVPlayerItem created successfully")
        
        // Create player and looper
        player = AVQueuePlayer(playerItem: playerItem)
        guard let player = player else {
            print("[VideoService] ❌ Failed to create AVQueuePlayer")
            playbackState = .failed(VideoServiceError.playerInitializationFailed)
            return
        }
        
        print("[VideoService] 🎵 AVQueuePlayer created successfully")
        
        playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        print("[VideoService] 🔄 AVPlayerLooper created successfully")
        
        // Set up observation after components are ready
        setupPlayerObservation()
        
        print("[VideoService] 🎬 Local video loading completed for: \(url.lastPathComponent)")
        print("[VideoService] 📊 Initial player item status: \(playerItem.status.debugDescription)")
    }

    private func playLocalVideo() {
        guard let player = player else {
            print("[VideoService] ❌ Cannot play - player is nil")
            return
        }
        
        guard let playerItem = playerItem else {
            print("[VideoService] ❌ Cannot play - playerItem is nil")
            return
        }
        
        guard playerItem.status == .readyToPlay else {
            print("[VideoService] ❌ Cannot play - playerItem not ready (status: \(playerItem.status.debugDescription))")
            return
        }
        
        print("[VideoService] ▶️ Starting local video playback")
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
        guard let playerItem = playerItem else {
            print("[VideoService] ❌ Cannot setup observation - playerItem is nil")
            return
        }
        
        print("[VideoService] 👀 Setting up player item observation")
        print("[VideoService] 📊 Current player item status: \(playerItem.status.debugDescription)")

        // Observe player item status
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                print("[VideoService] 🎬 Player item status changed: \(status.debugDescription)")
                switch status {
                case .readyToPlay:
                    print("[VideoService] ✅ Video ready to play!")
                    print("[VideoService] 📏 Video duration: \(playerItem.duration.seconds)s")
                    print("[VideoService] 🎥 Video tracks: \(playerItem.tracks.count)")
                    self?.playbackState = .ready
                case .failed:
                    let errorMsg = playerItem.error?.localizedDescription ?? "Unknown error"
                    print("[VideoService] ❌ Video failed to load: \(errorMsg)")
                    if let nsError = playerItem.error as? NSError {
                        print("[VideoService] 🔍 Error domain: \(nsError.domain), code: \(nsError.code)")
                        print("[VideoService] 📋 Error info: \(nsError.userInfo)")
                    }
                    if let error = playerItem.error {
                        self?.playbackState = .failed(VideoServiceError.playbackFailed(error))
                    } else {
                        self?.playbackState = .failed(VideoServiceError.playerInitializationFailed)
                    }
                case .unknown:
                    print("[VideoService] 🔄 Video loading (status: unknown)...")
                    self?.playbackState = .loading
                @unknown default:
                    print("[VideoService] ⚠️ Unknown player item status: \(status)")
                    break
                }
            }
            .store(in: &cancellables)

        // Observe player status for local videos only
        player?.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard case .local = self?.currentVideoType else { return }
                
                print("[VideoService] 🎵 Player timeControlStatus changed: \(status.debugDescription)")
                
                switch status {
                case .playing:
                    print("[VideoService] ▶️ Player started playing")
                    self?.isPlaying = true
                    if case .failed = self?.playbackState {
                        // Don't override failed state
                        print("[VideoService] ⚠️ Not updating playback state - currently in failed state")
                    } else {
                        self?.playbackState = .playing
                    }
                case .paused:
                    print("[VideoService] ⏸️ Player paused")
                    self?.isPlaying = false
                    if self?.playbackState == .playing {
                        self?.playbackState = .paused
                    }
                case .waitingToPlayAtSpecifiedRate:
                    print("[VideoService] ⏳ Player waiting to play at specified rate")
                    break
                @unknown default:
                    print("[VideoService] ⚠️ Unknown timeControlStatus: \(status)")
                    break
                }
            }
            .store(in: &cancellables)
            
        // Additional observation for player item errors
        playerItem.publisher(for: \.error)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    print("[VideoService] ❌ Player item error detected: \(error.localizedDescription)")
                    let nsError = error as NSError
                    print("[VideoService] 🔍 Error details - Domain: \(nsError.domain), Code: \(nsError.code)")
                    print("[VideoService] 📋 User info: \(nsError.userInfo)")
                    self?.playbackState = .failed(VideoServiceError.playbackFailed(error))
                }
            }
            .store(in: &cancellables)
            
        // Additional logging for current status
        print("[VideoService] 📊 Final setup - Player item status: \(playerItem.status.debugDescription)")
        print("[VideoService] 📊 Final setup - Player time control: \(player?.timeControlStatus.debugDescription ?? "unknown")")
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

extension AVPlayer.TimeControlStatus {
    var debugDescription: String {
        switch self {
        case .paused:
            return "paused"
        case .playing:
            return "playing"
        case .waitingToPlayAtSpecifiedRate:
            return "waitingToPlayAtSpecifiedRate"
        @unknown default:
            return "unknown_timeControlStatus"
        }
    }
}

extension VideoType {
    var debugDescription: String {
        switch self {
        case .local(let url):
            return "local(\(url.lastPathComponent))"
        case .youtube(let video):
            return "youtube(\(video.videoId))"
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

