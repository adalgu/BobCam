//
//  Phase2ValidationTest.swift
//  BobCam
//
//  Created by Claude on 2025/07/17.
//  Quick validation test for Phase 2 integration
//

import Foundation
import Vision
import CoreGraphics

// MARK: - Phase 2 Integration Validation Test
class Phase2ValidationTest {
    
    private let visionService: VisionService
    private let optimizedService: OptimizedLipDetectionService
    
    init() {
        let config = LipDetectionConfiguration.default
        self.visionService = VisionService(configuration: config)
        self.optimizedService = OptimizedLipDetectionService(configuration: config)
    }
    
    // MARK: - Test Methods
    
    /// Test if VisionService initializes correctly with OptimizedLipDetectionService
    func testVisionServiceInitialization() -> Bool {
        print("🧪 Testing VisionService initialization...")
        
        // Check if the service initializes without crash
        let initialState = visionService.serviceState
        let isInitialized = (initialState == .idle)
        
        print("✅ VisionService initialized with state: \(initialState)")
        return isInitialized
    }
    
    /// Test monitoring system integration
    func testMonitoringIntegration() -> Bool {
        print("🧪 Testing monitoring system integration...")
        
        // Test performance monitoring
        let performanceMonitor = optimizedService.performanceMonitor
        let hasPerformanceMonitor = (performanceMonitor is PerformanceMonitorService)
        
        // Test accuracy monitoring  
        let accuracyMonitor = optimizedService.accuracyMonitor
        let hasAccuracyMonitor = (accuracyMonitor is AccuracyMonitorService)
        
        print("✅ Performance Monitor: \(hasPerformanceMonitor ? "✓" : "✗")")
        print("✅ Accuracy Monitor: \(hasAccuracyMonitor ? "✓" : "✗")")
        
        return hasPerformanceMonitor && hasAccuracyMonitor
    }
    
    /// Test configuration compatibility
    func testConfigurationCompatibility() -> Bool {
        print("🧪 Testing configuration compatibility...")
        
        let config = LipDetectionConfiguration.default
        let hasAllFields = config.historySize > 0 && 
                          config.eatingPatternThreshold > 0 &&
                          config.emaAlpha > 0
        
        print("✅ Configuration fields: \(hasAllFields ? "✓" : "✗")")
        print("   - History Size: \(config.historySize)")
        print("   - Eating Pattern Threshold: \(config.eatingPatternThreshold)")
        print("   - EMA Alpha: \(config.emaAlpha)")
        
        return hasAllFields
    }
    
    /// Test CircularBuffer functionality
    func testCircularBuffer() -> Bool {
        print("🧪 Testing CircularBuffer functionality...")
        
        var buffer = CircularBuffer<Float>(capacity: 5)
        
        // Test writing and reading
        buffer.write(1.0)
        buffer.write(2.0)
        buffer.write(3.0)
        
        let items = buffer.allItems()
        let correctCount = items.count == 3
        let correctValues = items == [1.0, 2.0, 3.0]
        
        print("✅ Buffer count: \(correctCount ? "✓" : "✗") (expected: 3, actual: \(items.count))")
        print("✅ Buffer values: \(correctValues ? "✓" : "✗")")
        
        return correctCount && correctValues
    }
    
    /// Test MetricsCalculator functionality
    func testMetricsCalculator() -> Bool {
        print("🧪 Testing MetricsCalculator functionality...")
        
        let boxA = CGRect(x: 0, y: 0, width: 100, height: 100)
        let boxB = CGRect(x: 50, y: 50, width: 100, height: 100)
        
        let iou = MetricsCalculator.calculateIoU(boxA: boxA, boxB: boxB)
        let hasValidIoU = iou > 0 && iou <= 1.0
        
        var calculator = MetricsCalculator()
        let jitter1 = calculator.calculateJitter(currentBox: boxA)
        let jitter2 = calculator.calculateJitter(currentBox: boxB)
        
        let hasValidJitter = jitter1 == 0.0 && jitter2 > 0  // First frame should be 0
        
        print("✅ IoU calculation: \(hasValidIoU ? "✓" : "✗") (value: \(iou))")
        print("✅ Jitter calculation: \(hasValidJitter ? "✓" : "✗") (j1: \(jitter1), j2: \(jitter2))")
        
        return hasValidIoU && hasValidJitter
    }
    
    // MARK: - Main Test Runner
    
    func runAllTests() -> Bool {
        print("\n🚀 Running Phase 2 Integration Validation Tests...")
        print("=" * 50)
        
        let tests = [
            ("VisionService Initialization", testVisionServiceInitialization),
            ("Monitoring Integration", testMonitoringIntegration),
            ("Configuration Compatibility", testConfigurationCompatibility),
            ("CircularBuffer Functionality", testCircularBuffer),
            ("MetricsCalculator Functionality", testMetricsCalculator)
        ]
        
        var passedTests = 0
        let totalTests = tests.count
        
        for (testName, testMethod) in tests {
            print("\n📋 \(testName):")
            let result = testMethod()
            
            if result {
                passedTests += 1
                print("🟢 PASSED")
            } else {
                print("🔴 FAILED")
            }
        }
        
        print("\n" + "=" * 50)
        print("📊 Test Results: \(passedTests)/\(totalTests) passed")
        
        let allPassed = passedTests == totalTests
        if allPassed {
            print("🎉 All tests passed! Phase 2 integration is ready for accuracy testing.")
        } else {
            print("⚠️  Some tests failed. Please review the integration.")
        }
        
        return allPassed
    }
}

// MARK: - String Extension for repeat
extension String {
    static func * (lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}