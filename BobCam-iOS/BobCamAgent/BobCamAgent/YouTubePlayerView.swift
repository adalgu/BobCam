import SwiftUI
import WebKit
import Combine

// MARK: - YouTube Player State
enum YouTubePlayerState: Int, CaseIterable {
    case unstarted = -1
    case ended = 0
    case playing = 1
    case paused = 2
    case buffering = 3
    case cued = 5
    
    var isPlaying: Bool {
        return self == .playing
    }
    
    var isPaused: Bool {
        return self == .paused
    }
}



// MARK: - YouTube Player View
struct YouTubePlayerView: UIViewRepresentable {
    let youTubeVideo: YouTubeVideo
    @Binding var playerState: YouTubePlayerState
    @Binding var isReady: Bool
    var onStateChange: ((YouTubePlayerState) -> Void)? = nil
    var onReady: (() -> Void)? = nil
    var onError: ((Error) -> Void)? = nil
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        
        // Configure for media playback
        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        webView.configuration.allowsPictureInPictureMediaPlayback = false
        
        // Set up JavaScript message handling
        let contentController = webView.configuration.userContentController
        contentController.add(context.coordinator, name: "playerStateChanged")
        contentController.add(context.coordinator, name: "playerReady")
        contentController.add(context.coordinator, name: "playerError")
        
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load if the video has changed or if not yet loaded
        if let currentURL = webView.url, currentURL != youTubeVideo.embedURL {
            loadYouTubeVideo(in: webView)
        } else if webView.url == nil {
            loadYouTubeVideo(in: webView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func loadYouTubeVideo(in webView: WKWebView) {
        guard let embedURL = youTubeVideo.embedURL else {
            onError?(YouTubePlayerError.invalidURL)
            return
        }
        
        let htmlString = generateHTMLString(for: youTubeVideo)
        webView.loadHTMLString(htmlString, baseURL: embedURL)
    }
    
    private func generateHTMLString(for video: YouTubeVideo) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    background-color: black;
                    overflow: hidden;
                }
                #player {
                    width: 100vw;
                    height: 100vh;
                    border: none;
                }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <script>
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                
                var player;
                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        height: '100%',
                        width: '100%',
                        videoId: '\(video.videoId)',
                        playerVars: {
                            'playsinline': 1,
                            'controls': 0,
                            'rel': 0,
                            'modestbranding': 1,
                            'fs': 0,
                            'disablekb': 1,
                            'iv_load_policy': 3,
                            'cc_load_policy': 0,
                            'loop': 1,
                            'playlist': '\(video.videoId)',
                            'mute': 0,
                            'autoplay': 0
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError
                        }
                    });
                }
                
                function onPlayerReady(event) {
                    window.webkit.messageHandlers.playerReady.postMessage('ready');
                }
                
                function onPlayerStateChange(event) {
                    window.webkit.messageHandlers.playerStateChanged.postMessage(event.data);
                }
                
                function onPlayerError(event) {
                    window.webkit.messageHandlers.playerError.postMessage(event.data);
                }
                
                // Control functions that can be called from Swift
                function playVideo() {
                    if (player && player.playVideo) {
                        player.playVideo();
                    }
                }
                
                function pauseVideo() {
                    if (player && player.pauseVideo) {
                        player.pauseVideo();
                    }
                }
                
                function stopVideo() {
                    if (player && player.stopVideo) {
                        player.stopVideo();
                    }
                }
                
                function seekToStart() {
                    if (player && player.seekTo) {
                        player.seekTo(0);
                    }
                }
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - Coordinator
extension YouTubePlayerView {
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: YouTubePlayerView
        
        init(_ parent: YouTubePlayerView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                switch message.name {
                case "playerReady":
                    self.parent.isReady = true
                    self.parent.onReady?()
                    
                case "playerStateChanged":
                    if let stateValue = message.body as? Int,
                       let state = YouTubePlayerState(rawValue: stateValue) {
                        self.parent.playerState = state
                        self.parent.onStateChange?(state)
                    }
                    
                case "playerError":
                    let error = YouTubePlayerError.playbackError(message.body as? Int ?? -1)
                    self.parent.onError?(error)
                    
                default:
                    break
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.onError?(error)
            }
        }
    }
}

// MARK: - YouTube Player Controller
class YouTubePlayerController: ObservableObject {
    @Published var playerState: YouTubePlayerState = .unstarted
    @Published var isReady: Bool = false
    @Published var currentVideo: YouTubeVideo?
    
    private weak var webView: WKWebView?
    
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }
    
    func play() {
        executeJavaScript("playVideo()")
    }
    
    func pause() {
        executeJavaScript("pauseVideo()")
    }
    
    func stop() {
        executeJavaScript("stopVideo()")
    }
    
    func seekToStart() {
        executeJavaScript("seekToStart()")
    }
    
    private func executeJavaScript(_ script: String) {
        guard isReady else { return }
        
        webView?.evaluateJavaScript(script) { [weak self] result, error in
            if let error = error {
                print("YouTube Player JavaScript error: \(error)")
            }
        }
    }
}

// MARK: - YouTube Player Errors
enum YouTubePlayerError: LocalizedError {
    case invalidURL
    case playbackError(Int)
    case networkError
    case restrictedContent
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "유효하지 않은 YouTube URL입니다"
        case .playbackError(let code):
            return "YouTube 재생 오류 (코드: \(code))"
        case .networkError:
            return "네트워크 연결을 확인해주세요"
        case .restrictedContent:
            return "제한된 콘텐츠입니다"
        }
    }
}