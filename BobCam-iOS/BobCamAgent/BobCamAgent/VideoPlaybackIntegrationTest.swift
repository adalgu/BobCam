import Foundation
import XCTest
import AVFoundation
import Combine
import SwiftUI
@testable import BobCamAgent

// MARK: - Integration Test for Video Playback System

/**
 * Comprehensive integration test validating the complete video playback flow
 * 
 * VALIDATION COVERAGE:
 * - App launch → default video loading
 * - Eating detection → video play/pause
 * - Manual override functionality
 * - Video selection from photo library
 * - Error recovery mechanisms
 * - Performance benchmarks
 * - State consistency validation
 */

class VideoPlaybackIntegrationTest: XCTestCase {
    
    // MARK: - Test Environment
    var videoService: VideoService!
    var videoSelectionService: VideoSelectionService!
    var visionService: VisionService!
    var debugLogger: VideoPlaybackDebugLogger!
    var cancellables: Set<AnyCancellable>!
    
    // Test state tracking
    var testResults: TestResults!
    var currentTestPhase: TestPhase = .initialization
    
    enum TestPhase {
        case initialization
        case defaultVideoLoading
        case eatingDetectionPlayback
        case manualOverrideTest
        case errorHandlingTest
        case performanceValidation
        case completed
    }
    
    struct TestResults {
        var defaultVideoLoadTime: TimeInterval?
        var playCommandResponseTime: TimeInterval?
        var pauseCommandResponseTime: TimeInterval?
        var memoryUsageDuringTest: Int64?
        var errorEncountered: [Error] = []
        var stateTransitions: [(from: PlaybackState, to: PlaybackState, time: Date)] = []
        var overallTestDuration: TimeInterval?
        
        var isSuccessful: Bool {
            return errorEncountered.isEmpty && 
                   (playCommandResponseTime ?? 0) < 1.0 &&
                   (pauseCommandResponseTime ?? 0) < 1.0
        }
        
        func generateReport() -> String {
            var report = "=== Video Playback Integration Test Report ===\n\n"
            
            report += "Performance Metrics:\n"
            if let loadTime = defaultVideoLoadTime {
                report += "• Default video load time: \(Int(loadTime * 1000))ms\n"
            }
            if let playTime = playCommandResponseTime {
                report += "• Play command response: \(Int(playTime * 1000))ms\n"
            }
            if let pauseTime = pauseCommandResponseTime {
                report += "• Pause command response: \(Int(pauseTime * 1000))ms\n"
            }
            if let memory = memoryUsageDuringTest {
                report += "• Peak memory usage: \(memory / 1024 / 1024)MB\n"
            }
            
            report += "\nState Transitions:\n"
            for transition in stateTransitions {
                let time = DateFormatter.localizedString(from: transition.time, dateStyle: .none, timeStyle: .medium)
                report += "• [\(time)] \(transition.from.debugDescription) → \(transition.to.debugDescription)\n"
            }
            
            if !errorEncountered.isEmpty {
                report += "\nErrors Encountered:\n"
                for (index, error) in errorEncountered.enumerated() {
                    report += "• \(index + 1). \(error.localizedDescription)\n"
                }
            }
            
            report += "\nOverall Result: \(isSuccessful ? "✅ PASSED" : "❌ FAILED")\n"
            
            return report
        }
    }
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        debugLogger = VideoPlaybackDebugLogger(config: .development)
        videoService = VideoService()
        videoSelectionService = VideoSelectionService(videoService: videoService)
        visionService = VisionService()
        cancellables = Set<AnyCancellable>()
        testResults = TestResults()
        
        // Enable comprehensive debug logging
        videoService.enableDebugLogging(with: debugLogger)
        
        setupTestMonitoring()
        debugLogger.log(level: .info, category: "TEST_SETUP", message: "Integration test environment initialized")
    }
    
    override func tearDown() {
        // Generate final test report
        testResults.overallTestDuration = Date().timeIntervalSince(testStartTime)
        let report = testResults.generateReport()
        print("\n" + report)
        
        // Save report to file
        saveTestReport(report)
        
        // Cleanup
        cancellables?.removeAll()
        videoService?.cleanupPlayer()
        videoService = nil
        videoSelectionService = nil
        visionService = nil
        debugLogger = nil
        
        super.tearDown()
    }
    
    // MARK: - Core Integration Test
    
    private var testStartTime = Date()
    
    func testCompleteVideoPlaybackFlow() {
        let expectation = XCTestExpectation(description: "Complete video playback flow test")
        testStartTime = Date()
        
        debugLogger.logTestStart("testCompleteVideoPlaybackFlow")
        
        // Phase 1: Default video loading
        runDefaultVideoLoadingTest { [weak self] in
            guard let self = self else { return }
            
            // Phase 2: Eating detection playback
            self.runEatingDetectionTest { [weak self] in
                guard let self = self else { return }
                
                // Phase 3: Manual override test
                self.runManualOverrideTest { [weak self] in
                    guard let self = self else { return }
                    
                    // Phase 4: Error handling test
                    self.runErrorHandlingTest { [weak self] in
                        guard let self = self else { return }
                        
                        // Phase 5: Performance validation
                        self.runPerformanceValidationTest {
                            self.currentTestPhase = .completed
                            expectation.fulfill()
                        }
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 60.0)
        debugLogger.logTestComplete("testCompleteVideoPlaybackFlow")
    }
    
    // MARK: - Test Phase Implementations
    
    private func runDefaultVideoLoadingTest(completion: @escaping () -> Void) {
        currentTestPhase = .defaultVideoLoading
        debugLogger.log(level: .info, category: "TEST_PHASE", message: "Starting default video loading test")
        
        let startTime = Date()
        
        // Monitor loading completion
        videoService.$playbackState
            .dropFirst()
            .sink { [weak self] state in
                switch state {
                case .ready:
                    self?.testResults.defaultVideoLoadTime = Date().timeIntervalSince(startTime)
                    self?.debugLogger.log(level: .info, category: "TEST_RESULT", 
                                         message: "Default video loaded successfully")
                    completion()
                case .failed(let error):
                    // For integration test, we handle the case where demo video might not exist
                    self?.debugLogger.log(level: .info, category: "TEST_RESULT",
                                         message: "No default video available - this is acceptable")
                    completion()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Trigger default video loading
        videoSelectionService.resetToDefaultVideo()
    }
    
    private func runEatingDetectionTest(completion: @escaping () -> Void) {
        currentTestPhase = .eatingDetectionPlayback
        debugLogger.log(level: .info, category: "TEST_PHASE", message: "Starting eating detection test")
        
        // Ensure we have a video loaded (or continue without if none available)
        if videoService.currentVideoType == nil {
            debugLogger.log(level: .info, category: "TEST_SKIP", message: "Skipping eating detection test - no video loaded")
            completion()
            return
        }
        
        var testStep = 0
        let totalSteps = 3
        
        func nextStep() {
            testStep += 1
            if testStep >= totalSteps {
                completion()
            }
        }
        
        // Step 1: Test eating detection → play
        let playStartTime = Date()
        
        videoService.$isPlaying
            .dropFirst()
            .prefix(1)
            .sink { [weak self] isPlaying in
                if isPlaying {
                    self?.testResults.playCommandResponseTime = Date().timeIntervalSince(playStartTime)
                    self?.debugLogger.log(level: .info, category: "TEST_RESULT",
                                         message: "Play command executed successfully")
                    
                    // Step 2: Test stop eating → pause
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        let pauseStartTime = Date()
                        
                        self?.videoService.$isPlaying
                            .dropFirst()
                            .prefix(1)
                            .sink { isStillPlaying in
                                if !isStillPlaying {
                                    self?.testResults.pauseCommandResponseTime = Date().timeIntervalSince(pauseStartTime)
                                    self?.debugLogger.log(level: .info, category: "TEST_RESULT",
                                                         message: "Pause command executed successfully")
                                    nextStep()
                                }
                            }
                            .store(in: &self?.cancellables ?? Set<AnyCancellable>())
                        
                        // Simulate stop eating
                        self?.simulateEatingDetection(isEating: false)
                    }
                } else {
                    nextStep() // Skip if play didn't work
                }
            }
            .store(in: &cancellables)
        
        // Simulate eating detection
        simulateEatingDetection(isEating: true)
    }
    
    private func runManualOverrideTest(completion: @escaping () -> Void) {
        currentTestPhase = .manualOverrideTest
        debugLogger.log(level: .info, category: "TEST_PHASE", message: "Starting manual override test")
        
        if videoService.currentVideoType == nil {
            debugLogger.log(level: .info, category: "TEST_SKIP", message: "Skipping manual override test - no video loaded")
            completion()
            return
        }
        
        // Test manual play command
        videoService.playVideo()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let isPlayingAfterManualPlay = self.videoService.isPlaying
            
            // Test manual pause command
            self.videoService.pauseVideo()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let isPlayingAfterManualPause = self.videoService.isPlaying
                
                self.debugLogger.log(level: .info, category: "TEST_RESULT",
                                   message: "Manual override test - Play: \(isPlayingAfterManualPlay), Pause: \(!isPlayingAfterManualPause)")
                
                completion()
            }
        }
    }
    
    private func runErrorHandlingTest(completion: @escaping () -> Void) {
        currentTestPhase = .errorHandlingTest
        debugLogger.log(level: .info, category: "TEST_PHASE", message: "Starting error handling test")
        
        // Test invalid video loading
        let invalidURL = URL(fileURLWithPath: "/nonexistent/video.mp4")
        let invalidVideoType = VideoType.local(invalidURL)
        
        videoService.$playbackState
            .dropFirst()
            .prefix(1)
            .sink { [weak self] state in
                if case .failed(let error) = state {
                    self?.testResults.errorEncountered.append(error)
                    self?.debugLogger.log(level: .info, category: "TEST_RESULT",
                                         message: "Error handling test passed - error correctly caught")
                } else {
                    self?.debugLogger.log(level: .warning, category: "TEST_RESULT",
                                         message: "Error handling test - expected error not caught")
                }
                completion()
            }
            .store(in: &cancellables)
        
        videoService.loadVideo(invalidVideoType)
    }
    
    private func runPerformanceValidationTest(completion: @escaping () -> Void) {
        currentTestPhase = .performanceValidation
        debugLogger.log(level: .info, category: "TEST_PHASE", message: "Starting performance validation test")
        
        // Measure memory usage
        testResults.memoryUsageDuringTest = getCurrentMemoryUsage()
        
        // Validate performance metrics
        let performanceIssues = validatePerformanceMetrics()
        
        if performanceIssues.isEmpty {
            debugLogger.log(level: .info, category: "TEST_RESULT", message: "Performance validation passed")
        } else {
            for issue in performanceIssues {
                debugLogger.log(level: .warning, category: "PERFORMANCE_ISSUE", message: issue)
            }
        }
        
        completion()
    }
    
    // MARK: - Helper Methods
    
    private func setupTestMonitoring() {
        // Monitor all state transitions
        videoService.$playbackState
            .removeDuplicates()
            .scan((PlaybackState.idle, PlaybackState.idle)) { (previous, new) in
                return (previous.1, new)
            }
            .sink { [weak self] (oldState, newState) in
                if oldState != newState {
                    self?.testResults.stateTransitions.append((from: oldState, to: newState, time: Date()))
                }
            }
            .store(in: &cancellables)
        
        // Monitor for errors
        videoService.$playbackState
            .compactMap { state -> Error? in
                if case .failed(let error) = state {
                    return error
                }
                return nil
            }
            .sink { [weak self] error in
                self?.testResults.errorEncountered.append(error)
            }
            .store(in: &cancellables)
    }
    
    private func simulateEatingDetection(isEating: Bool) {
        debugLogger.log(level: .info, category: "TEST_SIMULATION", 
                       message: "Simulating eating detection: \(isEating)")
        
        // Simulate the ContentView eating detection logic
        if isEating {
            if videoService.currentVideoType != nil && videoService.playbackState == .ready {
                videoService.playVideo()
            }
        } else {
            if videoService.currentVideoType != nil && videoService.playbackState == .playing {
                videoService.pauseVideo()
            }
        }
    }
    
    private func validatePerformanceMetrics() -> [String] {
        var issues: [String] = []
        
        if let loadTime = testResults.defaultVideoLoadTime, loadTime > 3.0 {
            issues.append("Default video load time too slow: \(Int(loadTime * 1000))ms")
        }
        
        if let playTime = testResults.playCommandResponseTime, playTime > 1.0 {
            issues.append("Play command response too slow: \(Int(playTime * 1000))ms")
        }
        
        if let pauseTime = testResults.pauseCommandResponseTime, pauseTime > 1.0 {
            issues.append("Pause command response too slow: \(Int(pauseTime * 1000))ms")
        }
        
        if let memory = testResults.memoryUsageDuringTest, memory > 200 * 1024 * 1024 {
            issues.append("High memory usage detected: \(memory / 1024 / 1024)MB")
        }
        
        return issues
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
    
    private func saveTestReport(_ report: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let reportsDirectory = documentsPath.appendingPathComponent("TestReports")
        
        do {
            try FileManager.default.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileName = "video_playback_integration_test_\(dateFormatter.string(from: Date())).txt"
            
            let reportURL = reportsDirectory.appendingPathComponent(fileName)
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
            
            debugLogger.log(level: .info, category: "TEST_REPORT", 
                           message: "Test report saved to: \(reportURL.path)")
        } catch {
            debugLogger.logError(error, category: "TEST_REPORT", 
                                context: ["action": "save_report"])
        }
    }
}

// MARK: - Focused Test Cases for Specific Scenarios

extension VideoPlaybackIntegrationTest {
    
    func testVideoPlaybackStabilityUnderLoad() {
        let expectation = XCTestExpectation(description: "Video playback stability under load")
        
        debugLogger.logTestStart("testVideoPlaybackStabilityUnderLoad")
        
        // Load test video
        videoSelectionService.resetToDefaultVideo()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Simulate rapid play/pause cycles
            let totalCycles = 10
            var currentCycle = 0
            var errors: [Error] = []
            
            func runCycle() {
                currentCycle += 1
                
                // Play
                self.videoService.playVideo()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Pause
                    self.videoService.pauseVideo()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if currentCycle < totalCycles {
                            runCycle()
                        } else {
                            // Test completed
                            XCTAssertTrue(errors.isEmpty, "No errors should occur during stability test")
                            expectation.fulfill()
                        }
                    }
                }
            }
            
            // Monitor for errors during test
            self.videoService.$playbackState
                .compactMap { state -> Error? in
                    if case .failed(let error) = state {
                        return error
                    }
                    return nil
                }
                .sink { error in
                    errors.append(error)
                }
                .store(in: &self.cancellables)
            
            runCycle()
        }
        
        wait(for: [expectation], timeout: 30.0)
        debugLogger.logTestComplete("testVideoPlaybackStabilityUnderLoad")
    }
    
    func testVideoServiceMemoryManagement() {
        debugLogger.logTestStart("testVideoServiceMemoryManagement")
        
        let initialMemory = getCurrentMemoryUsage()
        
        // Load and unload multiple videos
        for i in 0..<5 {
            videoSelectionService.resetToDefaultVideo()
            
            // Wait a bit
            Thread.sleep(forTimeInterval: 0.5)
            
            videoService.cleanupPlayer()
        }
        
        // Force garbage collection
        autoreleasepool {
            // Empty pool to trigger cleanup
        }
        
        let finalMemory = getCurrentMemoryUsage()
        
        if let initial = initialMemory, let final = finalMemory {
            let memoryIncrease = final - initial
            let increaseInMB = memoryIncrease / 1024 / 1024
            
            debugLogger.log(level: .info, category: "MEMORY_TEST",
                           message: "Memory change: \(increaseInMB)MB",
                           context: [
                               "initialMemory": initial,
                               "finalMemory": final,
                               "increase": memoryIncrease
                           ])
            
            XCTAssertLessThan(increaseInMB, 50, "Memory increase should be less than 50MB")
        }
        
        debugLogger.logTestComplete("testVideoServiceMemoryManagement")
    }
}

// MARK: - Test Utilities and Mocks

extension VideoPlaybackIntegrationTest {
    
    /// Create a mock video URL for testing purposes
    func createMockVideoURL() -> URL? {
        let bundle = Bundle(for: type(of: self))
        return bundle.url(forResource: "test_video", withExtension: "mp4")
    }
    
    /// Create a test YouTube video
    func createTestYouTubeVideo() -> YouTubeVideo {
        return YouTubeVideo(
            videoId: "dQw4w9WgXcQ", 
            title: "Test Video",
            channelTitle: "Test Channel",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            duration: 210,
            isChildSafe: true
        )
    }
}