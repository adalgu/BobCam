import SwiftUI

@main
struct BobCamApp: App {
    var body: some Scene {
        WindowGroup {
            OnboardingView()
                .preferredColorScheme(.dark) // 아이들 눈에 편안한 다크 모드
        }
    }
}
