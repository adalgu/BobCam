import Foundation
import AVFoundation

enum Constants {
    enum Vision {
        static let processingFPS: Int = 15
        static let frameSkipCount: Int = 4  // 60fps에서 15fps로
        static let lipMovementThreshold: Double = 0.02
        static let handFaceDistanceRatio: Double = 1.5
        static let lipMovementEatingThreshold: Double = 0.3  // 30% 이상이면 먹는 중
    }

    enum Timing {
        static let defaultWaitSeconds: Int = 5
        static let minWaitSeconds: Int = 1
        static let maxWaitSeconds: Int = 30
        static let praiseDuration: TimeInterval = 2.0
        static let forcePlayDuration: TimeInterval = 30.0
    }

    enum Camera {
        static let sessionPreset = AVCaptureSession.Preset.hd1280x720
        static let position = AVCaptureDevice.Position.front
    }

    enum Animation {
        static let fadeOutDuration: TimeInterval = 0.5
        static let fadeInDuration: TimeInterval = 0.3
    }
}
