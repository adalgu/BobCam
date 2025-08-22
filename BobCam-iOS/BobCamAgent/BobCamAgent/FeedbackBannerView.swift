import SwiftUI

struct FeedbackBannerView: View {
    enum FeedbackState {
        case eating
        case notEating
        case neutral
    }

    let state: FeedbackState
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 6)
        .padding(.top, 8)
        .padding(.horizontal, 12)
        .accessibilityLabel(text)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var backgroundColor: Color {
        switch state {
        case .eating:
            return .green
        case .notEating:
            return .orange
        case .neutral:
            return .gray
        }
    }

    private var iconName: String {
        switch state {
        case .eating:
            return "checkmark.circle.fill"
        case .notEating:
            return "hand.draw.fill"
        case .neutral:
            return "waveform"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        FeedbackBannerView(state: .eating, text: "좋아요 잘 먹고 있어요.")
        FeedbackBannerView(state: .notEating, text: "밥 더 먹어요.")
        FeedbackBannerView(state: .neutral, text: "분석 중…")
    }
    .padding()
    .background(Color.black)
    .previewLayout(.sizeThatFits)
}
