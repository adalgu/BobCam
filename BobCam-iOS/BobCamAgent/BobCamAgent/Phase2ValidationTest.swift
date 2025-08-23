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
    
    /// Test MultiModalEatingDetectionService with utensil detection
    func testMultiModalUtensilDetection() -> Bool {
        print("🧪 Testing MultiModal service with utensil detection...")
        
        let config = MultiModalConfiguration.default
        let multiModalService = MultiModalEatingDetectionService(configuration: config)
        
        // Test initialization
        let initialState = multiModalService.serviceState
        let isInitialized = (initialState == .idle)
        print("✅ MultiModal service initialized: \(isInitialized ? "✓" : "✗")")
        
        // Test configuration
        let utensilEnabled = config.utensilDetectionEnabled
        let validThreshold = config.utensilConfidenceThreshold > 0.0 && config.utensilConfidenceThreshold <= 1.0
        let validDistance = config.utensilToMouthDistanceThreshold > 0.0
        let validFPS = config.utensilDetectionFPS > 0
        
        print("✅ Utensil detection enabled: \(utensilEnabled ? "✓" : "✗")")
        print("✅ Valid confidence threshold: \(validThreshold ? "✓" : "✗") (\(config.utensilConfidenceThreshold))")
        print("✅ Valid distance threshold: \(validDistance ? "✓" : "✗") (\(config.utensilToMouthDistanceThreshold))")
        print("✅ Valid FPS setting: \(validFPS ? "✓" : "✗") (\(config.utensilDetectionFPS))")
        
        // Test helper methods
        let spoonLabel = multiModalService.isUtensilLabel("spoon")
        let forkLabel = multiModalService.isUtensilLabel("fork")
        let nonUtensilLabel = multiModalService.isUtensilLabel("cup")
        
        print("✅ Utensil label detection: \(spoonLabel && forkLabel && !nonUtensilLabel ? "✓" : "✗")")
        
        // Test utensil distance calculation
        let utensilCenter = CGPoint(x: 0.5, y: 0.5)
        let faceBox = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
        let distance = multiModalService.calculateUtensilToMouthDistance(utensilCenter: utensilCenter, faceBox: faceBox)
        let validDistanceCalculation = distance >= 0.0 && distance <= 1.0
        
        print("✅ Utensil distance calculation: \(validDistanceCalculation ? "✓" : "✗") (distance: \(distance))")
        
        // Test performance metrics
        let metrics = multiModalService.getPerformanceMetrics()
        let hasUtensilMetrics = metrics.keys.contains("utensil_confidence") && 
                               metrics.keys.contains("utensil_detection_enabled") &&
                               metrics.keys.contains("utensil_fps")
        
        print("✅ Utensil performance metrics: \(hasUtensilMetrics ? "✓" : "✗")")
        
        // Test utensil details
        let utensilDetails = multiModalService.getUtensilDetectionDetails()
        let hasDetails = utensilDetails.keys.contains("enabled") && 
                        utensilDetails.keys.contains("confidence_threshold") &&
                        utensilDetails.keys.contains("distance_threshold")
        
        print("✅ Utensil detection details: \(hasDetails ? "✓" : "✗")")
        
        let allChecks = isInitialized && utensilEnabled && validThreshold && 
                       validDistance && validFPS && spoonLabel && forkLabel && 
                       !nonUtensilLabel && validDistanceCalculation && 
                       hasUtensilMetrics && hasDetails
        
        return allChecks
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
            ("MetricsCalculator Functionality", testMetricsCalculator),
            ("MultiModal Utensil Detection", testMultiModalUtensilDetection)
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
