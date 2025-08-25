import SwiftUI

struct DebugTestView: View {
    @StateObject private var videoService = VideoService()
    @StateObject private var visionService = VisionService()
    @State private var simulatedEating: Bool = false
    @State private var debugMessages: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Debug Video Control Test")
                .font(.title)
                .padding()
            
            // Video State Display
            VStack(alignment: .leading) {
                Text("Video State: \(String(describing: videoService.playbackState))")
                Text("Is Playing: \(videoService.isPlaying)")
                Text("Video Type: \(videoService.currentVideoType?.description ?? "none")")
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            
            // Eating State Display  
            VStack(alignment: .leading) {
                Text("Eating Detected: \(visionService.isEating)")
                Text("Simulated Eating: \(simulatedEating)")
            }
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(10)
            
            // Control Buttons
            HStack(spacing: 20) {
                Button("Load Test Video") {
                    loadTestVideo()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Toggle Eating") {
                    toggleEatingSimulation()
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            HStack(spacing: 20) {
                Button("Play Video") {
                    videoService.playVideo()
                    addDebugMessage("Manual Play Video Called")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Pause Video") {
                    videoService.pauseVideo()
                    addDebugMessage("Manual Pause Video Called")
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            // Debug Messages
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(debugMessages.indices, id: \.self) { index in
                        Text(debugMessages[index])
                            .font(.caption)
                            .padding(2)
                    }
                }
            }
            .frame(height: 200)
            .padding()
            .background(Color.black.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .onReceive(visionService.$isEating) { isEating in
            addDebugMessage("🎬 Vision isEating changed: \(isEating)")
            addDebugMessage("🎬 Video state: \(videoService.playbackState)")
            if isEating {
                addDebugMessage("🎬 Calling videoService.playVideo()")
                videoService.playVideo()
            } else {
                addDebugMessage("🎬 Calling videoService.pauseVideo()")
                videoService.pauseVideo()
            }
        }
    }
    
    private func loadTestVideo() {
        addDebugMessage("Loading test video...")
        
        // Try to load from bundle first
        if let videoURL = Bundle.main.url(forResource: "sample_video", withExtension: "mp4") {
            videoService.loadVideo(from: videoURL)
            addDebugMessage("Loaded sample_video.mp4 from bundle")
        } else {
            // Create a simple test video URL
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let videoURL = documentsPath.appendingPathComponent("test_video.mp4")
            addDebugMessage("No bundle video found, would use: \(videoURL)")
            
            // For testing, try to load any available video from the app bundle
            if let bundlePath = Bundle.main.path(forResource: "sample_video", ofType: "mp4") {
                let url = URL(fileURLWithPath: bundlePath)
                videoService.loadVideo(from: url)
                addDebugMessage("Loaded from bundle path: \(bundlePath)")
            } else {
                addDebugMessage("❌ No test video available")
            }
        }
    }
    
    private func toggleEatingSimulation() {
        simulatedEating.toggle()
        addDebugMessage("Simulating eating: \(simulatedEating)")
        
        // Directly trigger VisionService eating state change
        visionService.isEating = simulatedEating
    }
    
    private func addDebugMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugMessages.append("[\(timestamp)] \(message)")
        
        // Keep only last 20 messages
        if debugMessages.count > 20 {
            debugMessages.removeFirst()
        }
        
        print("[DebugTestView] \(message)")
    }
}

#Preview {
    DebugTestView()
}