import Foundation
import AVFoundation
import Combine

// MARK: - VideoService Debug Extensions

/**
 * Debug extensions for VideoService to add comprehensive logging and monitoring
 * 
 * FEATURES:
 * - Asset loading status tracking
 * - AVPlayer state monitoring 
 * - Play/pause command execution logging
 * - Error detection and reporting
 * - Performance metrics collection
 * - State transition validation
 */

extension VideoService {
    
    // MARK: - Debug Integration
    
    /// Enable comprehensive debug logging for this VideoService instance
    func enableDebugLogging(with logger: VideoPlaybackDebugLogger) {
        setupDebugObservers(logger: logger)
        logger.log(level: .info, category: "DEBUG_SETUP", message: "Debug logging enabled for VideoService")
    }
    
    // MARK: - Private Debug Setup
    
    private func setupDebugObservers(logger: VideoPlaybackDebugLogger) {
        // Monitor playback state changes
        self.$playbackState
            .removeDuplicates()
            .sink { [weak self] newState in
                // Log state transition with context
                if let oldState = self?.previousPlaybackState {
                    logger.logPlaybackStateTransition(
                        from: oldState, 
                        to: newState, 
                        triggeredBy: "VideoService"
                    )
                }
                self?.previousPlaybackState = newState
                
                // Log specific state events
                self?.logStateSpecificEvents(state: newState, logger: logger)
            }
            .store(in: &cancellables)
        
        // Monitor playing state
        self.$isPlaying
            .removeDuplicates()
            .sink { isPlaying in
                logger.log(
                    level: .info,
                    category: "PLAYBACK_STATUS",
                    message: "Video playback status changed: \(isPlaying ? "PLAYING" : "PAUSED")",
                    context: ["isPlaying": isPlaying, "timestamp": Date().timeIntervalSince1970]
                )
            }
            .store(in: &cancellables)
        
        // Monitor current video type changes
        self.$currentVideoType
            .sink { videoType in
                let videoDescription = videoType?.displayName ?? "None"
                logger.log(
                    level: .info,
                    category: "VIDEO_TYPE",
                    message: "Current video type changed: \(videoDescription)",
                    context: ["videoType": videoDescription]
                )
            }
            .store(in: &cancellables)
        
        // Monitor network availability for YouTube videos
        self.$isNetworkAvailable
            .removeDuplicates()
            .sink { isAvailable in
                logger.log(
                    level: isAvailable ? .info : .warning,
                    category: "NETWORK_STATUS",
                    message: "Network availability changed: \(isAvailable ? "AVAILABLE" : "UNAVAILABLE")",
                    context: ["networkAvailable": isAvailable]
                )
            }
            .store(in: &cancellables)
    }
    
    private func logStateSpecificEvents(state: PlaybackState, logger: VideoPlaybackDebugLogger) {
        switch state {
        case .loading:
            logger.log(
                level: .info,
                category: "ASSET_LOADING",
                message: "Video asset loading started",
                context: ["videoType": currentVideoType?.displayName ?? "unknown"]
            )
            
        case .ready:
            logger.log(
                level: .info,
                category: "ASSET_READY",
                message: "Video asset ready for playback",
                context: [
                    "videoType": currentVideoType?.displayName ?? "unknown",
                    "playerAvailable": avPlayer != nil
                ]
            )
            
        case .failed(let error):
            logger.logError(
                error,
                category: "PLAYBACK_ERROR",
                context: [
                    "videoType": currentVideoType?.displayName ?? "unknown",
                    "playbackState": "failed"
                ]
            )
            
        default:
            break
        }
    }
    
    // MARK: - Enhanced Public Methods with Debug Logging
    
    /// Enhanced loadVideo with debug logging
    func loadVideoWithDebugLogging(_ videoType: VideoType, logger: VideoPlaybackDebugLogger) {
        logger.logVideoAssetLoading(
            url: videoType.debugURL,
            context: "User initiated loading"
        )
        
        let startTime = Date()
        
        // Call original method
        loadVideo(videoType)
        
        // Monitor loading result
        self.$playbackState
            .dropFirst()
            .prefix(1)
            .sink { state in
                let success = (state == .ready)
                var error: Error? = nil
                
                if case .failed(let loadError) = state {
                    error = loadError
                }
                
                logger.logVideoAssetLoadComplete(
                    url: videoType.debugURL,
                    success: success,
                    error: error
                )
                
                // Log performance metrics
                let responseTime = Date().timeIntervalSince(startTime)
                let metrics = VideoPerformanceMetrics(
                    responseTime: responseTime,
                    memoryUsage: getCurrentMemoryUsage(),
                    cpuUsage: nil,
                    frameDrops: nil
                )
                
                if responseTime > 2.0 {
                    logger.logPerformanceWarning(
                        "Slow video loading detected",
                        metrics: metrics
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    /// Enhanced playVideo with debug logging and validation
    func playVideoWithDebugLogging(logger: VideoPlaybackDebugLogger, context: String = "Manual") {
        logger.logPlaybackCommand("play", expectedState: .playing, context: context)
        
        // Pre-command validation
        let preValidation = validatePlaybackPrerequisites()
        if !preValidation.isValid {
            logger.log(
                level: .warning,
                category: "PLAYBACK_VALIDATION",
                message: "Play command prerequisites not met: \(preValidation.reason)",
                context: [
                    "currentState": playbackState.debugDescription,
                    "hasVideo": currentVideoType != nil,
                    "networkAvailable": isNetworkAvailable
                ]
            )
        }
        
        // Execute command
        let commandTime = Date()
        playVideo()
        
        // Monitor result
        monitorCommandResult(
            command: "play",
            expectedState: .playing,
            startTime: commandTime,
            logger: logger
        )
    }
    
    /// Enhanced pauseVideo with debug logging
    func pauseVideoWithDebugLogging(logger: VideoPlaybackDebugLogger, context: String = "Manual") {
        logger.logPlaybackCommand("pause", expectedState: .paused, context: context)
        
        let commandTime = Date()
        pauseVideo()
        
        monitorCommandResult(
            command: "pause",
            expectedState: .paused,
            startTime: commandTime,
            logger: logger
        )
    }
    
    // MARK: - Debug Helper Methods
    
    private func validatePlaybackPrerequisites() -> (isValid: Bool, reason: String) {
        if currentVideoType == nil {
            return (false, "No video loaded")
        }
        
        if playbackState == .failed {
            return (false, "Video in failed state")
        }
        
        if playbackState == .loading {
            return (false, "Video still loading")
        }
        
        if case .youtube = currentVideoType, !isNetworkAvailable {
            return (false, "Network unavailable for YouTube video")
        }
        
        return (true, "All prerequisites met")
    }
    
    private func monitorCommandResult(command: String, 
                                    expectedState: PlaybackState, 
                                    startTime: Date,
                                    logger: VideoPlaybackDebugLogger) {
        
        // Set up timeout monitoring
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            if self.playbackState != expectedState {
                logger.log(
                    level: .warning,
                    category: "COMMAND_TIMEOUT",
                    message: "Command \(command) did not reach expected state within timeout",
                    context: [
                        "expectedState": expectedState.debugDescription,
                        "actualState": self.playbackState.debugDescription,
                        "timeout": 5.0
                    ]
                )
            }
        }
        
        // Monitor for successful completion
        self.$playbackState
            .dropFirst()
            .prefix(1)
            .sink { state in
                timeoutTimer.invalidate()
                
                let responseTime = Date().timeIntervalSince(startTime)
                let success = (state == expectedState)
                
                let metrics = VideoPerformanceMetrics(
                    responseTime: responseTime,
                    memoryUsage: self.getCurrentMemoryUsage(),
                    cpuUsage: nil,
                    frameDrops: nil
                )
                
                logger.log(
                    level: success ? .info : .warning,
                    category: "COMMAND_RESULT",
                    message: "Command \(command) completed with result: \(success ? "SUCCESS" : "UNEXPECTED")",
                    context: [
                        "expectedState": expectedState.debugDescription,
                        "actualState": state.debugDescription,
                        "success": success
                    ],
                    performanceMetrics: metrics
                )
                
                // Log performance warnings
                if responseTime > 1.0 {
                    logger.logPerformanceWarning(
                        "Slow command response: \(command)",
                        metrics: metrics
                    )
                }
            }
            .store(in: &self.cancellables)
    }
    
    private func getCurrentMemoryUsage() -> Int64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : nil
    }
}

// MARK: - Private Properties for State Tracking

private var previousPlaybackStateKey: UInt8 = 0

extension VideoService {
    private var previousPlaybackState: PlaybackState? {
        get {
            return objc_getAssociatedObject(self, &previousPlaybackStateKey) as? PlaybackState
        }
        set {
            objc_setAssociatedObject(self, &previousPlaybackStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - Debug Extensions for Supporting Types

extension VideoType {
    var debugURL: URL {
        switch self {
        case .local(let url):
            return url
        case .youtube(let video):
            return URL(string: "https://youtube.com/watch?v=\(video.videoId)") ?? URL(fileURLWithPath: "youtube://\(video.videoId)")
        }
    }
}

// MARK: - Enhanced AVPlayer Observation

extension VideoService {
    
    /// Set up enhanced AVPlayer observation with debug logging
    func setupEnhancedPlayerObservation(logger: VideoPlaybackDebugLogger) {
        guard let player = player, let playerItem = playerItem else {
            logger.log(level: .warning, category: "PLAYER_OBSERVATION", message: "Cannot setup observation - player or item is nil")
            return
        }
        
        // Observe player status with detailed logging
        player.publisher(for: \.status)
            .removeDuplicates()
            .sink { status in
                logger.log(
                    level: .verbose,
                    category: "AVPLAYER_STATUS",
                    message: "AVPlayer status changed: \(status.debugDescription)",
                    context: [
                        "status": status.debugDescription,
                        "rate": player.rate,
                        "currentTime": player.currentTime().seconds
                    ]
                )
            }
            .store(in: &cancellables)
        
        // Observe player item status
        playerItem.publisher(for: \.status)
            .removeDuplicates()
            .sink { status in
                logger.log(
                    level: .verbose,
                    category: "PLAYERITEM_STATUS",
                    message: "AVPlayerItem status changed: \(status.debugDescription)",
                    context: [
                        "status": status.debugDescription,
                        "duration": playerItem.duration.seconds,
                        "loadedTimeRanges": playerItem.loadedTimeRanges.count
                    ]
                )
                
                // Log detailed error information
                if status == .failed, let error = playerItem.error {
                    logger.logError(
                        error,
                        category: "PLAYERITEM_ERROR",
                        context: [
                            "asset": playerItem.asset.description,
                            "tracks": playerItem.tracks.count
                        ]
                    )
                }
            }
            .store(in: &cancellables)
        
        // Observe time control status for more granular playback state tracking
        player.publisher(for: \.timeControlStatus)
            .removeDuplicates()
            .sink { timeControlStatus in
                let statusDescription: String
                switch timeControlStatus {
                case .paused:
                    statusDescription = "paused"
                case .playing:
                    statusDescription = "playing"  
                case .waitingToPlayAtSpecifiedRate:
                    statusDescription = "waiting"
                @unknown default:
                    statusDescription = "unknown"
                }
                
                logger.log(
                    level: .verbose,
                    category: "TIME_CONTROL",
                    message: "Time control status changed: \(statusDescription)",
                    context: [
                        "status": statusDescription,
                        "rate": player.rate,
                        "reasonForWaiting": player.reasonForWaitingToPlay?.rawValue ?? "none"
                    ]
                )
            }
            .store(in: &cancellables)
        
        // Monitor stalled playback
        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled, object: playerItem)
            .sink { _ in
                logger.log(
                    level: .warning,
                    category: "PLAYBACK_STALLED",
                    message: "Video playback stalled",
                    context: [
                        "currentTime": player.currentTime().seconds,
                        "loadedTimeRanges": playerItem.loadedTimeRanges.description
                    ]
                )
            }
            .store(in: &cancellables)
        
        // Monitor failed to play to end time
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
            .sink { notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    logger.logError(
                        error,
                        category: "PLAYBACK_FAILED",
                        context: ["event": "failedToPlayToEndTime"]
                    )
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Integration with ContentView

extension ContentView {
    
    /// Enable comprehensive debug logging for video playback
    func enableVideoPlaybackDebugLogging() {
        let debugLogger = VideoPlaybackDebugLogger(config: .development)
        
        // Enable debug logging in video service
        videoService.enableDebugLogging(with: debugLogger)
        
        // Log eating detection events
        onReceive(visionService.$isEating) { isEating in
            debugLogger.logEatingDetectionTrigger(
                isEating: isEating,
                confidence: Double(visionService.detectionConfidence),
                consecutiveFrames: visionService.consecutiveEatingFrames
            )
        }
        
        // Log video selection events
        onReceive(videoSelectionService.$selectedVideoType) { videoType in
            debugLogger.logVideoSelectionResult(
                videoType: videoType,
                success: videoType != nil,
                error: nil
            )
        }
    }
}

// MARK: - Runtime Mach Error Handling

import Darwin.Mach

extension VideoService {
    private func getSystemInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        
        // Memory information
        if let memoryUsage = getCurrentMemoryUsage() {
            info["memoryUsage"] = memoryUsage
        }
        
        // System load
        var loadAvg = [Double](repeating: 0, count: 3)
        if getloadavg(&loadAvg, 3) != -1 {
            info["loadAverage"] = loadAvg
        }
        
        return info
    }
}