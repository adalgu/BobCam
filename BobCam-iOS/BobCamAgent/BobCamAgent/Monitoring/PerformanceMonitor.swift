//
//  PerformanceMonitor.swift
//  BobCam
//
//  Created by Gemini-CLI on 2025/07/17.
//

import Foundation

/// 성능 측정 결과를 전달하기 위한 델리게이트 프로토콜
protocol PerformanceMonitorDelegate: AnyObject {
    func didUpdatePerformance(metrics: PerformanceMetrics)
}

/// 성능 관련 지표를 정의하는 구조체
struct PerformanceMetrics {
    let framesPerSecond: Double
    let processingTime: TimeInterval // 밀리초 단위
}

/// 성능 모니터링을 담당하는 서비스 프로토콜
protocol PerformanceMonitoring {
    var delegate: PerformanceMonitorDelegate? { get set }
    func startFrameProcessing()
    func endFrameProcessing()
}

class PerformanceMonitorService: PerformanceMonitoring {
    weak var delegate: PerformanceMonitorDelegate?
    
    private var lastFrameTimestamp: Date?
    private var frameCount: Int = 0
    private var lastReportTime: Date = Date()
    
    private var processingStartTime: Date?
    
    func startFrameProcessing() {
        processingStartTime = Date()
    }
    
    func endFrameProcessing() {
        guard let startTime = processingStartTime else { return }
        let processingTime = Date().timeIntervalSince(startTime) * 1000 // 밀리초로 변환
        
        frameCount += 1
        let now = Date()
        let elapsedTime = now.timeIntervalSince(lastReportTime)
        
        if elapsedTime >= 1.0 {
            let fps = Double(frameCount) / elapsedTime
            let metrics = PerformanceMetrics(framesPerSecond: fps, processingTime: processingTime)
            delegate?.didUpdatePerformance(metrics: metrics)
            
            // Reset
            frameCount = 0
            lastReportTime = now
        }
    }
}
