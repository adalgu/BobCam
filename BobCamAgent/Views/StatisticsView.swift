import SwiftUI
import Charts

struct StatisticsView: View {
    @ObservedObject private var statsService = StatisticsService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                todayStatsCard
                weeklyChartCard
                recentSessionsCard
            }
            .padding()
        }
        .navigationTitle("식사 기록")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var todayStatsCard: some View {
        let todayStats = statsService.getTodayStats()

        return VStack(alignment: .leading, spacing: 16) {
            Text("오늘")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                StatItem(
                    title: "총 식사 시간",
                    value: formatDuration(todayStats.totalDuration),
                    icon: "clock",
                    color: .blue
                )

                StatItem(
                    title: "영상 재생",
                    value: String(format: "%.0f%%", todayStats.averagePlaybackRatio * 100),
                    icon: "play.circle",
                    color: .green
                )

                StatItem(
                    title: "중단 횟수",
                    value: "\(todayStats.totalPauseCount)회",
                    icon: "pause.circle",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var weeklyChartCard: some View {
        let weeklyStats = statsService.getWeeklyStats()

        return VStack(alignment: .leading, spacing: 16) {
            Text("주간 추이")
                .font(.headline)
                .foregroundColor(.secondary)

            if #available(iOS 16.0, *) {
                Chart(weeklyStats) { dayStats in
                    BarMark(
                        x: .value("날짜", dayStats.id, unit: .day),
                        y: .value("시간", dayStats.totalDuration / 60)
                    )
                    .foregroundStyle(.blue.gradient)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text("\(Int(minutes))분")
                            }
                        }
                    }
                }
            } else {
                SimpleBarChart(data: weeklyStats)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var recentSessionsCard: some View {
        let recentSessions = Array(statsService.sessions.prefix(10))

        return VStack(alignment: .leading, spacing: 16) {
            Text("최근 식사")
                .font(.headline)
                .foregroundColor(.secondary)

            if recentSessions.isEmpty {
                Text("아직 기록된 식사가 없습니다")
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            } else {
                ForEach(recentSessions) { session in
                    SessionRow(session: session)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes)분"
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SessionRow: View {
    let session: MealSession

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d (E) HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: session.startTime))
                    .font(.subheadline)

                Text(session.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(session.formattedPlaybackRatio)
                    .font(.subheadline)
                    .foregroundColor(.green)

                Text("중단 \(session.pauseCount)회")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
    }
}

struct SimpleBarChart: View {
    let data: [DailyStats]

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data) { dayStats in
                    VStack {
                        Spacer()

                        Rectangle()
                            .fill(Color.blue)
                            .frame(height: barHeight(for: dayStats, maxHeight: geometry.size.height - 30))

                        Text(dayLabel(dayStats.id))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func barHeight(for stats: DailyStats, maxHeight: CGFloat) -> CGFloat {
        let maxDuration = data.map { $0.totalDuration }.max() ?? 1
        guard maxDuration > 0 else { return 0 }
        return CGFloat(stats.totalDuration / maxDuration) * maxHeight
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}
