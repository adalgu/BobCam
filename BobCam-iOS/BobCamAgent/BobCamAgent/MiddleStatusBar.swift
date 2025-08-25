import SwiftUI

struct MiddleStatusBar: View {
    let isEating: Bool
    let isFaceDetected: Bool
    let serviceState: VisionServiceState
    let currentLipDistance: Float
    let detectionConfidence: Float
    let consecutiveEatingFrames: Int
    
    @State private var showDetailedInfo = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main status bar
            HStack(spacing: 16) {
                // Status indicator
                HStack(spacing: 8) {
                    StatusIndicatorLight()
                    
                    Text(getStatusMessage())
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Detail toggle button
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showDetailedInfo.toggle()
                    }
                }) {
                    Image(systemName: showDetailedInfo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // Detailed info panel (expandable)
            if showDetailedInfo {
                DetailedInfoPanel()
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    getStatusColor().opacity(0.9),
                    getStatusColor().opacity(0.7)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            Rectangle()
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(0) // 가로바 형태로 모서리 없음
    }
    
    @ViewBuilder
    private func StatusIndicatorLight() -> some View {
        ZStack {
            Circle()
                .fill(getStatusColor())
                .frame(width: 16, height: 16)
            
            Circle()
                .fill(getStatusColor())
                .frame(width: 12, height: 12)
                .opacity(0.6)
                .scaleEffect(isEating ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isEating)
        }
    }
    
    @ViewBuilder
    private func DetailedInfoPanel() -> some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.3))
            
            HStack(spacing: 20) {
                // Lip movement
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.white.opacity(0.8))
                        Text("입 움직임")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    ProgressView(value: min(Double(currentLipDistance * 10), 1.0))
                        .progressViewStyle(LinearProgressViewStyle(tint: currentLipDistance > 0.08 ? .green : .yellow))
                        .frame(height: 6)
                    
                    Text(String(format: "%.3f", currentLipDistance))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Detection confidence
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .foregroundColor(.white.opacity(0.8))
                        Text("신뢰도")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    ProgressView(value: Double(detectionConfidence))
                        .progressViewStyle(LinearProgressViewStyle(tint: detectionConfidence > 0.7 ? .green : detectionConfidence > 0.4 ? .yellow : .red))
                        .frame(height: 6)
                    
                    Text("\(Int(detectionConfidence * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Consecutive frames
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.white.opacity(0.8))
                        Text("연속")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Text("\(consecutiveEatingFrames)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(consecutiveEatingFrames > 5 ? .green : .white)
                    
                    Text("frames")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
    
    private func getStatusMessage() -> String {
        switch serviceState {
        case .failed, .cameraError:
            return "감지 오류가 발생했습니다"
        case .idle, .paused:
            return "얼굴을 분석하고 있어요..."
        case .running:
            if !isFaceDetected {
                return "얼굴을 카메라 앞에 위치해주세요"
            } else if isEating {
                return "식사 중! 잘하고 있어요 🍽️"
            } else {
                return "밥을 더 먹어보세요 😊"
            }
        }
    }
    
    private func getStatusColor() -> Color {
        switch serviceState {
        case .failed, .cameraError:
            return .red
        case .idle, .paused:
            return .orange
        case .running:
            if !isFaceDetected {
                return .yellow
            } else if isEating {
                return .green
            } else {
                return .blue
            }
        }
    }
}

#Preview {
    MiddleStatusBar(
        isEating: true,
        isFaceDetected: true,
        serviceState: .running,
        currentLipDistance: 0.085,
        detectionConfidence: 0.78,
        consecutiveEatingFrames: 12
    )
}