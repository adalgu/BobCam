import Foundation
import AVFoundation

/// Quick test utility to validate video loading functionality
/// This can be run to check if demo.mp4 is accessible and loadable
class VideoLoadingTest {
    
    static func testBundleVideoAccess() {
        print("🧪 [VideoLoadingTest] Starting bundle video access test...")
        
        // Test 1: Check if demo.mp4 exists in bundle
        print("📁 Testing Bundle.main.path...")
        if let bundlePath = Bundle.main.path(forResource: "demo", ofType: "mp4") {
            print("✅ Found demo.mp4 via Bundle.main.path: \(bundlePath)")
            testFileAccess(path: bundlePath)
        } else {
            print("❌ demo.mp4 NOT found via Bundle.main.path")
        }
        
        // Test 2: Check Bundle.main.url
        print("🔗 Testing Bundle.main.url...")
        if let bundleURL = Bundle.main.url(forResource: "demo", withExtension: "mp4") {
            print("✅ Found demo.mp4 via Bundle.main.url: \(bundleURL)")
            testURLAccess(url: bundleURL)
        } else {
            print("❌ demo.mp4 NOT found via Bundle.main.url")
        }
        
        // Test 3: List all MP4 files in bundle
        print("📋 Listing all MP4 files in bundle...")
        let mp4Files = Bundle.main.paths(forResourcesOfType: "mp4", inDirectory: nil)
        if mp4Files.isEmpty {
            print("❌ No MP4 files found in bundle!")
        } else {
            print("📹 Found \(mp4Files.count) MP4 file(s):")
            for file in mp4Files {
                print("  - \(file)")
            }
        }
        
        print("🧪 [VideoLoadingTest] Test completed\n")
    }
    
    private static func testFileAccess(path: String) {
        let fileExists = FileManager.default.fileExists(atPath: path)
        print("📁 File exists at path: \(fileExists)")
        
        if fileExists {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: path)
                if let fileSize = attributes[.size] as? NSNumber {
                    print("📊 File size: \(fileSize.intValue) bytes")
                }
            } catch {
                print("⚠️ Could not get file attributes: \(error)")
            }
        }
    }
    
    private static func testURLAccess(url: URL) {
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        print("📁 File exists at URL path: \(fileExists)")
        
        if fileExists {
            // Test AVAsset creation
            print("🎬 Testing AVAsset creation...")
            let asset = AVAsset(url: url)
            
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    let isPlayable = try await asset.load(.isPlayable)
                    
                    print("✅ AVAsset loaded successfully:")
                    print("  - Duration: \(duration.seconds) seconds")
                    print("  - Playable: \(isPlayable)")
                } catch {
                    print("❌ AVAsset loading failed: \(error)")
                }
            }
        }
    }
    
    /// Test the VideoService loading functionality
    static func testVideoServiceLoading() {
        print("🧪 [VideoLoadingTest] Starting VideoService loading test...")
        
        if let bundleURL = Bundle.main.url(forResource: "demo", withExtension: "mp4") {
            print("📹 Testing VideoService with demo.mp4...")
            
            let videoService = VideoService()
            let videoType = VideoType.local(bundleURL)
            
            // Load the video
            videoService.loadVideo(videoType)
            
            // Give it some time to load asynchronously
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("📊 VideoService state after 2 seconds:")
                print("  - Playback state: \(videoService.playbackState)")
                print("  - Current video type: \(videoService.currentVideoType?.debugDescription ?? "none")")
                print("  - Is playing: \(videoService.isPlaying)")
            }
        } else {
            print("❌ Cannot test VideoService - demo.mp4 not found in bundle")
        }
        
        print("🧪 [VideoLoadingTest] VideoService test initiated\n")
    }
}

#if DEBUG
extension VideoLoadingTest {
    /// Call this from ContentView.onAppear for debugging
    static func runAllTests() {
        testBundleVideoAccess()
        testVideoServiceLoading()
    }
}
#endif