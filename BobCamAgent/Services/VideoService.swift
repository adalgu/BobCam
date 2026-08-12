import Foundation
import AVFoundation
import Combine

final class VideoService: NSObject, VideoServiceProtocol, ObservableObject {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentSource: VideoSource?
    private(set) var player: AVPlayer?

    private var timeObserver: Any?

    func loadVideo(from source: VideoSource) {
        currentSource = source

        switch source {
        case .youtube:
            print("YouTube requires WebView - handled in UI layer")

        case .photoLibrary(let url), .local(let url):
            setupPlayer(with: url)
        }
    }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func fadeOut(duration: TimeInterval, completion: (() -> Void)?) {
        guard let player = player else {
            completion?()
            return
        }

        let originalVolume = player.volume
        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = originalVolume / Float(steps)

        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak player] in
                player?.volume = originalVolume - (volumeStep * Float(i + 1))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.pause()
            self?.player?.volume = originalVolume
            completion?()
        }
    }

    func fadeIn(duration: TimeInterval, completion: (() -> Void)?) {
        guard let player = player else {
            completion?()
            return
        }

        let targetVolume: Float = 1.0
        player.volume = 0
        play()

        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = targetVolume / Float(steps)

        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak player] in
                player?.volume = volumeStep * Float(i + 1)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion?()
        }
    }

    private func setupPlayer(with url: URL) {
        cleanupPlayer()

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        player?.seek(to: .zero)
        if isPlaying {
            player?.play()
        }
    }

    private func cleanupPlayer() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
        player = nil
    }

    deinit {
        cleanupPlayer()
    }
}
