import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var videoSelectionService: VideoSelectionService
    @ObservedObject var videoService: VideoService
    @ObservedObject var visionService: VisionService
    @Binding var isPresented: Bool
    
    // Local state for settings
    @State private var isDebugModeEnabled = false
    @State private var showPerformanceMetrics = false
    @State private var showAccuracyDisplay = false
    @State private var showingResetConfirmation = false
    @State private var showingPrivacyPolicy = false
    @State private var selectedSensitivity: Double = 0.5
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Video Management Settings
                    VideoSettingsSection(
                        selectionService: videoSelectionService,
                        videoService: videoService
                    )
                    
                    // Algorithm Parameter Controls
                    AlgorithmSettingsSection(
                        visionService: visionService,
                        selectedSensitivity: $selectedSensitivity,
                        isDebugModeEnabled: $isDebugModeEnabled,
                        showPerformanceMetrics: $showPerformanceMetrics,
                        showAccuracyDisplay: $showAccuracyDisplay
                    )
                    
                    // User Experience Settings
                    UserExperienceSection(
                        showingResetConfirmation: $showingResetConfirmation,
                        showPerformanceMetrics: $showPerformanceMetrics,
                        showAccuracyDisplay: $showAccuracyDisplay
                    )
                    
                    // Privacy and App Information
                    PrivacyAndAppInfoSection(
                        showingPrivacyPolicy: $showingPrivacyPolicy
                    )
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .accessibilityLabel("Close settings")
                }
            }
        }
        .onAppear {
            selectedSensitivity = Double(visionService.sensitivity)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .alert("Reset to Defaults", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }
    
    private func resetToDefaults() {
        visionService.sensitivity = 0.5
        selectedSensitivity = 0.5
        isDebugModeEnabled = false
        showPerformanceMetrics = false
        showAccuracyDisplay = false
        videoSelectionService.resetToDefaultVideo()
    }
}

// MARK: - Video Settings Section
struct VideoSettingsSection: View {
    @ObservedObject var selectionService: VideoSelectionService
    @ObservedObject var videoService: VideoService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "비디오 설정", icon: "video")
            
            // 비디오 선택 카드
            VideoPreviewCard(
                selectionService: selectionService,
                videoService: videoService
            )
            
            // 비디오 선택 버튼
            HStack {
                VideoSelectionButton(selectionService: selectionService)
                Spacer()
            }
            
            // 비디오 설정 안내
            InfoBox(
                title: "비디오 선택 안내",
                message: "갤러리에서 원하는 비디오를 선택하여 재생할 수 있습니다. 최대 100MB까지 지원되며, mp4, mov 형식을 권장합니다.",
                icon: "info.circle"
            )
        }
    }
}

// MARK: - Algorithm Parameter Controls Section  
struct AlgorithmSettingsSection: View {
    @ObservedObject var visionService: VisionService
    @Binding var selectedSensitivity: Double
    @Binding var isDebugModeEnabled: Bool
    @Binding var showPerformanceMetrics: Bool
    @Binding var showAccuracyDisplay: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Algorithm Settings", icon: "brain.head.profile")
            
            // Sensitivity Control
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Detection Sensitivity")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f", selectedSensitivity))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Current sensitivity: \(String(format: "%.1f", selectedSensitivity))")
                }
                
                Slider(
                    value: $selectedSensitivity,
                    in: 0.1...2.0,
                    step: 0.1
                ) {
                    Text("Sensitivity")
                } minimumValueLabel: {
                    Text("Low")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("High")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .onChange(of: selectedSensitivity) { newValue in
                    visionService.sensitivity = Float(newValue)
                }
                .accessibilityValue("Sensitivity \(String(format: "%.1f", selectedSensitivity))")
                
                Text("Higher sensitivity detects subtle movements, lower sensitivity requires more pronounced eating motions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Current Detection Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Status")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Circle()
                        .fill(visionService.isEating ? .green : .red)
                        .frame(width: 12, height: 12)
                    
                    Text(visionService.isEating ? "Eating Detected" : "Not Eating")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(visionService.serviceState.displayString)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(visionService.serviceState.color.opacity(0.2))
                        .foregroundColor(visionService.serviceState.color)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Debug Mode Toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Debug Mode", isOn: $isDebugModeEnabled)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isDebugModeEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug features enabled:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Real-time algorithm monitoring")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• Performance metrics display")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• Detailed logging")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - App Info Section
struct AppInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "앱 정보", icon: "info.circle")
            
            VStack(spacing: 12) {
                InfoRow(title: "버전", value: "1.0.0")
                InfoRow(title: "개발자", value: "BobCam Team")
                InfoRow(title: "지원", value: "support@bobcam.app")
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 개인정보 처리방침 안내
            InfoBox(
                title: "개인정보 보호",
                message: "모든 비디오 처리는 기기 내에서만 이루어지며, 외부 서버로 데이터가 전송되지 않습니다.",
                icon: "shield.checkered"
            )
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

struct InfoBox: View {
    let title: String
    let message: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView(
        videoSelectionService: VideoSelectionService(videoService: VideoService()),
        videoService: VideoService(),
        visionService: VisionService(),
        isPresented: .constant(true)
    )
}