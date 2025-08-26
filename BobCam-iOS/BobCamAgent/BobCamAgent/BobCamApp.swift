import SwiftUI

@main
struct BobCamApp: App {
    var body: some Scene {
        WindowGroup {
            // Using ContentView with debug logging for video control testing
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    // Debug video loading on launch
                    // VideoLoadingDebugger.testDemoVideoLoading()
                }
        }
    }
}
