import Foundation
import AVFoundation
import Combine
import SwiftUI

// MARK: - Reactive Video Service with Optimized Playback Control
final class ReactiveVideoService: VideoService {
    
    // MARK: - Performance Properties
    private let playbackQueue = DispatchQueue(label: "com.bobcam.video.playback", 
                                             qos: .userInteractive)
    private var isTransitioning = false
    private var lastCommandTimestamp: CFTimeInterval = 0
    
    // Command debouncing
    private let commandDebounceInterval: TimeInterval = 0.05 // 50ms debounce
    
    // Pre-buffering for instant playback
    private var isPreBuffered = false
    private var preBufferObserver: Any?
    
    // Performance metrics
    @Published var playbackLatencyMs: Double = 0
    @Published var commandResponseTimeMs: Double = 0
    
    // MARK: - Optimized Initialization
    override init() {
        super.init()
        setupOptimizedAudioSession()
        setupPreBuffering()
    }
    
    // MARK: - Immediate Playback Methods
    
    /// Play video with minimal latency
    func playVideoImmediate() {
        let commandStart = CACurrentMediaTime()
        
        // Debounce rapid commands
        guard !isTransitioning,
              commandStart - lastCommandTimestamp >= commandDebounceInterval else { return }
        
        lastCommandTimestamp = commandStart
        isTransitioning = true
        
        // Execute on high-priority queue
        playbackQueue.async { [weak self] in
            guard let self = self else { return }
            
            defer { self.isTransitioning = false }
            
            switch self.currentVideoType {
            case .local:
                self.playLocalVideoOptimized()
            case .youtube:
                self.playYouTubeVideoOptimized()
            case .none:
                break
            }
            
            // Measure response time
            let responseTime = (CACurrentMediaTime() - commandStart) * 1000
            DispatchQueue.main.async {
                self.commandResponseTimeMs = responseTime
                print("[⚡️ ReactiveVideo] Play command executed in \(String(format: "%.1f", responseTime))ms")
            }
        }
    }
    
    /// Pause video with minimal latency
    func pauseVideoImmediate() {
        let commandStart = CACurrentMediaTime()
        
        // Debounce rapid commands
        guard !isTransitioning,
              commandStart - lastCommandTimestamp >= commandDebounceInterval else { return }
        
        lastCommandTimestamp = commandStart
        isTransitioning = true
        
        // Execute on high-priority queue
        playbackQueue.async { [weak self] in
            guard let self = self else { return }
            
            defer { self.isTransitioning = false }
            
            switch self.currentVideoType {
            case .local:
                self.pauseLocalVideoOptimized()
            case .youtube:
                self.pauseYouTubeVideoOptimized()
            case .none:
                break
            }
            
            // Measure response time
            let responseTime = (CACurrentMediaTime() - commandStart) * 1000
            DispatchQueue.main.async {
                self.commandResponseTimeMs = responseTime
                print("[⚡️ ReactiveVideo] Pause command executed in \(String(format: "%.1f", responseTime))ms")
            }
        }
    }
    
    // MARK: - Optimized Local Video Playback
    
    private func playLocalVideoOptimized() {
        guard let player = player,
              let playerItem = playerItem else { return }
        
        // Check if ready to play
        guard playerItem.status == .readyToPlay else {
            // Wait for ready state
            playerItem.publisher(for: \.status)
                .first(where: { $0 == .readyToPlay })
                .receive(on: playbackQueue)
                .sink { [weak self] _ in
                    self?.playLocalVideoOptimized()
                }
                .store(in: &cancellables)
            return
        }
        
        // Set rate directly for faster response
        player.rate = 1.0
        
        // Update state immediately
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = true
            self?.playbackState = .playing
        }
    }
    
    private func pauseLocalVideoOptimized() {
        guard let player = player else { return }
        
        // Set rate to 0 immediately
        player.rate = 0.0
        
        // Update state immediately
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.playbackState = .paused
        }
    }
    
    // MARK: - Optimized YouTube Video Playback
    
    private func playYouTubeVideoOptimized() {
        let controller = youTubePlayerControllerReference ?? youTubePlayerController
        
        guard controller.isReady else {
            // Wait for ready state
            controller.$isReady
                .first(where: { $0 })
                .receive(on: playbackQueue)
                .sink { [weak self] _ in
                    self?.playYouTubeVideoOptimized()
                }
                .store(in: &cancellables)
            return
        }
        
        controller.play()
        
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = true
            self?.playbackState = .playing
        }
    }
    
    private func pauseYouTubeVideoOptimized() {
        let controller = youTubePlayerControllerReference ?? youTubePlayerController
        
        guard controller.isReady else { return }
        
        controller.pause()
        
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.playbackState = .paused
        }
    }
    
    // MARK: - Pre-buffering Setup
    
    private func setupPreBuffering() {
        // Observe when video is loaded to start pre-buffering
        $currentVideoType
            .compactMap { $0 }
            .sink { [weak self] videoType in
                self?.startPreBuffering(for: videoType)
            }
            .store(in: &cancellables)
    }
    
    private func startPreBuffering(for videoType: VideoType) {
        guard case .local = videoType,
              let player = player else { return }
        
        // Pre-buffer video content
        player.automaticallyWaitsToMinimizeStalling = false
        player.playImmediatelyAtRate(0) // Pre-buffer without playing
        
        // Monitor buffer status
        if let playerItem = playerItem {
            preBufferObserver = playerItem.observe(\.isPlaybackLikelyToKeepUp) { [weak self] item, _ in
                if item.isPlaybackLikelyToKeepUp {
                    self?.isPreBuffered = true
                    print("[⚡️ ReactiveVideo] Video pre-buffered and ready for instant playback")
                }
            }
        }
    }
    
    // MARK: - Optimized Audio Session
    
    private func setupOptimizedAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configure for low-latency playback
            try audioSession.setCategory(.playback,
                                        mode: .moviePlayback,
                                        options: [.mixWithOthers, .allowAirPlay])
            
            // Set preferred buffer duration for lower latency
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms buffer
            
            // Activate session
            try audioSession.setActive(true)
            
            print("[⚡️ ReactiveVideo] Audio session configured for low-latency playback")
        } catch {
            print("[ReactiveVideo] Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - Load Video Override
    
    override func loadVideo(_ videoType: VideoType) {
        super.loadVideo(videoType)
        
        // Additional optimization for loaded videos
        switch videoType {
        case .local(let url):
            optimizeLocalVideoLoading(from: url)
        case .youtube:
            // YouTube optimization handled separately
            break
        }
    }
    
    private func optimizeLocalVideoLoading(from url: URL) {
        guard let playerItem = playerItem else { return }
        
        // Configure for faster loading
        playerItem.preferredForwardBufferDuration = 2.0 // Buffer 2 seconds ahead
        
        // Set canUseNetworkResourcesForLiveStreamingWhilePaused for network videos
        if url.scheme?.hasPrefix("http") == true {
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        }
        
        // Monitor loading progress
        playerItem.publisher(for: \.loadedTimeRanges)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeRanges in
                guard let firstRange = timeRanges.first?.timeRangeValue else { return }
                let bufferedDuration = CMTimeGetSeconds(firstRange.duration)
                if bufferedDuration > 0.5 {
                    self?.isPreBuffered = true
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Performance Monitoring
    
    func measurePlaybackLatency() -> Double {
        guard let player = player,
              let currentItem = player.currentItem else { return 0 }
        
        // Measure presentation timestamp vs current time
        if let presentationTimestamp = currentItem.presentationSize.width > 0 ? 
            currentItem.currentTime() : nil {
            let systemTime = CACurrentMediaTime()
            // Calculate approximate latency (simplified)
            return abs(CMTimeGetSeconds(presentationTimestamp) - systemTime) * 1000
        }
        
        return 0
    }
    
    // MARK: - Cleanup
    
    override func cleanupPlayer() {
        // Remove pre-buffer observer
        if let observer = preBufferObserver {
            NotificationCenter.default.removeObserver(observer)
            preBufferObserver = nil
        }
        
        isPreBuffered = false
        isTransitioning = false
        
        super.cleanupPlayer()
    }
}

// MARK: - Video Playback Optimization Extensions

extension ReactiveVideoService {
    
    /// Enable hardware acceleration for video decoding
    func enableHardwareAcceleration() {
        guard let playerItem = playerItem else { return }
        
        // Enable hardware decoding hints
        if let asset = playerItem.asset as? AVURLAsset {
            asset.resourceLoader.setDelegate(nil, queue: nil)
        }
        
        // Set video composition for hardware acceleration
        playerItem.videoComposition = AVVideoComposition(propertiesOf: playerItem.asset)
    }
    
    /// Optimize for specific video characteristics
    func optimizeForVideoCharacteristics() {
        guard let playerItem = playerItem,
              let videoTrack = playerItem.asset.tracks(withMediaType: .video).first else { return }
        
        // Adjust buffering based on video properties
        let frameRate = videoTrack.nominalFrameRate
        let dimensions = videoTrack.naturalSize
        
        // Higher resolution or frame rate needs more buffer
        if dimensions.width > 1920 || frameRate > 30 {
            playerItem.preferredForwardBufferDuration = 3.0
        } else {
            playerItem.preferredForwardBufferDuration = 1.5
        }
    }
}