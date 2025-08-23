import XCTest
import Vision
@testable import BobCamAgent

// MARK: - Test Helper Protocol

protocol TestHandObservation {
    func testPoint(for jointName: VNHumanHandPoseObservation.JointName) -> CGPoint?
    var testPoints: [VNHumanHandPoseObservation.JointName: CGPoint] { get }
}

// MARK: - Test Implementation

class TestHandObservationImpl: TestHandObservation {
    let testPoints: [VNHumanHandPoseObservation.JointName: CGPoint]
    
    init(points: [VNHumanHandPoseObservation.JointName: CGPoint]) {
        self.testPoints = points
    }
    
    func testPoint(for jointName: VNHumanHandPoseObservation.JointName) -> CGPoint? {
        return testPoints[jointName]
    }
}

class MultiModalEatingDetectionServiceTests: XCTestCase {

    var service: MultiModalEatingDetectionService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        service = MultiModalEatingDetectionService()
    }

    override func tearDownWithError() throws {
        service = nil
        try super.tearDownWithError()
    }

    // MARK: - fuseSignals Tests

    func testFuseSignals_Eating_HighConfidence() {
        // Given
        let signals: [EatingSignal] = [
            .lipMovement(confidence: 0.9, distance: 0.1),
            .handToMouth(confidence: 0.9, distance: 0.1, detected: true)
        ]

        // When
        let result = service.fuseSignals(signals)

        // Then
        guard case .eating(let confidence) = result else {
            XCTFail("Expected .eating state, but got \(result)")
            return
        }
        XCTAssertGreaterThan(confidence, 0.8, "Confidence should be high")
    }

    func testFuseSignals_NotEating_LowConfidence() {
        // Given
        let signals: [EatingSignal] = [
            .lipMovement(confidence: 0.1, distance: 0.5),
            .handToMouth(confidence: 0.1, distance: 0.5, detected: false)
        ]

        // When
        let result = service.fuseSignals(signals)

        // Then
        guard case .notEating(let confidence) = result else {
            XCTFail("Expected .notEating state, but got \(result)")
            return
        }
        XCTAssertGreaterThan(confidence, 0.8, "Confidence should be high for not eating")
    }

    func testFuseSignals_Uncertain_NoSignals() {
        // Given
        let signals: [EatingSignal] = []

        // When
        let result = service.fuseSignals(signals)

        // Then
        guard case .uncertain = result else {
            XCTFail("Expected .uncertain state, but got \(result)")
            return
        }
    }

    // MARK: - Helper Methods

    private func createTestHandObservation(wrist: CGPoint, thumbTip: CGPoint, indexTip: CGPoint) -> TestHandObservation {
        let points: [VNHumanHandPoseObservation.JointName: CGPoint] = [
            .wrist: wrist,
            .thumbTip: thumbTip,
            .indexTip: indexTip
        ]
        return TestHandObservationImpl(points: points)
    }

    // MARK: - Distance Calculation Tests

    func testCalculateDistance_HandNearMouth() {
        // Given
        let handPoints: [VNHumanHandPoseObservation.JointName: CGPoint] = [
            .wrist: CGPoint(x: 0.5, y: 0.6),
            .thumbTip: CGPoint(x: 0.5, y: 0.55),
            .indexTip: CGPoint(x: 0.5, y: 0.55)
        ]
        let faceBox = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)

        // When
        let distance = service.calculateHandToMouthDistance(handPoints: handPoints, faceBox: faceBox)

        // Then
        XCTAssertLessThan(distance, 0.2, "Hand should be close to mouth")
    }

    func testCalculateDistance_HandFarFromMouth() {
        // Given
        let handPoints: [VNHumanHandPoseObservation.JointName: CGPoint] = [
            .wrist: CGPoint(x: 0.1, y: 0.1),
            .thumbTip: CGPoint(x: 0.1, y: 0.15),
            .indexTip: CGPoint(x: 0.1, y: 0.15)
        ]
        let faceBox = CGRect(x: 0.8, y: 0.8, width: 0.2, height: 0.2)

        // When
        let distance = service.calculateHandToMouthDistance(handPoints: handPoints, faceBox: faceBox)

        // Then
        XCTAssertGreaterThan(distance, 0.5, "Hand should be far from mouth")
    }
}
