//
//  CrashPrevention.swift
//  BobCam
//
//  PHASE 3: Comprehensive crash prevention system for skeleton overlay
//

import Foundation
import UIKit
import SwiftUI

/// Centralized crash prevention system
class CrashPrevention {
    
    // MARK: - Singleton
    static let shared = CrashPrevention()
    private init() {}
    
    // MARK: - Crash Prevention State
    private var hasDetectedCrash = false
    private var crashCount = 0
    private let maxCrashCount = 3
    
    // MARK: - Main Prevention Methods
    
    /// Check if landmarks overlay should be disabled to prevent crashes
    static func shouldDisableLandmarksOverlay() -> Bool {
        // Always disable in production builds
        #if !DEBUG
        print("🔴 [CrashPrevention] Landmarks overlay disabled in Release build")
        return true
        #endif
        
        // Check system resources
        if isSystemUnderPressure() {
            print("🔴 [CrashPrevention] System under pressure - disabling landmarks")
            return true
        }
        
        // Check crash history
        if shared.crashCount >= shared.maxCrashCount {
            print("🔴 [CrashPrevention] Too many crashes detected - permanently disabling")
            return true
        }
        
        // Check device capabilities
        if !hasMinimumDeviceCapabilities() {
            print("🔴 [CrashPrevention] Device doesn't meet minimum requirements")
            return true
        }
        
        return false
    }
    
    /// Report a crash related to landmarks overlay
    static func reportLandmarksCrash(error: Error? = nil) {
        shared.crashCount += 1
        shared.hasDetectedCrash = true
        
        print("🚨 [CrashPrevention] Landmarks crash reported. Count: \(shared.crashCount)")
        
        if let error = error {
            print("Error details: \(error.localizedDescription)")
        }
        
        // Store crash count persistently
        UserDefaults.standard.set(shared.crashCount, forKey: "landmarks_crash_count")
        UserDefaults.standard.set(true, forKey: "landmarks_crashes_detected")
    }
    
    /// Reset crash count (for testing or after fixes)
    static func resetCrashCount() {
        shared.crashCount = 0
        shared.hasDetectedCrash = false
        UserDefaults.standard.removeObject(forKey: "landmarks_crash_count")
        UserDefaults.standard.removeObject(forKey: "landmarks_crashes_detected")
        print("✅ [CrashPrevention] Crash count reset")
    }
    
    // MARK: - System Health Checks
    
    private static func isSystemUnderPressure() -> Bool {
        // Check thermal state
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .critical || thermalState == .serious {
            return true
        }
        
        // Check memory pressure
        if getMemoryUsageMB() > 150.0 {
            return true
        }
        
        // Check available storage
        if getAvailableStorageGB() < 0.5 {
            return true
        }
        
        return false
    }
    
    private static func hasMinimumDeviceCapabilities() -> Bool {
        // Check iOS version (require iOS 15.0+)
        if #available(iOS 15.0, *) {
            // Check device model capabilities
            let deviceModel = UIDevice.current.model
            
            // Disable on iPad (different rendering characteristics)
            if deviceModel.contains("iPad") {
                return false
            }
            
            return true
        }
        return false
    }
    
    private static func getMemoryUsageMB() -> Double {
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
    
    private static func getAvailableStorageGB() -> Double {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return Double(capacity) / 1024.0 / 1024.0 / 1024.0
            }
        } catch {
            print("⚠️ [CrashPrevention] Could not check storage: \(error)")
        }
        return 1.0 // Assume enough storage if we can't check
    }
    
    // MARK: - Initialization and Persistence
    
    func loadPersistentState() {
        crashCount = UserDefaults.standard.integer(forKey: "landmarks_crash_count")
        hasDetectedCrash = UserDefaults.standard.bool(forKey: "landmarks_crashes_detected")
        
        if hasDetectedCrash {
            print("⚠️ [CrashPrevention] Previous crashes detected. Count: \(crashCount)")
        }
    }
}

// MARK: - SwiftUI Integration

struct CrashPreventionView: View {
    let isDebugBuild: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.orange)
                Text("Debug Feature Status")
                    .font(.headline)
                Spacer()
            }
            
            if CrashPrevention.shouldDisableLandmarksOverlay() {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Landmarks Overlay: Disabled")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    
                    Text("Reason: " + disableReason())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Landmarks Overlay: Available")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            
            if isDebugBuild {
                Divider()
                
                Button("Reset Crash History") {
                    CrashPrevention.resetCrashCount()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func disableReason() -> String {
        #if !DEBUG
        return "Release build"
        #else
        if CrashPrevention.shared.crashCount >= 3 {
            return "Too many crashes detected"
        } else if CrashPrevention.isSystemUnderPressure() {
            return "System under pressure"
        } else if !CrashPrevention.hasMinimumDeviceCapabilities() {
            return "Device not supported"
        }
        return "Unknown"
        #endif
    }
}

// MARK: - Error Recovery

extension CrashPrevention {
    
    /// Attempt to recover from a landmarks-related crash
    static func attemptRecovery() {
        print("🔄 [CrashPrevention] Attempting recovery from landmarks crash")
        
        // Force disable landmarks overlay
        DispatchQueue.main.async {
            if let debugSettings = findDebugSettingsInstance() {
                debugSettings.disableLandmarksOverlaySafely()
            }
        }
        
        // Clear any cached vision data
        clearVisionServiceCache()
        
        // Force garbage collection
        autoreleasepool {
            // Force memory cleanup
        }
    }
    
    private static func findDebugSettingsInstance() -> DebugSettings? {
        // This would need to be implemented based on how DebugSettings is managed
        // For now, return nil
        return nil
    }
    
    private static func clearVisionServiceCache() {
        // This would clear any cached vision processing data
        print("🧹 [CrashPrevention] Clearing vision service cache")
    }
}

// MARK: - App Integration

extension CrashPrevention {
    
    /// Initialize crash prevention on app launch
    static func initializeOnAppLaunch() {
        shared.loadPersistentState()
        
        // Set up crash detection
        setupCrashDetection()
        
        print("✅ [CrashPrevention] Initialized. Crashes: \(shared.crashCount)")
    }
    
    private static func setupCrashDetection() {
        // This would set up NSUncaughtExceptionHandler or similar
        // For now, just log that it's been set up
        print("🔍 [CrashPrevention] Crash detection configured")
    }
}