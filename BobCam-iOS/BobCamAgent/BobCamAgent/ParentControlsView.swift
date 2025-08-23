import SwiftUI

// MARK: - Parent Controls View
struct ParentControlsView: View {
    @State private var showingParentPanel = false
    @State private var parentPanelOffset: CGFloat = 0
    @State private var isAuthenticated = false
    @State private var showingAuthenticationAlert = false
    @State private var authenticationCode = ""
    @State private var enteredCode = ""
    
    // Parent settings
    @State private var sessionDuration: Double = 15 // minutes
    @State private var enableBreakReminders = true
    @State private var sensitivityLevel: Double = 0.5
    @State private var enableSounds = true
    @State private var enableHaptics = true
    
    // Services for control
    @ObservedObject var videoService: VideoService
    @ObservedObject var videoSelectionService: VideoSelectionService
    @ObservedObject var visionService: VisionService
    
    // Generated parent code (in production, this should be more secure)
    private let parentCode = "1234"
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Parent access button (subtle, top-left)
                parentAccessButton(geometry)
                
                // Parent control panel (slides from top)
                parentControlPanel(geometry)
            }
        }
    }
    
    // MARK: - Parent Access Button
    private func parentAccessButton(_ geometry: GeometryProxy) -> some View {
        Button(action: {
            requestParentAccess()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12))
                
                Text("Parent")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .position(
            x: geometry.size.width * 0.1,
            y: geometry.size.height * 0.05
        )
        .alert("Parent Access", isPresented: $showingAuthenticationAlert) {
            SecureField("Enter code", text: $enteredCode)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
            
            Button("Cancel") {
                enteredCode = ""
            }
            
            Button("Access") {
                authenticateParent()
            }
        } message: {
            Text("Enter the parent code to access controls")
        }
    }
    
    // MARK: - Parent Control Panel
    private func parentControlPanel(_ geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Panel header
            panelHeader()
            
            // Panel content
            if isAuthenticated && showingParentPanel {
                panelContent()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .frame(width: geometry.size.width * 0.9)
        .position(
            x: geometry.size.width * 0.5,
            y: geometry.size.height * 0.3 + parentPanelOffset
        )
        .offset(y: showingParentPanel ? 0 : -geometry.size.height)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showingParentPanel)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let translationY = value.translation.height
                    if translationY > 0 {
                        parentPanelOffset = translationY * 0.3
                    }
                }
                .onEnded { value in
                    let translationY = value.translation.height
                    if translationY > 50 {
                        closeParentPanel()
                    }
                    parentPanelOffset = 0
                }
        )
    }
    
    // MARK: - Panel Header
    private func panelHeader() -> some View {
        HStack {
            Image(systemName: "person.2.badge.gearshape.fill")
                .font(.system(size: 18))
                .foregroundColor(.blue)
            
            Text("Parent Controls")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: closeParentPanel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.clear)
    }
    
    // MARK: - Panel Content
    private func panelContent() -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Session controls
                sessionControlsSection()
                
                // Detection settings
                detectionSettingsSection()
                
                // Video controls
                videoControlsSection()
                
                // App settings
                appSettingsSection()
                
                // Action buttons
                actionButtonsSection()
            }
            .padding()
        }
        .frame(maxHeight: 400)
    }
    
    // MARK: - Session Controls Section
    private func sessionControlsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Session Controls", icon: "clock.fill")
            
            VStack(spacing: 8) {
                HStack {
                    Text("Duration:")
                    Spacer()
                    Text("\(Int(sessionDuration)) min")
                        .foregroundColor(.blue)
                }
                
                Slider(value: $sessionDuration, in: 5...60, step: 5)
                    .tint(.blue)
            }
            
            Toggle("Break Reminders", isOn: $enableBreakReminders)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
        )
    }
    
    // MARK: - Detection Settings Section
    private func detectionSettingsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Detection Settings", icon: "eye.fill")
            
            VStack(spacing: 8) {
                HStack {
                    Text("Sensitivity:")
                    Spacer()
                    Text(sensitivityText)
                        .foregroundColor(.blue)
                }
                
                Slider(value: $sensitivityLevel, in: 0...1, step: 0.1)
                    .tint(.blue)
                    .onChange(of: sensitivityLevel) { value in
                        visionService.sensitivity = Float(value)
                    }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
        )
    }
    
    // MARK: - Video Controls Section
    private func videoControlsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Video Controls", icon: "play.rectangle.fill")
            
            HStack(spacing: 12) {
                Button("Pause Video") {
                    videoService.pauseVideo()
                }
                .buttonStyle(parentControlButtonStyle(color: .orange))
                
                Button("Play Video") {
                    videoService.playVideo()
                }
                .buttonStyle(parentControlButtonStyle(color: .green))
            }
            
            Button("Change Video") {
                // This would trigger video selection
                videoSelectionService.isShowingVideoPicker = true
            }
            .buttonStyle(parentControlButtonStyle(color: .blue))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
        )
    }
    
    // MARK: - App Settings Section
    private func appSettingsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("App Settings", icon: "gear.fill")
            
            VStack(spacing: 8) {
                Toggle("Sound Effects", isOn: $enableSounds)
                Toggle("Haptic Feedback", isOn: $enableHaptics)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
        )
    }
    
    // MARK: - Action Buttons Section
    private func actionButtonsSection() -> some View {
        VStack(spacing: 12) {
            Button("Reset Session Stats") {
                // Reset game stats
                // This would need to be connected to GameStatsManager
            }
            .buttonStyle(parentControlButtonStyle(color: .yellow))
            
            Button("Emergency Stop") {
                emergencyStop()
            }
            .buttonStyle(parentControlButtonStyle(color: .red))
        }
        .padding()
    }
    
    // MARK: - Helper Views
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    private var sensitivityText: String {
        switch sensitivityLevel {
        case 0.0..<0.3:
            return "Low"
        case 0.3..<0.7:
            return "Medium"
        default:
            return "High"
        }
    }
    
    // MARK: - Action Methods
    private func requestParentAccess() {
        enteredCode = ""
        showingAuthenticationAlert = true
    }
    
    private func authenticateParent() {
        if enteredCode == parentCode {
            isAuthenticated = true
            showingParentPanel = true
            showingAuthenticationAlert = false
        } else {
            // Show error feedback
            enteredCode = ""
        }
    }
    
    private func closeParentPanel() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showingParentPanel = false
        }
        
        // Auto-logout after 30 seconds of inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if showingParentPanel == false {
                isAuthenticated = false
            }
        }
    }
    
    private func emergencyStop() {
        videoService.pauseVideo()
        visionService.stopTracking()
        closeParentPanel()
        
        // Could add additional emergency actions here
    }
}

// MARK: - Parent Control Button Style
struct parentControlButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        
        ParentControlsView(
            videoService: VideoService(),
            videoSelectionService: VideoSelectionService(videoService: VideoService()),
            visionService: VisionService()
        )
    }
}