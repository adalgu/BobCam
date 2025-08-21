import SwiftUI

// MARK: - Status Bar UI Component
struct StatusBar: View {
    let isEating: Bool
    @ObservedObject var visionService: VisionService
    @ObservedObject var videoService: VideoService
    @ObservedObject var videoSelectionService: VideoSelectionService
    @Binding var sensitivity: Float
    @State private var showSettings = false
    @State private var manualOverride = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 감지 상태 인디케이터
            EatingStatusIndicator(isEating: isEating || manualOverride)
            
            Spacer()
            
            // 민감도 슬라이더
            SensitivitySlider(sensitivity: $sensitivity)
            
            Spacer()
            
            // Override 버튼
            OverrideButton(isActive: $manualOverride)
            
            // 설정 버튼
            SettingsButton(action: { showSettings = true })
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
            
            HStack(spacing: 8) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Slider(value: $sensitivity, in: 0.1...1.0, step: 0.1) { editing in
                    isAdjusting = editing
                }
                .frame(width: 80)
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
