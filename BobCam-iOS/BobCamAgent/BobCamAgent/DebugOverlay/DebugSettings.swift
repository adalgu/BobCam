//
//  DebugSettings.swift
//  BobCam
//
//  Debug settings and state management for the debug overlay system
//

import Foundation
import Combine
import UIKit

// MARK: - Supporting Types

enum SystemHealthStatus {
    case healthy
    case warning
    case critical
    case failure
    
    var color: UIColor {
        switch self {
        case .healthy: return .systemGreen
        case .warning: return .systemYellow  
        case .critical: return .systemOrange
        case .failure: return .systemRed
        }
    }
    
    var description: String {
        switch self {
        case .healthy: return "System Healthy"
        case .warning: return "Performance Issues"
        case .critical: return "Critical Issues"
        case .failure: return "System Failure"
        }
    }
}

struct VisionSystemError {
    let timestamp: Date
    let type: ErrorType
    let message: String
    let severity: Severity
    
    enum ErrorType {
        case memoryPressure
        case frameProcessingFailure
        case landmarkExtractionError
        case threadSafetyViolation
        case visionFrameworkError
        case cameraConnectionError
        
        var icon: String {
            switch self {
            case .memoryPressure: return "memorychip.fill"
            case .frameProcessingFailure: return "camera.fill"
            case .landmarkExtractionError: return "face.dashed.fill"
            case .threadSafetyViolation: return "exclamationmark.triangle.fill"
            case .visionFrameworkError: return "eye.fill"
            case .cameraConnectionError: return "video.slash.fill"
            }
        }
    }
    
    enum Severity: Int, CaseIterable {
        case info = 0
        case warning = 1
        case error = 2
        case critical = 3
        
        var color: UIColor {
            switch self {
            case .info: return .systemBlue
            case .warning: return .systemYellow
            case .error: return .systemOrange  
            case .critical: return .systemRed
            }
        }
    }
}

/// Debug settings manager for controlling visibility and behavior of debug features
class DebugSettings: ObservableObject {

    // MARK: - Published Properties
    @Published var isDebugModeEnabled: Bool = false
    @Published var showPerformanceMetrics: Bool = true
    @Published var showAccuracyMetrics: Bool = true
    @Published var showAlgorithmParameters: Bool = true
    @Published var showBufferVisualization: Bool = true
    @Published var showLandmarksOverlay: Bool = false

    // MARK: - Landmark Visualization Settings
    @Published var landmarkPointSize: CGFloat = 2.0
    @Published var landmarkLineWidth: CGFloat = 1.0
    @Published var showLandmarkLabels: Bool = false
    @Published var landmarkOpacity: Double = 0.8

    // MARK: - Performance Settings
    @Published var updateInterval: TimeInterval = 0.1 // 10Hz updates for debug UI
    @Published var enableRealTimeUpdates: Bool = true

    // MARK: - Configuration Access
    var currentConfiguration: LipDetectionConfiguration = .default
    
    // MARK: - Exception Logging & Monitoring
    @Published var enableExceptionLogging: Bool = true
    @Published var enableMemoryMonitoring: Bool = true
    @Published var enableThreadSafetyValidation: Bool = true
    @Published var exceptionCount: Int = 0
    @Published var lastExceptionMessage: String = ""
    @Published var lastExceptionTime: Date?
    
    // System health tracking
    @Published var systemHealthStatus: SystemHealthStatus = .healthy
    @Published var visionSystemErrors: [VisionSystemError] = []

    // MARK: - Color Schemes
    enum DebugColorScheme: String, CaseIterable {
        case dark = "dark"
        case light = "light"
        case highContrast = "high_contrast"

        var displayName: String {
            switch self {
            case .dark: return "Dark"
            case .light: return "Light"
            case .highContrast: return "High Contrast"
            }
        }
    }

    @Published var colorScheme: DebugColorScheme = .dark

    // MARK: - Initialization
    init() {
        // Load settings from UserDefaults if available
        loadSettings()

        // Set up auto-save when settings change
        setupAutoSave()
    }

    // MARK: - Public Methods

    /// Toggle specific debug features
    func toggle(_ debugToggle: DebugToggle) {
        switch debugToggle {
        case .performance:
            showPerformanceMetrics.toggle()
        case .accuracy:
            showAccuracyMetrics.toggle()
        case .parameters:
            showAlgorithmParameters.toggle()
        case .buffer:
            showBufferVisualization.toggle()
        case .landmarks:
            showLandmarksOverlay.toggle()
        }
    }

    /// Check if specific debug feature is enabled
    func isEnabled(_ debugToggle: DebugToggle) -> Bool {
        switch debugToggle {
        case .performance:
            return showPerformanceMetrics
        case .accuracy:
            return showAccuracyMetrics
        case .parameters:
            return showAlgorithmParameters
        case .buffer:
            return showBufferVisualization
        case .landmarks:
            return showLandmarksOverlay
        }
    }

    /// Reset all debug settings to defaults
    func resetToDefaults() {
        isDebugModeEnabled = false
        showPerformanceMetrics = true
        showAccuracyMetrics = true
        showAlgorithmParameters = true
        showBufferVisualization = true
        showLandmarksOverlay = false

        landmarkPointSize = 2.0
        landmarkLineWidth = 1.0
        showLandmarkLabels = false
        landmarkOpacity = 0.8

        updateInterval = 0.1
        enableRealTimeUpdates = true
        colorScheme = .dark

        saveSettings()
    }

    /// Enable all debug features (useful for comprehensive testing)
    func enableAllFeatures() {
        showPerformanceMetrics = true
        showAccuracyMetrics = true
        showAlgorithmParameters = true
        showBufferVisualization = true
        showLandmarksOverlay = true
        isDebugModeEnabled = true
    }

    /// Disable all debug features (performance mode)
    func disableAllFeatures() {
        showPerformanceMetrics = false
        showAccuracyMetrics = false
        showAlgorithmParameters = false
        showBufferVisualization = false
        showLandmarksOverlay = false
        isDebugModeEnabled = false
    }

    /// Update configuration (called from VisionService)
    func updateConfiguration(_ config: LipDetectionConfiguration) {
        currentConfiguration = config
    }
    
    /// Log a vision system error
    func logError(_ type: VisionSystemError.ErrorType, message: String, severity: VisionSystemError.Severity = .warning) {
        guard enableExceptionLogging else { return }
        
        let error = VisionSystemError(
            timestamp: Date(),
            type: type,
            message: message,
            severity: severity
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.visionSystemErrors.append(error)
            
            // Keep only last 50 errors
            if let self = self, self.visionSystemErrors.count > 50 {
                self.visionSystemErrors.removeFirst(self.visionSystemErrors.count - 50)
            }
            
            // Update exception count and last message
            self?.exceptionCount += 1
            self?.lastExceptionMessage = message
            self?.lastExceptionTime = Date()
            
            // Update system health status
            self?.updateSystemHealthStatus()
        }
        
        print("🔍 [VisionSystem] \(severity) - \(type): \(message)")
    }
    
    /// Log thread safety violation
    func logThreadSafetyViolation(_ message: String) {
        guard enableThreadSafetyValidation else { return }
        logError(.threadSafetyViolation, message: message, severity: .error)
    }
    
    /// Log memory pressure event
    func logMemoryPressure(_ level: String, details: String = "") {
        guard enableMemoryMonitoring else { return }
        let message = "Memory pressure: \(level)" + (details.isEmpty ? "" : " - \(details)")
        logError(.memoryPressure, message: message, severity: .warning)
    }
    
    /// Update system health status based on recent errors
    private func updateSystemHealthStatus() {
        let recentErrors = visionSystemErrors.filter { 
            $0.timestamp.timeIntervalSinceNow > -300 // Last 5 minutes
        }
        
        let criticalErrors = recentErrors.filter { $0.severity == .critical }
        let errors = recentErrors.filter { $0.severity == .error }
        let warnings = recentErrors.filter { $0.severity == .warning }
        
        if !criticalErrors.isEmpty {
            systemHealthStatus = .failure
        } else if errors.count >= 3 {
            systemHealthStatus = .critical
        } else if warnings.count >= 5 {
            systemHealthStatus = .warning
        } else {
            systemHealthStatus = .healthy
        }
    }
    
    /// Clear old errors (older than 1 hour)
    func cleanupOldErrors() {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        visionSystemErrors.removeAll { $0.timestamp < oneHourAgo }
        updateSystemHealthStatus()
    }

    // MARK: - Private Methods

    private func setupAutoSave() {
        // Save settings whenever they change
        $isDebugModeEnabled
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $showPerformanceMetrics
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $showAccuracyMetrics
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $showAlgorithmParameters
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $showBufferVisualization
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)

        $showLandmarksOverlay
            .dropFirst()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard

        isDebugModeEnabled = defaults.bool(forKey: "debug_mode_enabled")
        showPerformanceMetrics = defaults.object(forKey: "show_performance_metrics") as? Bool ?? true
        showAccuracyMetrics = defaults.object(forKey: "show_accuracy_metrics") as? Bool ?? true
        showAlgorithmParameters = defaults.object(forKey: "show_algorithm_parameters") as? Bool ?? true
        showBufferVisualization = defaults.object(forKey: "show_buffer_visualization") as? Bool ?? true
        showLandmarksOverlay = defaults.bool(forKey: "show_landmarks_overlay")

        landmarkPointSize = CGFloat(defaults.double(forKey: "landmark_point_size"))
        if landmarkPointSize == 0 { landmarkPointSize = 2.0 }

        landmarkLineWidth = CGFloat(defaults.double(forKey: "landmark_line_width"))
        if landmarkLineWidth == 0 { landmarkLineWidth = 1.0 }

        showLandmarkLabels = defaults.bool(forKey: "show_landmark_labels")

        landmarkOpacity = defaults.double(forKey: "landmark_opacity")
        if landmarkOpacity == 0 { landmarkOpacity = 0.8 }

        updateInterval = defaults.double(forKey: "update_interval")
        if updateInterval == 0 { updateInterval = 0.1 }

        enableRealTimeUpdates = defaults.object(forKey: "enable_real_time_updates") as? Bool ?? true

        if let colorSchemeString = defaults.string(forKey: "color_scheme"),
           let scheme = DebugColorScheme(rawValue: colorSchemeString) {
            colorScheme = scheme
        }
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard

        defaults.set(isDebugModeEnabled, forKey: "debug_mode_enabled")
        defaults.set(showPerformanceMetrics, forKey: "show_performance_metrics")
        defaults.set(showAccuracyMetrics, forKey: "show_accuracy_metrics")
        defaults.set(showAlgorithmParameters, forKey: "show_algorithm_parameters")
        defaults.set(showBufferVisualization, forKey: "show_buffer_visualization")
        defaults.set(showLandmarksOverlay, forKey: "show_landmarks_overlay")

        defaults.set(Double(landmarkPointSize), forKey: "landmark_point_size")
        defaults.set(Double(landmarkLineWidth), forKey: "landmark_line_width")
        defaults.set(showLandmarkLabels, forKey: "show_landmark_labels")
        defaults.set(landmarkOpacity, forKey: "landmark_opacity")

        defaults.set(updateInterval, forKey: "update_interval")
        defaults.set(enableRealTimeUpdates, forKey: "enable_real_time_updates")
        defaults.set(colorScheme.rawValue, forKey: "color_scheme")
    }

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Debug Performance Profiler
class DebugPerformanceProfiler: ObservableObject {

    // MARK: - Published Properties
    @Published var frameProcessingTimes: [TimeInterval] = []
    @Published var memoryUsage: Double = 0.0
    @Published var cpuUsage: Double = 0.0

    // MARK: - Properties
    private let maxHistorySize = 60  // 1 minute at 1fps
    private var lastMemoryCheck = Date()
    private let memoryCheckInterval: TimeInterval = 1.0

    // MARK: - Public Methods

    func recordFrameProcessingTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.frameProcessingTimes.append(time)
            if self.frameProcessingTimes.count > self.maxHistorySize {
                self.frameProcessingTimes.removeFirst()
            }

            // Update memory usage periodically
            let now = Date()
            if now.timeIntervalSince(self.lastMemoryCheck) >= self.memoryCheckInterval {
                self.updateSystemMetrics()
                self.lastMemoryCheck = now
            }
        }
    }

    var averageFrameTime: TimeInterval {
        guard !frameProcessingTimes.isEmpty else { return 0 }
        return frameProcessingTimes.reduce(0, +) / Double(frameProcessingTimes.count)
    }

    var maxFrameTime: TimeInterval {
        frameProcessingTimes.max() ?? 0
    }

    var minFrameTime: TimeInterval {
        frameProcessingTimes.min() ?? 0
    }

    // MARK: - Private Methods

    private func updateSystemMetrics() {
        // Update memory usage
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let memoryUsageMB = Double(taskInfo.resident_size) / 1024.0 / 1024.0
            DispatchQueue.main.async { [weak self] in
                self?.memoryUsage = memoryUsageMB
            }
        }

        // CPU usage would require more complex implementation
        // For now, we'll use a placeholder
        DispatchQueue.main.async { [weak self] in
            self?.cpuUsage = Double.random(in: 10...30) // Placeholder
        }
    }
}

// MARK: - Debug Data Export
extension DebugSettings {

    /// Export debug session data for analysis
    func exportDebugData() -> [String: Any] {
        return [
            "timestamp": Date().timeIntervalSince1970,
            "configuration": [
                "historySize": currentConfiguration.historySize,
                "minMovementThreshold": currentConfiguration.minMovementThreshold,
                "eatingPatternThreshold": currentConfiguration.eatingPatternThreshold,
                "varianceThreshold": currentConfiguration.varianceThreshold,
                "emaAlpha": currentConfiguration.emaAlpha
            ],
            "debug_settings": [
                "debug_mode_enabled": isDebugModeEnabled,
                "show_performance_metrics": showPerformanceMetrics,
                "show_accuracy_metrics": showAccuracyMetrics,
                "show_algorithm_parameters": showAlgorithmParameters,
                "show_buffer_visualization": showBufferVisualization,
                "show_landmarks_overlay": showLandmarksOverlay
            ]
        ]
    }

    /// Generate debug report string
    func generateDebugReport() -> String {
        let data = exportDebugData()
        let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        return String(data: jsonData ?? Data(), encoding: .utf8) ?? "Error generating report"
    }
}
