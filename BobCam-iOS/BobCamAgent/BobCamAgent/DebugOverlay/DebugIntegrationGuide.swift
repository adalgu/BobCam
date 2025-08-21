//
//  DebugIntegrationGuide.swift
//  BobCam
//
//  Integration guide and helper utilities for the debug overlay system
//

import SwiftUI
import Foundation

// MARK: - Debug System Integration
/**
 # Debug Overlay System Integration Guide
 
 ## Overview
 The BobCam debug overlay system provides comprehensive real-time visualization and parameter tuning capabilities for the lip detection algorithm. This system is designed to help developers and testers achieve the target 70% accuracy through iterative parameter optimization.
 
 ## Components
 
 ### 1. DebugOverlayView
 - Main debug UI panel with expandable sections
 - Real-time performance and accuracy metrics display
 - Quick toggle buttons for different debug features
 - Minimal performance impact design
 
 ### 2. LandmarksOverlayView
 - Real-time lip landmark visualization on camera feed
 - Visual indication of algorithm-specific detection points
 - Trail visualization showing movement history
 - Configurable display options (point size, opacity, labels)
 
 ### 3. DebugSettings
 - Centralized configuration management
 - Persistent settings storage via UserDefaults
 - Export capabilities for debugging sessions
 - Performance profiling integration
 
 ### 4. DebugCameraView
 - Enhanced camera view with integrated debug overlays
 - Seamless integration with existing camera pipeline
 - Thread-safe landmark updates
 
 ## Integration Steps
 
 ### Step 1: Replace ContentView
 ```swift
 // In your main App file, replace:
 ContentView()
 
 // With:
 DebugEnabledContentView()
 ```
 
 ### Step 2: Update VisionService (Already Done)
 The VisionService has been enhanced with:
 - debugLandmarks and debugFaceObservation properties
 - updateDebugLandmarks() method
 - getCurrentLandmarksForDebug() method
 
 ### Step 3: Configure Debug Build Settings
 Add to your project's build configuration:
 ```swift
 #if DEBUG
 let shouldEnableDebugOverlay = true
 #else
 let shouldEnableDebugOverlay = false
 #endif
 ```
 
 ## Usage Instructions
 
 ### For Developers
 
 1. **Enable Debug Mode**
    - Tap the bug icon in the top-right corner
    - Toggle individual debug features using the letter buttons (P/A/T/B/L)
    - Expand the debug panel for detailed controls
 
 2. **Parameter Tuning**
    - Use the sensitivity slider for real-time adjustments
    - Monitor IoU values for accuracy feedback
    - Watch FPS counter to ensure performance targets (15fps)
    - Observe processing time to stay under 100ms
 
 3. **Algorithm Analysis**
    - Enable landmarks overlay to see detection points
    - Watch the algorithm-specific points (green/blue markers)
    - Monitor the yellow line showing lip distance calculation
    - Use buffer visualization to see eating pattern detection
 
 4. **Performance Optimization**
    - Monitor FPS drops (red indicates <8fps, orange <12fps)
    - Watch processing time spikes
    - Use memory usage indicators
    - Check tracking failure counts
 
 ### For Testers
 
 1. **Quick Debug Mode**
    ```swift
    // Enable all debug features quickly
    debugSettings.enableAllFeatures()
    ```
 
 2. **Performance Mode**
    ```swift
    // Disable debug overlays for performance testing
    debugSettings.disableAllFeatures()
    ```
 
 3. **Export Debug Data**
    ```swift
    let debugReport = debugSettings.generateDebugReport()
    // Share or log the report for analysis
    ```
 
 ## Performance Considerations
 
 The debug overlay system is designed with minimal performance impact:
 
 - **Target**: <5ms overhead per frame
 - **UI Updates**: Throttled to 10Hz (100ms intervals)
 - **Landmark Rendering**: Optimized Core Graphics drawing
 - **Memory Usage**: Circular buffers prevent memory leaks
 - **Thread Safety**: All UI updates on main thread
 
 ## Customization Options
 
 ### Landmark Visualization
 - Point size: 1.0-10.0 pixels
 - Line width: 0.5-5.0 pixels
 - Opacity: 0.1-1.0
 - Colors: Customizable per feature type
 - Labels: Toggle point indices and region names
 
 ### Performance Metrics
 - Update frequency: 0.1-2.0 seconds
 - History length: 10-100 samples
 - Warning thresholds: Configurable per metric
 
 ### Buffer Visualization
 - History size: 5-30 frames
 - Chart types: Line graph, bar chart, scatter plot
 - Smoothing: EMA visualization toggle
 
 ## Debug Build Integration
 
 ### Conditional Compilation
 ```swift
 #if DEBUG
 struct ContentView: View {
     var body: some View {
         DebugEnabledContentView()
     }
 }
 #else
 struct ContentView: View {
     var body: some View {
         ProductionContentView()
     }
 }
 #endif
 ```
 
 ### Feature Flags
 ```swift
 enum DebugFeatureFlags {
     static let landmarksOverlay = true
     static let performanceMetrics = true
     static let parameterTuning = true
     static let bufferVisualization = true
     static let exportCapability = true
 }
 ```
 
 ## Testing Scenarios
 
 ### Accuracy Testing
 1. Enable accuracy metrics and landmarks overlay
 2. Test various lighting conditions
 3. Test different distances from camera
 4. Test various eating motions (chewing, swallowing, talking)
 5. Monitor IoU values and adjust thresholds accordingly
 
 ### Performance Testing
 1. Enable performance metrics only
 2. Test on different device models
 3. Monitor FPS consistency
 4. Check processing time distribution
 5. Verify memory usage stability
 
 ### Algorithm Tuning
 1. Enable parameter controls
 2. Start with default values
 3. Adjust sensitivity in 0.1 increments
 4. Monitor real-time accuracy feedback
 5. Document optimal parameter combinations
 
 ## Troubleshooting
 
 ### Common Issues
 
 1. **High Processing Time (>100ms)**
    - Disable non-essential debug features
    - Check for memory pressure
    - Verify frame rate throttling is working
 
 2. **Low FPS (<10fps)**
    - Reduce landmark visualization complexity
    - Increase UI update intervals
    - Check for main thread blocking
 
 3. **Poor Accuracy (<50% IoU)**
    - Adjust EMA alpha values
    - Modify eating pattern thresholds
    - Check lighting conditions
    - Verify landmark detection quality
 
 4. **UI Responsiveness Issues**
    - Ensure UI updates on main thread
    - Check for excessive debug data retention
    - Verify timer-based updates are working
 
 ### Debug Console Output
 The system provides structured logging:
 ```
 [DEBUG] Vision processing: 15.2ms, FPS: 14.1
 [DEBUG] IoU: 0.856, Jitter: 0.023, Failures: 0
 [DEBUG] Algorithm state: eating, confidence: 0.78
 [DEBUG] EMA smoothing applied, alpha: 0.3
 ```
 
 ## Future Enhancements
 
 - A/B testing framework integration
 - Machine learning parameter optimization
 - Remote debugging capabilities
 - Advanced visualization modes
 - Performance regression detection
 - Automated accuracy benchmarking
 
 ## Support
 
 For issues or feature requests related to the debug overlay system:
 1. Check the console output for error messages
 2. Export debug data for analysis
 3. Document reproduction steps
 4. Include device model and iOS version information
 */

// MARK: - Debug Integration Helpers

struct DebugIntegrationHelpers {
    
    /// Initialize debug system with recommended settings
    static func setupDebugEnvironment() -> DebugSettings {
        let settings = DebugSettings()
        
        #if DEBUG
        // Enable key debug features for development
        settings.isDebugModeEnabled = true
        settings.showPerformanceMetrics = true
        settings.showAccuracyMetrics = true
        settings.showAlgorithmParameters = true
        
        // Conservative settings for performance
        settings.showLandmarksOverlay = false
        settings.showBufferVisualization = false
        #else
        // Production: all debug features disabled
        settings.disableAllFeatures()
        #endif
        
        return settings
    }
    
    /// Quick setup for accuracy testing
    static func setupAccuracyTesting(debugSettings: DebugSettings) {
        debugSettings.enableAllFeatures()
        debugSettings.showLandmarksOverlay = true
        debugSettings.showLandmarkLabels = true
        debugSettings.landmarkPointSize = 3.0
        debugSettings.landmarkOpacity = 0.9
    }
    
    /// Quick setup for performance testing
    static func setupPerformanceTesting(debugSettings: DebugSettings) {
        debugSettings.disableAllFeatures()
        debugSettings.isDebugModeEnabled = true
        debugSettings.showPerformanceMetrics = true
        debugSettings.updateInterval = 0.5 // Slower updates for performance testing
    }
    
    /// Validate debug system configuration
    static func validateConfiguration(debugSettings: DebugSettings) -> [String] {
        var warnings: [String] = []
        
        if debugSettings.isDebugModeEnabled {
            if debugSettings.updateInterval < 0.05 {
                warnings.append("Update interval too frequent, may impact performance")
            }
            
            if debugSettings.showLandmarksOverlay && debugSettings.landmarkPointSize > 5.0 {
                warnings.append("Large landmark points may obscure camera view")
            }
            
            if debugSettings.enableRealTimeUpdates && debugSettings.updateInterval < 0.1 {
                warnings.append("Real-time updates with high frequency may cause UI lag")
            }
        }
        
        return warnings
    }
}

// MARK: - Debug Constants

enum DebugConstants {
    // Performance targets
    static let targetFPS: Double = 15.0
    static let maxProcessingTime: TimeInterval = 0.1 // 100ms
    static let minAccuracyThreshold: Double = 0.7 // 70%
    
    // UI configuration
    static let debugPanelWidth: CGFloat = 300
    static let debugPanelMaxHeight: CGFloat = 400
    static let quickToggleButtonSize: CGFloat = 20
    
    // Visualization settings
    static let landmarkTrailDuration: TimeInterval = 2.0
    static let bufferHistorySize: Int = 60
    static let metricUpdateInterval: TimeInterval = 0.1
    
    // Colors
    static let performanceGoodColor = Color.green
    static let performanceWarningColor = Color.orange
    static let performancePoorColor = Color.red
    
    // Export settings
    static let maxExportDataSize: Int = 1024 * 1024 // 1MB
    static let exportDateFormat = "yyyy-MM-dd_HH-mm-ss"
}

// MARK: - Debug Metrics Calculator

struct DebugMetricsCalculator {
    
    /// Calculate performance score (0-100)
    static func calculatePerformanceScore(
        fps: Double,
        processingTime: TimeInterval,
        memoryUsage: Double
    ) -> Double {
        let fpsScore = min(fps / DebugConstants.targetFPS, 1.0) * 40 // 40 points max
        let timeScore = max(0, (1.0 - processingTime / DebugConstants.maxProcessingTime)) * 40 // 40 points max
        let memoryScore = max(0, (1.0 - memoryUsage / 100.0)) * 20 // 20 points max, assuming 100MB baseline
        
        return (fpsScore + timeScore + memoryScore) * 100 / 100
    }
    
    /// Calculate accuracy confidence level
    static func calculateAccuracyConfidence(
        iou: Double,
        jitter: Double,
        trackingFailures: Int
    ) -> Double {
        let iouScore = iou * 60 // 60 points max
        let jitterScore = max(0, (1.0 - jitter * 20)) * 30 // 30 points max, penalize jitter
        let failureScore = max(0, (1.0 - Double(trackingFailures) / 10.0)) * 10 // 10 points max
        
        return min(100, iouScore + jitterScore + failureScore)
    }
}

// MARK: - Usage Examples

#if DEBUG
struct DebugUsageExamples {
    
    // Example 1: Basic debug setup
    static func basicDebugSetup() -> some View {
        let debugSettings = DebugIntegrationHelpers.setupDebugEnvironment()
        
        return DebugEnabledContentView()
            .environmentObject(debugSettings)
    }
    
    // Example 2: Accuracy testing setup
    static func accuracyTestingSetup() -> some View {
        let debugSettings = DebugSettings()
        DebugIntegrationHelpers.setupAccuracyTesting(debugSettings: debugSettings)
        
        return DebugEnabledContentView()
            .environmentObject(debugSettings)
    }
    
    // Example 3: Performance testing setup
    static func performanceTestingSetup() -> some View {
        let debugSettings = DebugSettings()
        DebugIntegrationHelpers.setupPerformanceTesting(debugSettings: debugSettings)
        
        return DebugEnabledContentView()
            .environmentObject(debugSettings)
    }
}
#endif