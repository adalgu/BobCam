//
//  DebugCameraView.swift
//  BobCam
//
//  Enhanced camera view with integrated debug overlay support
//

import SwiftUI
import AVFoundation
import Vision
import Combine

/// Enhanced CameraView with debug overlay integration
struct DebugCameraView: UIViewRepresentable {
    let cameraService: CameraService
    @ObservedObject var visionService: VisionService
    @ObservedObject var debugSettings: DebugSettings
    
    func makeUIView(context: Context) -> DebugCameraUIView {
        let view = DebugCameraUIView()
        view.backgroundColor = .black
        view.visionService = visionService
        view.debugSettings = debugSettings
        
        // Set up camera preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraService.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        
        // Front camera mirroring
        if let connection = previewLayer.connection,
           connection.isVideoMirroringSupported {
            connection.isVideoMirrored = true
        }
        
        view.previewLayer = previewLayer
        view.layer.addSublayer(previewLayer)
        
        // Set up landmarks overlay
        let landmarksOverlay = LandmarksOverlayUIView()
        landmarksOverlay.debugSettings = debugSettings
        landmarksOverlay.frame = view.bounds
        landmarksOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(landmarksOverlay)
        view.landmarksOverlay = landmarksOverlay
        
        return view
    }
    
    func updateUIView(_ uiView: DebugCameraUIView, context: Context) {
        uiView.visionService = visionService
        uiView.debugSettings = debugSettings
        
        // Update preview layer frame
        if let previewLayer = uiView.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
        
        // Update landmarks overlay
        if let landmarksOverlay = uiView.landmarksOverlay {
            landmarksOverlay.cameraFrame = uiView.bounds
            landmarksOverlay.debugSettings = debugSettings
            
            if debugSettings.showLandmarksOverlay {
                landmarksOverlay.setNeedsDisplay()
            }
        }
    }
}

/// Custom UIView that manages camera preview and debug overlays
class DebugCameraUIView: UIView {
    
    // MARK: - Properties
    var visionService: VisionService? {
        didSet {
            setupVisionServiceObservers()
        }
    }
    
    var debugSettings: DebugSettings? {
        didSet {
            updateDebugVisualization()
        }
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    var landmarksOverlay: LandmarksOverlayUIView?
    
    // MARK: - Vision Observers
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .black
        clipsToBounds = true
    }
    
    private func setupVisionServiceObservers() {
        cancellables.removeAll()
        
        guard let visionService = visionService else { return }
        
        // Observe when new landmarks are available
        // Note: This would require VisionService to expose landmarks
        // For now, we'll set up the structure
        
        visionService.$isEating
            .sink { [weak self] _ in
                self?.updateLandmarksDisplay()
            }
            .store(in: &cancellables)
    }
    
    private func updateLandmarksDisplay() {
        guard let debugSettings = debugSettings,
              debugSettings.showLandmarksOverlay else { return }
        
        // Get current landmarks from vision service
        if let visionService = visionService {
            let (landmarks, faceObservation) = visionService.getCurrentLandmarksForDebug()
            landmarksOverlay?.updateLandmarks(landmarks, faceObservation: faceObservation)
        }
    }
    
    private func updateDebugVisualization() {
        guard let debugSettings = debugSettings else { return }
        
        landmarksOverlay?.isHidden = !debugSettings.showLandmarksOverlay
        
        if debugSettings.showLandmarksOverlay {
            landmarksOverlay?.setNeedsDisplay()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update preview layer frame
        previewLayer?.frame = bounds
        
        // Update landmarks overlay frame
        landmarksOverlay?.frame = bounds
        landmarksOverlay?.cameraFrame = bounds
    }
}



// MARK: - Import required for objc_setAssociatedObject
import ObjectiveC

// MARK: - Debug-Enabled Content View
/// Enhanced ContentView with debug overlay support
struct DebugEnabledContentView: View {
    @StateObject private var cameraService = CameraService()
    @StateObject private var visionService = VisionService()
    @StateObject private var videoService = VideoService()
    @StateObject private var videoSelectionService: VideoSelectionService
    @StateObject private var debugSettings = DebugSettings()
    @State private var showingSettings = false
    
    init() {
        let videoService = VideoService()
        _videoService = StateObject(wrappedValue: videoService)
        _videoSelectionService = StateObject(wrappedValue: VideoSelectionService(videoService: videoService))
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Enhanced camera feed with debug overlay (left 40%)
                ZStack {
                    DebugCameraView(
                        cameraService: cameraService,
                        visionService: visionService,
                        debugSettings: debugSettings
                    )
                    .frame(width: geometry.size.width * 0.4)
                    .onAppear {
                        cameraService.startSession()
                        cameraService.delegate = visionService
                    }
                }
                
                // Video player (right 60%)
                VideoPlayerView(
                    videoService: videoService,
                    videoSelectionService: videoSelectionService
                )
                .frame(width: geometry.size.width * 0.6)
            }
            .overlay(alignment: .bottom) {
                StatusBar(
                    isEating: visionService.isEating,
                    visionService: visionService,
                    videoService: videoService,
                    videoSelectionService: videoSelectionService,
                    sensitivity: $visionService.sensitivity
                )
                .padding()
            }
            .overlay(alignment: .topTrailing) {
                // Settings button
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding()
            }
            .overlay {
                // Debug overlay system
                DebugOverlayView(
                    visionService: visionService,
                    debugSettings: debugSettings
                )
            }
        }
        .ignoresSafeArea()
        .onReceive(visionService.$isEating) { isEating in
            if isEating {
                videoService.playVideo()
            } else {
                videoService.pauseVideo()
            }
        }
        .sheet(isPresented: $showingSettings) {
            DebugEnabledSettingsView(
                videoSelectionService: videoSelectionService,
                videoService: videoService,
                visionService: visionService,
                debugSettings: debugSettings,
                isPresented: $showingSettings
            )
        }
    }
}

// MARK: - Debug-Enabled Settings View
struct DebugEnabledSettingsView: View {
    @ObservedObject var videoSelectionService: VideoSelectionService
    @ObservedObject var videoService: VideoService
    @ObservedObject var visionService: VisionService
    @ObservedObject var debugSettings: DebugSettings
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                // Original settings sections would go here
                Section("Debug Settings") {
                    Toggle("Debug Mode", isOn: $debugSettings.isDebugModeEnabled)
                    
                    if debugSettings.isDebugModeEnabled {
                        Toggle("Performance Metrics", isOn: $debugSettings.showPerformanceMetrics)
                        Toggle("Accuracy Metrics", isOn: $debugSettings.showAccuracyMetrics)
                        Toggle("Algorithm Parameters", isOn: $debugSettings.showAlgorithmParameters)
                        Toggle("Buffer Visualization", isOn: $debugSettings.showBufferVisualization)
                        Toggle("Landmarks Overlay", isOn: $debugSettings.showLandmarksOverlay)
                        
                        if debugSettings.showLandmarksOverlay {
                            VStack(alignment: .leading) {
                                Text("Landmark Point Size: \(String(format: "%.1f", debugSettings.landmarkPointSize))")
                                    .font(.caption)
                                Slider(value: $debugSettings.landmarkPointSize, in: 1.0...10.0)
                                
                                Text("Landmark Opacity: \(String(format: "%.1f", debugSettings.landmarkOpacity))")
                                    .font(.caption)
                                Slider(value: $debugSettings.landmarkOpacity, in: 0.1...1.0)
                                
                                Toggle("Show Labels", isOn: $debugSettings.showLandmarkLabels)
                            }
                        }
                        
                        Button("Reset Debug Settings") {
                            debugSettings.resetToDefaults()
                        }
                        .foregroundColor(.red)
                        
                        Button("Export Debug Data") {
                            // Export functionality would go here
                            let report = debugSettings.generateDebugReport()
                            print("Debug Report:\n\(report)")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    DebugEnabledContentView()
}