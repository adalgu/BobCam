import Foundation
import Combine

final class FeedbackService: ObservableObject, FeedbackServiceProtocol {
    @Published private(set) var currentState: FeedbackState = .playing
    @Published var nudgeMessage: String = "밥 먹자!"

    var waitTimeSeconds: Int = 5

    private var isMonitoring = false
    private var waitTimer: Timer?
    private var praiseTimer: Timer?
    private var forcePlayTimer: Timer?
    private var currentWaitSeconds: Int = 0
    private var pauseCount: Int = 0

    private let nudgeMessages = ["밥 먹자!", "냠냠!", "한 입 더!"]

    var onShouldPlay: (() -> Void)?
    var onShouldPause: (() -> Void)?
    var onShouldFadeOut: ((TimeInterval) -> Void)?
    var onShouldFadeIn: ((TimeInterval) -> Void)?

    func startMonitoring() {
        isMonitoring = true
        currentState = .playing
        onShouldPlay?()
    }

    func stopMonitoring() {
        isMonitoring = false
        invalidateAllTimers()
        currentState = .playing
    }

    func updateEatingState(_ isEating: Bool) {
        guard isMonitoring else { return }

        if case .pausedByParent = currentState { return }
        if case .forcedByParent = currentState { return }

        if isEating {
            handleEatingDetected()
        } else {
            handleNotEating()
        }
    }

    func pauseByParent() {
        invalidateAllTimers()
        currentState = .pausedByParent
        onShouldPause?()
    }

    func resumeFromParent() {
        currentState = .playing
        onShouldPlay?()
    }

    func forcePlayByParent() {
        invalidateAllTimers()
        currentState = .forcedByParent
        onShouldPlay?()

        forcePlayTimer = Timer.scheduledTimer(withTimeInterval: Constants.Timing.forcePlayDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentState = .playing
            }
        }
    }

    private func handleEatingDetected() {
        switch currentState {
        case .waiting:
            invalidateWaitTimer()
            currentState = .playing

        case .nudging:
            showPraise()

        case .praising, .playing, .pausedByParent, .forcedByParent:
            break
        }
    }

    private func handleNotEating() {
        switch currentState {
        case .playing:
            startWaitCountdown()

        case .waiting, .nudging, .praising, .pausedByParent, .forcedByParent:
            break
        }
    }

    private func startWaitCountdown() {
        currentWaitSeconds = waitTimeSeconds
        currentState = .waiting(secondsRemaining: currentWaitSeconds)

        waitTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickWaitTimer()
        }
    }

    private func tickWaitTimer() {
        currentWaitSeconds -= 1

        if currentWaitSeconds <= 0 {
            invalidateWaitTimer()
            showNudge()
        } else {
            currentState = .waiting(secondsRemaining: currentWaitSeconds)
        }
    }

    private func showNudge() {
        pauseCount += 1
        nudgeMessage = nudgeMessages.randomElement() ?? "밥 먹자!"
        currentState = .nudging

        if pauseCount <= 2 {
            onShouldFadeOut?(Constants.Animation.fadeOutDuration)
        } else {
            onShouldPause?()
        }
    }

    private func showPraise() {
        currentState = .praising

        praiseTimer = Timer.scheduledTimer(withTimeInterval: Constants.Timing.praiseDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentState = .playing
                self?.onShouldFadeIn?(Constants.Animation.fadeInDuration)
            }
        }
    }

    private func invalidateAllTimers() {
        invalidateWaitTimer()
        praiseTimer?.invalidate()
        praiseTimer = nil
        forcePlayTimer?.invalidate()
        forcePlayTimer = nil
    }

    private func invalidateWaitTimer() {
        waitTimer?.invalidate()
        waitTimer = nil
    }

    deinit {
        invalidateAllTimers()
    }
}
