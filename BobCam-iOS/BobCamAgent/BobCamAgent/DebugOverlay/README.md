# BobCam Debug Overlay System

A comprehensive real-time debug and visualization system for the BobCam lip detection algorithm, designed to help achieve the target 70% accuracy through systematic parameter tuning and performance monitoring.

## 🎯 Overview

The debug overlay system provides developers and testers with real-time insights into the lip detection algorithm's performance, accuracy, and internal state. It enables data-driven optimization of algorithm parameters and provides visual feedback for algorithm development.

## 🏗️ Architecture

### Core Components

```
DebugOverlay/
├── DebugOverlayView.swift           # Main debug UI panel
├── DebugSettings.swift              # Settings and configuration management
├── LandmarksOverlayView.swift       # Real-time landmark visualization
├── DebugCameraView.swift            # Enhanced camera view with overlays
├── ContentView+Debug.swift          # Debug-enabled ContentView
├── DebugIntegrationGuide.swift      # Integration helpers and documentation
└── README.md                        # This file
```

### System Design

- **Minimal Performance Impact**: <5ms overhead per frame
- **Thread-Safe**: All UI updates on main thread
- **Memory Efficient**: Circular buffers prevent memory leaks
- **Configurable**: Granular control over debug features
- **Persistent**: Settings saved via UserDefaults

## 🚀 Quick Start

### 1. Enable Debug Mode

Replace your existing ContentView with the debug-enabled version:

```swift
// In your App.swift or main ContentView
#if DEBUG
DebugContentView()
#else
ContentView()
#endif
```

### 2. Basic Usage

1. **Tap the bug icon** (🐛) in the top-right corner to enable debug mode
2. **Use quick toggles**: P (Performance), A (Accuracy), T (Parameters), B (Buffer), L (Landmarks)
3. **Expand the panel** for detailed controls and metrics
4. **Adjust parameters** in real-time using sliders

### 3. Essential Debug Features

- **Performance Monitoring**: Real-time FPS and processing time
- **Accuracy Metrics**: IoU values, jitter measurements, tracking failures
- **Landmark Visualization**: See exactly what the algorithm detects
- **Parameter Tuning**: Live adjustment of detection sensitivity
- **Buffer Analysis**: Visualize eating pattern detection over time

## 📊 Debug Features

### Performance Metrics
- **FPS Counter**: Monitor frame rate (target: 15fps)
- **Processing Time**: Track algorithm latency (target: <100ms)
- **Memory Usage**: Monitor memory consumption
- **Color-coded indicators**: Green (good), Orange (warning), Red (poor)

### Accuracy Monitoring
- **IoU (Intersection over Union)**: Measure detection accuracy
- **Jitter**: Track landmark stability
- **Tracking Failures**: Count detection failures
- **Real-time feedback**: Immediate response to parameter changes

### Landmark Visualization
- **Lip Landmarks**: Real-time overlay of detected lip points
- **Algorithm Points**: Key points used in distance calculation
- **Movement Trails**: Historical visualization of lip movement
- **Measurement Lines**: Visual indication of calculated distances

### Parameter Control
- **Sensitivity Slider**: Real-time adjustment (0.1 - 1.0)
- **Configuration Display**: View current algorithm parameters
- **Live Updates**: Immediate effect of parameter changes
- **Performance Impact**: Monitor parameter adjustment effects

### Buffer Visualization
- **Distance History**: Graph of lip distance over time
- **Pattern Detection**: Visual indication of eating patterns
- **EMA Smoothing**: Effect of smoothing on raw data
- **Timeline**: 60-sample rolling history

## 🛠️ Integration Guide

### Method 1: Drop-in Replacement

```swift
// Replace existing ContentView usage
ContentView() 

// With debug-enabled version
DebugContentView()
```

### Method 2: Conditional Integration

```swift
@main
struct BobCamApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            DebugContentView()
            #else
            ContentView()
            #endif
        }
    }
}
```

### Method 3: Feature Flag Control

```swift
struct MyContentView: View {
    @AppStorage("debug_enabled") private var debugEnabled = false
    
    var body: some View {
        if debugEnabled {
            DebugContentView()
        } else {
            ContentView()
        }
    }
}
```

## 🎮 Usage Scenarios

### Accuracy Tuning Workflow

1. **Enable all debug features**:
   ```swift
   debugSettings.enableAllFeatures()
   ```

2. **Monitor key metrics**:
   - IoU > 0.7 (70% accuracy target)
   - Jitter < 0.01 (stability)
   - Processing time < 100ms

3. **Adjust parameters systematically**:
   - Start with sensitivity = 0.5
   - Adjust in 0.1 increments
   - Monitor real-time accuracy feedback

4. **Document optimal settings**:
   ```swift
   let report = debugSettings.generateDebugReport()
   ```

### Performance Testing Workflow

1. **Performance-only mode**:
   ```swift
   debugSettings.setupPerformanceTesting(debugSettings: debugSettings)
   ```

2. **Monitor critical metrics**:
   - FPS consistency (target: 15fps)
   - Processing time distribution
   - Memory usage stability

3. **Test on different devices**:
   - iPhone models with different capabilities
   - Various iOS versions
   - Different lighting conditions

### Algorithm Development Workflow

1. **Enable landmark visualization**:
   ```swift
   debugSettings.showLandmarksOverlay = true
   debugSettings.showLandmarkLabels = true
   ```

2. **Analyze detection quality**:
   - Verify landmark accuracy
   - Check algorithm-specific points
   - Monitor distance calculations

3. **Iterate and validate**:
   - Adjust algorithm parameters
   - Test edge cases
   - Validate improvements

## 🎛️ Configuration Options

### Landmark Visualization
```swift
debugSettings.landmarkPointSize = 3.0      // 1.0-10.0
debugSettings.landmarkLineWidth = 1.5      // 0.5-5.0
debugSettings.landmarkOpacity = 0.8        // 0.1-1.0
debugSettings.showLandmarkLabels = true    // Show point indices
```

### Performance Settings
```swift
debugSettings.updateInterval = 0.1         // 0.05-2.0 seconds
debugSettings.enableRealTimeUpdates = true // Real-time vs batched
```

### Debug Panel
```swift
debugSettings.showPerformanceMetrics = true
debugSettings.showAccuracyMetrics = true
debugSettings.showAlgorithmParameters = true
debugSettings.showBufferVisualization = true
```

## 📈 Performance Impact

The debug system is designed for minimal performance impact:

| Feature | Overhead | Notes |
|---------|----------|--------|
| Performance Metrics | <1ms | Lightweight calculations |
| Accuracy Monitoring | <2ms | Depends on IoU calculations |
| Landmark Overlay | 2-5ms | Core Graphics rendering |
| Buffer Visualization | <1ms | Simple line charts |
| Parameter UI | <1ms | SwiftUI updates |

**Total Target**: <10ms overhead (maintaining 15fps target)

## 🔧 Troubleshooting

### Common Issues

**High Processing Time (>100ms)**
- Solution: Disable landmark visualization temporarily
- Check: Memory pressure, background apps
- Monitor: CPU usage patterns

**Low FPS (<10fps)**
- Solution: Reduce debug feature complexity
- Check: Update intervals, UI responsiveness
- Monitor: Main thread blocking

**Poor Detection Accuracy (<50%)**
- Solution: Adjust sensitivity and thresholds
- Check: Lighting conditions, camera distance
- Monitor: Landmark stability and quality

**UI Lag or Freezing**
- Solution: Reduce update frequency
- Check: Main thread usage
- Monitor: Memory allocations

### Debug Console Output

Enable detailed logging for troubleshooting:

```
[DEBUG] Vision: 15.2ms, FPS: 14.1, Memory: 45.2MB
[DEBUG] Accuracy: IoU=0.856, Jitter=0.023, Failures=0
[DEBUG] Algorithm: eating=true, confidence=0.78
[DEBUG] Config: sensitivity=0.5, threshold=0.15
```

## 🧪 Testing Guidelines

### Unit Testing Debug Components

```swift
func testDebugSettingsConfiguration() {
    let settings = DebugSettings()
    settings.enableAllFeatures()
    
    XCTAssertTrue(settings.isDebugModeEnabled)
    XCTAssertTrue(settings.showPerformanceMetrics)
    // ... additional assertions
}

func testPerformanceMetricsCalculation() {
    let score = DebugMetricsCalculator.calculatePerformanceScore(
        fps: 15.0,
        processingTime: 0.08,
        memoryUsage: 50.0
    )
    
    XCTAssertGreaterThan(score, 70.0) // Expect good performance score
}
```

### Integration Testing

```swift
func testDebugOverlayIntegration() {
    let visionService = VisionService()
    let debugSettings = DebugSettings()
    
    // Test landmark updates
    visionService.updateDebugLandmarks(mockLandmarks, faceObservation: mockFace)
    let (landmarks, face) = visionService.getCurrentLandmarksForDebug()
    
    XCTAssertNotNil(landmarks)
    XCTAssertNotNil(face)
}
```

## 🔮 Future Enhancements

### Planned Features
- [ ] A/B testing framework integration
- [ ] Machine learning parameter optimization
- [ ] Remote debugging capabilities
- [ ] Advanced visualization modes (3D landmarks)
- [ ] Performance regression detection
- [ ] Automated accuracy benchmarking
- [ ] Export to external analysis tools

### Research Integration
- [ ] Integration with research data collection
- [ ] Academic paper visualization tools
- [ ] Statistical analysis dashboard
- [ ] Comparative algorithm testing

## 📝 API Reference

### DebugSettings

```swift
class DebugSettings: ObservableObject {
    @Published var isDebugModeEnabled: Bool
    @Published var showPerformanceMetrics: Bool
    @Published var showAccuracyMetrics: Bool
    @Published var showAlgorithmParameters: Bool
    @Published var showBufferVisualization: Bool
    @Published var showLandmarksOverlay: Bool
    
    func enableAllFeatures()
    func disableAllFeatures()
    func resetToDefaults()
    func generateDebugReport() -> String
}
```

### DebugIntegrationHelpers

```swift
struct DebugIntegrationHelpers {
    static func setupDebugEnvironment() -> DebugSettings
    static func setupAccuracyTesting(debugSettings: DebugSettings)
    static func setupPerformanceTesting(debugSettings: DebugSettings)
    static func validateConfiguration(debugSettings: DebugSettings) -> [String]
}
```

### VisionService Debug Extensions

```swift
extension VisionService {
    func updateDebugLandmarks(_ landmarks: VNFaceLandmarks2D?, faceObservation: VNFaceObservation?)
    func getCurrentLandmarksForDebug() -> (VNFaceLandmarks2D?, VNFaceObservation?)
}
```

## 🤝 Contributing

### Adding New Debug Features

1. **Create the UI component** in the DebugOverlay directory
2. **Add settings toggle** in DebugSettings
3. **Integrate with main overlay** in DebugOverlayView
4. **Update documentation** and usage examples
5. **Add unit tests** for new functionality

### Code Style Guidelines

- Follow Swift API design guidelines
- Use meaningful variable names
- Add comprehensive documentation
- Maintain thread safety
- Optimize for performance

## 📄 License

Part of the BobCam project. See the main project LICENSE for details.

---

**Built for Phase 2 Algorithm Accuracy Improvement**  
Target: 70% detection accuracy through systematic parameter optimization