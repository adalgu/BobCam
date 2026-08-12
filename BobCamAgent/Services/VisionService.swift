import Foundation
import Vision
import CoreVideo
import Combine

final class VisionService: NSObject, VisionServiceProtocol, ObservableObject {
    @Published private(set) var isEating: Bool = false
    @Published private(set) var faceDetected: Bool = false
    @Published private(set) var handNearFace: Bool = false
    @Published private(set) var lipMovement: Double = 0.0

    private var isProcessing: Bool = false
    private var frameCount: Int = 0
    private let processingQueue = DispatchQueue(label: "vision.processing", qos: .userInteractive)

    private lazy var faceRequest: VNDetectFaceLandmarksRequest = {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleFaceDetection(request: request, error: error)
        }
        request.revision = VNDetectFaceLandmarksRequestRevision3
        return request
    }()

    private lazy var handRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest { [weak self] request, error in
            self?.handleHandDetection(request: request, error: error)
        }
        request.maximumHandCount = 2
        return request
    }()

    private var previousLipDistance: Double = 0.0
    private var lipMovementHistory: [Double] = []
    private let historySize = 10
    private var lastFaceBounds: CGRect = .zero

    func startProcessing() {
        isProcessing = true
        frameCount = 0
    }

    func stopProcessing() {
        isProcessing = false
        resetState()
    }

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isProcessing else { return }

        frameCount += 1
        guard frameCount % Constants.Vision.frameSkipCount == 0 else { return }

        processingQueue.async { [weak self] in
            self?.performVisionRequests(on: pixelBuffer)
        }
    }

    private func performVisionRequests(on pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([faceRequest, handRequest])
        } catch {
            print("Vision request failed: \(error)")
        }
    }

    private func handleFaceDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNFaceObservation],
              let face = observations.first else {
            DispatchQueue.main.async { [weak self] in
                self?.faceDetected = false
                self?.lipMovement = 0.0
                self?.updateEatingState()
            }
            return
        }

        lastFaceBounds = face.boundingBox

        if let landmarks = face.landmarks,
           let outerLips = landmarks.outerLips,
           let innerLips = landmarks.innerLips {

            let movement = calculateLipMovement(outerLips: outerLips, innerLips: innerLips)

            DispatchQueue.main.async { [weak self] in
                self?.faceDetected = true
                self?.lipMovement = movement
                self?.updateEatingState()
            }
        }
    }

    private func handleHandDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNHumanHandPoseObservation],
              !observations.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.handNearFace = false
                self?.updateEatingState()
            }
            return
        }

        let isNear = observations.contains { observation in
            isHandNearFace(observation)
        }

        DispatchQueue.main.async { [weak self] in
            self?.handNearFace = isNear
            self?.updateEatingState()
        }
    }

    private func calculateLipMovement(outerLips: VNFaceLandmarkRegion2D, innerLips: VNFaceLandmarkRegion2D) -> Double {
        let outerPoints = outerLips.normalizedPoints
        let innerPoints = innerLips.normalizedPoints

        guard outerPoints.count >= 6, innerPoints.count >= 5 else { return 0.0 }

        let topPoint = outerPoints[3]
        let bottomPoint = outerPoints[9 % outerPoints.count]

        let currentDistance = abs(topPoint.y - bottomPoint.y)
        let movement = abs(currentDistance - previousLipDistance)
        previousLipDistance = currentDistance

        lipMovementHistory.append(movement)
        if lipMovementHistory.count > historySize {
            lipMovementHistory.removeFirst()
        }

        let average = lipMovementHistory.reduce(0, +) / Double(lipMovementHistory.count)
        return min(1.0, average / Constants.Vision.lipMovementThreshold)
    }

    private func isHandNearFace(_ hand: VNHumanHandPoseObservation) -> Bool {
        guard lastFaceBounds != .zero else { return false }

        do {
            let wristPoint = try hand.recognizedPoint(.wrist)
            guard wristPoint.confidence > 0.3 else { return false }

            let handPosition = wristPoint.location
            let expandedBounds = lastFaceBounds.insetBy(
                dx: -lastFaceBounds.width * (Constants.Vision.handFaceDistanceRatio - 1) / 2,
                dy: -lastFaceBounds.height * (Constants.Vision.handFaceDistanceRatio - 1) / 2
            )

            return expandedBounds.contains(handPosition)
        } catch {
            return false
        }
    }

    private func updateEatingState() {
        let isLipMoving = lipMovement > Constants.Vision.lipMovementEatingThreshold
        isEating = isLipMoving || handNearFace
    }

    private func resetState() {
        DispatchQueue.main.async { [weak self] in
            self?.isEating = false
            self?.faceDetected = false
            self?.handNearFace = false
            self?.lipMovement = 0.0
        }
        previousLipDistance = 0.0
        lipMovementHistory.removeAll()
        lastFaceBounds = .zero
    }
}
