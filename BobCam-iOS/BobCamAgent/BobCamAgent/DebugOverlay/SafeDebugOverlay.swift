//
//  SafeDebugOverlay.swift
//  BobCam
//
//  PHASE 3: Safe replacement for problematic debug overlay features
//

import SwiftUI
import Vision

/// Safe debug overlay that replaces crash-prone landmarks visualization
struct SafeDebugOverlay: View {
    @ObservedObject var visionService: VisionService
    @ObservedObject var debugSettings: DebugSettings
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                // Safe debug panel (bottom-right corner)
                VStack(alignment: .trailing, spacing: 8) {
                    // System status indicator
                    if debugSettings.isDebugModeEnabled {
                        systemStatusView
                    }
                    
                    // Debug controls
                    debugControlsView
                }
                .padding()
            }
        }
    }
    
    // MARK: - Safe Debug Components
    
    private var systemStatusView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(systemHealthColor)
                    .frame(width: 8, height: 8)
                Text("System")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            
            Text(systemHealthText)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    private var debugControlsView: some View {
        VStack(spacing: 4) {
            // Memory usage indicator
            HStack(spacing: 4) {
                Image(systemName: "memorychip.fill")
                    .font(.caption2)
                    .foregroundColor(memoryUsageColor)
                Text("\(memoryUsageText)MB")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            
            // Landmarks overlay status (disabled)
            Button(action: {
                showLandmarksDisabledAlert()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "mouth.fill")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("Landmarks")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // Performance metrics toggle
            Button(action: {
                debugSettings.showPerformanceMetrics.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: debugSettings.showPerformanceMetrics ? "speedometer" : "speedometer")
                        .font(.caption2)
                        .foregroundColor(debugSettings.showPerformanceMetrics ? .green : .white)
                    Text("Metrics")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
        )
    }
    
    // MARK: - System Health Properties
    
    private var systemHealthColor: Color {
        if CrashPrevention.shouldDisableLandmarksOverlay() {
            return .red
        }
        
        let thermalState = ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .critical:
            return .red
        case .serious:
            return .orange
        case .fair:
            return .yellow
        case .nominal:
            return .green
        @unknown default:
            return .gray
        }
    }
    
    private var systemHealthText: String {
        if CrashPrevention.shouldDisableLandmarksOverlay() {
            return "Protected"
        }
        
        let thermalState = ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .critical:
            return "Critical"
        case .serious:
            return "Warning"
        case .fair:
            return "Fair"
        case .nominal:
            return "Good"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var memoryUsageColor: Color {
        let usage = getMemoryUsage()
        if usage > 200 {
            return .red
        } else if usage > 150 {
            return .orange
        } else if usage > 100 {
            return .yellow
        }
        return .green
    }
    
    private var memoryUsageText: String {
        return String(format: "%.0f", getMemoryUsage())
    }
    
    private func getMemoryUsage() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(taskInfo.resident_size) / 1024.0 / 1024.0
        }
        return 0.0
    }
    
    // MARK: - Actions
    
    private func showLandmarksDisabledAlert() {
        print("ℹ️ [SafeDebugOverlay] Landmarks overlay disabled for stability")
        
        // In a real implementation, this would show an alert
        // For now, just log the reason
        let reason = CrashPrevention.shouldDisableLandmarksOverlay() ? 
            "Landmarks overlay has been disabled to prevent app crashes. This feature is experimental and can cause instability." :
            "Landmarks overlay is available but not currently enabled."
        
        print("Reason: \(reason)")
    }
}

// MARK: - Performance Metrics Overlay

struct SafePerformanceMetricsView: View {
    @ObservedObject var visionService: VisionService
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // FPS indicator
                    HStack(spacing: 4) {
                        Text("FPS:")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        Text("15")  // Vision service runs at 15fps
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    
                    // Eating detection status
                    HStack(spacing: 4) {
                        Text("Eating:")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        Circle()
                            .fill(visionService.isEating ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                    }
                    
                    // Face detection status
                    HStack(spacing: 4) {
                        Text("Face:")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        Circle()
                            .fill(visionService.isFaceDetected ? Color.blue : Color.gray)
                            .frame(width: 6, height: 6)
                    }
                    
                    // Service state
                    HStack(spacing: 4) {
                        Text("State:")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        Text(serviceStateText)
                            .font(.caption2)
                            .foregroundColor(serviceStateColor)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.8))
                )
                .padding()
            }
            
            Spacer()
        }
    }
    
    private var serviceStateText: String {
        switch visionService.serviceState {
        case .idle:
            return "Idle"
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        case .failed:
            return "Failed"
        case .cameraError:
            return "Camera Error"
        }
    }
    
    private var serviceStateColor: Color {
        switch visionService.serviceState {
        case .idle:
            return .gray
        case .running:
            return .green
        case .paused:
            return .orange
        case .failed, .cameraError:
            return .red
        }
    }
}

// MARK: - Safe Debugging Information View

struct SafeDebuggingInfoView: View {
    let title: String
    let isEnabled: Bool
    let reason: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isEnabled ? .green : .red)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            if !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SafeDebugOverlay(
        visionService: VisionService(),
        debugSettings: DebugSettings()
    )
    .background(Color.black)
}