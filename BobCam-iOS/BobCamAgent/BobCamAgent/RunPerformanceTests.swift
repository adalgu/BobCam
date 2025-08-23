import Foundation

/// Simple test runner for MultiModal performance testing
/// This can be called from ContentView or other parts of the app for manual testing
class PerformanceTestRunner {
    
    static func runAllTests() {
        print("🎬 Starting BobCam Multi-Modal Performance Testing Suite")
        print("Testing Date: \(Date())")
        print("Testing Multi-Modal Eating Detection Service Integration")
        print("")
        
        let performanceTest = MultiModalPerformanceTest()
        let results = performanceTest.runComprehensiveTest()
        
        // Save results to file for analysis
        saveResultsToFile(results)
        
        print("\n📁 Results saved to Documents directory")
        print("🏁 Testing completed. Check console output for detailed results.")
    }
    
    private static func saveResultsToFile(_ results: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                         in: .userDomainMask)[0]
            let fileName = "BobCam_MultiModal_Test_Results_\(Int(Date().timeIntervalSince1970)).json"
            let fileURL = documentsPath.appendingPathComponent(fileName)
            
            try jsonData.write(to: fileURL)
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("\n📄 Test Results JSON Preview:")
                print(String(jsonString.prefix(500)) + "...")
            }
            
        } catch {
            print("❌ Failed to save results: \(error.localizedDescription)")
        }
    }
    
    /// Quick validation test that can be run during app initialization
    static func runQuickValidation() -> Bool {
        print("⚡ Running quick multi-modal validation...")
        
        let service = MultiModalEatingDetectionService()
        
        // Test basic initialization
        guard service.serviceState != .failed(VisionServiceError.configurationInvalid) else {
            print("❌ Service initialization failed")
            return false
        }
        
        // Test signal fusion with basic cases
        let testSignals = [
            EatingSignal.lipMovement(confidence: 0.8, distance: 0.1),
            EatingSignal.handToMouth(confidence: 0.7, distance: 0.15, detected: true)
        ]
        
        let result = service.fuseSignals(testSignals)
        
        switch result {
        case .eating:
            print("✅ Signal fusion working correctly")
            return true
        case .notEating, .uncertain:
            print("⚠️ Signal fusion returned unexpected result: \(result)")
            return false
        }
    }
}

// MARK: - Development Helper Functions

#if DEBUG
extension PerformanceTestRunner {
    
    /// Development utility to test specific signal combinations
    static func testSignalCombination(lip: Float, hand: Float, utensil: Float, handDetected: Bool = true, utensilDetected: Bool = true) {
        print("\n🧪 Testing signal combination: lip=\(lip), hand=\(hand), utensil=\(utensil)")
        
        let service = MultiModalEatingDetectionService()
        let signals = [
            EatingSignal.lipMovement(confidence: lip, distance: 0.1),
            EatingSignal.handToMouth(confidence: hand, distance: 0.15, detected: handDetected),
            EatingSignal.utensilDetected(confidence: utensil, position: CGPoint(x: 0.5, y: 0.5), detected: utensilDetected)
        ]
        
        let result = service.fuseSignals(signals)
        print("Result: \(result)")
    }
    
    /// Performance benchmark for signal fusion
    static func benchmarkSignalFusion(iterations: Int = 1000) {
        print("\n⏱️ Benchmarking signal fusion (\(iterations) iterations)")
        
        let service = MultiModalEatingDetectionService()
        let testSignals = [
            EatingSignal.lipMovement(confidence: 0.8, distance: 0.1),
            EatingSignal.handToMouth(confidence: 0.7, distance: 0.15, detected: true),
            EatingSignal.utensilDetected(confidence: 0.6, position: CGPoint(x: 0.5, y: 0.5), detected: true)
        ]
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = service.fuseSignals(testSignals)
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = (totalTime / Double(iterations)) * 1000 // Convert to milliseconds
        
        print("Total time: \(String(format: "%.3f", totalTime))s")
        print("Average time per fusion: \(String(format: "%.3f", avgTime))ms")
        print("Fusions per second: \(String(format: "%.0f", 1.0 / (totalTime / Double(iterations))))")
    }
}
#endif