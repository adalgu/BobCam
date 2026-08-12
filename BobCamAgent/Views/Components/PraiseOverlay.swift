import SwiftUI

struct PraiseOverlay: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    private let praiseMessages = ["잘하고 있어!", "최고야!", "멋져!"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            Text(praiseMessages.randomElement() ?? "잘하고 있어!")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .green.opacity(0.8), radius: 20, x: 0, y: 0)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.2
                opacity = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.2)) {
                    scale = 1.0
                }
            }
        }
    }
}
