import Foundation

struct EatingState {
    var isEating: Bool = false
    var faceDetected: Bool = false
    var handNearFace: Bool = false
    var lipMovement: Double = 0.0
    var lastUpdated: Date = Date()
}
