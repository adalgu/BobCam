import SwiftUI

struct ParentControlBar: View {
    @ObservedObject var feedbackService: FeedbackService
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: togglePause) {
                HStack {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    Text(isPaused ? "재개" : "일시정지")
                        .font(.subheadline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(20)
            }

            Button(action: forcePlay) {
                HStack {
                    Image(systemName: "forward.fill")
                    Text("강제재생")
                        .font(.subheadline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.8))
                .cornerRadius(20)
            }
            .disabled(feedbackService.currentState == .forcedByParent)
            .opacity(feedbackService.currentState == .forcedByParent ? 0.5 : 1)

            Spacer()

            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(Color.gray.opacity(0.6)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.black.opacity(0.7), .clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var isPaused: Bool {
        if case .pausedByParent = feedbackService.currentState {
            return true
        }
        return false
    }

    private func togglePause() {
        if isPaused {
            feedbackService.resumeFromParent()
        } else {
            feedbackService.pauseByParent()
        }
    }

    private func forcePlay() {
        feedbackService.forcePlayByParent()
    }
}
