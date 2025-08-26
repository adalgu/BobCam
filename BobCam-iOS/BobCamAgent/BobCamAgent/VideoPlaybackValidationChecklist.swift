import Foundation
import AVFoundation
import SwiftUI

// MARK: - Video Playback Validation Checklist & Safeguards

/**
 * Comprehensive validation checklist and safeguards for video playback system
 * 
 * PURPOSE:
 * - Identify potential failure points before they cause issues
 * - Provide systematic validation of video playback prerequisites
 * - Implement fallback mechanisms for common failure scenarios
 * - Generate actionable debugging information
 */

// MARK: - Validation Checklist Structure

struct VideoPlaybackValidationResult {
    let checkName: String
    let passed: Bool
    let details: String
    let severity: ValidationSeverity
    let suggestedAction: String?
    let context: [String: Any]
    
    enum ValidationSeverity {
        case info
        case warning
        case error
        case critical
        
        var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
    }
}

// MARK: - Comprehensive Validation System

class VideoPlaybackValidator: ObservableObject {
    
    @Published var lastValidationResults: [VideoPlaybackValidationResult] = []
    @Published var systemHealthScore: Double = 1.0
    @Published var criticalIssuesCount: Int = 0
    
    private let videoService: VideoService
    private let videoSelectionService: VideoSelectionService
    
    init(videoService: VideoService, videoSelectionService: VideoSelectionService) {
        self.videoService = videoService
        self.videoSelectionService = videoSelectionService
    }
    
    // MARK: - Main Validation Entry Point
    
    func performCompleteValidation() -> ValidationReport {
        var results: [VideoPlaybackValidationResult] = []
        
        // Core system validations
        results.append(contentsOf: validateVideoService())
        results.append(contentsOf: validateAVFoundationSetup())
        results.append(contentsOf: validateVideoAssets())
        results.append(contentsOf: validatePlaybackState())
        results.append(contentsOf: validateUserInterface())
        results.append(contentsOf: validatePerformance())
        results.append(contentsOf: validateErrorHandling())
        
        // Update published properties
        lastValidationResults = results
        calculateHealthScore(from: results)
        
        return ValidationReport(
            timestamp: Date(),
            results: results,
            healthScore: systemHealthScore,
            criticalIssues: results.filter { $0.severity == .critical },
            recommendations: generateRecommendations(from: results)
        )
    }
    
    // MARK: - Specific Validation Methods
    
    private func validateVideoService() -> [VideoPlaybackValidationResult] {
        var results: [VideoPlaybackValidationResult] = []
        
        // Check if VideoService is properly initialized
        results.append(VideoPlaybackValidationResult(
            checkName: "VideoService Initialization",
            passed: videoService != nil,
            details: videoService != nil ? "VideoService is properly initialized" : "VideoService is nil",
            severity: videoService != nil ? .info : .critical,
            suggestedAction: videoService != nil ? nil : "Recreate VideoService instance",
            context: ["hasVideoService": videoService != nil]
        ))
        
        // Check current playback state validity
        let currentState = videoService.playbackState
        let stateValid = validatePlaybackStateConsistency(currentState)
        results.append(VideoPlaybackValidationResult(
            checkName: "Playback State Consistency",
            passed: stateValid.isValid,
            details: stateValid.description,
            severity: stateValid.isValid ? .info : .warning,
            suggestedAction: stateValid.isValid ? nil : "Reset video service state",
            context: ["currentState": currentState.debugDescription]
        ))
        
        // Check video type consistency
        let hasVideoType = videoService.currentVideoType != nil
        let hasPlayer = videoService.avPlayer != nil
        let consistencyCheck = (hasVideoType && hasPlayer) || (!hasVideoType && !hasPlayer)
        
        results.append(VideoPlaybackValidationResult(
            checkName: "Video Type Consistency",
            passed: consistencyCheck,
            details: consistencyCheck ? "Video type and player state are consistent" : "Mismatch between video type and player state",
            severity: consistencyCheck ? .info : .warning,
            suggestedAction: consistencyCheck ? nil : "Synchronize video type and player state",
            context: [
                "hasVideoType": hasVideoType,
                "hasPlayer": hasPlayer,
                "videoType": videoService.currentVideoType?.displayName ?? "none"
            ]
        ))
        
        return results
    }
    
    private func validateAVFoundationSetup() -> [VideoPlaybackValidationResult] {
        var results: [VideoPlaybackValidationResult] = []
        
        // Check AVAudioSession configuration
        let audioSession = AVAudioSession.sharedInstance()
        let correctCategory = audioSession.category == .playback
        
        results.append(VideoPlaybackValidationResult(
            checkName: "Audio Session Configuration",
            passed: correctCategory,
            details: "Audio session category: \(audioSession.category.rawValue)",
            severity: correctCategory ? .info : .warning,
            suggestedAction: correctCategory ? nil : "Set audio session category to .playback",
            context: ["audioCategory": audioSession.category.rawValue]
        ))
        
        // Check AVPlayer setup if exists
        if let player = videoService.avPlayer {
            let playerRate = player.rate
            let playerStatus = player.status
            
            results.append(VideoPlaybackValidationResult(
                checkName: "AVPlayer Status",
                passed: playerStatus != .failed,
                details: "Player status: \(playerStatus.debugDescription), rate: \(playerRate)",
                severity: playerStatus == .failed ? .error : .info,
                suggestedAction: playerStatus == .failed ? "Recreate AVPlayer with new asset" : nil,
                context: [
                    "playerStatus": playerStatus.debugDescription,
                    "playerRate": playerRate,
                    "playerError": player.error?.localizedDescription ?? "none"
                ]
            ))
            
            // Check player item status
            if let playerItem = player.currentItem {
                let itemStatus = playerItem.status
                results.append(VideoPlaybackValidationResult(
                    checkName: "AVPlayerItem Status",
                    passed: itemStatus == .readyToPlay,
                    details: "Player item status: \(itemStatus.debugDescription)",
                    severity: itemStatus == .failed ? .error : (itemStatus == .readyToPlay ? .info : .warning),
                    suggestedAction: itemStatus == .failed ? "Replace player item with valid asset" : nil,
                    context: [
                        "itemStatus": itemStatus.debugDescription,
                        "itemError": playerItem.error?.localizedDescription ?? "none",
                        "duration": playerItem.duration.seconds
                    ]
                ))
            }
        }
        
        return results
    }
    
    private func validateVideoAssets() -> [VideoPlaybackValidationResult] {
        var results: [VideoPlaybackValidationResult] = []
        
        // Check default video availability
        let defaultVideoExists = Bundle.main.path(forResource: "demo", ofType: "mp4") != nil
        results.append(VideoPlaybackValidationResult(
            checkName: "Default Video Availability",
            passed: defaultVideoExists,
            details: defaultVideoExists ? "demo.mp4 found in app bundle" : "demo.mp4 not found in app bundle",
            severity: defaultVideoExists ? .info : .warning,
            suggestedAction: defaultVideoExists ? nil : "Add demo.mp4 to app bundle or handle missing default video gracefully",
            context: ["defaultVideoExists": defaultVideoExists]
        ))
        
        // Check selected video validity
        if let selectedVideoType = videoSelectionService.selectedVideoType {
            switch selectedVideoType {
            case .local(let url):
                let fileExists = FileManager.default.fileExists(atPath: url.path)
                results.append(VideoPlaybackValidationResult(
                    checkName: "Selected Video File Existence",
                    passed: fileExists,
                    details: fileExists ? "Selected video file exists at path" : "Selected video file not found",
                    severity: fileExists ? .info : .error,
                    suggestedAction: fileExists ? nil : "Reselect video or clear invalid selection",
                    context: [
                        "videoPath": url.path,
                        "fileName": url.lastPathComponent
                    ]
                ))
                
                if fileExists {
                    // Check file accessibility and format
                    validateLocalVideoFile(url: url, results: &results)
                }
                
            case .youtube(let youTubeVideo):
                // Check YouTube video validity
                let networkAvailable = videoService.isNetworkAvailable
                results.append(VideoPlaybackValidationResult(
                    checkName: "YouTube Playback Prerequisites",
                    passed: networkAvailable,
                    details: "Network available: \(networkAvailable), Video ID: \(youTubeVideo.videoId)",
                    severity: networkAvailable ? .info : .error,
                    suggestedAction: networkAvailable ? nil : "Check internet connection for YouTube playback",
                    context: [
                        "networkAvailable": networkAvailable,
                        "videoId": youTubeVideo.videoId,
                        "isChildSafe": youTubeVideo.isChildSafe
                    ]
                ))
            }
        } else {
            results.append(VideoPlaybackValidationResult(
                checkName: "Video Selection Status",
                passed: false,
                details: "No video currently selected",
                severity: .warning,
                suggestedAction: "Select a video for playback",
                context: ["hasSelectedVideo": false]
            ))
        }
        
        return results
    }
    
    private func validateLocalVideoFile(url: URL, results: inout [VideoPlaybackValidationResult]) {
        do {
            let asset = AVAsset(url: url)
            let duration = try asset.load(.duration)
            let isPlayable = try asset.load(.isPlayable)
            
            results.append(VideoPlaybackValidationResult(
                checkName: "Video Asset Playability",
                passed: isPlayable && duration.seconds > 0,
                details: "Playable: \(isPlayable), Duration: \(duration.seconds)s",
                severity: (isPlayable && duration.seconds > 0) ? .info : .error,
                suggestedAction: (isPlayable && duration.seconds > 0) ? nil : "Select a valid video file",
                context: [
                    "isPlayable": isPlayable,
                    "durationSeconds": duration.seconds,
                    "hasVideoTracks": asset.tracks(withMediaType: .video).count > 0
                ]
            ))
        } catch {
            results.append(VideoPlaybackValidationResult(
                checkName: "Video Asset Loading",
                passed: false,
                details: "Failed to load asset: \(error.localizedDescription)",
                severity: .error,
                suggestedAction: "Select a different video file",
                context: ["loadError": error.localizedDescription]
            ))
        }
    }
    
    private func validatePlaybackState() -> [VideoPlaybackValidationResult] {
        var results: [VideoPlaybackValidationResult] = []
        
        let currentState = videoService.playbackState
        let isPlaying = videoService.isPlaying
        
        // Check state consistency
        let statePlayingConsistency = validatePlaybackStatePlayingConsistency(state: currentState, isPlaying: isPlaying)
        results.append(VideoPlaybackValidationResult(
            checkName: "State Playing Consistency",
            passed: statePlayingConsistency.isConsistent,
            details: statePlayingConsistency.description,
            severity: statePlayingConsistency.isConsistent ? .info : .warning,
            suggestedAction: statePlayingConsistency.isConsistent ? nil : "Synchronize playback state with playing status",
            context: [
                "playbackState": currentState.debugDescription,
                "isPlaying": isPlaying
            ]
        ))
        
        // Check for stuck states
        let stateValidForAction = validateStateAllowsActions(currentState)
        results.append(VideoPlaybackValidationResult(
            checkName: "State Action Compatibility",
            passed: stateValidForAction.canPerformActions,
            details: stateValidForAction.description,
            severity: stateValidForAction.canPerformActions ? .info : .warning,
            suggestedAction: stateValidForAction.canPerformActions ? nil : "Reset to a valid state",
            context: ["currentState": currentState.debugDescription]
        ))
        
        return results
    }
    
    private func validateUserInterface() -> [VideoPlaybackValidationResult] {
        var results: [VideoPlaybackValidationResult] = []
        
        // Check video selection service state
        let hasSelectedVideo = videoSelectionService.hasSelectedVideo
        let selectionState = videoSelectionService.selectionState
        
        results.append(VideoPlaybackValidationResult(
            checkName: "Video Selection State",
            passed: selectionState != .failed(VideoSelectionService.VideoSelectionError.importFailed),
            details: "Selection state: \(selectionState), Has video: \(hasSelectedVideo)",
            severity: .info,
            suggestedAction: nil,
            context: [
                "hasSelectedVideo": hasSelectedVideo,
                "selectionState": String(describing: selectionState)
            ]
        ))
        
        return results
    }
    
    private func validatePerformance() -> [VideoPlaybackValidationResult] {
        var results: [VideoPlaybackValidationResult] = []
        
        // Check memory usage
        if let memoryUsage = getCurrentMemoryUsage() {
            let memoryMB = memoryUsage / 1024 / 1024
            let acceptable = memoryMB < 200
            
            results.append(VideoPlaybackValidationResult(
                checkName: "Memory Usage",
                passed: acceptable,
                details: "Current memory usage: \(memoryMB)MB",
                severity: acceptable ? .info : .warning,
                suggestedAction: acceptable ? nil : "Consider memory optimization",
                context: ["memoryUsageMB": memoryMB]
            ))
        }
        
        return results
    }
    
    private func validateErrorHandling() -> [VideoPlaybackValidationResult] {
        var results: [VideoPlaybackValidationResult] = []
        
        // Check if currently in error state
        if case .failed(let error) = videoService.playbackState {
            results.append(VideoPlaybackValidationResult(
                checkName: "Current Error State",
                passed: false,
                details: "Service in error state: \(error.localizedDescription)",
                severity: .error,
                suggestedAction: "Reset service or handle error condition",
                context: [
                    "error": error.localizedDescription,
                    "errorType": String(describing: type(of: error))
                ]
            ))
        }
        
        return results
    }
    
    // MARK: - Helper Validation Functions
    
    private func validatePlaybackStateConsistency(_ state: PlaybackState) -> (isValid: Bool, description: String) {
        switch state {
        case .idle:
            let hasVideo = videoService.currentVideoType != nil
            return (
                !hasVideo,
                hasVideo ? "Idle state with video loaded (inconsistent)" : "Idle state with no video (consistent)"
            )
        case .ready:
            let hasVideo = videoService.currentVideoType != nil
            return (
                hasVideo,
                hasVideo ? "Ready state with video loaded (consistent)" : "Ready state without video (inconsistent)"
            )
        case .playing:
            let isPlaying = videoService.isPlaying
            return (
                isPlaying,
                isPlaying ? "Playing state matches isPlaying flag" : "Playing state but isPlaying is false"
            )
        case .paused:
            let isPlaying = videoService.isPlaying
            return (
                !isPlaying,
                !isPlaying ? "Paused state matches isPlaying flag" : "Paused state but isPlaying is true"
            )
        case .loading, .failed:
            return (true, "State is acceptable")
        }
    }
    
    private func validatePlaybackStatePlayingConsistency(state: PlaybackState, isPlaying: Bool) -> (isConsistent: Bool, description: String) {
        switch (state, isPlaying) {
        case (.playing, true):
            return (true, "Playing state and isPlaying flag are consistent")
        case (.paused, false), (.ready, false), (.idle, false), (.loading, false):
            return (true, "Non-playing state and isPlaying flag are consistent")
        case (.failed, false):
            return (true, "Failed state with isPlaying false is acceptable")
        default:
            return (false, "Playback state (\(state.debugDescription)) and isPlaying (\(isPlaying)) are inconsistent")
        }
    }
    
    private func validateStateAllowsActions(_ state: PlaybackState) -> (canPerformActions: Bool, description: String) {
        switch state {
        case .failed:
            return (false, "Failed state prevents actions - requires reset")
        case .loading:
            return (false, "Loading state prevents actions - wait for completion")
        case .idle, .ready, .playing, .paused:
            return (true, "State allows normal playback actions")
        }
    }
    
    private func calculateHealthScore(from results: [VideoPlaybackValidationResult]) {
        let totalChecks = results.count
        guard totalChecks > 0 else {
            systemHealthScore = 1.0
            return
        }
        
        var score: Double = 0.0
        var criticalCount = 0
        
        for result in results {
            if result.passed {
                score += 1.0
            } else {
                switch result.severity {
                case .info:
                    score += 0.9
                case .warning:
                    score += 0.7
                case .error:
                    score += 0.3
                case .critical:
                    score += 0.0
                    criticalCount += 1
                }
            }
        }
        
        systemHealthScore = score / Double(totalChecks)
        criticalIssuesCount = criticalCount
    }
    
    private func generateRecommendations(from results: [VideoPlaybackValidationResult]) -> [String] {
        var recommendations: [String] = []
        
        let failedResults = results.filter { !$0.passed }
        let criticalResults = failedResults.filter { $0.severity == .critical }
        let errorResults = failedResults.filter { $0.severity == .error }
        
        if !criticalResults.isEmpty {
            recommendations.append("🚨 CRITICAL: Address critical issues immediately to restore functionality")
            for critical in criticalResults {
                if let action = critical.suggestedAction {
                    recommendations.append("• \(action)")
                }
            }
        }
        
        if !errorResults.isEmpty {
            recommendations.append("❌ ERRORS: Fix error conditions to improve reliability")
            for error in errorResults {
                if let action = error.suggestedAction {
                    recommendations.append("• \(action)")
                }
            }
        }
        
        // General recommendations based on patterns
        let hasVideoIssues = results.contains { $0.checkName.contains("Video") && !$0.passed }
        if hasVideoIssues {
            recommendations.append("📹 Consider resetting video selection and reloading assets")
        }
        
        let hasStateIssues = results.contains { $0.checkName.contains("State") && !$0.passed }
        if hasStateIssues {
            recommendations.append("🔄 Consider restarting video service to restore consistent state")
        }
        
        return recommendations
    }
    
    private func getCurrentMemoryUsage() -> Int64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : nil
    }
}

// MARK: - Validation Report Structure

struct ValidationReport {
    let timestamp: Date
    let results: [VideoPlaybackValidationResult]
    let healthScore: Double
    let criticalIssues: [VideoPlaybackValidationResult]
    let recommendations: [String]
    
    var overallStatus: String {
        if healthScore >= 0.9 {
            return "✅ EXCELLENT"
        } else if healthScore >= 0.8 {
            return "✅ GOOD"
        } else if healthScore >= 0.7 {
            return "⚠️ FAIR"
        } else if healthScore >= 0.5 {
            return "❌ POOR"
        } else {
            return "🚨 CRITICAL"
        }
    }
    
    func generateSummary() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var summary = "=== Video Playback Validation Report ===\n"
        summary += "Timestamp: \(dateFormatter.string(from: timestamp))\n"
        summary += "Overall Status: \(overallStatus)\n"
        summary += "Health Score: \(Int(healthScore * 100))%\n"
        summary += "Total Checks: \(results.count)\n"
        summary += "Critical Issues: \(criticalIssues.count)\n\n"
        
        if !criticalIssues.isEmpty {
            summary += "🚨 CRITICAL ISSUES:\n"
            for issue in criticalIssues {
                summary += "• \(issue.checkName): \(issue.details)\n"
                if let action = issue.suggestedAction {
                    summary += "  → \(action)\n"
                }
            }
            summary += "\n"
        }
        
        if !recommendations.isEmpty {
            summary += "📋 RECOMMENDATIONS:\n"
            for recommendation in recommendations {
                summary += "• \(recommendation)\n"
            }
            summary += "\n"
        }
        
        summary += "📊 DETAILED RESULTS:\n"
        for result in results {
            let status = result.passed ? "✅" : result.severity.emoji
            summary += "\(status) \(result.checkName): \(result.details)\n"
        }
        
        return summary
    }
    
    func saveToFile() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let reportsDirectory = documentsPath.appendingPathComponent("ValidationReports")
        
        do {
            try FileManager.default.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileName = "validation_report_\(dateFormatter.string(from: timestamp)).txt"
            
            let reportURL = reportsDirectory.appendingPathComponent(fileName)
            try generateSummary().write(to: reportURL, atomically: true, encoding: .utf8)
            
            return reportURL
        } catch {
            print("Failed to save validation report: \(error)")
            return nil
        }
    }
}

// MARK: - SwiftUI Integration

struct VideoPlaybackValidationView: View {
    @StateObject private var validator: VideoPlaybackValidator
    @State private var latestReport: ValidationReport?
    
    init(videoService: VideoService, videoSelectionService: VideoSelectionService) {
        _validator = StateObject(wrappedValue: VideoPlaybackValidator(
            videoService: videoService, 
            videoSelectionService: videoSelectionService
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("System Health")
                    .font(.headline)
                Spacer()
                Text("\(Int(validator.systemHealthScore * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(healthScoreColor)
            }
            
            if validator.criticalIssuesCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("\(validator.criticalIssuesCount) Critical Issues")
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
            }
            
            Button("Run Validation") {
                latestReport = validator.performCompleteValidation()
            }
            .buttonStyle(.bordered)
            
            if let report = latestReport {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Check: \(report.overallStatus)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if !report.recommendations.isEmpty {
                        Text("Recommendations:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        ForEach(Array(report.recommendations.enumerated()), id: \.offset) { _, recommendation in
                            Text("• \(recommendation)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var healthScoreColor: Color {
        if validator.systemHealthScore >= 0.8 {
            return .green
        } else if validator.systemHealthScore >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}