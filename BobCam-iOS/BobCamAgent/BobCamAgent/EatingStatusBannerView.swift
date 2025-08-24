import SwiftUI

// MARK: - Eating Status Banner View
struct EatingStatusBannerView: View {
    enum DetectionStatus {
        case eating
        case notEating
        case analyzing
        case noFaceDetected
        case error
        
        var message: String {
            switch self {
            case .eating:
                return "식사 중! 잘하고 있어요 🍽️"
            case .notEating:
                return "밥을 더 먹어보세요 😊"
            case .analyzing:
                return "얼굴을 분석하고 있어요..."
            case .noFaceDetected:
                return "얼굴을 카메라 앞에 위치해주세요"
            case .error:
                return "감지 오류가 발생했습니다"
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .eating:
                return .green
            case .notEating:
                return .orange
            case .analyzing:
                return .blue
            case .noFaceDetected:
                return .gray
            case .error:
                return .red
            }
        }
        
        var iconName: String {
            switch self {
            case .eating:
                return "checkmark.circle.fill"
            case .notEating:
                return "exclamationmark.circle.fill"
            case .analyzing:
                return "magnifyingglass.circle.fill"
            case .noFaceDetected:
                return "person.circle.fill"
            case .error:
                return "xmark.circle.fill"
            }
        }
    }
    
    let status: DetectionStatus
    @State private var isVisible: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon with animation
            Image(systemName: status.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .scaleEffect(isVisible ? 1.1 : 0.9)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isVisible)
            
            // Status message
            Text(status.message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(status.backgroundColor.opacity(0.9))
                .shadow(color: status.backgroundColor.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            isVisible = true
        }
        .accessibilityLabel(status.message)
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        EatingStatusBannerView(status: .eating)
        EatingStatusBannerView(status: .notEating)
        EatingStatusBannerView(status: .analyzing)
        EatingStatusBannerView(status: .noFaceDetected)
        EatingStatusBannerView(status: .error)
    }
    .padding()
    .background(Color.black)
    .previewLayout(.sizeThatFits)
}