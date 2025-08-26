import SwiftUI
import Combine
import AVFoundation

// MARK: - Reactive Content View with Optimized State Management
struct ReactiveContentView: View {
    @StateObject private var cameraService = CameraService()
    @StateObject private var visionService = PerformanceOptimizedVisionService()
    @StateObject private var videoService = ReactiveVideoService()
    @StateObject private var videoSelectionService: VideoSelectionService
    @StateObject private var performanceMonitor = PerformanceMonitor()
    
    @State private var showingSettings = false
    @State private var manualOverride = false
    @State private var currentDetectionStatus = "분석 중..."
    
    // Performance metrics display
    @State private var showPerformanceMetrics = true
    
    // Reactive pipeline
    private let stateUpdateSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let videoService = ReactiveVideoService()
        _videoService = StateObject(wrappedValue: videoService)
        _videoSelectionService = StateObject(wrappedValue: VideoSelectionService(videoService: videoService))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Camera View (40%)
                cameraSection(geometry: geometry)
                
                // Performance Metrics Bar
                if showPerformanceMetrics {
                    performanceMetricsBar
                }
                
                // Status Bar
                statusBarSection(geometry: geometry)
                
                // Video View (remaining space)
                videoSection(geometry: geometry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .onAppear(perform: setupOptimizedPipeline)
        .onDisappear(perform: teardownPipeline)
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                videoSelectionService: videoSelectionService,
                videoService: videoService,
                visionService: visionService,
                isPresented: $showingSettings
            )
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func cameraSection(geometry: GeometryProxy) -> some View {
        ZStack {
            CameraView(cameraService: cameraService)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            
            // Real-time detection overlay
            if showPerformanceMetrics {
                VStack {
                    HStack {
                        Spacer()
                        DetectionOverlay(visionService: visionService)
                            .padding()
                    }
                    Spacer()
                }
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height * 0.4)
    }
    
    @ViewBuilder
    private func statusBarSection(geometry: GeometryProxy) -> some View {
        ZStack {
            Rectangle()
                .fill(statusBarGradient)
                .frame(maxWidth: .infinity)
            
            HStack(spacing: 12) {
                // Status indicator with animation
                StatusIndicator(
                    status: currentDetectionStatus,
                    isEating: visionService.isEating || manualOverride
                )
                
                Spacer()
                
                // Quick controls
                QuickControlsBar(
                    sensitivity: $visionService.sensitivity,
                    manualOverride: $manualOverride,
                    onSettingsTap: { showingSettings = true }
                )
            }
            .padding(.horizontal, 16)
        }
        .frame(width: geometry.size.width, height: 60)
    }
    
    @ViewBuilder
    private func videoSection(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottom) {
            VideoPlayerView(
                videoService: videoService,
                videoSelectionService: videoSelectionService
            )
            .environmentObject(visionService)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Optimized control panel
            OptimizedStatusBar(
                visionService: visionService,
                videoService: videoService,
                videoSelectionService: videoSelectionService,
                manualOverride: $manualOverride
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(width: geometry.size.width, 
               height: geometry.size.height - (geometry.size.height * 0.4) - 60 - (showPerformanceMetrics ? 40 : 0))
    }
    
    // MARK: - Performance Metrics Bar
    
    @ViewBuilder
    private var performanceMetricsBar: some View {
        HStack(spacing: 16) {
            MetricBadge(
                label: "FPS",
                value: String(format: "%.0f", visionService.metrics.fps),
                color: visionService.metrics.fps >= 14 ? .green : .orange
            )
            
            MetricBadge(
                label: "처리",
                value: String(format: "%.0fms", visionService.metrics.processingTimeMs),
                color: visionService.metrics.processingTimeMs < 100 ? .green : .orange
            )
            
            MetricBadge(
                label: "지연",
                value: String(format: "%.0fms", visionService.metrics.actionLatencyMs),
                color: visionService.metrics.actionLatencyMs < 200 ? .green : .orange
            )
            
            MetricBadge(
                label: "메모리",
                value: String(format: "%.0fMB", performanceMonitor.memoryUsageMB),
                color: performanceMonitor.memoryUsageMB < 100 ? .green : .orange
            )
            
            Spacer()
            
            Button(action: { showPerformanceMetrics.toggle() }) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
        .frame(height: 40)
    }
    
    private var statusBarGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                getStatusColor().opacity(0.8),
                getStatusColor()
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Optimized Pipeline Setup
    
    private func setupOptimizedPipeline() {
        print("[ReactiveContentView] 🚀 Setting up optimized pipeline")
        
        // Configure camera service
        cameraService.delegate = visionService
        
        // Start services
        cameraService.startSession()
        visionService.startTracking()
        
        // Setup direct eating state to video control pipeline
        visionService.onEatingStateChanged = { [weak videoService, weak self] isEating in
            guard let videoService = videoService,
                  let self = self,
                  !self.manualOverride else { return }
            
            // Direct video control with minimal latency
            DispatchQueue.main.async {
                if isEating {
                    videoService.playVideoImmediate()
                } else {
                    videoService.pauseVideoImmediate()
                }
            }
        }
        
        // Setup performance monitoring
        performanceMonitor.startMonitoring()
        performanceMonitor.onMetricsUpdated = { [weak self] metrics in
            // Update UI with performance metrics
            DispatchQueue.main.async {
                self?.updateDetectionStatus()
            }
        }
    }
    
    private func teardownPipeline() {
        print("[ReactiveContentView] 🛑 Tearing down pipeline")
        
        performanceMonitor.stopMonitoring()
        visionService.stopTracking()
        cameraService.stopSession()
        visionService.onEatingStateChanged = nil
    }
    
    // MARK: - Helper Methods
    
    private func updateDetectionStatus() {
        if manualOverride {
            currentDetectionStatus = "수동 제어 중 🎮"
        } else if visionService.isEating {
            let latency = visionService.metrics.actionLatencyMs
            if latency < 100 {
                currentDetectionStatus = "식사 중! ⚡️ \(Int(latency))ms"
            } else if latency < 200 {
                currentDetectionStatus = "식사 중! 🍽️ \(Int(latency))ms"
            } else {
                currentDetectionStatus = "식사 중! 🍽️"
            }
        } else {
            currentDetectionStatus = "밥을 더 먹어보세요 😊"
        }
    }
    
    private func getStatusColor() -> Color {
        if manualOverride {
            return .purple
        } else if visionService.isEating {
            return visionService.metrics.actionLatencyMs < 200 ? .green : .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Sub-components

struct MetricBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct StatusIndicator: View {
    let status: String
    let isEating: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isEating ? .green : .orange)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .fill(isEating ? .green : .orange)
                        .scaleEffect(isEating ? 1.5 : 1.0)
                        .opacity(isEating ? 0.3 : 0.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                 value: isEating)
                )
            
            Text(status)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

struct QuickControlsBar: View {
    @Binding var sensitivity: Float
    @Binding var manualOverride: Bool
    let onSettingsTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Sensitivity slider
            VStack(spacing: 2) {
                Text("민감도")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                
                Slider(value: $sensitivity, in: 0.1...1.0, step: 0.1)
                    .frame(width: 80)
                    .accentColor(.white)
                
                Text("\(Int(sensitivity * 100))%")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Manual override toggle
            Button(action: {
                withAnimation(.spring(response: 0.2)) {
                    manualOverride.toggle()
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }) {
                Image(systemName: manualOverride ? "hand.raised.fill" : "hand.raised")
                    .font(.title2)
                    .foregroundColor(.white)
                    .scaleEffect(manualOverride ? 1.2 : 1.0)
            }
            
            // Settings button
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct DetectionOverlay: View {
    @ObservedObject var visionService: PerformanceOptimizedVisionService
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if visionService.isEating {
                Label("Eating", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
            }
            
            Text("Latency: \(Int(visionService.metrics.detectionLatencyMs))ms")
                .font(.caption2)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
        }
    }
}

struct OptimizedStatusBar: View {
    @ObservedObject var visionService: PerformanceOptimizedVisionService
    @ObservedObject var videoService: ReactiveVideoService
    @ObservedObject var videoSelectionService: VideoSelectionService
    @Binding var manualOverride: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Eating indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(visionService.isEating || manualOverride ? .green : .red)
                    .frame(width: 10, height: 10)
                
                Text(visionService.isEating || manualOverride ? "식사 중" : "대기 중")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Performance indicator
            if visionService.metrics.actionLatencyMs < 200 {
                Label("\(Int(visionService.metrics.actionLatencyMs))ms", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            // Manual override button
            Button(action: {
                manualOverride.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Image(systemName: manualOverride ? "hand.raised.fill" : "hand.raised")
                    .foregroundColor(manualOverride ? .purple : .white)
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}