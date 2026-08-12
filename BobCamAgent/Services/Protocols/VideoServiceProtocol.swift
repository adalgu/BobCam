import Foundation
import AVFoundation

enum VideoSource: Identifiable, Equatable {
    case youtube(url: URL)
    case photoLibrary(url: URL)
    case local(url: URL)

    var id: String {
        switch self {
        case .youtube(let url):
            return "youtube:\(url.absoluteString)"
        case .photoLibrary(let url):
            return "photo:\(url.absoluteString)"
        case .local(let url):
            return "local:\(url.absoluteString)"
        }
    }

    static func == (lhs: VideoSource, rhs: VideoSource) -> Bool {
        lhs.id == rhs.id
    }
}

protocol VideoServiceProtocol: ObservableObject {
    var isPlaying: Bool { get }
    var currentSource: VideoSource? { get }
    var player: AVPlayer? { get }

    func loadVideo(from source: VideoSource)
    func play()
    func pause()
    func fadeOut(duration: TimeInterval, completion: (() -> Void)?)
    func fadeIn(duration: TimeInterval, completion: (() -> Void)?)
}
