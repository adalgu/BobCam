import Foundation
import Combine

protocol FeedbackServiceProtocol: ObservableObject {
    var currentState: FeedbackState { get }
    var nudgeMessage: String { get }
    var waitTimeSeconds: Int { get set }

    func startMonitoring()
    func stopMonitoring()
    func updateEatingState(_ isEating: Bool)
    func pauseByParent()
    func resumeFromParent()
    func forcePlayByParent()
}
