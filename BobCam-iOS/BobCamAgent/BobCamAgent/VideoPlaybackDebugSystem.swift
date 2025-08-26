import Foundation
import AVFoundation
import Combine
import SwiftUI

// MARK: - Enhanced Debug Logging System for Video Playback

/**
 * Comprehensive debug logging system for video playback monitoring
 * 
 * FEATURES:
 * - Real-time state monitoring
 * - Performance metrics tracking
 * - Error logging with context
 * - AVFoundation integration
 * - Visual debug overlay
 * - Export capabilities for debugging
 */

// MARK: - Debug Configuration
struct VideoPlaybackDebugConfig {
    let enableConsoleLogging: Bool
    let enableFileLogging: Bool
    let enableVisualOverlay: Bool
    let enablePerformanceMetrics: Bool
    let logLevel: DebugLogLevel
    
    static let development = VideoPlaybackDebugConfig(
        enableConsoleLogging: true,
        enableFileLogging: true,
        enableVisualOverlay: true,
        enablePerformanceMetrics: true,
        logLevel: .verbose
    )
    
    static let production = VideoPlaybackDebugConfig(
        enableConsoleLogging: false,
        enableFileLogging: true,
        enableVisualOverlay: false,
        enablePerformanceMetrics: false,
        logLevel: .error
    )
}

enum DebugLogLevel: Int, CaseIterable {
    case verbose = 0
    case info = 1
    case warning = 2
    case error = 3
    
    var emoji: String {
        switch self {
        case .verbose: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    var name: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}

// MARK: - Debug Log Entry
struct VideoDebugLogEntry {
    let timestamp: Date
    let level: DebugLogLevel
    let category: String
    let message: String
    let context: [String: Any]?
    let performanceMetrics: VideoPerformanceMetrics?
    
    var formattedMessage: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeString = formatter.string(from: timestamp)
        
        var logMessage = "[\(timeString)] \(level.emoji) \(category): \(message)"
        
        if let context = context, !context.isEmpty {
            let contextString = context.map { "\($0)=\($1)" }.joined(separator: ", ")
            logMessage += " | Context: \(contextString)"
        }
        
        if let metrics = performanceMetrics {
            logMessage += " | Metrics: \(metrics.summary)"
        }
        
        return logMessage
    }
}

// MARK: - Performance Metrics
struct VideoPerformanceMetrics {
    let responseTime: TimeInterval?
    let memoryUsage: Int64?
    let cpuUsage: Double?
    let frameDrops: Int?
    
    var summary: String {
        var components: [String] = []
        
        if let responseTime = responseTime {
            components.append("RT: \(Int(responseTime * 1000))ms")
        }
        
        if let memoryUsage = memoryUsage {
            components.append("Mem: \(memoryUsage / 1024 / 1024)MB")
        }
        
        if let cpuUsage = cpuUsage {
            components.append("CPU: \(Int(cpuUsage))%")
        }
        
        if let frameDrops = frameDrops {
            components.append("Drops: \(frameDrops)")
        }
        
        return components.joined(separator: ", ")
    }
}

// MARK: - Enhanced Debug Logger
class VideoPlaybackDebugLogger: ObservableObject {
    
    // MARK: - Published Properties for UI
    @Published var isEnabled: Bool = false
    @Published var currentLogs: [VideoDebugLogEntry] = []
    @Published var performanceMetrics: VideoPerformanceMetrics?
    @Published var connectionStatus: AVPlayerConnectionStatus = .unknown
    
    // MARK: - Private Properties
    private let config: VideoPlaybackDebugConfig
    private var logQueue = DispatchQueue(label: "VideoDebugLogger", qos: .utility)
    private var fileHandle: FileHandle?
    private var logFileURL: URL?
    private var performanceTimer: Timer?
    private var lastLogTime: Date = Date()
    
    // Performance tracking
    private var commandStartTimes: [String: Date] = [:]
    private var stateTransitionTimes: [PlaybackState: Date] = [:]
    
    // MARK: - Initialization
    init(config: VideoPlaybackDebugConfig = .development) {
        self.config = config
        self.isEnabled = config.enableConsoleLogging || config.enableFileLogging
        
        setupFileLogging()
        setupPerformanceMonitoring()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Logging Methods
    
    func logVideoAssetLoading(url: URL, context: String = "") {
        guard shouldLog(.info) else { return }
        
        let startTime = Date()
        commandStartTimes["asset_loading"] = startTime
        
        log(level: .info,
            category: "ASSET_LOADING",
            message: "Loading video asset: \(url.lastPathComponent)",
            context: ["url": url.absoluteString, "context": context])
    }
    
    func logVideoAssetLoadComplete(url: URL, success: Bool, error: Error? = nil) {
        guard shouldLog(.info) else { return }
        
        var metrics: VideoPerformanceMetrics?
        if let startTime = commandStartTimes["asset_loading"] {
            let responseTime = Date().timeIntervalSince(startTime)
            metrics = VideoPerformanceMetrics(responseTime: responseTime, memoryUsage: nil, cpuUsage: nil, frameDrops: nil)
            commandStartTimes.removeValue(forKey: "asset_loading")
        }
        
        let level: DebugLogLevel = success ? .info : .error
        let status = success ? "SUCCESS" : "FAILED"
        
        var context: [String: Any] = ["url": url.lastPathComponent, "status": status]
        if let error = error {
            context["error"] = error.localizedDescription
        }
        
        log(level: level,
            category: "ASSET_LOADING",
            message: "Asset loading \(status.lowercased()): \(url.lastPathComponent)",
            context: context,
            performanceMetrics: metrics)
    }
    
    func logAVPlayerStateChange(from oldState: AVPlayer.Status, to newState: AVPlayer.Status, player: AVPlayer) {
        guard shouldLog(.verbose) else { return }
        
        let context: [String: Any] = [
            "oldState": oldState.debugDescription,
            "newState": newState.debugDescription,
            "playerRate": player.rate,
            "playerError": player.error?.localizedDescription ?? "none"
        ]
        
        log(level: .verbose,
            category: "AVPLAYER_STATE",
            message: "AVPlayer status changed: \(oldState.debugDescription) → \(newState.debugDescription)",
            context: context)
    }
    
    func logPlaybackCommand(_ command: String, expectedState: PlaybackState, context: String = "") {
        guard shouldLog(.info) else { return }
        
        let startTime = Date()
        commandStartTimes[command] = startTime
        
        log(level: .info,
            category: "PLAYBACK_COMMAND",
            message: "Executing \(command) command",
            context: ["expectedState": expectedState.debugDescription, "context": context])
    }
    
    func logPlaybackStateTransition(from oldState: PlaybackState, to newState: PlaybackState, triggeredBy: String = "unknown") {
        guard shouldLog(.info) else { return }
        
        // Track transition timing
        let transitionTime = Date()
        stateTransitionTimes[newState] = transitionTime
        
        // Calculate command response time if applicable
        var metrics: VideoPerformanceMetrics?
        let possibleCommands = ["play", "pause", "stop", "load"]
        
        for command in possibleCommands {
            if let startTime = commandStartTimes[command] {
                let responseTime = transitionTime.timeIntervalSince(startTime)
                metrics = VideoPerformanceMetrics(responseTime: responseTime, memoryUsage: nil, cpuUsage: nil, frameDrops: nil)
                commandStartTimes.removeValue(forKey: command)
                break
            }
        }
        
        let level: DebugLogLevel = newState.isError ? .error : .info
        
        log(level: level,
            category: "STATE_TRANSITION",
            message: "Playback state transition: \(oldState.debugDescription) → \(newState.debugDescription)",
            context: ["triggeredBy": triggeredBy, "transitionTime": transitionTime.timeIntervalSince1970],
            performanceMetrics: metrics)
    }
    
    func logEatingDetectionTrigger(isEating: Bool, confidence: Double, consecutiveFrames: Int) {
        guard shouldLog(.info) else { return }
        
        log(level: .info,
            category: "EATING_DETECTION",
            message: "Eating detection trigger: \(isEating ? "EATING" : "NOT_EATING")",
            context: [
                "confidence": confidence,
                "consecutiveFrames": consecutiveFrames,
                "timestamp": Date().timeIntervalSince1970
            ])
    }
    
    func logVideoSelectionResult(videoType: VideoType?, success: Bool, error: Error? = nil) {
        guard shouldLog(.info) else { return }
        
        let level: DebugLogLevel = success ? .info : .error
        let videoDescription = videoType?.displayName ?? "none"
        
        var context: [String: Any] = ["videoType": videoDescription, "success": success]
        if let error = error {
            context["error"] = error.localizedDescription
        }
        
        log(level: level,
            category: "VIDEO_SELECTION",
            message: "Video selection result: \(videoDescription)",
            context: context)
    }
    
    func logError(_ error: Error, category: String, context: [String: Any] = [:]) {
        guard shouldLog(.error) else { return }
        
        var errorContext = context
        errorContext["errorType"] = String(describing: type(of: error))
        errorContext["localizedDescription"] = error.localizedDescription
        
        if let nsError = error as? NSError {
            errorContext["domain"] = nsError.domain
            errorContext["code"] = nsError.code
            errorContext["userInfo"] = nsError.userInfo.description
        }
        
        log(level: .error,
            category: category,
            message: "Error occurred: \(error.localizedDescription)",
            context: errorContext)
    }
    
    func logPerformanceWarning(_ message: String, metrics: VideoPerformanceMetrics) {
        guard shouldLog(.warning) else { return }
        
        log(level: .warning,
            category: "PERFORMANCE",
            message: message,
            context: nil,
            performanceMetrics: metrics)
    }
    
    // MARK: - Debug Overlay Data
    
    func getCurrentDebugInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        info["Log Level"] = config.logLevel.name
        info["Total Logs"] = "\(currentLogs.count)"
        info["Last Log"] = DateFormatter.localizedString(from: lastLogTime, dateStyle: .none, timeStyle: .medium)
        
        if let metrics = performanceMetrics {
            if let responseTime = metrics.responseTime {
                info["Last Response Time"] = "\(Int(responseTime * 1000))ms"
            }
            if let memoryUsage = metrics.memoryUsage {
                info["Memory Usage"] = "\(memoryUsage / 1024 / 1024)MB"
            }
        }
        
        return info
    }
    
    // MARK: - Log Export
    
    func exportLogs() -> String {
        return currentLogs.map { $0.formattedMessage }.joined(separator: "\n")
    }
    
    func exportLogsToFile() -> URL? {
        guard let logFileURL = logFileURL else { return nil }
        
        let exportURL = logFileURL.appendingPathExtension("export")
        let logContent = exportLogs()
        
        do {
            try logContent.write(to: exportURL, atomically: true, encoding: .utf8)
            return exportURL
        } catch {
            print("Failed to export logs: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func shouldLog(_ level: DebugLogLevel) -> Bool {
        return isEnabled && level.rawValue >= config.logLevel.rawValue
    }
    
    private func log(level: DebugLogLevel, 
                    category: String, 
                    message: String, 
                    context: [String: Any]? = nil,
                    performanceMetrics: VideoPerformanceMetrics? = nil) {
        
        let entry = VideoDebugLogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            context: context,
            performanceMetrics: performanceMetrics
        )
        
        lastLogTime = entry.timestamp
        
        // Update UI on main thread
        DispatchQueue.main.async {
            self.currentLogs.append(entry)
            
            // Limit log history to prevent memory issues
            if self.currentLogs.count > 1000 {
                self.currentLogs.removeFirst(self.currentLogs.count - 1000)
            }
            
            if let metrics = performanceMetrics {
                self.performanceMetrics = metrics
            }
        }
        
        // Console logging
        if config.enableConsoleLogging {
            print(entry.formattedMessage)
        }
        
        // File logging
        if config.enableFileLogging {
            writeToFile(entry.formattedMessage)
        }
    }
    
    private func setupFileLogging() {
        guard config.enableFileLogging else { return }
        
        logQueue.async {
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let logDirectory = documentsPath.appendingPathComponent("VideoPlaybackLogs")
                
                try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let fileName = "video_playback_\(dateFormatter.string(from: Date())).log"
                
                self.logFileURL = logDirectory.appendingPathComponent(fileName)
                
                if let logFileURL = self.logFileURL {
                    FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
                    self.fileHandle = try FileHandle(forWritingTo: logFileURL)
                }
            } catch {
                print("Failed to setup file logging: \(error)")
            }
        }
    }
    
    private func setupPerformanceMonitoring() {
        guard config.enablePerformanceMetrics else { return }
        
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
    }
    
    private func updatePerformanceMetrics() {
        let memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let memoryUsage = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        let metrics = VideoPerformanceMetrics(
            responseTime: nil,
            memoryUsage: memoryUsage == KERN_SUCCESS ? Int64(memoryInfo.resident_size) : nil,
            cpuUsage: nil,
            frameDrops: nil
        )
        
        DispatchQueue.main.async {
            self.performanceMetrics = metrics
        }
    }
    
    private func writeToFile(_ message: String) {
        guard let fileHandle = fileHandle else { return }
        
        logQueue.async {
            let data = (message + "\n").data(using: .utf8) ?? Data()
            fileHandle.write(data)
        }
    }
    
    private func cleanup() {
        performanceTimer?.invalidate()
        fileHandle?.closeFile()
    }
}

// MARK: - Extensions for Better Debug Output

extension PlaybackState {
    var debugDescription: String {
        switch self {
        case .idle:
            return "idle"
        case .loading:
            return "loading"
        case .ready:
            return "ready"
        case .playing:
            return "playing"
        case .paused:
            return "paused"
        case .failed(let error):
            return "failed(\(error.localizedDescription))"
        }
    }
    
    var isError: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

extension AVPlayer.Status {
    var debugDescription: String {
        switch self {
        case .unknown:
            return "unknown"
        case .readyToPlay:
            return "readyToPlay"
        case .failed:
            return "failed"
        @unknown default:
            return "unknown_case"
        }
    }
}

enum AVPlayerConnectionStatus {
    case unknown
    case connected
    case disconnected
    case error(Error)
}

// MARK: - Debug Overlay View

struct VideoPlaybackDebugOverlay: View {
    @ObservedObject var debugLogger: VideoPlaybackDebugLogger
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                if debugLogger.isEnabled {
                    VStack {
                        if isExpanded {
                            debugInfoPanel
                        }
                        
                        debugToggleButton
                    }
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding()
                }
            }
        }
    }
    
    private var debugInfoPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Debug Info")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(Array(debugLogger.getCurrentDebugInfo().keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(debugLogger.getCurrentDebugInfo()[key] ?? "")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            HStack {
                Button("Export Logs") {
                    _ = debugLogger.exportLogsToFile()
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Spacer()
                
                Button("Clear") {
                    debugLogger.currentLogs.removeAll()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(8)
        .frame(width: 200)
    }
    
    private var debugToggleButton: some View {
        Button(action: {
            withAnimation(.spring()) {
                isExpanded.toggle()
            }
        }) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                .foregroundColor(.white)
                .padding(8)
        }
    }
}

// MARK: - Service Integration Extension

extension VideoService {
    func enableDebugLogging(with logger: VideoPlaybackDebugLogger) {
        // This would be integrated into VideoService to provide debug logging
        // Example integration points:
        
        // 1. Player observation setup
        // 2. Asset loading monitoring  
        // 3. State transition tracking
        // 4. Performance metrics collection
        
        logger.log(level: .info, category: "DEBUG_SETUP", message: "Debug logging enabled for VideoService")
    }
}