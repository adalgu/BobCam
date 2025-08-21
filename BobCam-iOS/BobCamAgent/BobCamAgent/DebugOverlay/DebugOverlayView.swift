//
//  DebugOverlayView.swift
//  BobCam
//
//  Debug UI overlay system for real-time algorithm visualization and parameter tuning
//

import SwiftUI
import Vision
import Combine

/// Main debug overlay view that combines all debug components
struct DebugOverlayView: View {
    @ObservedObject var visionService: VisionService
    @ObservedObject var debugSettings: DebugSettings
    @State private var isExpanded = false
    
    var body: some View {
        ZStack {
            // Main debug panel
            if debugSettings.isDebugModeEnabled {
                debugPanel
                    .animation(.easeInOut(duration: 0.3), value: isExpanded)
            }
            
            // Debug toggle button (always visible in debug builds)
            VStack {
                HStack {
                    Spacer()
                    debugToggleButton
                }
                Spacer()
            }
            .padding()
        }
    }
    
    private var debugToggleButton: some View {
        Button(action: {
            debugSettings.isDebugModeEnabled.toggle()
        }) {
            Image(systemName: debugSettings.isDebugModeEnabled ? "bug.fill" : "bug")
                .font(.system(size: 16))
                .foregroundColor(debugSettings.isDebugModeEnabled ? .green : .gray)
                .padding(8)
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
        }
    }
    
    private var debugPanel: some View {
        VStack(spacing: 0) {
            HStack {
                // Expand/Collapse button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                }
                
                Text("Debug Panel")
                    .foregroundColor(.white)
                    .font(.caption.bold())
                
                Spacer()
                
                // Quick toggle buttons
                debugQuickToggles
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            
            if isExpanded {
                ScrollView {
                    VStack(spacing: 8) {
                        // Performance metrics
                        if debugSettings.showPerformanceMetrics {
                            PerformanceMetricsView(
                                performanceMetrics: visionService.currentPerformance
                            )
                        }
                        
                        // Accuracy metrics
                        if debugSettings.showAccuracyMetrics {
                            AccuracyMetricsView(
                                accuracyMetrics: visionService.currentAccuracy
                            )
                        }
                        
                        // Algorithm parameters
                        if debugSettings.showAlgorithmParameters {
                            AlgorithmParametersView(
                                visionService: visionService,
                                debugSettings: debugSettings
                            )
                        }
                        
                        // Buffer visualization
                        if debugSettings.showBufferVisualization {
                            BufferVisualizationView(
                                visionService: visionService
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .background(Color.black.opacity(0.7))
                .frame(maxHeight: 300)
            }
        }
        .cornerRadius(12)
        .padding(.top, 50) // Avoid status bar
        .padding(.horizontal, 8)
    }
    
    private var debugQuickToggles: some View {
        HStack(spacing: 6) {
            ForEach(DebugToggle.allCases, id: \.self) { toggle in
                Button(action: {
                    debugSettings.toggle(toggle)
                }) {
                    Text(toggle.abbreviation)
                        .font(.caption2.bold())
                        .foregroundColor(debugSettings.isEnabled(toggle) ? .green : .gray)
                        .frame(width: 20, height: 20)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
    }
}

/// Quick toggle options for debug features
enum DebugToggle: CaseIterable {
    case performance
    case accuracy
    case parameters
    case buffer
    case landmarks
    
    var abbreviation: String {
        switch self {
        case .performance: return "P"
        case .accuracy: return "A"
        case .parameters: return "T"
        case .buffer: return "B"
        case .landmarks: return "L"
        }
    }
    
    var fullName: String {
        switch self {
        case .performance: return "Performance"
        case .accuracy: return "Accuracy"
        case .parameters: return "Parameters"
        case .buffer: return "Buffer"
        case .landmarks: return "Landmarks"
        }
    }
}

// MARK: - Performance Metrics View
struct PerformanceMetricsView: View {
    let performanceMetrics: PerformanceMetrics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("Performance")
                    .foregroundColor(.white)
                    .font(.caption.bold())
                Spacer()
            }
            
            if let metrics = performanceMetrics {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FPS: \(String(format: "%.1f", metrics.framesPerSecond))")
                            .foregroundColor(fpsColor(metrics.framesPerSecond))
                            .font(.caption2)
                        
                        Text("Processing: \(String(format: "%.1f ms", metrics.processingTime))")
                            .foregroundColor(processingTimeColor(metrics.processingTime))
                            .font(.caption2)
                    }
                    
                    Spacer()
                    
                    // FPS gauge
                    CircularProgressView(
                        progress: min(metrics.framesPerSecond / 15.0, 1.0),
                        lineWidth: 3,
                        size: 30,
                        color: fpsColor(metrics.framesPerSecond)
                    )
                }
            } else {
                Text("No data")
                    .foregroundColor(.gray)
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
    
    private func fpsColor(_ fps: Double) -> Color {
        if fps >= 12 { return .green }
        if fps >= 8 { return .orange }
        return .red
    }
    
    private func processingTimeColor(_ time: TimeInterval) -> Color {
        if time <= 50 { return .green }  // Good: ≤50ms
        if time <= 100 { return .orange } // Fair: ≤100ms
        return .red  // Poor: >100ms
    }
}

// MARK: - Accuracy Metrics View
struct AccuracyMetricsView: View {
    let accuracyMetrics: AccuracyMetrics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Accuracy")
                    .foregroundColor(.white)
                    .font(.caption.bold())
                Spacer()
            }
            
            if let metrics = accuracyMetrics {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("IoU: \(String(format: "%.3f", metrics.intersectionOverUnion))")
                            .foregroundColor(iouColor(metrics.intersectionOverUnion))
                            .font(.caption2)
                        
                        Spacer()
                        
                        CircularProgressView(
                            progress: metrics.intersectionOverUnion,
                            lineWidth: 3,
                            size: 25,
                            color: iouColor(metrics.intersectionOverUnion)
                        )
                    }
                    
                    Text("Jitter: \(String(format: "%.4f", metrics.jitter))")
                        .foregroundColor(jitterColor(metrics.jitter))
                        .font(.caption2)
                    
                    Text("Failures: \(metrics.trackingFailures)")
                        .foregroundColor(metrics.trackingFailures > 0 ? .red : .green)
                        .font(.caption2)
                }
            } else {
                Text("No data")
                    .foregroundColor(.gray)
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
    
    private func iouColor(_ iou: Double) -> Color {
        if iou >= 0.7 { return .green }
        if iou >= 0.5 { return .orange }
        return .red
    }
    
    private func jitterColor(_ jitter: Double) -> Color {
        if jitter <= 0.01 { return .green }
        if jitter <= 0.05 { return .orange }
        return .red
    }
}

// MARK: - Algorithm Parameters View
struct AlgorithmParametersView: View {
    @ObservedObject var visionService: VisionService
    @ObservedObject var debugSettings: DebugSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.purple)
                    .font(.caption)
                Text("Parameters")
                    .foregroundColor(.white)
                    .font(.caption.bold())
                Spacer()
            }
            
            VStack(spacing: 6) {
                // Sensitivity slider
                parameterSlider(
                    title: "Sensitivity",
                    value: $visionService.sensitivity,
                    range: 0.1...1.0,
                    format: "%.2f"
                )
                
                // Live configuration values (read-only display)
                configurationDisplay
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
    
    private func parameterSlider(
        title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                    .font(.caption2)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .foregroundColor(.cyan)
                    .font(.caption2.bold())
            }
            
            Slider(value: value, in: range)
                .accentColor(.cyan)
                .frame(height: 20)
        }
    }
    
    private var configurationDisplay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Configuration (read-only):")
                .foregroundColor(.gray)
                .font(.caption2)
            
            Group {
                Text("History: \(debugSettings.currentConfiguration.historySize)")
                Text("Min Movement: \(String(format: "%.3f", debugSettings.currentConfiguration.minMovementThreshold))")
                Text("Eating Threshold: \(String(format: "%.3f", debugSettings.currentConfiguration.eatingPatternThreshold))")
                Text("Variance: \(String(format: "%.4f", debugSettings.currentConfiguration.varianceThreshold))")
                Text("EMA Alpha: \(String(format: "%.2f", debugSettings.currentConfiguration.emaAlpha))")
            }
            .foregroundColor(.gray)
            .font(.caption2)
        }
    }
}

// MARK: - Buffer Visualization View
struct BufferVisualizationView: View {
    @ObservedObject var visionService: VisionService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("Lip Distance History")
                    .foregroundColor(.white)
                    .font(.caption.bold())
                Spacer()
            }
            
            // Simple line chart placeholder
            BufferChartView()
                .frame(height: 60)
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Buffer Chart View (Simplified Line Chart)
struct BufferChartView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                Path { path in
                    let stepX = geometry.size.width / 10
                    let stepY = geometry.size.height / 4
                    
                    for i in 0...10 {
                        path.move(to: CGPoint(x: stepX * CGFloat(i), y: 0))
                        path.addLine(to: CGPoint(x: stepX * CGFloat(i), y: geometry.size.height))
                    }
                    
                    for i in 0...4 {
                        path.move(to: CGPoint(x: 0, y: stepY * CGFloat(i)))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: stepY * CGFloat(i)))
                    }
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                
                // Sample data line (placeholder)
                Path { path in
                    let points: [CGFloat] = [0.1, 0.2, 0.4, 0.3, 0.6, 0.5, 0.7, 0.4, 0.2, 0.1]
                    let stepX = geometry.size.width / CGFloat(points.count - 1)
                    
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * (1 - points[0])))
                    
                    for (index, point) in points.enumerated() {
                        let x = stepX * CGFloat(index)
                        let y = geometry.size.height * (1 - point)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.orange, lineWidth: 2)
                
                // Current eating state indicator
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .position(x: geometry.size.width - 10, y: geometry.size.height * 0.3)
            }
        }
        .background(Color.black.opacity(0.2))
        .cornerRadius(4)
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        DebugOverlayView(
            visionService: VisionService(),
            debugSettings: DebugSettings()
        )
    }
}