import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let url: URL
    @Binding var isPlaying: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let videoID = extractVideoID(from: url) {
            let embedURL = "https://www.youtube.com/embed/\(videoID)?autoplay=1&playsinline=1&controls=0"
            if let embedURLObject = URL(string: embedURL) {
                let request = URLRequest(url: embedURLObject)
                webView.load(request)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func extractVideoID(from url: URL) -> String? {
        let urlString = url.absoluteString

        if urlString.contains("youtu.be") {
            return url.lastPathComponent
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let videoID = queryItems.first(where: { $0.name == "v" })?.value {
            return videoID
        }

        return nil
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: YouTubePlayerView

        init(_ parent: YouTubePlayerView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isPlaying = true
        }
    }
}
