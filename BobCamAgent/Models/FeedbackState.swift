import Foundation

enum FeedbackState: Equatable {
    case playing
    case waiting(secondsRemaining: Int)
    case nudging
    case praising
    case pausedByParent
    case forcedByParent

    var isVideoPlaying: Bool {
        switch self {
        case .playing, .forcedByParent:
            return true
        default:
            return false
        }
    }
}
