//
//  MetricsCalculator.swift
//  BobCam
//
//  Created by Gemini-CLI on 2025/07/17.
//

import Foundation
import CoreGraphics

/// 정확도 및 성능 지표 계산을 위한 유틸리티
struct MetricsCalculator {

    private var previousBox: CGRect?

    /// **Intersection over Union (IoU) 계산**
    /// - 두 개의 사각형 영역이 얼마나 겹치는지를 나타내는 지표 (0.0 ~ 1.0)
    /// - Parameters:
    ///   - boxA: 첫 번째 사각형
    ///   - boxB: 두 번째 사각형
    /// - Returns: IoU 값
    static func calculateIoU(boxA: CGRect, boxB: CGRect) -> Double {
        let intersection = boxA.intersection(boxB)
        let union = boxA.union(boxB)

        guard !intersection.isNull, !union.isNull, union.width * union.height > 0 else {
            return 0.0
        }

        let intersectionArea = intersection.width * intersection.height
        let unionArea = union.width * union.height

        return Double(intersectionArea / unionArea)
    }

    /// **Jitter (떨림) 지수 계산**
    /// - 이전 프레임과의 위치 변화량을 기반으로 떨림 정도를 측정
    /// - Parameters:
    ///   - currentBox: 현재 프레임의 바운딩 박스
    /// - Returns: 이전 프레임과의 중심점 거리 (Jitter 값)
    mutating func calculateJitter(currentBox: CGRect) -> Double {
        guard let prevBox = previousBox else {
            self.previousBox = currentBox
            return 0.0 // 첫 프레임은 Jitter 없음
        }

        let dx = currentBox.midX - prevBox.midX
        let dy = currentBox.midY - prevBox.midY

        let distance = sqrt(dx * dx + dy * dy)

        self.previousBox = currentBox
        return Double(distance)
    }

    /// **추적 실패 조건 정의**
    /// - N 프레임 연속으로 탐지에 실패했는지 여부 확인
    /// - Parameters:
    ///   - detectionSuccess: 현재 프레임의 탐지 성공 여부
    ///   - failureCounter: 연속 실패 횟수를 관리하는 외부 변수 (inout)
    ///   - threshold: 실패로 간주할 연속 실패 횟수
    /// - Returns: 추적 실패 여부 (Bool)
    static func isTrackingFailed(
        detectionSuccess: Bool,
        failureCounter: inout Int,
        threshold: Int
    ) -> Bool {
        if detectionSuccess {
            failureCounter = 0
            return false
        } else {
            failureCounter += 1
            return failureCounter >= threshold
        }
    }
}
