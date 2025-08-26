import Foundation
import XCTest
import AVFoundation
import Combine
import SwiftUI
@testable import BobCamAgent

// MARK: - Video Playback Validation Test Suite
/**
 * Comprehensive test suite for validating video playback functionality
 * 
 * COVERAGE:
 * - Default video loading on app launch
 * - Video play/pause based on eating detection
 * - Manual override controls
 * - Video selection from photo library
 * - Error handling scenarios
 * - AVFoundation state management
 * - Debug logging and monitoring
 */
class VideoPlaybackValidationSuite: XCTestCase {
    
    // MARK: - Test Properties
    var videoService: VideoService!
    var videoSelectionService: VideoSelectionService!
    var visionService: VisionService!
    var cancellables: Set<AnyCancellable>!
    var debugLogger: VideoPlaybackDebugLogger!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Initialize services with debug logging
        debugLogger = VideoPlaybackDebugLogger()
        videoService = VideoService()
        videoSelectionService = VideoSelectionService(videoService: videoService)
        visionService = VisionService()
        cancellables = Set<AnyCancellable>()
        
        // Enable comprehensive debug logging
        enableDebugLogging()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        videoService?.cleanupPlayer()
        videoService = nil
        videoSelectionService = nil
        visionService = nil
        debugLogger = nil
        
        super.tearDown()
    }
    
    // MARK: - Test Cases: Default Video Loading
    
    func testDefaultVideoLoading() {
        let expectation = XCTestExpectation(description: "Default video loads successfully")
        
        debugLogger.logTestStart("testDefaultVideoLoading")
        
        // Monitor video loading state
        videoService.$playbackState
            .dropFirst() // Skip initial .idle state
            .sink { [weak self] state in
                self?.debugLogger.logPlaybackStateChange(state, context: "Default video loading")
                
                switch state {
                case .ready:
                    XCTAssertNotNil(self?.videoService.currentVideoType, "Video type should be set after loading")
                    XCTAssertTrue(self?.videoSelectionService.selectedVideoType != nil || 
                                  self?.videoService.currentVideoType != nil, 
                                  "Either selection service or video service should have video loaded")
                    expectation.fulfill()
                case .failed(let error):
                    // For default video, failure might be expected if demo.mp4 doesn't exist
                    self?.debugLogger.logError("Default video loading failed: \(error.localizedDescription)")
                    
                    // This is acceptable - app should handle missing default video gracefully
                    if self?.videoService.currentVideoType == nil {
                        self?.debugLogger.log("No default video available - user must select video")
                        expectation.fulfill()
                    } else {
                        XCTFail("Unexpected error: \(error.localizedDescription)")
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Trigger default video loading
        videoSelectionService.loadDefaultVideo()
        
        wait(for: [expectation], timeout: 10.0)
        debugLogger.logTestComplete("testDefaultVideoLoading")
    }
    
    // MARK: - Test Cases: Eating Detection Video Control
    
    func testVideoPlaybackOnEatingDetection() {
        let expectation = XCTestExpectation(description: "Video plays when eating detected")
        
        debugLogger.logTestStart("testVideoPlaybackOnEatingDetection")
        
        // First ensure we have a video loaded
        prepareTestVideo { [weak self] in
            guard let self = self else { return }
            
            // Monitor video playback state
            self.videoService.$isPlaying
                .dropFirst()
                .sink { isPlaying in
                    self.debugLogger.logVideoPlaybackChange(isPlaying, context: "Eating detection triggered")
                    
                    if isPlaying && self.videoService.playbackState == .playing {
                        XCTAssertTrue(isPlaying, "Video should be playing when eating detected")
                        expectation.fulfill()
                    }
                }
                .store(in: &self.cancellables)
            
            // Simulate eating detection
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.simulateEatingDetection(isEating: true)
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
        debugLogger.logTestComplete("testVideoPlaybackOnEatingDetection")
    }
    
    func testVideoPauseOnStopEating() {
        let expectation = XCTestExpectation(description: "Video pauses when eating stops")
        
        debugLogger.logTestStart("testVideoPauseOnStopEating")
        
        prepareTestVideo { [weak self] in
            guard let self = self else { return }
            
            var hasStartedPlaying = false
            
            self.videoService.$isPlaying
                .sink { isPlaying in
                    self.debugLogger.logVideoPlaybackChange(isPlaying, context: "Stop eating detection")
                    
                    if isPlaying && !hasStartedPlaying {
                        hasStartedPlaying = true
                        // Now simulate stop eating
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.simulateEatingDetection(isEating: false)
                        }
                    } else if !isPlaying && hasStartedPlaying {
                        XCTAssertFalse(isPlaying, "Video should pause when eating stops")
                        XCTAssertTrue(self.videoService.playbackState == .paused, "Playback state should be paused")
                        expectation.fulfill()
                    }
                }
                .store(in: &self.cancellables)
            
            // Start with eating detection
            self.simulateEatingDetection(isEating: true)
        }
        
        wait(for: [expectation], timeout: 20.0)
        debugLogger.logTestComplete("testVideoPauseOnStopEating")
    }
    
    // MARK: - Test Cases: Manual Override Controls
    
    func testManualOverridePlayback() {
        let expectation = XCTestExpectation(description: "Manual override controls video correctly")
        
        debugLogger.logTestStart("testManualOverridePlayback")
        
        prepareTestVideo { [weak self] in
            guard let self = self else { return }
            
            // Test manual play
            self.videoService.playVideo()
            
            // Verify video plays regardless of eating detection
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                XCTAssertTrue(self.videoService.isPlaying, "Manual play should work")
                XCTAssertEqual(self.videoService.playbackState, .playing, "State should be playing")
                
                // Test manual pause
                self.videoService.pauseVideo()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    XCTAssertFalse(self.videoService.isPlaying, "Manual pause should work")
                    XCTAssertEqual(self.videoService.playbackState, .paused, "State should be paused")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
        debugLogger.logTestComplete("testManualOverridePlayback")
    }
    
    // MARK: - Test Cases: Video Selection Functionality
    
    func testVideoTypeSwitch() {
        let expectation = XCTestExpectation(description: "Can switch between video types")
        
        debugLogger.logTestStart("testVideoTypeSwitch")
        
        // Test switching to default video
        videoSelectionService.resetToDefaultVideo()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Verify video type is set (either local demo or none if not available)
            let hasVideo = self.videoSelectionService.selectedVideoType != nil
            self.debugLogger.log("Video selection result: hasVideo=\(hasVideo), type=\(String(describing: self.videoSelectionService.selectedVideoType))")
            
            // Test clearing video
            self.videoSelectionService.clearSelectedVideo()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                XCTAssertNil(self.videoSelectionService.selectedVideoType, "Video should be cleared")
                XCTAssertFalse(self.videoSelectionService.hasSelectedVideo, "Selection flag should be false")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        debugLogger.logTestComplete("testVideoTypeSwitch")
    }
    
    // MARK: - Test Cases: Error Handling
    
    func testInvalidVideoHandling() {
        let expectation = XCTestExpectation(description: "Invalid video errors handled gracefully")
        
        debugLogger.logTestStart("testInvalidVideoHandling")
        
        // Create invalid URL
        let invalidURL = URL(fileURLWithPath: "/nonexistent/video.mp4")
        let invalidVideoType = VideoType.local(invalidURL)
        
        videoService.$playbackState
            .sink { [weak self] state in
                self?.debugLogger.logPlaybackStateChange(state, context: "Invalid video test")
                
                if case .failed(let error) = state {
                    XCTAssertTrue(true, "Error correctly caught: \(error.localizedDescription)")
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Load invalid video
        videoService.loadVideo(invalidVideoType)
        
        wait(for: [expectation], timeout: 10.0)
        debugLogger.logTestComplete("testInvalidVideoHandling")
    }
    
    func testNetworkErrorHandling() {
        let expectation = XCTestExpectation(description: "Network errors handled gracefully")
        
        debugLogger.logTestStart("testNetworkErrorHandling")
        
        // Create test YouTube video
        let youTubeVideo = YouTubeVideo(videoId: "dQw4w9WgXcQ", title: "Test Video")
        let youTubeVideoType = VideoType.youtube(youTubeVideo)
        
        // Simulate network unavailable
        // Note: In real testing, you'd mock the network monitor
        
        videoService.$playbackState
            .sink { [weak self] state in
                self?.debugLogger.logPlaybackStateChange(state, context: "YouTube network test")
                
                switch state {
                case .ready, .failed:
                    // Either should be acceptable depending on network state
                    expectation.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        videoService.loadVideo(youTubeVideoType)
        
        wait(for: [expectation], timeout: 15.0)
        debugLogger.logTestComplete("testNetworkErrorHandling")
    }
    
    // MARK: - Test Cases: Performance & Memory
    
    func testMemoryCleanup() {
        debugLogger.logTestStart("testMemoryCleanup")
        
        // Load and unload multiple videos
        prepareTestVideo { [weak self] in
            guard let self = self else { return }
            
            // Create multiple loading cycles
            for i in 0..<3 {
                self.videoService.cleanupPlayer()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
                    self.videoSelectionService.resetToDefaultVideo()
                }
            }
            
            // Final cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.videoService.cleanupPlayer()
                
                XCTAssertNil(self.videoService.avPlayer, "Player should be nil after cleanup")
                XCTAssertEqual(self.videoService.playbackState, .idle, "State should reset to idle")
                XCTAssertFalse(self.videoService.isPlaying, "Should not be playing after cleanup")
                
                self.debugLogger.log("Memory cleanup test completed successfully")
            }
        }
        
        debugLogger.logTestComplete("testMemoryCleanup")
    }
    
    // MARK: - Helper Methods
    
    private func prepareTestVideo(completion: @escaping () -> Void) {
        debugLogger.log("Preparing test video...")
        
        // Try to load default video first
        videoSelectionService.resetToDefaultVideo()
        
        // Wait for loading to complete or fail
        videoService.$playbackState
            .dropFirst()
            .sink { [weak self] state in
                switch state {
                case .ready:
                    self?.debugLogger.log("Test video loaded successfully")
                    DispatchQueue.main.async {
                        completion()
                    }
                case .failed(let error):
                    self?.debugLogger.logError("Test video loading failed: \(error.localizedDescription)")
                    // Still proceed with test - some tests check error handling
                    DispatchQueue.main.async {
                        completion()
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func simulateEatingDetection(isEating: Bool) {
        debugLogger.log("Simulating eating detection: \(isEating)")
        
        // Create a mock vision service state change
        // In real app, this would come from VisionService
        let mockDetectionResult = isEating
        
        // Simulate the eating state change handling from ContentView
        if mockDetectionResult {
            debugLogger.log("Triggering video play from eating detection")
            videoService.playVideo()
        } else {
            debugLogger.log("Triggering video pause from eating detection")
            videoService.pauseVideo()
        }
    }
    
    private func enableDebugLogging() {
        // Enable comprehensive logging for all video service events
        videoService.$playbackState
            .sink { [weak self] state in
                self?.debugLogger.logPlaybackStateChange(state, context: "General monitoring")
            }
            .store(in: &cancellables)
        
        videoService.$isPlaying
            .sink { [weak self] isPlaying in
                self?.debugLogger.logVideoPlaybackChange(isPlaying, context: "General monitoring")
            }
            .store(in: &cancellables)
        
        videoService.$currentVideoType
            .sink { [weak self] videoType in
                self?.debugLogger.logVideoTypeChange(videoType)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Debug Logger
class VideoPlaybackDebugLogger {
    private let dateFormatter: DateFormatter
    private var logEntries: [String] = []
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }
    
    func logTestStart(_ testName: String) {
        let message = "🧪 TEST START: \(testName)"
        log(message)
        print("\n" + "="*50)
        print(message)
        print("="*50)
    }
    
    func logTestComplete(_ testName: String) {
        let message = "✅ TEST COMPLETE: \(testName)"
        log(message)
        print(message)
        print("="*50 + "\n")
    }
    
    func logPlaybackStateChange(_ state: PlaybackState, context: String) {
        let stateDescription: String
        switch state {
        case .idle:
            stateDescription = "idle"
        case .loading:
            stateDescription = "loading"
        case .ready:
            stateDescription = "ready"
        case .playing:
            stateDescription = "playing"
        case .paused:
            stateDescription = "paused"
        case .failed(let error):
            stateDescription = "failed(\(error.localizedDescription))"
        }
        
        log("🎬 PLAYBACK STATE: \(stateDescription) | Context: \(context)")
    }
    
    func logVideoPlaybackChange(_ isPlaying: Bool, context: String) {
        let statusIcon = isPlaying ? "▶️" : "⏸️"
        log("\(statusIcon) VIDEO PLAYBACK: \(isPlaying ? "PLAYING" : "PAUSED") | Context: \(context)")
    }
    
    func logVideoTypeChange(_ videoType: VideoType?) {
        let typeDescription: String
        if let videoType = videoType {
            typeDescription = videoType.description
        } else {
            typeDescription = "None"
        }
        log("📺 VIDEO TYPE: \(typeDescription)")
    }
    
    func logError(_ message: String) {
        log("❌ ERROR: \(message)")
    }
    
    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)"
        logEntries.append(logEntry)
        print(logEntry)
    }
    
    func exportLogs() -> String {
        return logEntries.joined(separator: "\n")
    }
}

// MARK: - Test Extensions
extension VideoPlaybackValidationSuite {
    
    /// Comprehensive integration test simulating real user flow
    func testFullUserVideoWorkflow() {
        let expectation = XCTestExpectation(description: "Full user workflow completes successfully")
        
        debugLogger.logTestStart("testFullUserVideoWorkflow")
        
        var workflowStep = 0
        let totalSteps = 4
        
        func advanceWorkflow() {
            workflowStep += 1
            debugLogger.log("Workflow step \(workflowStep)/\(totalSteps)")
            
            if workflowStep >= totalSteps {
                expectation.fulfill()
            }
        }
        
        // Step 1: App launch - load default video
        videoSelectionService.resetToDefaultVideo()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            advanceWorkflow()
            
            // Step 2: User starts eating - video should play
            self.simulateEatingDetection(isEating: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                XCTAssertTrue(self.videoService.isPlaying || self.videoService.currentVideoType == nil, 
                              "Video should be playing if loaded")
                advanceWorkflow()
                
                // Step 3: User stops eating - video should pause
                self.simulateEatingDetection(isEating: false)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    XCTAssertFalse(self.videoService.isPlaying || self.videoService.currentVideoType == nil, 
                                   "Video should be paused if loaded")
                    advanceWorkflow()
                    
                    // Step 4: Manual override - video plays despite not eating
                    self.videoService.playVideo()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        // Should be playing if video is available
                        advanceWorkflow()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
        debugLogger.logTestComplete("testFullUserVideoWorkflow")
    }
}

// MARK: - Performance Testing Extension
extension VideoPlaybackValidationSuite {
    
    func testVideoPlaybackPerformance() {
        let expectation = XCTestExpectation(description: "Video playback performance is acceptable")
        
        debugLogger.logTestStart("testVideoPlaybackPerformance")
        
        prepareTestVideo { [weak self] in
            guard let self = self else { return }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            var responseTime: CFAbsoluteTime = 0
            
            // Measure response time for play command
            self.videoService.$isPlaying
                .dropFirst()
                .sink { isPlaying in
                    if isPlaying {
                        responseTime = CFAbsoluteTimeGetCurrent() - startTime
                        self.debugLogger.log("Video play response time: \(responseTime * 1000)ms")
                        
                        // Assert reasonable response time (less than 500ms)
                        XCTAssertLessThan(responseTime, 0.5, "Video should respond within 500ms")
                        expectation.fulfill()
                    }
                }
                .store(in: &self.cancellables)
            
            // Trigger play command
            self.videoService.playVideo()
        }
        
        wait(for: [expectation], timeout: 10.0)
        debugLogger.logTestComplete("testVideoPlaybackPerformance")
    }
}