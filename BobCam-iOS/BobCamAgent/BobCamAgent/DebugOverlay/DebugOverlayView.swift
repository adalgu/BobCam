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
                    debugToggleButtons
                }
                Spacer()
            }
            .padding()
        }
    }

    private var debugToggleButtons: some View {
        HStack(spacing: 8) {
            // Lip overlay quick toggle (visible even when debug panel collapsed)
            Button(action: {
                debugSettings.showLandmarksOverlay.toggle()
            }) {
                Image(systemName: debugSettings.showLandmarksOverlay ? "mouth.fill" : "mouth")
                    .font(.system(size: 14))
                    .foregroundColor(debugSettings.showLandmarksOverlay ? .yellow : .white)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }

            // Main debug mode toggle
            Button(action: {
                debugSettings.isDebugModeEnabled.toggle()
            }) {
                Image(systemName: debugSettings.isDebugModeEnabled ? "ladybug.fill" : "ladybug")
                    .font(.system(size: 16))
                    .foregroundColor(debugSettings.isDebugModeEnabled ? .green : .gray)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
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
                                jitter: visionService.jitter,
                                processingTimeMs: visionService.processingTimeMs,
                                fps: visionService.fps,
                                memoryMB: visionService.memoryMB,
                                peakMemoryMB: visionService.peakMemoryMB
                            )
                        }

                        // Accuracy metrics
                        if debugSettings.showAccuracyMetrics {
                            AccuracyMetricsView(
                                jitter: visionService.jitter
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
    let jitter: Double
    let processingTimeMs: Double
    let fps: Double
    let memoryMB: Double
    let peakMemoryMB: Double
    
    @State private var crashDetected = false
    @State private var lastUpdateTime = Date()
    @State private var frameDropCount = 0
    @State private var lastFrameCount: Double = 0

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
                
                // System health indicators
                systemHealthIndicators
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jitter: \(String(format: "%.4f", jitter))")
                        .foregroundColor(jitterColor(jitter))
                        .font(.caption2)
                    Text("Proc: \(String(format: "%.1f ms", processingTimeMs))")
                        .foregroundColor(procColor(processingTimeMs))
                        .font(.caption2)
                    Text("FPS: \(String(format: "%.1f", fps))")
                        .foregroundColor(fpsColor(fps))
                        .font(.caption2)
                    
                    HStack {
                        Text("Mem: \(String(format: "%.1f MB", memoryMB))")
                            .foregroundColor(memoryColor(memoryMB, peak: peakMemoryMB))
                            .font(.caption2)
                        
                        // Memory pressure indicator
                        if memoryPressureLevel != .normal {
                            memoryPressureIndicator
                        }
                    }
                    
                    // Frame drop indicator
                    if frameDropCount > 0 {
                        Text("Dropped: \(frameDropCount) frames")
                            .foregroundColor(.red)
                            .font(.caption2)
                    }
                    
                    // Exception/crash indicator
                    if crashDetected {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            Text("Exception detected")
                                .foregroundColor(.red)
                                .font(.caption2)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(8)
        .background(backgroundColorForHealth)
        .cornerRadius(8)
        .onAppear {
            setupCrashDetection()
        }
        .onChange(of: fps) { newFPS in
            detectFrameDrops(newFPS: newFPS)
        }
    }
    
    private var systemHealthIndicators: some View {
        HStack(spacing: 4) {
            // CPU health
            Circle()
                .fill(cpuHealthColor)
                .frame(width: 8, height: 8)
            
            // Memory health  
            Circle()
                .fill(memoryHealthColor)
                .frame(width: 8, height: 8)
                
            // Vision system health
            Circle()
                .fill(visionHealthColor)
                .frame(width: 8, height: 8)
        }
    }
    
    private var memoryPressureIndicator: some View {
        Text(memoryPressureLevel.symbol)
            .foregroundColor(.red)
            .font(.caption2)
    }
    
    private var memoryPressureLevel: MemoryPressureLevel {
        let pressure = ProcessInfo.processInfo.thermalState
        switch pressure {
        case .nominal: return .normal
        case .fair: return .moderate  
        case .serious: return .high
        case .critical: return .critical
        @unknown default: return .unknown
        }
    }
    
    private enum MemoryPressureLevel {
        case normal, moderate, high, critical, unknown
        
        var symbol: String {
            switch self {
            case .normal: return ""
            case .moderate: return "⚠️"
            case .high: return "🔶"  
            case .critical: return "🔴"
            case .unknown: return "❓"
            }
        }
    }
    
    private var backgroundColorForHealth: Color {
        if crashDetected {
            return Color.red.opacity(0.2)
        } else if memoryPressureLevel == .critical {
            return Color.orange.opacity(0.2)
        } else {
            return Color.black.opacity(0.3)
        }
    }
    
    private var cpuHealthColor: Color {
        if processingTimeMs > 100 { return .red }
        if processingTimeMs > 50 { return .orange }
        return .green
    }
    
    private var memoryHealthColor: Color {
        switch memoryPressureLevel {
        case .normal: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        case .unknown: return .gray
        }
    }
    
    private var visionHealthColor: Color {
        if fps < 8 { return .red }
        if fps < 12 { return .orange }  
        if jitter > 0.05 { return .yellow }
        return .green
    }
    
    private func setupCrashDetection() {
        // Monitor for NSException and EXC_BAD_ACCESS
        signal(SIGABRT) { _ in
            DispatchQueue.main.async {
                // This won't actually execute in a crash, but shows the intent
            }
        }
    }
    
    private func detectFrameDrops(newFPS: Double) {
        let currentTime = Date()
        let timeDelta = currentTime.timeIntervalSince(lastUpdateTime)
        
        if timeDelta > 0.5 { // Check every 500ms
            let expectedFrames = timeDelta * 15.0 // Target 15fps
            let actualFrames = newFPS * timeDelta
            let droppedFrames = max(0, expectedFrames - actualFrames)
            
            if droppedFrames > 2 {
                frameDropCount = Int(droppedFrames)
                // Clear counter after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    frameDropCount = 0
                }
            }
            
            lastUpdateTime = currentTime
            lastFrameCount = newFPS
        }
    }

    private func jitterColor(_ jitter: Double) -> Color {
        if jitter <= 0.01 { return .green }
        if jitter <= 0.05 { return .orange }
        return .red
    }

    private func procColor(_ ms: Double) -> Color {
        if ms <= 50 { return .green }
        if ms <= 100 { return .orange }
        return .red
    }

    private func fpsColor(_ value: Double) -> Color {
        if value >= 15 { return .green }
        if value >= 12 { return .orange }
        return .red
    }
    
    private func memoryColor(_ current: Double, peak: Double) -> Color {
        let memoryIncrease = current / max(peak, 1.0)
        if current > 100 { return .red }      // Over 100MB
        if current > 50 { return .orange }    // Over 50MB
        if memoryIncrease > 0.8 { return .yellow } // Near peak
        return .cyan
    }
}

// MARK: - Accuracy Metrics View
struct AccuracyMetricsView: View {
    let jitter: Double

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

            VStack(alignment: .leading, spacing: 2) {
                Text("Jitter: \(String(format: "%.4f", jitter))")
                    .foregroundColor(jitterColor(jitter))
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
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
