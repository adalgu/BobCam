import SwiftUI

@main
struct BobCamApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // In debug builds show the debug-enabled content view so the debug overlay (including lip toggle) is available.
            ContentViewFactory.createContentView()
                .preferredColorScheme(.dark)
            #else
            // Production app flow: onboarding first
            OnboardingView()
                .preferredColorScheme(.dark) // 아이들 눈에 편안한 다크 모드
            #endif
        }
    }
}
