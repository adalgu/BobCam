import SwiftUI
import AVFoundation

/// Debug utility to test video loading directly
struct VideoLoadingDebugger {
    static func testDemoVideoLoading() {
        print("🔍 === VIDEO LOADING DEBUGGER ===")
        
        // Test 1: Check Bundle Resources
        print("\n📦 Test 1: Bundle Resources")
        if let bundleURL = Bundle.main.url(forResource: "demo", withExtension: "mp4") {
            print("✅ Found demo.mp4 at: \(bundleURL)")
            print("   - Path: \(bundleURL.path)")
            print("   - File exists: \(FileManager.default.fileExists(atPath: bundleURL.path))")
            
            // Test 2: AVAsset Creation
            print("\n🎬 Test 2: AVAsset Creation")
            let asset = AVAsset(url: bundleURL)
            
            Task {
                do {
                    // Test asset properties
                    let duration = try await asset.load(.duration)
                    let isPlayable = try await asset.load(.isPlayable)
                    let tracks = try await asset.load(.tracks)
                    
                    print("✅ Asset loaded successfully:")
                    print("   - Duration: \(duration.seconds) seconds")
                    print("   - Playable: \(isPlayable)")
                    print("   - Tracks: \(tracks.count)")
                    
                    // Test 3: AVPlayerItem Creation
                    print("\n📺 Test 3: AVPlayerItem Creation")
                    let playerItem = AVPlayerItem(asset: asset)
                    print("✅ PlayerItem created")
                    print("   - Initial status: \(playerItem.status.rawValue)")
                    
                    // Test 4: AVPlayer Creation
                    print("\n▶️ Test 4: AVPlayer Creation")
                    let player = AVPlayer(playerItem: playerItem)
                    print("✅ Player created")
                    print("   - Rate: \(player.rate)")
                    print("   - Error: \(player.error?.localizedDescription ?? "none")")
                    
                    // Monitor status changes
                    print("\n📊 Monitoring status changes...")
                    
                    // Add observer for status
                    let observation = playerItem.observe(\.status, options: [.new]) { item, change in
                        DispatchQueue.main.async {
                            print("🔄 Status changed to: \(item.status.rawValue)")
                            switch item.status {
                            case .readyToPlay:
                                print("✅ READY TO PLAY!")
                            case .failed:
                                print("❌ FAILED: \(item.error?.localizedDescription ?? "unknown")")
                            case .unknown:
                                print("⏳ Status unknown")
                            @unknown default:
                                print("❓ Unknown status")
                            }
                        }
                    }
                    
                    // Force load
                    playerItem.preferredForwardBufferDuration = 2
                    
                    // Wait a bit for status update
                    try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    
                    print("\n📊 Final Status Check:")
                    print("   - PlayerItem status: \(playerItem.status.rawValue)")
                    print("   - Player error: \(player.error?.localizedDescription ?? "none")")
                    print("   - PlayerItem error: \(playerItem.error?.localizedDescription ?? "none")")
                    
                } catch {
                    print("❌ Asset loading failed: \(error)")
                }
            }
        } else {
            print("❌ demo.mp4 NOT found in bundle!")
            
            // List all resources in bundle
            print("\n📋 All MP4 files in bundle:")
            let mp4s = Bundle.main.paths(forResourcesOfType: "mp4", inDirectory: nil)
            if mp4s.isEmpty {
                print("   - No MP4 files found")
            } else {
                for path in mp4s {
                    print("   - \(path)")
                }
            }
        }
        
        print("\n🔍 === END DEBUG ===")
    }
}

// Add this debug view for testing
struct VideoDebugView: View {
    @State private var debugOutput: String = "Tap to start test"
    
    var body: some View {
        VStack {
            Text("Video Loading Debugger")
                .font(.headline)
                .padding()
            
            ScrollView {
                Text(debugOutput)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
            
            Button("Run Debug Test") {
                debugOutput = "Running test...\n"
                VideoLoadingDebugger.testDemoVideoLoading()
            }
            .padding()
        }
    }
}