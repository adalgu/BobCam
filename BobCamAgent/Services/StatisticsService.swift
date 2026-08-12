import Foundation
import Combine

final class StatisticsService: ObservableObject {
    static let shared = StatisticsService()

    @Published private(set) var sessions: [MealSession] = []
    @Published private(set) var currentSession: MealSession?

    private var sessionStartTime: Date?
    private var playbackStartTime: Date?
    private var isCurrentlyPlaying = false

    private let storageKey = "BobCamSessions"
    private let maxStoredSessions = 100

    private init() {
        loadSessions()
    }

    func startSession() {
        currentSession = MealSession()
        sessionStartTime = Date()
    }

    func endSession() {
        guard var session = currentSession else { return }

        session.endTime = Date()
        if let start = sessionStartTime {
            session.totalDuration = Date().timeIntervalSince(start)
        }

        if isCurrentlyPlaying, let playStart = playbackStartTime {
            session.playbackDuration += Date().timeIntervalSince(playStart)
        }

        sessions.insert(session, at: 0)
        saveSessions()

        currentSession = nil
        sessionStartTime = nil
        playbackStartTime = nil
        isCurrentlyPlaying = false
    }

    func recordPlaybackStart() {
        if !isCurrentlyPlaying {
            playbackStartTime = Date()
            isCurrentlyPlaying = true
        }
    }

    func recordPlaybackPause() {
        if isCurrentlyPlaying, let start = playbackStartTime {
            currentSession?.playbackDuration += Date().timeIntervalSince(start)
            currentSession?.pauseCount += 1
            isCurrentlyPlaying = false
            playbackStartTime = nil
        }
    }

    func getStatsForDate(_ date: Date) -> DailyStats {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        let daySessions = sessions.filter { session in
            calendar.isDate(session.startTime, inSameDayAs: date)
        }

        return DailyStats(id: startOfDay, sessions: daySessions)
    }

    func getWeeklyStats() -> [DailyStats] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<7).compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                return nil
            }
            return getStatsForDate(date)
        }.reversed()
    }

    func getTodayStats() -> DailyStats {
        getStatsForDate(Date())
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MealSession].self, from: data) else {
            return
        }
        sessions = decoded
    }

    private func saveSessions() {
        let sessionsToSave = Array(sessions.prefix(maxStoredSessions))

        if let encoded = try? JSONEncoder().encode(sessionsToSave) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    func clearAllData() {
        sessions.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
