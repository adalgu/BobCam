import Foundation

struct MealSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var totalDuration: TimeInterval
    var playbackDuration: TimeInterval
    var pauseCount: Int

    init() {
        self.id = UUID()
        self.startTime = Date()
        self.endTime = nil
        self.totalDuration = 0
        self.playbackDuration = 0
        self.pauseCount = 0
    }

    var playbackRatio: Double {
        guard totalDuration > 0 else { return 0 }
        return playbackDuration / totalDuration
    }

    var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d분 %02d초", minutes, seconds)
    }

    var formattedPlaybackRatio: String {
        return String(format: "%.0f%%", playbackRatio * 100)
    }
}

struct DailyStats: Identifiable {
    let id: Date
    let sessions: [MealSession]

    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.totalDuration }
    }

    var totalPlaybackDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.playbackDuration }
    }

    var totalPauseCount: Int {
        sessions.reduce(0) { $0 + $1.pauseCount }
    }

    var averagePlaybackRatio: Double {
        guard totalDuration > 0 else { return 0 }
        return totalPlaybackDuration / totalDuration
    }
}
