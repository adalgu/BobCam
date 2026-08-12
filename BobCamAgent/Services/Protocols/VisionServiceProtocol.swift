import Foundation
import CoreVideo

protocol VisionServiceProtocol: ObservableObject {
    var isEating: Bool { get }
    var faceDetected: Bool { get }
    var handNearFace: Bool { get }
    var lipMovement: Double { get }

    func startProcessing()
    func stopProcessing()
    func processFrame(_ pixelBuffer: CVPixelBuffer)
}
