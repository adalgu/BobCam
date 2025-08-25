import SwiftUI

// MARK: - Status Bar UI Component
struct StatusBar: View {
    let isEating: Bool
    @ObservedObject var visionService: VisionService
    @ObservedObject var videoService: VideoService
    @ObservedObject var videoSelectionService: VideoSelectionService
    @Binding var sensitivity: Float
    @Binding var manualOverride: Bool // State에서 Binding으로 변경
    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 12) {
            // 감지 상태 인디케이터
            EatingStatusIndicator(isEating: isEating || manualOverride)

            Spacer(minLength: 8)

            // 민감도 슬라이더
            SensitivitySlider(sensitivity: $sensitivity)

            Spacer(minLength: 8)

            // Override 버튼
            OverrideButton(isActive: $manualOverride)
            
            // 비디오 테스트 버튼 (디버깅용)
            Button(action: {
                print("[StatusBar] 수동 비디오 재생 테스트")
                videoService.playVideo()
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            // 식사 감지 테스트 버튼 (디버깅용)
            Button(action: {
                print("[StatusBar] 식사 감지 상태 강제 토글")
                visionService.isEating.toggle()
            }) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }

            // 설정 버튼
            SettingsButton(action: { showSettings = true })
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 8)
        )
        .sheet(isPresented: $showSettings) {
            SettingsView(
                videoSelectionService: videoSelectionService,
                videoService: videoService,
                visionService: visionService,
                isPresented: $showSettings
            )
        }
    }
}

// MARK: - Eating Status Indicator
struct EatingStatusIndicator: View {
    let isEating: Bool

    var body: some View {
        HStack(spacing: 8) {
            // LED 스타일 인디케이터
            Circle()
                .fill(isEating ? .green : .red)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .fill(isEating ? .green : .red)
                        .scaleEffect(isEating ? 1.5 : 1.0)
                        .opacity(isEating ? 0.3 : 0.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                 value: isEating)
                )

            // 상태 텍스트
            Text(isEating ? "식사 중" : "대기 중")
                .font(.caption)
                .foregroundColor(isEating ? .green : .secondary)
        }
        .accessibilityLabel(isEating ? "아이가 식사 중입니다" : "식사 감지 대기 중입니다")
    }
}

// MARK: - Sensitivity Slider
struct SensitivitySlider: View {
    @Binding var sensitivity: Float
    @State private var isAdjusting = false

    var body: some View {
        VStack(spacing: 4) {
            Text("민감도")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)

                Slider(value: $sensitivity, in: 0.1...1.0, step: 0.1) { editing in
                    isAdjusting = editing
                }
                .frame(width: 70)
                .accentColor(.blue)

                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Text("\(Int(sensitivity * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .animation(.none, value: sensitivity)
        }
        .frame(maxWidth: 100)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("감지 민감도")
        .accessibilityValue("\(Int(sensitivity * 100))퍼센트")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                sensitivity = min(1.0, sensitivity + 0.1)
            case .decrement:
                sensitivity = max(0.1, sensitivity - 0.1)
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Override Button
struct OverrideButton: View {
    @Binding var isActive: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isActive.toggle()
            }

            // 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }) {
            VStack(spacing: 4) {
                Image(systemName: isActive ? "hand.raised.fill" : "hand.raised")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isActive ? .white : .blue)

                Text("수동")
                    .font(.caption2)
                    .foregroundColor(isActive ? .white : .blue)
            }
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? .blue : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isActive ? .clear : .blue, lineWidth: 2)
                    )
            )
        }
        .scaleEffect(isActive ? 1.1 : 1.0)
        .accessibilityLabel("수동 제어")
        .accessibilityHint(isActive ? "수동 제어가 활성화됨. 탭하여 비활성화" : "탭하여 수동 제어 활성화")
    }
}

// MARK: - Settings Button
struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .accessibilityLabel("설정")
        .accessibilityHint("앱 설정을 엽니다")
    }
}

// MARK: - Preview
struct StatusBar_Previews: PreviewProvider {
    static var previews: some View {
        let videoService = VideoService()
        VStack {
            Spacer()

            StatusBar(
                isEating: true,
                visionService: VisionService(),
                videoService: videoService,
                videoSelectionService: VideoSelectionService(videoService: videoService),
                sensitivity: .constant(0.5),
                manualOverride: .constant(false)
            )
            .padding()
        }
        .background(Color.black)
        .previewDisplayName("Status Bar - Eating")

        VStack {
            Spacer()

            StatusBar(
                isEating: false,
                visionService: VisionService(),
                videoService: videoService,
                videoSelectionService: VideoSelectionService(videoService: videoService),
                sensitivity: .constant(0.7),
                manualOverride: .constant(false)
            )
            .padding()
        }
        .background(Color.black)
        .previewDisplayName("Status Bar - Waiting")
    }
}
