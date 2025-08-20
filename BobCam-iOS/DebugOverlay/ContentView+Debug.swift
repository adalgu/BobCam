//
//  ContentView+Debug.swift
//  BobCam
//
//  Debug-enabled extension of ContentView for development builds
//

import SwiftUI

// MARK: - Debug-Enabled ContentView Alternative

/// Drop-in replacement for ContentView with debug overlay support
/// 
/// Usage:
/// 1. For debug builds: Use DebugContentView instead of ContentView
/// 2. For release builds: Use original ContentView
/// 
/// Integration example:
/// ```swift
/// @main
/// struct BobCamApp: App {
///     var body: some Scene {
///         WindowGroup {
///             #if DEBUG
///             DebugContentView()
///             #else
///             ContentView()
///             #endif
///         }
///     }
/// }
/// ```
struct DebugContentView: View {
    @StateObject private var cameraService = CameraService()
    @StateObject private var visionService = VisionService()
    @StateObject private var videoService = VideoService()
    @StateObject private var videoSelectionService: VideoSelectionService
    @StateObject private var debugSettings = DebugIntegrationHelpers.setupDebugEnvironment()
    @State private var showingSettings = false
    
    init() {
        let videoService = VideoService()
        _videoService = StateObject(wrappedValue: videoService)
        _videoSelectionService = StateObject(wrappedValue: VideoSelectionService(videoService: videoService))
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Enhanced camera feed with debug capabilities (left 40%)
                ZStack {
                    if debugSettings.showLandmarksOverlay {
                        // Use debug-enabled camera view
                        DebugCameraView(
                            cameraService: cameraService,
                            visionService: visionService,
                            debugSettings: debugSettings
                        )
                    } else {
                        // Use standard camera view for better performance
                        CameraView(cameraService: cameraService)
                    }
                }
                .frame(width: geometry.size.width * 0.4)
                .onAppear {
                    cameraService.startSession()
                    cameraService.delegate = visionService
                    visionService.startTracking()
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
                // Debug overlay system (conditionally rendered)
                if debugSettings.isDebugModeEnabled {
                    DebugOverlayView(
                        visionService: visionService,
                        debugSettings: debugSettings
                    )
                }
            }
        }
        .ignoresSafeArea()
        .onReceive(visionService.$isEating) { isEating in
            // Lip detection result controls video playback
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
        .onAppear {
            // Validate debug configuration on app launch
            let warnings = DebugIntegrationHelpers.validateConfiguration(debugSettings: debugSettings)
            for warning in warnings {
                print("⚠️ Debug Configuration Warning: \(warning)")
            }
            
            // Update debug settings with current configuration
            debugSettings.updateConfiguration(visionService.configuration)
        }
    }
}

// MARK: - Conditional ContentView Factory

/// Factory for creating appropriate ContentView based on build configuration
struct ContentViewFactory {
    
    /// Returns debug-enabled ContentView for DEBUG builds, standard ContentView for RELEASE
    @ViewBuilder
    static func createContentView() -> some View {
        #if DEBUG
        DebugContentView()
        #else
        ContentView()
        #endif
    }
    
    /// Force debug mode (useful for testing debug features in release builds)
    @ViewBuilder
    static func createDebugContentView() -> some View {
        DebugContentView()
    }
    
    /// Force production mode (useful for performance testing in debug builds)
    @ViewBuilder
    static func createProductionContentView() -> some View {
        ContentView()
    }
}

// MARK: - Debug Feature Toggle Extension

extension ContentView {
    
    /// Add debug overlay to existing ContentView
    func withDebugOverlay(enabled: Bool = true) -> some View {
        ZStack {
            self
            
            if enabled {
                DebugOverlayView(
                    visionService: VisionService(), // This would need proper injection
                    debugSettings: DebugSettings()
                )
            }
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct ContentView_Debug_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard debug view
            DebugContentView()
                .previewDisplayName("Debug Mode")
            
            // Debug view with landmarks enabled
            DebugContentView()
                .onAppear {
                    // This would need proper state injection in real implementation
                }
                .previewDisplayName("Debug + Landmarks")
            
            // Production view for comparison
            ContentView()
                .previewDisplayName("Production Mode")
        }
    }
}
#endif

// MARK: - App Integration Example

/**
 Example BobCamApp.swift with debug integration:
 
 ```swift
 import SwiftUI
 
 @main
 struct BobCamApp: App {
     var body: some Scene {
         WindowGroup {
             ContentViewFactory.createContentView()
         }
     }
 }
 ```
 
 Alternative with explicit control:
 
 ```swift
 @main
 struct BobCamApp: App {
     @AppStorage("debug_mode_enabled") private var debugModeEnabled = false
     
     var body: some Scene {
         WindowGroup {
             if debugModeEnabled {
                 DebugContentView()
             } else {
                 ContentView()
             }
         }
     }
 }
 ```
 */