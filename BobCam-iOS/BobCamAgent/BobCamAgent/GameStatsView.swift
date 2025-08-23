import SwiftUI

// MARK: - Game Stats Model
class GameStatsManager: ObservableObject {
    @Published var points: Int = 0
    @Published var level: Int = 1
    @Published var streak: Int = 0
    @Published var totalBites: Int = 0
    @Published var sessionTime: TimeInterval = 0
    
    private var lastEatingDetection: Date?
    private var sessionStartTime = Date()
    
    // Level progression thresholds
    private let pointsPerLevel = 100
    private let pointsPerBite = 10
    private let bonusPointsForStreak = 5
    private let maxStreakBonus = 50
    
    init() {
        startSession()
    }
    
    func startSession() {
        sessionStartTime = Date()
        sessionTime = 0
    }
    
    func updateEatingDetection(isEating: Bool) {
        let now = Date()
        
        if isEating && lastEatingDetection == nil {
            // New bite detected
            registerBite()
            lastEatingDetection = now
        } else if !isEating && lastEatingDetection != nil {
            // End of eating action
            lastEatingDetection = nil
        }
        
        // Update session time
        sessionTime = now.timeIntervalSince(sessionStartTime)
    }
    
    private func registerBite() {
        totalBites += 1
        streak += 1
        
        // Calculate points with streak bonus
        var earnedPoints = pointsPerBite
        let streakBonus = min(streak * bonusPointsForStreak, maxStreakBonus)
        earnedPoints += streakBonus
        
        points += earnedPoints
        
        // Check for level up
        let newLevel = (points / pointsPerLevel) + 1
        if newLevel > level {
            level = newLevel
            // Could trigger level up animation here
        }
    }
    
    func resetStreak() {
        streak = 0
    }
    
    func resetSession() {
        points = 0
        level = 1
        streak = 0
        totalBites = 0
        sessionTime = 0
        lastEatingDetection = nil
        startSession()
    }
    
    // Computed properties for display
    var progressToNextLevel: Float {
        let currentLevelPoints = (level - 1) * pointsPerLevel
        let pointsInCurrentLevel = points - currentLevelPoints
        return Float(pointsInCurrentLevel) / Float(pointsPerLevel)
    }
    
    var formattedSessionTime: String {
        let minutes = Int(sessionTime) / 60
        let seconds = Int(sessionTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Game Stats View
struct GameStatsView: View {
    @StateObject private var statsManager = GameStatsManager()
    @State private var showingDetailedStats = false
    @State private var animatePoints = false
    @State private var animateLevel = false
    
    // Bindings to eating detection
    let isEating: Bool
    let isVideoPlaying: Bool
    
    init(isEating: Bool, isVideoPlaying: Bool) {
        self.isEating = isEating
        self.isVideoPlaying = isVideoPlaying
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Main stats display
                mainStatsView(geometry)
                
                Spacer()
                
                // Detailed stats (when expanded)
                if showingDetailedStats {
                    detailedStatsView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            statsManager.startSession()
        }
        .onChange(of: isEating) { eating in
            statsManager.updateEatingDetection(isEating: eating)
            if eating {
                triggerPointsAnimation()
            }
        }
        .onChange(of: statsManager.level) { _ in
            triggerLevelAnimation()
        }
    }
    
    // MARK: - Main Stats Display
    private func mainStatsView(_ geometry: GeometryProxy) -> some View {
        HStack(spacing: 20) {
            // Points display
            pointsView()
            
            // Level display with progress
            levelView()
            
            // Streak indicator
            streakView()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .position(
            x: geometry.size.width * 0.5,
            y: geometry.size.height * 0.08
        )
        .onTapGesture {
            toggleDetailedStats()
        }
    }
    
    // MARK: - Points View
    private func pointsView() -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                
                Text("\(statsManager.points)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .scaleEffect(animatePoints ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animatePoints)
            }
            
            Text("Points")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Level View
    private func levelView() -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                
                Text("L\(statsManager.level)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .scaleEffect(animateLevel ? 1.3 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: animateLevel)
            }
            
            // Progress bar to next level
            ProgressView(value: statsManager.progressToNextLevel)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(width: 40, height: 2)
        }
    }
    
    // MARK: - Streak View
    private func streakView() -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(statsManager.streak > 0 ? .red : .gray)
                
                Text("\(statsManager.streak)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Text("Streak")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Detailed Stats View
    private func detailedStatsView() -> some View {
        VStack(spacing: 12) {
            Text("Session Stats")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                detailStatItem(
                    icon: "mouth.fill",
                    value: "\(statsManager.totalBites)",
                    label: "Bites"
                )
                
                detailStatItem(
                    icon: "clock.fill",
                    value: statsManager.formattedSessionTime,
                    label: "Time"
                )
                
                detailStatItem(
                    icon: "chart.line.uptrend.xyaxis",
                    value: "\(Int(statsManager.progressToNextLevel * 100))%",
                    label: "Progress"
                )
            }
            
            // Reset button for testing/debugging
            Button("Reset Session") {
                statsManager.resetSession()
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.blue)
            .padding(.top, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Detail Stat Item
    private func detailStatItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
            
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Animation Methods
    private func triggerPointsAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            animatePoints = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animatePoints = false
        }
    }
    
    private func triggerLevelAnimation() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            animateLevel = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animateLevel = false
        }
    }
    
    private func toggleDetailedStats() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showingDetailedStats.toggle()
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        
        GameStatsView(isEating: false, isVideoPlaying: true)
    }
}