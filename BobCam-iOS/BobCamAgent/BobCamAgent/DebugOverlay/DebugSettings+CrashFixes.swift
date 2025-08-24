//
//  DebugSettings+CrashFixes.swift
//  BobCam
//
//  PHASE 3: Extensions to DebugSettings for crash prevention
//

import Foundation
import SwiftUI

// MARK: - Crash Prevention Extensions

extension DebugSettings {
    
    /// Safely enable landmarks overlay with system validation
    func enableLandmarksOverlaySafely() -> Bool {
        // Check device capabilities and system state
        if !canSafelyEnableOverlay() {
            print("⚠️ [DebugSettings] System not suitable for landmarks overlay")
            showLandmarksOverlay = false
            return false
        }
        
        print("✅ [DebugSettings] Enabling landmarks overlay with safety checks")
        showLandmarksOverlay = true
        return true
    }
    
    /// Disable landmarks overlay and clean up resources
    func disableLandmarksOverlaySafely() {
        print("🔴 [DebugSettings] Disabling landmarks overlay")
        showLandmarksOverlay = false
        
        // Force UI update on main thread
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    /// Check if system can safely enable landmark overlay
    private func canSafelyEnableOverlay() -> Bool {
        // Check memory pressure
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .critical || thermalState == .serious {
            logError(.memoryPressure, 
                    message: "High thermal state: \(thermalState)", 
                    severity: .warning)
            return false
        }
        
        // Check available memory (basic check)
        let memoryUsage = getMemoryUsage()
        if memoryUsage > 200.0 { // More than 200MB
            logError(.memoryPressure, 
                    message: "High memory usage: \(memoryUsage)MB", 
                    severity: .warning)
            return false
        }
        
        return true
    }
    
    /// Get current memory usage in MB
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
    
    /// Force disable all potentially problematic debug features
    func enableEmergencyMode() {
        print("🚨 [DebugSettings] Enabling emergency mode - disabling all overlays")
        
        showLandmarksOverlay = false
        showBufferVisualization = false
        enableRealTimeUpdates = false
        
        // Reduce update frequency
        updateInterval = 0.5 // 2Hz instead of 10Hz
        
        logError(.visionFrameworkError, 
                message: "Emergency mode enabled", 
                severity: .critical)
    }
}

// MARK: - Settings View Integration

extension DebugSettings {
    
    /// Create a safe toggle for landmarks overlay in settings
    func createSafeLandmarksToggle() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Landmarks Overlay (Experimental)", isOn: Binding(
                    get: { self.showLandmarksOverlay },
                    set: { newValue in
                        if newValue {
                            if !self.enableLandmarksOverlaySafely() {
                                // Show alert about system limitations
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.showSystemLimitationAlert()
                                }
                            }
                        } else {
                            self.disableLandmarksOverlaySafely()
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
            
            if showLandmarksOverlay {
                Text("⚠️ May impact performance or cause instability")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.leading, 4)
            }
            
            // System status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(systemStatusColor)
                    .frame(width: 8, height: 8)
                Text(systemStatusText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 4)
        }
    }
    
    private var systemStatusColor: Color {
        if !canSafelyEnableOverlay() {
            return .red
        }
        return systemHealthStatus == .healthy ? .green : .yellow
    }
    
    private var systemStatusText: String {
        if !canSafelyEnableOverlay() {
            return "System under pressure"
        }
        return systemHealthStatus.description
    }
    
    private func showSystemLimitationAlert() {
        // This would need to be handled by the parent view
        print("🚨 [DebugSettings] System limitation alert should be shown")
    }
}

// MARK: - Automatic Safety Monitoring

extension DebugSettings {
    
    /// Start monitoring system health and auto-disable features if needed
    func startSafetyMonitoring() {
        // Monitor thermal state changes
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleThermalStateChange()
        }
        
        // Monitor memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleThermalStateChange() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .critical:
            enableEmergencyMode()
        case .serious:
            if showLandmarksOverlay {
                disableLandmarksOverlaySafely()
            }
        case .fair, .nominal:
            break
        @unknown default:
            break
        }
        
        logError(.memoryPressure, 
                message: "Thermal state changed to: \(thermalState)", 
                severity: thermalState == .critical ? .critical : .warning)
    }
    
    private func handleMemoryWarning() {
        print("⚠️ [DebugSettings] Memory warning received")
        
        if showLandmarksOverlay {
            disableLandmarksOverlaySafely()
            logError(.memoryPressure, 
                    message: "Disabled landmarks overlay due to memory warning", 
                    severity: .warning)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}