import Foundation
import AVFoundation

protocol CameraServiceProtocol: ObservableObject {
    var isRunning: Bool { get }
    var previewLayer: AVCaptureVideoPreviewLayer? { get }

    func startCapture()
    func stopCapture()
    func setFrameDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate)
}
