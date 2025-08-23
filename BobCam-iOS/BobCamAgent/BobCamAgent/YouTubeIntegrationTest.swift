import SwiftUI
import XCTest

// MARK: - YouTube Integration Test
@MainActor
class YouTubeIntegrationTest: ObservableObject {
    
    @Published var testResults: [TestResult] = []
    @Published var isRunning = false
    
    struct TestResult {
        let testName: String
        let passed: Bool
        let message: String
        let timestamp: Date
    }
    
    // MARK: - Test Cases
    
    func runAllTests() async {
        isRunning = true
        testResults.removeAll()
        
        // Test 1: YouTube URL validation
        await testYouTubeURLValidation()
        
        // Test 2: VideoType creation
        await testVideoTypeCreation()
        
        // Test 3: Child safety filter
        await testChildSafetyFilter()
        
        // Test 4: VideoService integration
        await testVideoServiceIntegration()
        
        // Test 5: VideoSelectionService integration
        await testVideoSelectionServiceIntegration()
        
        isRunning = false
    }
    
    // MARK: - Individual Tests
    
    private func testYouTubeURLValidation() async {
        let testName = "YouTube URL Validation"
        
        let validURLs = [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtu.be/dQw4w9WgXcQ",
            "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://www.youtube.com/embed/dQw4w9WgXcQ"
        ]
        
        let invalidURLs = [
            "https://vimeo.com/123456",
            "https://facebook.com/video",
            "invalid-url",
            ""
        ]
        
        var allPassed = true
        var messages: [String] = []
        
        // Test valid URLs
        for url in validURLs {
            if !YouTubeURLUtils.isValidYouTubeURL(url) {
                allPassed = false
                messages.append("Failed to validate: \(url)")
            }
        }
        
        // Test invalid URLs
        for url in invalidURLs {
            if YouTubeURLUtils.isValidYouTubeURL(url) {
                allPassed = false
                messages.append("Incorrectly validated: \(url)")
            }
        }
        
        let result = TestResult(
            testName: testName,
            passed: allPassed,
            message: allPassed ? "All URL validations passed" : messages.joined(separator: ", "),
            timestamp: Date()
        )
        
        testResults.append(result)
    }
    
    private func testVideoTypeCreation() async {
        let testName = "VideoType Creation"
        
        // Test local video type
        let localURL = URL(fileURLWithPath: "/path/to/video.mp4")
        let localVideoType = VideoType.local(localURL)
        
        guard localVideoType.isLocal && !localVideoType.isYouTube else {
            let result = TestResult(
                testName: testName,
                passed: false,
                message: "Local VideoType properties incorrect",
                timestamp: Date()
            )
            testResults.append(result)
            return
        }
        
        // Test YouTube video type
        let youTubeVideo = YouTubeVideo(videoId: "dQw4w9WgXcQ", title: "Test Video")
        let youTubeVideoType = VideoType.youtube(youTubeVideo)
        
        guard !youTubeVideoType.isLocal && youTubeVideoType.isYouTube else {
            let result = TestResult(
                testName: testName,
                passed: false,
                message: "YouTube VideoType properties incorrect",
                timestamp: Date()
            )
            testResults.append(result)
            return
        }
        
        let result = TestResult(
            testName: testName,
            passed: true,
            message: "VideoType creation successful",
            timestamp: Date()
        )
        
        testResults.append(result)
    }
    
    private func testChildSafetyFilter() async {
        let testName = "Child Safety Filter"
        
        // Test safe video
        let safeVideo = YouTubeVideo(videoId: "test123", isChildSafe: true)
        let isSafe = ChildSafetyFilter.isChildSafe(safeVideo)
        
        // Test unsafe video
        let unsafeVideo = YouTubeVideo(videoId: "test456", isChildSafe: false)
        let isUnsafe = !ChildSafetyFilter.isChildSafe(unsafeVideo)
        
        // Test URL validation
        let safeURL = "https://www.youtube.com/watch?v=kidsvideo"
        let unsafeURL = "https://www.youtube.com/watch?v=adultvideo"
        
        let urlSafe = ChildSafetyFilter.validateURL(safeURL)
        let urlUnsafe = !ChildSafetyFilter.validateURL(unsafeURL)
        
        let allPassed = isSafe && isUnsafe && urlSafe && urlUnsafe
        
        let result = TestResult(
            testName: testName,
            passed: allPassed,
            message: allPassed ? "Child safety filters working correctly" : "Child safety filter issues detected",
            timestamp: Date()
        )
        
        testResults.append(result)
    }
    
    private func testVideoServiceIntegration() async {
        let testName = "VideoService Integration"
        
        let videoService = VideoService()
        
        // Test initial state
        guard videoService.playbackState == .idle else {
            let result = TestResult(
                testName: testName,
                passed: false,
                message: "Initial VideoService state incorrect",
                timestamp: Date()
            )
            testResults.append(result)
            return
        }
        
        // Test YouTube video loading (without network)
        let youTubeVideo = YouTubeVideo(videoId: "test123", isChildSafe: true)
        let videoType = VideoType.youtube(youTubeVideo)
        
        videoService.loadVideo(videoType)
        
        // Should handle loading state
        let hasCorrectVideoType = videoService.currentVideoType == videoType
        
        let result = TestResult(
            testName: testName,
            passed: hasCorrectVideoType,
            message: hasCorrectVideoType ? "VideoService integration successful" : "VideoService integration failed",
            timestamp: Date()
        )
        
        testResults.append(result)
    }
    
    private func testVideoSelectionServiceIntegration() async {
        let testName = "VideoSelectionService Integration"
        
        let videoService = VideoService()
        let selectionService = VideoSelectionService(videoService: videoService)
        
        // Test YouTube URL validation
        selectionService.youTubeURLInput = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        
        do {
            let youTubeVideo = try await selectionService.validateAndCreateYouTubeVideo(
                from: selectionService.youTubeURLInput
            )
            
            let result = TestResult(
                testName: testName,
                passed: youTubeVideo.videoId == "dQw4w9WgXcQ",
                message: "VideoSelectionService YouTube integration successful",
                timestamp: Date()
            )
            
            testResults.append(result)
        } catch {
            let result = TestResult(
                testName: testName,
                passed: false,
                message: "VideoSelectionService integration failed: \(error.localizedDescription)",
                timestamp: Date()
            )
            
            testResults.append(result)
        }
    }
}

// MARK: - Test UI View
struct YouTubeIntegrationTestView: View {
    @StateObject private var testRunner = YouTubeIntegrationTest()
    
    var body: some View {
        NavigationView {
            VStack {
                if testRunner.isRunning {
                    ProgressView("테스트 실행 중...")
                        .padding()
                } else {
                    Button("YouTube 통합 테스트 실행") {
                        Task {
                            await testRunner.runAllTests()
                        }
                    }
                    .padding()
                }
                
                List(testRunner.testResults, id: \.testName) { result in
                    HStack {
                        Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.passed ? .green : .red)
                        
                        VStack(alignment: .leading) {
                            Text(result.testName)
                                .font(.headline)
                            Text(result.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("YouTube 통합 테스트")
        }
    }
}

#Preview {
    YouTubeIntegrationTestView()
}