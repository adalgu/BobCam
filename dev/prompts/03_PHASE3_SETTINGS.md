# Phase 3: 설정 및 통계 기능

## 목표
영상 선택, 설정 화면, 통계 기록 및 표시 기능을 구현하여 MVP를 완성합니다.

## 사전 조건
- Phase 1, 2 완료
- 핵심 감지 및 피드백 시스템 동작 확인

## 참고 문서
- SPEC: `/Users/macmini/study/01-active/BobCam/dev/docs/SPEC.md` (섹션 2.2.1, 3.2, 3.3, 3.4)

---

## Task 1: AppSettings 모델

### 1.1 설정 모델 정의

```swift
// Models/AppSettings.swift
import Foundation

struct AppSettings: Codable {
    var sensitivity: Double  // 0.0 ~ 1.0
    var waitTimeSeconds: Int  // 1 ~ 30
    var nudgeMessages: [String]

    static let defaultSettings = AppSettings(
        sensitivity: 0.5,
        waitTimeSeconds: 5,
        nudgeMessages: ["밥 먹자!", "냠냠!", "한 입 더!"]
    )
}

// MARK: - Settings Manager
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var settings: AppSettings {
        didSet {
            save()
        }
    }

    private let key = "BobCamSettings"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .defaultSettings
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    func reset() {
        settings = .defaultSettings
    }
}
```

---

## Task 2: 영상 선택 화면

### 2.1 VideoSource 업데이트

```swift
// Models/VideoSource.swift
import Foundation
import Photos

enum VideoSource: Identifiable, Equatable {
    case youtube(url: URL)
    case photoLibrary(asset: PHAsset)
    case local(url: URL, name: String)

    var id: String {
        switch self {
        case .youtube(let url):
            return "youtube:\(url.absoluteString)"
        case .photoLibrary(let asset):
            return "photo:\(asset.localIdentifier)"
        case .local(let url, _):
            return "local:\(url.absoluteString)"
        }
    }

    var displayName: String {
        switch self {
        case .youtube:
            return "YouTube 영상"
        case .photoLibrary:
            return "사진첩 영상"
        case .local(_, let name):
            return name
        }
    }

    static func == (lhs: VideoSource, rhs: VideoSource) -> Bool {
        lhs.id == rhs.id
    }
}
```

### 2.2 VideoSelectionView

```swift
// Views/VideoSelectionView.swift
import SwiftUI
import PhotosUI

struct VideoSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var youtubeURL = ""
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    let onVideoSelected: (VideoSource) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                Picker("소스", selection: $selectedTab) {
                    Text("YouTube").tag(0)
                    Text("사진첩").tag(1)
                    Text("저장된 영상").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                // Content based on tab
                switch selectedTab {
                case 0:
                    youtubeInputView
                case 1:
                    photoLibraryView
                case 2:
                    localVideosView
                default:
                    EmptyView()
                }

                Spacer()
            }
            .navigationTitle("영상 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - YouTube Input
    private var youtubeInputView: some View {
        VStack(spacing: 20) {
            Text("YouTube URL을 입력하세요")
                .font(.headline)
                .padding(.top, 40)

            TextField("https://youtube.com/watch?v=...", text: $youtubeURL)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.URL)
                .padding(.horizontal)

            Button(action: loadYouTube) {
                Text("재생하기")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(youtubeURL.isEmpty ? Color.gray : Color.red)
                    .cornerRadius(12)
            }
            .disabled(youtubeURL.isEmpty)
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Photo Library
    private var photoLibraryView: some View {
        VStack(spacing: 20) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("사진첩에서 영상 선택")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
                .padding()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                handlePhotoSelection(newItem)
            }

            Spacer()
        }
        .padding(.top, 20)
    }

    // MARK: - Local Videos
    private var localVideosView: some View {
        let localVideos = getLocalVideos()

        return Group {
            if localVideos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("저장된 영상이 없습니다")
                        .foregroundColor(.gray)
                }
                .padding(.top, 80)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(localVideos, id: \.id) { video in
                            LocalVideoRow(video: video) {
                                onVideoSelected(video)
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Actions
    private func loadYouTube() {
        guard let url = URL(string: youtubeURL) else { return }
        onVideoSelected(.youtube(url: url))
        dismiss()
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            if let asset = try? await loadPHAsset(from: item) {
                await MainActor.run {
                    onVideoSelected(.photoLibrary(asset: asset))
                    dismiss()
                }
            }
        }
    }

    private func loadPHAsset(from item: PhotosPickerItem) async throws -> PHAsset? {
        let identifier = item.itemIdentifier
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier ?? ""], options: nil)
        return result.firstObject
    }

    private func getLocalVideos() -> [VideoSource] {
        // Get videos from app's Documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videosURL = documentsURL.appendingPathComponent("Videos")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: videosURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return files
            .filter { ["mp4", "mov", "m4v"].contains($0.pathExtension.lowercased()) }
            .map { .local(url: $0, name: $0.deletingPathExtension().lastPathComponent) }
    }
}

// MARK: - Local Video Row
struct LocalVideoRow: View {
    let video: VideoSource
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                Text(video.displayName)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}
```

### 2.3 YouTube WebView

```swift
// Views/Components/YouTubePlayerView.swift
import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let url: URL
    @Binding var isPlaying: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Convert YouTube URL to embed URL
        if let videoID = extractVideoID(from: url) {
            let embedURL = "https://www.youtube.com/embed/\(videoID)?autoplay=1&playsinline=1&controls=0"
            if let embedURLObject = URL(string: embedURL) {
                let request = URLRequest(url: embedURLObject)
                webView.load(request)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func extractVideoID(from url: URL) -> String? {
        let urlString = url.absoluteString

        // Handle youtu.be format
        if urlString.contains("youtu.be") {
            return url.lastPathComponent
        }

        // Handle youtube.com format
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let videoID = queryItems.first(where: { $0.name == "v" })?.value {
            return videoID
        }

        return nil
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: YouTubePlayerView

        init(_ parent: YouTubePlayerView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isPlaying = true
        }
    }
}
```

---

## Task 3: 설정 화면

### 3.1 SettingsView

```swift
// Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settingsManager = SettingsManager.shared

    @State private var sensitivity: Double
    @State private var waitTime: Int
    @State private var messages: [String]
    @State private var editingMessageIndex: Int?

    init() {
        let settings = SettingsManager.shared.settings
        _sensitivity = State(initialValue: settings.sensitivity)
        _waitTime = State(initialValue: settings.waitTimeSeconds)
        _messages = State(initialValue: settings.nudgeMessages)
    }

    var body: some View {
        NavigationView {
            Form {
                // Detection Settings
                Section(header: Text("감지 설정")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("민감도")
                            Spacer()
                            Text(sensitivityText)
                                .foregroundColor(.gray)
                        }
                        Slider(value: $sensitivity, in: 0...1, step: 0.1)
                    }

                    Picker("대기 시간", selection: $waitTime) {
                        ForEach(1...30, id: \.self) { seconds in
                            Text("\(seconds)초").tag(seconds)
                        }
                    }
                }

                // Nudge Messages
                Section(header: Text("넛지 메시지")) {
                    ForEach(messages.indices, id: \.self) { index in
                        HStack {
                            TextField("메시지 \(index + 1)", text: $messages[index])

                            if messages.count > 1 {
                                Button(action: { removeMessage(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }

                    if messages.count < 5 {
                        Button(action: addMessage) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                Text("메시지 추가")
                            }
                        }
                    }
                }

                // Statistics Link
                Section {
                    NavigationLink(destination: StatisticsView()) {
                        HStack {
                            Image(systemName: "chart.bar")
                                .foregroundColor(.blue)
                            Text("식사 기록 보기")
                        }
                    }
                }

                // Reset
                Section {
                    Button(action: resetSettings) {
                        Text("기본값으로 초기화")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var sensitivityText: String {
        switch sensitivity {
        case 0..<0.3:
            return "낮음"
        case 0.3..<0.7:
            return "보통"
        default:
            return "높음"
        }
    }

    // MARK: - Actions
    private func addMessage() {
        messages.append("새 메시지")
    }

    private func removeMessage(at index: Int) {
        messages.remove(at: index)
    }

    private func saveSettings() {
        settingsManager.settings = AppSettings(
            sensitivity: sensitivity,
            waitTimeSeconds: waitTime,
            nudgeMessages: messages.filter { !$0.isEmpty }
        )
    }

    private func resetSettings() {
        let defaults = AppSettings.defaultSettings
        sensitivity = defaults.sensitivity
        waitTime = defaults.waitTimeSeconds
        messages = defaults.nudgeMessages
    }
}
```

---

## Task 4: StatisticsService 구현

### 4.1 MealSession 모델

```swift
// Models/MealSession.swift
import Foundation

struct MealSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var totalDuration: TimeInterval  // 전체 시간
    var playbackDuration: TimeInterval  // 영상 재생 시간
    var pauseCount: Int  // 중단 횟수

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
    let id: Date  // Date without time
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
```

### 4.2 StatisticsService

```swift
// Services/StatisticsService.swift
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

    // MARK: - Session Management
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

        // Finalize playback duration if still playing
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

    // MARK: - Statistics
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

    // MARK: - Persistence
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MealSession].self, from: data) else {
            return
        }
        sessions = decoded
    }

    private func saveSessions() {
        // Keep only recent sessions
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
```

---

## Task 5: 통계 화면

### 5.1 StatisticsView

```swift
// Views/StatisticsView.swift
import SwiftUI
import Charts

struct StatisticsView: View {
    @ObservedObject private var statsService = StatisticsService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Today's Stats
                todayStatsCard

                // Weekly Chart
                weeklyChartCard

                // Recent Sessions
                recentSessionsCard
            }
            .padding()
        }
        .navigationTitle("식사 기록")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Today's Stats
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

    // MARK: - Weekly Chart
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
                        y: .value("시간", dayStats.totalDuration / 60)  // minutes
                    )
                    .foregroundStyle(.blue.gradient)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
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
                // Fallback for iOS 15
                SimpleBarChart(data: weeklyStats)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Recent Sessions
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

    // MARK: - Helpers
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes)분"
    }
}

// MARK: - Stat Item
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

// MARK: - Session Row
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

// MARK: - Simple Bar Chart (iOS 15 fallback)
struct SimpleBarChart: View {
    let data: [DailyStats]

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data) { dayStats in
                    VStack {
                        Spacer()

                        Rectangle()
                            .fill(Color.blue.gradient)
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
```

---

## Task 6: MainView 최종 통합

### 6.1 완성된 MainView

```swift
// Views/MainView.swift
import SwiftUI
import AVFoundation
import Combine

struct MainView: View {
    // MARK: - Services
    @StateObject private var visionService = VisionService()
    @StateObject private var cameraService = CameraService()
    @StateObject private var videoService = VideoService()
    @StateObject private var feedbackService = FeedbackService()
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var statsService = StatisticsService.shared

    // MARK: - State
    @State private var showVideoSelection = true  // Start with video selection
    @State private var showSettings = false
    @State private var controlBarFrame: CGRect = .zero
    @State private var isYouTubeVideo = false
    @State private var youtubeURL: URL?

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Video Content
            if isYouTubeVideo, let url = youtubeURL {
                YouTubePlayerView(url: url, isPlaying: $feedbackService.isVideoPlaying)
                    .ignoresSafeArea()
                    .opacity(shouldShowVideo ? 1 : 0)
            } else {
                VideoPlayerView(player: videoService.player)
                    .ignoresSafeArea()
                    .opacity(shouldShowVideo ? 1 : 0)
            }

            // Nudge Overlay
            if case .nudging = feedbackService.currentState {
                NudgeOverlay(
                    message: feedbackService.nudgeMessage,
                    cameraService: cameraService
                )
                .transition(.opacity)
            }

            // Praise Overlay
            if case .praising = feedbackService.currentState {
                PraiseOverlay()
                    .transition(.scale.combined(with: .opacity))
            }

            // Waiting indicator
            if case .waiting(let seconds) = feedbackService.currentState {
                VStack {
                    Spacer()
                    Text("\(seconds)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding()
                        .background(Circle().fill(Color.black.opacity(0.5)))
                    Spacer().frame(height: 100)
                }
            }

            // Parent Control Bar
            VStack {
                ParentControlBar(feedbackService: feedbackService) {
                    showSettings = true
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ControlBarFrameKey.self,
                            value: geo.frame(in: .global)
                        )
                    }
                )
                Spacer()
            }
        }
        .blockChildTouches(exceptIn: [controlBarFrame])
        .onPreferenceChange(ControlBarFrameKey.self) { frame in
            controlBarFrame = frame
        }
        .animation(.easeInOut(duration: 0.3), value: feedbackService.currentState)
        .onAppear {
            applySettings()
        }
        .onDisappear {
            endMealSession()
        }
        .onChange(of: settingsManager.settings) { _, _ in
            applySettings()
        }
        .onReceive(visionService.$isEating) { isEating in
            feedbackService.updateEatingState(isEating)

            // Record for statistics
            if isEating {
                statsService.recordPlaybackStart()
            } else if case .nudging = feedbackService.currentState {
                statsService.recordPlaybackPause()
            }
        }
        .sheet(isPresented: $showVideoSelection, onDismiss: {
            if videoService.currentSource == nil && !isYouTubeVideo {
                // User cancelled without selecting - show again
                showVideoSelection = true
            }
        }) {
            VideoSelectionView { source in
                loadVideo(source)
                startMealSession()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Computed Properties
    private var shouldShowVideo: Bool {
        feedbackService.currentState.isVideoPlaying
    }

    // MARK: - Actions
    private func loadVideo(_ source: VideoSource) {
        switch source {
        case .youtube(let url):
            isYouTubeVideo = true
            youtubeURL = url

        case .photoLibrary(let asset):
            isYouTubeVideo = false
            loadFromPhotoLibrary(asset)

        case .local(let url, _):
            isYouTubeVideo = false
            videoService.loadVideo(from: .local(url: url))
        }
    }

    private func loadFromPhotoLibrary(_ asset: PHAsset) {
        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .highQualityFormat

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            if let urlAsset = avAsset as? AVURLAsset {
                DispatchQueue.main.async {
                    videoService.loadVideo(from: .local(url: urlAsset.url))
                    videoService.play()
                }
            }
        }
    }

    private func startMealSession() {
        statsService.startSession()
        setupServices()
        feedbackService.startMonitoring()
    }

    private func endMealSession() {
        feedbackService.stopMonitoring()
        cleanupServices()
        statsService.endSession()
    }

    private func setupServices() {
        let frameProcessor = FrameProcessor(visionService: visionService)
        cameraService.setFrameDelegate(frameProcessor)

        feedbackService.onShouldPlay = { [weak videoService] in
            videoService?.play()
        }
        feedbackService.onShouldPause = { [weak videoService] in
            videoService?.pause()
        }
        feedbackService.onShouldFadeOut = { [weak videoService] duration in
            videoService?.fadeOut(duration: duration, completion: nil)
        }
        feedbackService.onShouldFadeIn = { [weak videoService] duration in
            videoService?.fadeIn(duration: duration, completion: nil)
        }

        cameraService.startCapture()
        visionService.startProcessing()
    }

    private func cleanupServices() {
        visionService.stopProcessing()
        cameraService.stopCapture()
    }

    private func applySettings() {
        let settings = settingsManager.settings
        feedbackService.waitTimeSeconds = settings.waitTimeSeconds
        // Apply sensitivity to VisionService if needed
    }
}
```

---

## Task 7: 최종 테스트

### 7.1 기능 테스트 체크리스트

**영상 선택**
- [ ] YouTube URL 입력 및 재생
- [ ] 사진첩에서 영상 선택
- [ ] 로컬 영상 목록 표시 및 선택

**설정**
- [ ] 민감도 조절 및 저장
- [ ] 대기 시간 조절 및 저장
- [ ] 넛지 메시지 편집/추가/삭제
- [ ] 설정 초기화

**통계**
- [ ] 오늘 통계 표시
- [ ] 주간 차트 표시
- [ ] 최근 세션 목록 표시
- [ ] 세션 시작/종료 기록

**통합 흐름**
- [ ] 앱 시작 → 영상 선택 → 식사 세션 시작
- [ ] 먹기 감지 → 영상 재생
- [ ] 먹기 멈춤 → 카운트다운 → 넛지
- [ ] 먹기 재개 → 칭찬 → 영상 재생
- [ ] 세션 종료 → 통계 저장

### 7.2 성능 및 안정성

- [ ] 30분 연속 사용 테스트
- [ ] 메모리 누수 없음
- [ ] 배터리 소모 적정
- [ ] 앱 크래시 없음

---

## 완료 기준 (MVP 전체)

- [ ] 입술 움직임으로 "먹는 중" 판단
- [ ] 손이 얼굴 근처에 오면 "먹는 중" 판단
- [ ] 5초간 안 먹으면 영상 정지
- [ ] 넛지 화면 표시 (카메라 + 메시지)
- [ ] 먹기 시작하면 칭찬 + 영상 재생
- [ ] 유튜브/로컬 영상 재생
- [ ] 사진첩에서 영상 선택
- [ ] 일시 정지/강제 재생 버튼
- [ ] 설정에서 민감도/시간 조절
- [ ] 식사 통계 기록 및 표시
- [ ] 30분 이상 안정적 동작

---

## 배포 준비 체크리스트

- [ ] Info.plist에 카메라/사진첩 권한 설명 추가
- [ ] 앱 아이콘 설정
- [ ] Launch Screen 설정
- [ ] 번들 ID 확인
- [ ] 버전 번호 설정 (1.0.0)

---

**MVP 완성!** 🎉
