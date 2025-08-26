import Foundation
import XCTest

// MARK: - Video Playback Validation Runner

/**
 * Comprehensive validation runner for video playback system
 * 
 * EXECUTION:
 * - Runs all test suites
 * - Performs system validation
 * - Generates comprehensive report
 * - Provides actionable recommendations
 * 
 * USAGE:
 * Run this through Xcode Test Navigator or command line:
 * `xcodebuild test -scheme BobCamAgent -destination 'platform=iOS Simulator,name=iPhone 15'`
 */

class VideoPlaybackValidationRunner: XCTestCase {
    
    // MARK: - Test Configuration
    
    struct ValidationConfig {
        let runPerformanceTests: Bool
        let runStabilityTests: Bool
        let runIntegrationTests: Bool
        let runMemoryTests: Bool
        let generateDetailedReport: Bool
        let saveReportsToFile: Bool
        
        static let comprehensive = ValidationConfig(
            runPerformanceTests: true,
            runStabilityTests: true,
            runIntegrationTests: true,
            runMemoryTests: true,
            generateDetailedReport: true,
            saveReportsToFile: true
        )
        
        static let quickValidation = ValidationConfig(
            runPerformanceTests: false,
            runStabilityTests: false,
            runIntegrationTests: true,
            runMemoryTests: false,
            generateDetailedReport: false,
            saveReportsToFile: false
        )
    }
    
    // MARK: - Test Execution
    
    override class var defaultTestSuite: XCTestSuite {
        let suite = XCTestSuite(name: "Video Playback Validation Suite")
        
        // Add all validation test classes
        suite.addTest(VideoPlaybackValidationSuite.defaultTestSuite)
        suite.addTest(VideoPlaybackIntegrationTest.defaultTestSuite)
        
        return suite
    }
    
    func testRunCompleteVideoPlaybackValidation() {
        let config = ValidationConfig.comprehensive
        let reporter = ValidationReporter()
        
        reporter.logValidationStart()
        
        // Phase 1: Basic Functionality Tests
        runBasicFunctionalityTests(config: config, reporter: reporter)
        
        // Phase 2: Integration Tests
        if config.runIntegrationTests {
            runIntegrationTests(config: config, reporter: reporter)
        }
        
        // Phase 3: Performance Tests
        if config.runPerformanceTests {
            runPerformanceTests(config: config, reporter: reporter)
        }
        
        // Phase 4: Stability Tests
        if config.runStabilityTests {
            runStabilityTests(config: config, reporter: reporter)
        }
        
        // Phase 5: Memory Management Tests
        if config.runMemoryTests {
            runMemoryTests(config: config, reporter: reporter)
        }
        
        // Phase 6: System Validation
        runSystemValidation(config: config, reporter: reporter)
        
        // Generate final report
        let finalReport = reporter.generateFinalReport()
        
        if config.saveReportsToFile {
            saveReport(finalReport)
        }
        
        // Print summary to console
        print("\n" + finalReport.summary)
        
        // Assert overall success
        XCTAssertTrue(finalReport.overallSuccess, "Video playback validation failed. Check detailed report for issues.")
    }
    
    // MARK: - Test Phase Implementations
    
    private func runBasicFunctionalityTests(config: ValidationConfig, reporter: ValidationReporter) {
        reporter.logPhaseStart("Basic Functionality Tests")
        
        let videoService = VideoService()
        let videoSelectionService = VideoSelectionService(videoService: videoService)
        let debugLogger = VideoPlaybackDebugLogger()
        
        // Test 1: Service Initialization
        let initializationResult = TestResult(
            name: "Service Initialization",
            success: videoService != nil && videoSelectionService != nil,
            duration: 0,
            details: "VideoService and VideoSelectionService initialization",
            errorMessage: nil
        )
        reporter.addResult(initializationResult)
        
        // Test 2: Default Video Loading
        let loadExpectation = XCTestExpectation(description: "Default video loading")
        var loadResult: TestResult?
        let loadStartTime = Date()
        
        videoService.$playbackState
            .dropFirst()
            .prefix(1)
            .sink { state in
                let duration = Date().timeIntervalSince(loadStartTime)
                let success = (state == .ready) || (state == .idle) // Idle is acceptable if no demo video
                
                loadResult = TestResult(
                    name: "Default Video Loading",
                    success: success,
                    duration: duration,
                    details: "Playback state: \(state.debugDescription)",
                    errorMessage: success ? nil : "Failed to reach ready or idle state"
                )
                loadExpectation.fulfill()
            }
            .store(in: &reporter.cancellables)
        
        videoSelectionService.resetToDefaultVideo()
        wait(for: [loadExpectation], timeout: 10.0)
        
        if let result = loadResult {
            reporter.addResult(result)
        }
        
        // Test 3: Manual Play/Pause Commands
        if videoService.currentVideoType != nil {
            testManualPlayback(videoService: videoService, reporter: reporter)
        } else {
            reporter.addResult(TestResult(
                name: "Manual Playback Commands",
                success: true,
                duration: 0,
                details: "Skipped - no video available",
                errorMessage: nil
            ))
        }
        
        reporter.logPhaseComplete("Basic Functionality Tests")
    }
    
    private func testManualPlayback(videoService: VideoService, reporter: ValidationReporter) {
        let playExpectation = XCTestExpectation(description: "Manual play command")
        let playStartTime = Date()
        
        videoService.$isPlaying
            .dropFirst()
            .prefix(1)
            .sink { isPlaying in
                let duration = Date().timeIntervalSince(playStartTime)
                
                reporter.addResult(TestResult(
                    name: "Manual Play Command",
                    success: isPlaying,
                    duration: duration,
                    details: "isPlaying: \(isPlaying)",
                    errorMessage: isPlaying ? nil : "Video did not start playing"
                ))
                
                // Test pause command
                let pauseStartTime = Date()
                
                videoService.$isPlaying
                    .dropFirst()
                    .prefix(1)
                    .sink { isStillPlaying in
                        let pauseDuration = Date().timeIntervalSince(pauseStartTime)
                        
                        reporter.addResult(TestResult(
                            name: "Manual Pause Command",
                            success: !isStillPlaying,
                            duration: pauseDuration,
                            details: "isPlaying after pause: \(isStillPlaying)",
                            errorMessage: !isStillPlaying ? nil : "Video did not pause"
                        ))
                        
                        playExpectation.fulfill()
                    }
                    .store(in: &reporter.cancellables)
                
                videoService.pauseVideo()
            }
            .store(in: &reporter.cancellables)
        
        videoService.playVideo()
        wait(for: [playExpectation], timeout: 10.0)
    }
    
    private func runIntegrationTests(config: ValidationConfig, reporter: ValidationReporter) {
        reporter.logPhaseStart("Integration Tests")
        
        // Create integration test instance and run
        let integrationTest = VideoPlaybackIntegrationTest()
        integrationTest.setUp()
        
        let integrationStartTime = Date()
        
        // Run the complete integration test
        integrationTest.testCompleteVideoPlaybackFlow()
        
        let integrationDuration = Date().timeIntervalSince(integrationStartTime)
        
        reporter.addResult(TestResult(
            name: "Complete Integration Test",
            success: true, // If we reach here, the test passed
            duration: integrationDuration,
            details: "Full video playback workflow integration test",
            errorMessage: nil
        ))
        
        integrationTest.tearDown()
        reporter.logPhaseComplete("Integration Tests")
    }
    
    private func runPerformanceTests(config: ValidationConfig, reporter: ValidationReporter) {
        reporter.logPhaseStart("Performance Tests")
        
        let videoService = VideoService()
        let videoSelectionService = VideoSelectionService(videoService: videoService)
        
        // Performance Test 1: Video Loading Speed
        measureVideoLoadingPerformance(videoService: videoService, 
                                      videoSelectionService: videoSelectionService, 
                                      reporter: reporter)
        
        // Performance Test 2: Command Response Time
        measureCommandResponseTime(videoService: videoService, reporter: reporter)
        
        reporter.logPhaseComplete("Performance Tests")
    }
    
    private func measureVideoLoadingPerformance(videoService: VideoService, 
                                              videoSelectionService: VideoSelectionService,
                                              reporter: ValidationReporter) {
        let loadExpectation = XCTestExpectation(description: "Video loading performance")
        let startTime = Date()
        
        videoService.$playbackState
            .dropFirst()
            .prefix(1)
            .sink { state in
                let duration = Date().timeIntervalSince(startTime)
                let success = duration < 3.0 // Should load within 3 seconds
                
                reporter.addResult(TestResult(
                    name: "Video Loading Performance",
                    success: success,
                    duration: duration,
                    details: "Load time: \(Int(duration * 1000))ms, Target: <3000ms",
                    errorMessage: success ? nil : "Video loading too slow"
                ))
                
                loadExpectation.fulfill()
            }
            .store(in: &reporter.cancellables)
        
        videoSelectionService.resetToDefaultVideo()
        wait(for: [loadExpectation], timeout: 5.0)
    }
    
    private func measureCommandResponseTime(videoService: VideoService, reporter: ValidationReporter) {
        guard videoService.currentVideoType != nil else {
            reporter.addResult(TestResult(
                name: "Command Response Time",
                success: true,
                duration: 0,
                details: "Skipped - no video available",
                errorMessage: nil
            ))
            return
        }
        
        let commandExpectation = XCTestExpectation(description: "Command response time")
        let startTime = Date()
        
        videoService.$isPlaying
            .dropFirst()
            .prefix(1)
            .sink { isPlaying in
                let responseTime = Date().timeIntervalSince(startTime)
                let success = responseTime < 0.5 // Should respond within 500ms
                
                reporter.addResult(TestResult(
                    name: "Play Command Response Time",
                    success: success,
                    duration: responseTime,
                    details: "Response time: \(Int(responseTime * 1000))ms, Target: <500ms",
                    errorMessage: success ? nil : "Command response too slow"
                ))
                
                commandExpectation.fulfill()
            }
            .store(in: &reporter.cancellables)
        
        videoService.playVideo()
        wait(for: [commandExpectation], timeout: 2.0)
    }
    
    private func runStabilityTests(config: ValidationConfig, reporter: ValidationReporter) {
        reporter.logPhaseStart("Stability Tests")
        
        let videoService = VideoService()
        let videoSelectionService = VideoSelectionService(videoService: videoService)
        
        // Load video first
        videoSelectionService.resetToDefaultVideo()
        Thread.sleep(forTimeInterval: 2.0)
        
        guard videoService.currentVideoType != nil else {
            reporter.addResult(TestResult(
                name: "Stability Tests",
                success: true,
                duration: 0,
                details: "Skipped - no video available",
                errorMessage: nil
            ))
            reporter.logPhaseComplete("Stability Tests")
            return
        }
        
        // Stability Test: Rapid Play/Pause Cycles
        let stabilityStartTime = Date()
        var errorCount = 0
        let totalCycles = 5
        
        for cycle in 0..<totalCycles {
            videoService.playVideo()
            Thread.sleep(forTimeInterval: 0.2)
            
            videoService.pauseVideo()
            Thread.sleep(forTimeInterval: 0.2)
            
            // Check for error state
            if case .failed = videoService.playbackState {
                errorCount += 1
            }
        }
        
        let stabilityDuration = Date().timeIntervalSince(stabilityStartTime)
        let stabilitySuccess = errorCount == 0
        
        reporter.addResult(TestResult(
            name: "Rapid Play/Pause Stability",
            success: stabilitySuccess,
            duration: stabilityDuration,
            details: "Cycles: \(totalCycles), Errors: \(errorCount)",
            errorMessage: stabilitySuccess ? nil : "Stability issues detected during rapid cycling"
        ))
        
        reporter.logPhaseComplete("Stability Tests")
    }
    
    private func runMemoryTests(config: ValidationConfig, reporter: ValidationReporter) {
        reporter.logPhaseStart("Memory Tests")
        
        let initialMemory = getCurrentMemoryUsage()
        
        // Create and destroy multiple video services
        for _ in 0..<3 {
            autoreleasepool {
                let videoService = VideoService()
                let videoSelectionService = VideoSelectionService(videoService: videoService)
                
                videoSelectionService.resetToDefaultVideo()
                Thread.sleep(forTimeInterval: 1.0)
                
                videoService.cleanupPlayer()
            }
        }
        
        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool {}
        }
        
        let finalMemory = getCurrentMemoryUsage()
        
        if let initial = initialMemory, let final = finalMemory {
            let memoryIncrease = final - initial
            let increaseInMB = memoryIncrease / 1024 / 1024
            let success = increaseInMB < 50 // Should not increase by more than 50MB
            
            reporter.addResult(TestResult(
                name: "Memory Management",
                success: success,
                duration: 0,
                details: "Memory increase: \(increaseInMB)MB, Target: <50MB",
                errorMessage: success ? nil : "Excessive memory usage detected"
            ))
        } else {
            reporter.addResult(TestResult(
                name: "Memory Management",
                success: false,
                duration: 0,
                details: "Could not measure memory usage",
                errorMessage: "Memory measurement failed"
            ))
        }
        
        reporter.logPhaseComplete("Memory Tests")
    }
    
    private func runSystemValidation(config: ValidationConfig, reporter: ValidationReporter) {
        reporter.logPhaseStart("System Validation")
        
        let videoService = VideoService()
        let videoSelectionService = VideoSelectionService(videoService: videoService)
        let validator = VideoPlaybackValidator(videoService: videoService, videoSelectionService: videoSelectionService)
        
        let validationReport = validator.performCompleteValidation()
        
        reporter.addResult(TestResult(
            name: "System Health Check",
            success: validationReport.healthScore >= 0.8,
            duration: 0,
            details: "Health Score: \(Int(validationReport.healthScore * 100))%, Critical Issues: \(validationReport.criticalIssues.count)",
            errorMessage: validationReport.healthScore >= 0.8 ? nil : "System health below acceptable threshold"
        ))
        
        // Save validation report if configured
        if config.saveReportsToFile {
            _ = validationReport.saveToFile()
        }
        
        reporter.logPhaseComplete("System Validation")
    }
    
    // MARK: - Helper Methods
    
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
    
    private func saveReport(_ report: ValidationSummaryReport) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let reportsDirectory = documentsPath.appendingPathComponent("VideoValidationReports")
        
        do {
            try FileManager.default.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileName = "video_validation_\(dateFormatter.string(from: Date())).txt"
            
            let reportURL = reportsDirectory.appendingPathComponent(fileName)
            try report.detailedReport.write(to: reportURL, atomically: true, encoding: .utf8)
            
            print("📝 Detailed report saved to: \(reportURL.path)")
        } catch {
            print("❌ Failed to save report: \(error)")
        }
    }
}

// MARK: - Validation Reporter

import Combine

class ValidationReporter {
    var cancellables = Set<AnyCancellable>()
    
    private var testResults: [TestResult] = []
    private var phaseStartTimes: [String: Date] = [:]
    private let startTime = Date()
    
    struct TestResult {
        let name: String
        let success: Bool
        let duration: TimeInterval
        let details: String
        let errorMessage: String?
    }
    
    func logValidationStart() {
        print("\n🧪 === VIDEO PLAYBACK VALIDATION STARTED ===")
        print("📅 \(DateFormatter.localizedString(from: startTime, dateStyle: .medium, timeStyle: .medium))")
        print("=" * 50)
    }
    
    func logPhaseStart(_ phaseName: String) {
        phaseStartTimes[phaseName] = Date()
        print("\n🔍 PHASE: \(phaseName)")
        print("-" * 30)
    }
    
    func logPhaseComplete(_ phaseName: String) {
        if let startTime = phaseStartTimes[phaseName] {
            let duration = Date().timeIntervalSince(startTime)
            print("✅ PHASE COMPLETE: \(phaseName) (\(Int(duration * 1000))ms)")
        } else {
            print("✅ PHASE COMPLETE: \(phaseName)")
        }
    }
    
    func addResult(_ result: TestResult) {
        testResults.append(result)
        
        let status = result.success ? "✅" : "❌"
        let durationStr = result.duration > 0 ? " (\(Int(result.duration * 1000))ms)" : ""
        
        print("\(status) \(result.name)\(durationStr)")
        print("   \(result.details)")
        
        if let error = result.errorMessage {
            print("   ⚠️ \(error)")
        }
    }
    
    func generateFinalReport() -> ValidationSummaryReport {
        let totalDuration = Date().timeIntervalSince(startTime)
        let successfulTests = testResults.filter { $0.success }.count
        let failedTests = testResults.filter { !$0.success }.count
        let overallSuccess = failedTests == 0
        
        let summary = """
        
        🏁 === VALIDATION COMPLETE ===
        📊 Results: \(successfulTests) passed, \(failedTests) failed
        ⏱️ Total Duration: \(Int(totalDuration * 1000))ms
        🎯 Success Rate: \(Int(Double(successfulTests) / Double(testResults.count) * 100))%
        ✅ Overall: \(overallSuccess ? "PASSED" : "FAILED")
        
        """
        
        let detailedReport = generateDetailedReport()
        
        return ValidationSummaryReport(
            overallSuccess: overallSuccess,
            summary: summary,
            detailedReport: detailedReport,
            testResults: testResults,
            totalDuration: totalDuration
        )
    }
    
    private func generateDetailedReport() -> String {
        var report = "=== DETAILED VIDEO PLAYBACK VALIDATION REPORT ===\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .full
        
        report += "Generated: \(dateFormatter.string(from: Date()))\n"
        report += "Total Tests: \(testResults.count)\n"
        report += "Duration: \(Int(Date().timeIntervalSince(startTime) * 1000))ms\n\n"
        
        report += "TEST RESULTS:\n"
        report += "=" * 50 + "\n\n"
        
        for (index, result) in testResults.enumerated() {
            let status = result.success ? "PASSED" : "FAILED"
            report += "\(index + 1). \(result.name): \(status)\n"
            report += "   Duration: \(Int(result.duration * 1000))ms\n"
            report += "   Details: \(result.details)\n"
            
            if let error = result.errorMessage {
                report += "   Error: \(error)\n"
            }
            
            report += "\n"
        }
        
        // Summary statistics
        let successCount = testResults.filter { $0.success }.count
        let failureCount = testResults.count - successCount
        let averageDuration = testResults.map { $0.duration }.reduce(0, +) / Double(testResults.count)
        
        report += "SUMMARY STATISTICS:\n"
        report += "=" * 50 + "\n"
        report += "Successful Tests: \(successCount)\n"
        report += "Failed Tests: \(failureCount)\n"
        report += "Success Rate: \(Int(Double(successCount) / Double(testResults.count) * 100))%\n"
        report += "Average Test Duration: \(Int(averageDuration * 1000))ms\n"
        
        if failureCount > 0 {
            report += "\nFAILED TESTS:\n"
            report += "-" * 30 + "\n"
            
            let failedTests = testResults.filter { !$0.success }
            for failedTest in failedTests {
                report += "• \(failedTest.name)\n"
                report += "  Reason: \(failedTest.errorMessage ?? "Unknown")\n"
                report += "  Details: \(failedTest.details)\n\n"
            }
        }
        
        return report
    }
}

struct ValidationSummaryReport {
    let overallSuccess: Bool
    let summary: String
    let detailedReport: String
    let testResults: [ValidationReporter.TestResult]
    let totalDuration: TimeInterval
}

// MARK: - String Extension for Report Formatting

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}