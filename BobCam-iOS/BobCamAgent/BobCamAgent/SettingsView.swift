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
    @AppStorage("showFeedbackBanner") private var showFeedbackBanner: Bool = true
    @AppStorage("useMultiModalDetection") private var useMultiModalDetection: Bool = false

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
                        showAccuracyDisplay: $showAccuracyDisplay,
                        useMultiModalDetection: $useMultiModalDetection
                    )

                    // User Experience Settings
                    UserExperienceSection(
                        showingResetConfirmation: $showingResetConfirmation,
                        showPerformanceMetrics: $showPerformanceMetrics,
                        showAccuracyDisplay: $showAccuracyDisplay,
                        showFeedbackBanner: $showFeedbackBanner
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
                selectionService: selectionService
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
    @Binding var useMultiModalDetection: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Algorithm Settings", icon: "brain.head.profile")

            // Sensitivity Control
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Detection Sensitivity")
                        .font(.subheadline)

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
                            .lineLimit(2)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Current Detection Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Status")
                    .font(.subheadline)

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

            // Detection Method Selection
            VStack(alignment: .leading, spacing: 8) {
                Toggle("멀티모달 감지 (실험적)", isOn: $useMultiModalDetection)
                    .font(.subheadline)
                
                if useMultiModalDetection {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("멀티모달 감지 활성화:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• 입술 움직임 감지")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• 손 동작 감지 (8fps)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• 숟가락/젓가락 감지 (4fps)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("⚠️ 베타 기능: 배터리 사용량이 증가할 수 있습니다")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                    }
                    .padding(.top, 4)
                } else {
                    Text("기본 립 트래킹 모드 (15fps)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Debug Mode Toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Debug Mode", isOn: $isDebugModeEnabled)
                    .font(.subheadline)

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

                        // PHASE 3: Safe landmarks overlay warning
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("⚠️ Landmarks Overlay (Disabled)")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("This feature has been disabled due to app crash issues. Use Debug mode in development builds only.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
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

// MARK: - User Experience Settings Section
struct UserExperienceSection: View {
    @Binding var showingResetConfirmation: Bool
    @Binding var showPerformanceMetrics: Bool
    @Binding var showAccuracyDisplay: Bool
    @Binding var showFeedbackBanner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "User Experience", icon: "person.crop.circle")

            VStack(spacing: 12) {
                // Feedback banner toggle
                ToggleRow(
                    title: "Feedback Banner",
                    description: "Show guidance message at the top",
                    isOn: $showFeedbackBanner
                )

                Divider()

                // Performance monitoring toggle
                ToggleRow(
                    title: "Performance Monitoring",
                    description: "Display real-time performance metrics",
                    isOn: $showPerformanceMetrics
                )

                Divider()

                // Accuracy display toggle
                ToggleRow(
                    title: "Accuracy Display",
                    description: "Show algorithm accuracy information",
                    isOn: $showAccuracyDisplay
                )

                Divider()

                // Reset to defaults button
                Button(action: {
                    showingResetConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.red)
                        Text("Reset to Defaults")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .accessibilityLabel("Reset all settings to default values")
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Privacy and App Information Section
struct PrivacyAndAppInfoSection: View {
    @Binding var showingPrivacyPolicy: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Privacy & Information", icon: "shield.checkered")

            // App Information
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                    
                    Text("앱 정보")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("버전:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("빌드:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("빌드 시간:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(getCurrentBuildTime())
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
                .padding(.leading, 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            
            VStack(spacing: 12) {
                InfoRow(title: "iOS Minimum", value: "15.0+")
                InfoRow(title: "Developer", value: "BobCam Team")
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Privacy Information
            VStack(spacing: 12) {
                Button(action: {
                    showingPrivacyPolicy = true
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text("Privacy Policy")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .accessibilityLabel("View privacy policy")

                Divider()

                HStack {
                    Image(systemName: "checkmark.shield")
                        .foregroundColor(.green)
                    Text("Child Safety Compliant")
                        .foregroundColor(.primary)
                    Spacer()
                }
                .accessibilityLabel("Child safety compliant application")
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Data Processing Information
            InfoBox(
                title: "Local Processing Only",
                message: "All video processing occurs locally on your device. No data is transmitted to external servers, ensuring complete privacy and security for your family.",
                icon: "shield.checkered"
            )

            // Parental Controls Information
            InfoBox(
                title: "Parental Controls",
                message: "BobCam is designed with child safety in mind. The app requires no internet connection and processes all data locally to protect your child's privacy.",
                icon: "person.2.fill"
            )
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private func getCurrentBuildTime() -> String {
        #if DEBUG
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return "DEBUG - " + formatter.string(from: Date())
        #else
        return Bundle.main.infoDictionary?["BuildTimestamp"] as? String ?? "Unknown"
        #endif
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
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

struct ToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: $isOn)
                .font(.subheadline)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy Policy")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Last Updated: \(formattedDate)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        PolicySection(
                            title: "Data Collection",
                            content: "BobCam does not collect, store, or transmit any personal data. All video processing occurs locally on your device using Apple's Vision Framework."
                        )

                        PolicySection(
                            title: "Camera Usage",
                            content: "The app accesses your device's front-facing camera solely for real-time lip movement detection. Camera data is processed in real-time and never saved to device storage or transmitted externally."
                        )

                        PolicySection(
                            title: "Video Content",
                            content: "Videos selected from your photo library are temporarily accessed for playback only. No video content is modified, copied, or transmitted outside of your device."
                        )

                        PolicySection(
                            title: "Child Safety",
                            content: "BobCam is designed with child safety as a priority. The app operates entirely offline, requires no user accounts, and processes all data locally to ensure maximum privacy protection for families."
                        )

                        PolicySection(
                            title: "Third-Party Services",
                            content: "BobCam does not integrate with any third-party analytics, advertising, or data collection services. The app is completely self-contained."
                        )

                        PolicySection(
                            title: "Data Security",
                            content: "Since no data is collected or transmitted, there are no data security risks associated with external storage or transmission. All processing occurs within iOS's secure app sandbox."
                        )

                        PolicySection(
                            title: "Contact Information",
                            content: "For privacy-related questions or concerns, please contact us at privacy@bobcam.app"
                        )
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }
}

struct PolicySection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(content)")
    }
}

// MARK: - VisionServiceState Extension for UI Display
extension VisionServiceState {
    var displayString: String {
        switch self {
        case .idle:
            return "Idle"
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        case .failed:
            return "Error"
        case .cameraError:
            return "Camera Error"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .gray
        case .running:
            return .green
        case .paused:
            return .orange
        case .failed, .cameraError:
            return .red
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
