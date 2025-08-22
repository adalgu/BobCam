//
//  AccuracyMonitor.swift
//  BobCam
//
//  Created by Gemini-CLI on 2025/07/17.
//

import Foundation
import CoreGraphics

/// 정확도 측정 결과를 전달하기 위한 델리게이트 프로토콜
protocol AccuracyMonitorDelegate: AnyObject {
    func didUpdateAccuracy(metrics: AccuracyMetrics)
}

/// 정확도 관련 지표를 정의하는 구조체
struct AccuracyMetrics {
    let intersectionOverUnion: Double
    let jitter: Double
    let trackingFailures: Int
}

/// 정확도 모니터링을 담당하는 서비스 프로토콜
protocol AccuracyMonitoring {
    var delegate: AccuracyMonitorDelegate? { get set }
    func calculateMetrics(predictedBox: CGRect, groundTruthBox: CGRect?)
}

class AccuracyMonitorService: AccuracyMonitoring {
    weak var delegate: AccuracyMonitorDelegate?

    // Phase 2: MetricsCalculator를 사용한 완전한 구현
    private var metricsCalculator = MetricsCalculator()
    private var trackingFailureCounter = 0

    func calculateMetrics(predictedBox: CGRect, groundTruthBox: CGRect?) {
        // IoU 계산 (groundTruthBox가 있을 경우)
        let iou = groundTruthBox != nil ?
            MetricsCalculator.calculateIoU(boxA: predictedBox, boxB: groundTruthBox!) : 0.0

        // Jitter 계산 (이전 프레임 정보 필요)
        let jitter = metricsCalculator.calculateJitter(currentBox: predictedBox)

        // 추적 실패 카운트 (탐지 성공 여부 기반)
        let detectionSuccess = !predictedBox.isNull && predictedBox.width > 0 && predictedBox.height > 0
        let isTrackingFailed = MetricsCalculator.isTrackingFailed(
            detectionSuccess: detectionSuccess,
            failureCounter: &trackingFailureCounter,
            threshold: 5  // 5프레임 연속 실패 시 추적 실패로 판단
        )

        let trackingFailures = isTrackingFailed ? trackingFailureCounter : 0

        let metrics = AccuracyMetrics(
            intersectionOverUnion: iou,
            jitter: jitter,
            trackingFailures: trackingFailures
        )

        delegate?.didUpdateAccuracy(metrics: metrics)
    }
}
