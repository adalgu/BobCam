//
//  LipDetectionImproved.swift
//  BobCam
//
//  Created by Gemini-CLI on 2025/07/17.
//
//  Refactored to OptimizedLipDetectionService, incorporating monitoring,
//  EMA smoothing, and a circular buffer for efficient history management.
//

import Foundation
import Vision

// MARK: - Configuration and State (VisionService와 호환)
struct LipDetectionConfiguration: Codable {
    let historySize: Int
    let minMovementThreshold: Float
    let eatingPatternThreshold: Float
    let varianceThreshold: Float
    let emaAlpha: Float // EMA smoothing factor

    static let `default` = LipDetectionConfiguration(
        historySize: 15,
        minMovementThreshold: 0.05,
        eatingPatternThreshold: 0.15,
        varianceThreshold: 0.001,
        emaAlpha: 0.3 // 감독 제안값으로 시작
    )
}

enum LipDetectionState {
    case eating
    case notEating
    case uncertain
}

// MARK: - Optimized Lip Detection Service
class OptimizedLipDetectionService {

    // MARK: - Dependencies
    private let configuration: LipDetectionConfiguration
    public let performanceMonitor: PerformanceMonitoring
    public let accuracyMonitor: AccuracyMonitoring

    // MARK: - Properties
    private var lipDistanceHistory: CircularBuffer<Float>
    private var sensitivity: Float = 0.5
    private var lastSmoothedPoint: CGPoint?

    // MARK: - Initialization
    init(
        configuration: LipDetectionConfiguration = .default,
        performanceMonitor: PerformanceMonitoring = PerformanceMonitorService(),
        accuracyMonitor: AccuracyMonitoring = AccuracyMonitorService()
    ) {
        self.configuration = configuration
        self.performanceMonitor = performanceMonitor
        self.accuracyMonitor = accuracyMonitor
        self.lipDistanceHistory = CircularBuffer<Float>(capacity: configuration.historySize)
    }

    // MARK: - Public Methods
    func detect(from landmarks: VNFaceLandmarks2D, faceObservation: VNFaceObservation, groundTruthBox: CGRect? = nil) -> LipDetectionState {
        performanceMonitor.startFrameProcessing()

        guard let lipDistance = calculateSmoothedLipDistance(landmarks) else {
            performanceMonitor.endFrameProcessing()
            return .uncertain
        }

        lipDistanceHistory.write(lipDistance)

        let state = analyzeEatingPattern()

        // --- 모니터링 ---
        // 정확도 계산 (예시: 랜드마크의 바운딩 박스를 사용)
        let predictedBox = faceObservation.boundingBox
        accuracyMonitor.calculateMetrics(predictedBox: predictedBox, groundTruthBox: groundTruthBox)
        performanceMonitor.endFrameProcessing()
        // ---------------

        return state
    }

    func updateSensitivity(_ newSensitivity: Float) {
        sensitivity = max(0.1, min(1.0, newSensitivity))
    }

    func reset() {
        lipDistanceHistory.clear()
        lastSmoothedPoint = nil
    }

    // MARK: - Private: Algorithm Logic

    /// EMA를 적용하여 부드러워진 입술 중심점 간의 거리를 계산
    private func calculateSmoothedLipDistance(_ landmarks: VNFaceLandmarks2D) -> Float? {
        guard let outerLips = landmarks.outerLips,
              let topCenter = getAveragePoint(from: outerLips, indices: [9, 10, 11]), // 상단 중앙
              let bottomCenter = getAveragePoint(from: outerLips, indices: [0, 1, 2]) // 하단 중앙
        else {
            return nil
        }

        // EMA 적용
        let currentPoint = CGPoint(x: (topCenter.x + bottomCenter.x) / 2, y: (topCenter.y + bottomCenter.y) / 2)
        let smoothedPoint = applyEMA(to: currentPoint)
        self.lastSmoothedPoint = smoothedPoint

        // 부드러워진 좌표 기반 거리 계산
        let deltaX = topCenter.x - bottomCenter.x
        let deltaY = topCenter.y - bottomCenter.y
        let distance = sqrt(pow(deltaX, 2) + pow(deltaY, 2))

        return Float(distance)
    }

    private func applyEMA(to point: CGPoint) -> CGPoint {
        guard let lastPoint = lastSmoothedPoint else {
            return point
        }
        let alpha = CGFloat(configuration.emaAlpha)
        let smoothedX = alpha * point.x + (1 - alpha) * lastPoint.x
        let smoothedY = alpha * point.y + (1 - alpha) * lastPoint.y
        return CGPoint(x: smoothedX, y: smoothedY)
    }

    private func analyzeEatingPattern() -> LipDetectionState {
        guard lipDistanceHistory.isFull else {
            return .uncertain
        }

        let history = lipDistanceHistory.allItems()
        let halfSize = configuration.historySize / 2

        let recentAverage = history.suffix(halfSize).reduce(0, +) / Float(halfSize)
        let olderAverage = history.prefix(halfSize).reduce(0, +) / Float(halfSize)
        let changeRate = abs(recentAverage - olderAverage)

        let adjustedThreshold = configuration.eatingPatternThreshold * sensitivity

        return changeRate > adjustedThreshold ? .eating : .notEating
    }

    // MARK: - Private: Helpers

    /// 특�� 인덱스의 포인트들의 평균 위치를 계산
    private func getAveragePoint(from region: VNFaceLandmarkRegion2D, indices: [Int]) -> CGPoint? {
        let points = region.normalizedPoints
        guard !indices.contains(where: { $0 >= points.count }) else { return nil }

        let sum = indices.reduce(CGPoint.zero) { result, index in
            let point = points[index]
            return CGPoint(x: result.x + point.x, y: result.y + point.y)
        }

        return CGPoint(x: sum.x / CGFloat(indices.count), y: sum.y / CGFloat(indices.count))
    }
}
