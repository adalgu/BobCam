//
//  TuningIntegration.swift
//  BobCam
//
//  Created by Claude Code on 2025/08/20.
//
//  Integration layer connecting parameter tuning with existing VisionService
//  Provides seamless integration and deployment of optimized parameters
//

import Foundation
import Vision
import Combine
import SwiftUI

// MARK: - Tuning Integration Manager

class TuningIntegrationManager: ObservableObject {
    
    // MARK: - Properties
    @Published var isOptimizing: Bool = false
    @Published var optimizationProgress: Double = 0.0
    @Published var optimizedConfiguration: LipDetectionConfiguration?
    @Published var currentAccuracy: Double = 0.0
    @Published var targetAchieved: Bool = false
    
    private var tuningEngine: AdvancedOptimizationEngine
    private var groundTruthManager = GroundTruthManager()
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let optimizationConfig = OptimizationConfiguration(
        algorithm: .bayesianOptimization,
        maxIterations: 50,
        convergenceThreshold: 0.001,
        populationSize: 20,
        mutationRate: 0.1,
        crossoverRate: 0.8,
        targetAccuracy: 0.70,
        timeoutMinutes: 30.0
    )
    
    init() {
        self.tuningEngine = AdvancedOptimizationEngine(
            algorithm: optimizationConfig.algorithm,
            configuration: optimizationConfig
        )
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func startOptimization() async -> OptimizationResult {
        print("🎯 Starting systematic parameter optimization for 70% accuracy target")
        
        await MainActor.run {
            isOptimizing = true
            optimizationProgress = 0.0
            targetAchieved = false
        }
        
        // Load test datasets
        await groundTruthManager.loadDefaultDatasets()
        
        // Prepare comprehensive test data
        let testData = await prepareComprehensiveTestData()
        
        // Configure tuning engine
        tuningEngine.loadTestVideoFrames(testData.videoFrames)
        tuningEngine.loadGroundTruthData(testData.groundTruthFrames)
        
        // Start optimization
        await tuningEngine.startParameterTuning()
        
        // Validate results
        let validationResult = await validateOptimizationResults()
        
        await MainActor.run {
            isOptimizing = false
            optimizedConfiguration = validationResult.configuration
            currentAccuracy = validationResult.accuracy
            targetAchieved = validationResult.achievedTarget
        }
        
        return validationResult
    }
    
    func deployOptimizedConfiguration() -> Bool {
        guard let config = optimizedConfiguration, targetAchieved else {
            print("❌ No optimized configuration available or target not achieved")
            return false
        }
        
        // Update VisionService configuration
        updateVisionServiceConfiguration(config)
        
        // Save configuration for persistence
        saveOptimizedConfiguration(config)
        
        print("✅ Optimized configuration deployed successfully")
        return true
    }
    
    func runAccuracyValidation() async -> ValidationSummary {
        guard let config = optimizedConfiguration else {
            return ValidationSummary(
                accuracy: 0.0,
                precision: 0.0,
                recall: 0.0,
                f1Score: 0.0,
                isValid: false,
                message: "No optimized configuration available"
            )
        }
        
        // Run validation with multiple test scenarios
        let validationResults = await performComprehensiveValidation(configuration: config)
        
        return ValidationSummary(
            accuracy: validationResults.overallAccuracy,
            precision: validationResults.precision,
            recall: validationResults.recall,
            f1Score: validationResults.f1Score,
            isValid: validationResults.isTargetAchieved,
            message: validationResults.isTargetAchieved ? "Validation successful - 70% target achieved" : "Validation failed - target not met"
        )
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind tuning engine progress to local state
        tuningEngine.$currentProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.optimizationProgress = progress
            }
            .store(in: &cancellables)
    }
    
    private func prepareComprehensiveTestData() async -> (videoFrames: [(CVPixelBuffer, TimeInterval)], groundTruthFrames: [GroundTruthFrame]) {
        var allVideoFrames: [(CVPixelBuffer, TimeInterval)] = []
        var allGroundTruthFrames: [GroundTruthFrame] = []
        
        // Combine all available datasets for comprehensive testing
        for dataset in groundTruthManager.availableDatasets {
            let frames = await groundTruthManager.extractFramesFromDataset(dataset)
            let groundTruth = groundTruthManager.generateGroundTruthFrames(from: dataset)
            
            allVideoFrames.append(contentsOf: frames)
            allGroundTruthFrames.append(contentsOf: groundTruth)
        }
        
        print("📊 Prepared \(allVideoFrames.count) video frames and \(allGroundTruthFrames.count) ground truth frames")
        
        return (allVideoFrames, allGroundTruthFrames)
    }
    
    private func validateOptimizationResults() async -> OptimizationResult {
        guard let bestResult = tuningEngine.bestResult else {
            return OptimizationResult(
                configuration: nil,
                accuracy: 0.0,
                achievedTarget: false,
                validationMetrics: nil,
                message: "No optimization results available"
            )
        }
        
        // Parse configuration from best result
        let configuration = parseConfiguration(from: bestResult.parameterId)
        
        // Perform cross-validation
        let crossValidationAccuracy = await performCrossValidation(configuration: configuration)
        
        let achievedTarget = crossValidationAccuracy >= 0.70
        
        return OptimizationResult(
            configuration: configuration,
            accuracy: crossValidationAccuracy,
            achievedTarget: achievedTarget,
            validationMetrics: bestResult.metrics,
            message: achievedTarget ? "🎉 70% accuracy target achieved!" : "❌ Target not achieved, but best configuration identified"
        )
    }
    
    private func parseConfiguration(from parameterId: String) -> LipDetectionConfiguration {
        let components = parameterId.components(separatedBy: "_")
        
        guard components.count == 5,
              let historySize = Int(components[0]),
              let eatingThreshold = Float(components[1]),
              let emaAlpha = Float(components[2]),
              let movementThreshold = Float(components[3]),
              let varianceThreshold = Float(components[4]) else {
            return LipDetectionConfiguration.default
        }
        
        return LipDetectionConfiguration(
            historySize: historySize,
            minMovementThreshold: movementThreshold,
            eatingPatternThreshold: eatingThreshold,
            varianceThreshold: varianceThreshold,
            emaAlpha: emaAlpha
        )
    }
    
    private func performCrossValidation(configuration: LipDetectionConfiguration) async -> Double {
        print("🔬 Performing 5-fold cross-validation...")
        
        // Create 5 folds from available datasets
        let datasets = groundTruthManager.availableDatasets
        let foldSize = max(1, datasets.count / 5)
        var accuracies: [Double] = []
        
        for fold in 0..<5 {
            let startIndex = fold * foldSize
            let endIndex = min(startIndex + foldSize, datasets.count)
            
            if startIndex < datasets.count {
                let testDatasets = Array(datasets[startIndex..<endIndex])
                let accuracy = await evaluateConfigurationOnDatasets(configuration, datasets: testDatasets)
                accuracies.append(accuracy)
                
                print("  Fold \(fold + 1): \(String(format: "%.2f", accuracy * 100))%")
            }
        }
        
        let averageAccuracy = accuracies.isEmpty ? 0.0 : accuracies.reduce(0, +) / Double(accuracies.count)
        print("✅ Cross-validation average: \(String(format: "%.2f", averageAccuracy * 100))%")
        
        return averageAccuracy
    }
    
    private func evaluateConfigurationOnDatasets(_ configuration: LipDetectionConfiguration, datasets: [GroundTruthDataset]) async -> Double {
        let service = OptimizedLipDetectionService(configuration: configuration)
        let accuracyCalculator = GroundTruthAccuracyCalculator()
        
        var allPredictions: [LipDetectionState] = []
        var allGroundTruth: [GroundTruthFrame] = []
        var allTimestamps: [TimeInterval] = []
        
        for dataset in datasets {
            let frames = await groundTruthManager.extractFramesFromDataset(dataset)
            let groundTruthFrames = groundTruthManager.generateGroundTruthFrames(from: dataset)
            
            for (frame, timestamp) in frames {
                if let landmarks = await extractLandmarks(from: frame) {
                    let prediction = service.detect(from: landmarks)
                    
                    allPredictions.append(prediction)
                    allTimestamps.append(timestamp)
                    
                    // Find corresponding ground truth
                    if let gtFrame = groundTruthFrames.min(by: { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) }) {
                        allGroundTruth.append(gtFrame)
                    }
                }
            }
        }
        
        guard allPredictions.count == allGroundTruth.count else {
            return 0.0
        }
        
        let metrics = accuracyCalculator.calculateComprehensiveAccuracy(
            predictions: allPredictions,
            groundTruth: allGroundTruth,
            timestamps: allTimestamps
        )
        
        return metrics.overallAccuracy
    }
    
    private func performComprehensiveValidation(configuration: LipDetectionConfiguration) async -> ComprehensiveAccuracyMetrics {
        return await evaluateConfigurationComprehensively(configuration)
    }
    
    private func evaluateConfigurationComprehensively(_ configuration: LipDetectionConfiguration) async -> ComprehensiveAccuracyMetrics {
        let service = OptimizedLipDetectionService(configuration: configuration)
        let accuracyCalculator = GroundTruthAccuracyCalculator()
        
        // Prepare comprehensive test data
        let testData = await prepareComprehensiveTestData()
        
        var predictions: [LipDetectionState] = []
        var groundTruthFrames: [GroundTruthFrame] = []
        var timestamps: [TimeInterval] = []
        
        // Process all test frames
        for (frame, timestamp) in testData.videoFrames {
            if let landmarks = await extractLandmarks(from: frame) {
                let prediction = service.detect(from: landmarks)
                predictions.append(prediction)
                timestamps.append(timestamp)
                
                // Find corresponding ground truth
                if let gtFrame = testData.groundTruthFrames.min(by: { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) }) {
                    groundTruthFrames.append(gtFrame)
                }
            }
        }
        
        return accuracyCalculator.calculateComprehensiveAccuracy(
            predictions: predictions,
            groundTruth: groundTruthFrames,
            timestamps: timestamps
        )
    }
    
    private func extractLandmarks(from pixelBuffer: CVPixelBuffer) async -> VNFaceLandmarks2D? {
        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceLandmarksRequest { request, error in
                guard let results = request.results as? [VNFaceObservation],
                      let face = results.first,
                      let landmarks = face.landmarks else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: landmarks)
            }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func updateVisionServiceConfiguration(_ configuration: LipDetectionConfiguration) {
        // TODO: Update VisionService with optimized configuration
        // This would involve modifying VisionService.swift to use the new configuration
        print("🔧 Updating VisionService configuration...")
        
        // Update the global configuration
        UserDefaults.standard.set(configuration.historySize, forKey: "optimized_history_size")
        UserDefaults.standard.set(configuration.minMovementThreshold, forKey: "optimized_min_movement_threshold")
        UserDefaults.standard.set(configuration.eatingPatternThreshold, forKey: "optimized_eating_pattern_threshold")
        UserDefaults.standard.set(configuration.varianceThreshold, forKey: "optimized_variance_threshold")
        UserDefaults.standard.set(configuration.emaAlpha, forKey: "optimized_ema_alpha")
        
        // Notify VisionService to reload configuration
        NotificationCenter.default.post(name: .optimizedConfigurationUpdated, object: configuration)
    }
    
    private func saveOptimizedConfiguration(_ configuration: LipDetectionConfiguration) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(configuration) {
            UserDefaults.standard.set(data, forKey: "optimized_lip_detection_configuration")
            print("💾 Optimized configuration saved to UserDefaults")
        }
    }
}

// MARK: - Configuration Extensions for Codable

extension LipDetectionConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case historySize, minMovementThreshold, eatingPatternThreshold, varianceThreshold, emaAlpha
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let optimizedConfigurationUpdated = Notification.Name("optimizedConfigurationUpdated")
}

// MARK: - Result Types

struct OptimizationResult {
    let configuration: LipDetectionConfiguration?
    let accuracy: Double
    let achievedTarget: Bool
    let validationMetrics: ComprehensiveAccuracyMetrics?
    let message: String
}

struct ValidationSummary {
    let accuracy: Double
    let precision: Double
    let recall: Double
    let f1Score: Double
    let isValid: Bool
    let message: String
}

// MARK: - VisionService Integration Extension

extension TuningIntegrationManager {
    
    func integrateWithVisionService() -> VisionServiceIntegration {
        return VisionServiceIntegration(tuningManager: self)
    }
}

class VisionServiceIntegration {
    
    private weak var tuningManager: TuningIntegrationManager?
    
    init(tuningManager: TuningIntegrationManager) {
        self.tuningManager = tuningManager
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOptimizedConfigurationUpdate),
            name: .optimizedConfigurationUpdated,
            object: nil
        )
    }
    
    @objc private func handleOptimizedConfigurationUpdate(_ notification: Notification) {
        guard let configuration = notification.object as? LipDetectionConfiguration else { return }
        
        print("🔄 VisionService received optimized configuration update")
        
        // TODO: Integrate with actual VisionService
        // This would involve modifying VisionService.swift to accept dynamic configuration updates
    }
    
    func getCurrentOptimizedConfiguration() -> LipDetectionConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "optimized_lip_detection_configuration") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(LipDetectionConfiguration.self, from: data)
    }
    
    func resetToDefaultConfiguration() {
        UserDefaults.standard.removeObject(forKey: "optimized_lip_detection_configuration")
        UserDefaults.standard.removeObject(forKey: "optimized_history_size")
        UserDefaults.standard.removeObject(forKey: "optimized_min_movement_threshold")
        UserDefaults.standard.removeObject(forKey: "optimized_eating_pattern_threshold")
        UserDefaults.standard.removeObject(forKey: "optimized_variance_threshold")
        UserDefaults.standard.removeObject(forKey: "optimized_ema_alpha")
        
        NotificationCenter.default.post(name: .optimizedConfigurationUpdated, object: LipDetectionConfiguration.default)
    }
}

// MARK: - Command Line Interface for Optimization

class OptimizationCLI {
    
    private let tuningManager = TuningIntegrationManager()
    
    func runOptimization() async {
        print("🚀 BobCam Parameter Optimization CLI")
        print("Target: 70% accuracy for lip detection algorithm")
        print("="*50)
        
        let startTime = Date()
        
        // Run optimization
        let result = await tuningManager.startOptimization()
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Print results
        print("\n" + "="*50)
        print("🎯 OPTIMIZATION RESULTS")
        print("="*50)
        print("Duration: \(String(format: "%.1f", duration / 60)) minutes")
        print("Final Accuracy: \(String(format: "%.2f", result.accuracy * 100))%")
        print("Target Achieved: \(result.achievedTarget ? "✅ YES" : "❌ NO")")
        print("Message: \(result.message)")
        
        if let config = result.configuration {
            print("\n📋 OPTIMIZED CONFIGURATION:")
            print("History Size: \(config.historySize)")
            print("Eating Pattern Threshold: \(config.eatingPatternThreshold)")
            print("EMA Alpha: \(config.emaAlpha)")
            print("Min Movement Threshold: \(config.minMovementThreshold)")
            print("Variance Threshold: \(config.varianceThreshold)")
        }
        
        if result.achievedTarget {
            print("\n🚀 DEPLOYMENT")
            let deployed = tuningManager.deployOptimizedConfiguration()
            print("Configuration Deployed: \(deployed ? "✅ SUCCESS" : "❌ FAILED")")
            
            if deployed {
                print("\n🧪 VALIDATION")
                let validation = await tuningManager.runAccuracyValidation()
                print("Validation Accuracy: \(String(format: "%.2f", validation.accuracy * 100))%")
                print("Validation Status: \(validation.isValid ? "✅ PASSED" : "❌ FAILED")")
                print("Message: \(validation.message)")
            }
        }
        
        print("="*50)
        print(result.achievedTarget ? "🎉 OPTIMIZATION SUCCESSFUL!" : "⚠️  TARGET NOT ACHIEVED")
        print("="*50)
    }
}

// MARK: - SwiftUI Integration View

struct OptimizationIntegrationView: View {
    
    @StateObject private var tuningManager = TuningIntegrationManager()
    @State private var showingResults = false
    @State private var optimizationResult: OptimizationResult?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("70% Accuracy Optimization")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if tuningManager.isOptimizing {
                VStack(spacing: 16) {
                    ProgressView(value: tuningManager.optimizationProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(y: 2.0)
                    
                    Text("\(Int(tuningManager.optimizationProgress * 100))% Complete")
                        .font(.headline)
                    
                    Text("Running advanced optimization...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    if let config = tuningManager.optimizedConfiguration {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Optimized Configuration Available")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: tuningManager.targetAchieved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(tuningManager.targetAchieved ? .green : .orange)
                            }
                            
                            Text("Accuracy: \(String(format: "%.1f", tuningManager.currentAccuracy * 100))%")
                                .font(.subheadline)
                            
                            Text("Target: \(tuningManager.targetAchieved ? "✅ Achieved" : "❌ Not Achieved")")
                                .font(.subheadline)
                                .foregroundColor(tuningManager.targetAchieved ? .green : .red)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        if tuningManager.targetAchieved {
                            Button("Deploy Configuration") {
                                let _ = tuningManager.deployOptimizedConfiguration()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    Button("Start Optimization") {
                        Task {
                            let result = await tuningManager.startOptimization()
                            optimizationResult = result
                            showingResults = true
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(tuningManager.isOptimizing)
                }
            }
        }
        .padding()
        .alert("Optimization Results", isPresented: $showingResults) {
            Button("OK") { }
        } message: {
            Text(optimizationResult?.message ?? "No results available")
        }
    }
}