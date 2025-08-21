//
//  ParameterTuningUI.swift
//  BobCam
//
//  Created by Claude Code on 2025/08/20.
//
//  SwiftUI interface for parameter tuning and optimization visualization
//  Provides real-time monitoring and control of optimization process
//

import SwiftUI
import Combine

// MARK: - Main Parameter Tuning View

struct ParameterTuningView: View {
    
    @StateObject private var tuningEngine = ParameterTuningEngine()
    @StateObject private var groundTruthManager = GroundTruthManager()
    @State private var showingResults = false
    @State private var selectedDataset: GroundTruthDataset?
    @State private var showingABTest = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Header
                VStack {
                    Text("Parameter Optimization")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Systematic tuning for 70% accuracy target")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Dataset Selection
                DatasetSelectionView(
                    groundTruthManager: groundTruthManager,
                    selectedDataset: $selectedDataset
                )
                
                // Optimization Progress
                OptimizationProgressView(tuningEngine: tuningEngine)
                
                // Control Buttons
                VStack(spacing: 12) {
                    Button(action: startOptimization) {
                        HStack {
                            Image(systemName: tuningEngine.isRunning ? "stop.fill" : "play.fill")
                            Text(tuningEngine.isRunning ? "Stop Optimization" : "Start Optimization")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(tuningEngine.isRunning ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(selectedDataset == nil && !tuningEngine.isRunning)
                    
                    HStack(spacing: 12) {
                        Button("A/B Test") {
                            showingABTest = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                        Button("View Results") {
                            showingResults = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(tuningEngine.results.isEmpty)
                    }
                }
                .padding(.horizontal)
                
                // Best Result Summary
                if let bestResult = tuningEngine.bestResult {
                    BestResultSummaryView(result: bestResult)
                }
                
                Spacer()
            }
            .navigationTitle("Parameter Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingResults) {
                ResultsDetailView(results: tuningEngine.results, bestResult: tuningEngine.bestResult)
            }
            .sheet(isPresented: $showingABTest) {
                ABTestingView()
            }
        }
        .task {
            await groundTruthManager.loadDefaultDatasets()
        }
    }
    
    private func startOptimization() {
        if tuningEngine.isRunning {
            // TODO: Implement stop functionality
        } else {
            guard let dataset = selectedDataset else { return }
            
            Task {
                let frames = await groundTruthManager.extractFramesFromDataset(dataset)
                let groundTruthFrames = groundTruthManager.generateGroundTruthFrames(from: dataset)
                
                tuningEngine.loadTestVideoFrames(frames)
                tuningEngine.loadGroundTruthData(groundTruthFrames)
                
                await tuningEngine.startParameterTuning()
            }
        }
    }
}

// MARK: - Dataset Selection View

struct DatasetSelectionView: View {
    
    @ObservedObject var groundTruthManager: GroundTruthManager
    @Binding var selectedDataset: GroundTruthDataset?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Test Dataset")
                .font(.headline)
                .padding(.horizontal)
            
            if groundTruthManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading datasets...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(groundTruthManager.availableDatasets, id: \.id) { dataset in
                            DatasetCardView(
                                dataset: dataset,
                                isSelected: selectedDataset?.id == dataset.id
                            ) {
                                selectedDataset = dataset
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Dataset Card View

struct DatasetCardView: View {
    
    let dataset: GroundTruthDataset
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dataset.id.replacingOccurrences(of: "_", with: " "))
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(dataset.eatingEvents.count) events", systemImage: "fork.knife")
                    Label(dataset.metadata.lightingCondition.displayName, systemImage: "sun.max")
                    Label("Age \(dataset.metadata.participantAge)", systemImage: "person")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Quality: \(String(format: "%.0f", dataset.metadata.annotatorConfidence * 100))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(qualityColor)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .frame(width: 160, height: 100)
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
    
    private var qualityColor: Color {
        if dataset.metadata.annotatorConfidence >= 0.8 {
            return .green
        } else if dataset.metadata.annotatorConfidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Optimization Progress View

struct OptimizationProgressView: View {
    
    @ObservedObject var tuningEngine: ParameterTuningEngine
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Optimization Progress")
                    .font(.headline)
                Spacer()
                Text("\(Int(tuningEngine.currentProgress * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            
            ProgressView(value: tuningEngine.currentProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 2.0)
                .padding(.horizontal)
            
            HStack {
                VStack {
                    Text("\(tuningEngine.results.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Tested")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text(tuningEngine.bestResult?.metrics.isTargetAchieved == true ? "✅" : "❌")
                        .font(.title2)
                    Text("70% Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text(bestAccuracyText)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Best Accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var bestAccuracyText: String {
        guard let best = tuningEngine.bestResult else { return "--%" }
        return String(format: "%.1f%%", best.metrics.overallAccuracy * 100)
    }
}

// MARK: - Best Result Summary View

struct BestResultSummaryView: View {
    
    let result: ValidationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Best Configuration")
                    .font(.headline)
                Spacer()
                Image(systemName: result.passed70Percent ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.passed70Percent ? .green : .orange)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                MetricRow(label: "Overall Accuracy", value: result.metrics.overallAccuracy, isPercentage: true)
                MetricRow(label: "Precision", value: result.metrics.precision, isPercentage: true)
                MetricRow(label: "Recall", value: result.metrics.recall, isPercentage: true)
                MetricRow(label: "F1-Score", value: result.metrics.f1Score, isPercentage: true)
                MetricRow(label: "IoU Average", value: result.metrics.iouAverage, isPercentage: true)
            }
            
            Text("Parameter ID: \(result.parameterId)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(result.passed70Percent ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Metric Row View

struct MetricRow: View {
    
    let label: String
    let value: Double
    let isPercentage: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
            Spacer()
            Text(formattedValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(value >= 0.7 ? .green : (value >= 0.5 ? .orange : .red))
        }
    }
    
    private var formattedValue: String {
        if isPercentage {
            return String(format: "%.1f%%", value * 100)
        } else {
            return String(format: "%.3f", value)
        }
    }
}

// MARK: - Results Detail View

struct ResultsDetailView: View {
    
    let results: [ValidationResult]
    let bestResult: ValidationResult?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if results.isEmpty {
                    Text("No results available")
                        .foregroundColor(.secondary)
                        .font(.title2)
                } else {
                    List {
                        if let best = bestResult {
                            Section("Best Result") {
                                ResultRowView(result: best, isBest: true)
                            }
                        }
                        
                        Section("All Results") {
                            ForEach(results.indices, id: \.self) { index in
                                ResultRowView(result: results[index], isBest: false)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Optimization Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Result Row View

struct ResultRowView: View {
    
    let result: ValidationResult
    let isBest: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.parameterId.components(separatedBy: "_").joined(separator: ", "))
                    .font(.caption)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(String(format: "%.1f%%", result.metrics.overallAccuracy * 100))
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    if result.passed70Percent {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    if isBest {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            HStack {
                Text("P: \(String(format: "%.2f", result.metrics.precision))")
                    .font(.caption2)
                Text("R: \(String(format: "%.2f", result.metrics.recall))")
                    .font(.caption2)
                Text("F1: \(String(format: "%.2f", result.metrics.f1Score))")
                    .font(.caption2)
                Spacer()
                Text("\(String(format: "%.1f", result.processingTime))s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - A/B Testing View

struct ABTestingView: View {
    
    @State private var configA = LipDetectionConfiguration.default
    @State private var configB = LipDetectionConfiguration.default
    @State private var abResult: ABTestResult?
    @State private var isRunning = false
    @Environment(\.presentationMode) var presentationMode
    
    private let abTesting = ABTestingFramework()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("A/B Testing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                HStack(spacing: 20) {
                    ConfigurationEditor(title: "Configuration A", config: $configA)
                    ConfigurationEditor(title: "Configuration B", config: $configB)
                }
                
                Button("Run A/B Test") {
                    runABTest()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isRunning ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isRunning)
                
                if let result = abResult {
                    ABTestResultView(result: result)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func runABTest() {
        isRunning = true
        
        Task {
            // TODO: Load actual test data
            let testFrames: [(CVPixelBuffer, TimeInterval)] = []
            let groundTruth: [GroundTruthFrame] = []
            
            let result = await abTesting.compareConfigurations(
                configA, configB,
                testFrames: testFrames,
                groundTruth: groundTruth
            )
            
            await MainActor.run {
                abResult = result
                isRunning = false
            }
        }
    }
}

// MARK: - Configuration Editor View

struct ConfigurationEditor: View {
    
    let title: String
    @Binding var config: LipDetectionConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            ParameterSlider(
                title: "History Size",
                value: .constant(Double(config.historySize)),
                range: 5...30,
                step: 1
            ) { newValue in
                config = LipDetectionConfiguration(
                    historySize: Int(newValue),
                    minMovementThreshold: config.minMovementThreshold,
                    eatingPatternThreshold: config.eatingPatternThreshold,
                    varianceThreshold: config.varianceThreshold,
                    emaAlpha: config.emaAlpha
                )
            }
            
            ParameterSlider(
                title: "Eating Threshold",
                value: .constant(Double(config.eatingPatternThreshold)),
                range: 0.05...0.5,
                step: 0.05
            ) { newValue in
                config = LipDetectionConfiguration(
                    historySize: config.historySize,
                    minMovementThreshold: config.minMovementThreshold,
                    eatingPatternThreshold: Float(newValue),
                    varianceThreshold: config.varianceThreshold,
                    emaAlpha: config.emaAlpha
                )
            }
            
            ParameterSlider(
                title: "EMA Alpha",
                value: .constant(Double(config.emaAlpha)),
                range: 0.1...0.8,
                step: 0.1
            ) { newValue in
                config = LipDetectionConfiguration(
                    historySize: config.historySize,
                    minMovementThreshold: config.minMovementThreshold,
                    eatingPatternThreshold: config.eatingPatternThreshold,
                    varianceThreshold: config.varianceThreshold,
                    emaAlpha: Float(newValue)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Parameter Slider View

struct ParameterSlider: View {
    
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onChange: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Slider(value: $value, in: range, step: step) { _ in
                onChange(value)
            }
        }
    }
}

// MARK: - A/B Test Result View

struct ABTestResultView: View {
    
    let result: ABTestResult
    
    var body: some View {
        VStack(spacing: 16) {
            Text("A/B Test Results")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack {
                    Text("Configuration A")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(String(format: "%.1f%%", result.resultA.metrics.overallAccuracy * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(result.winner == .A ? .green : .secondary)
                    
                    if result.winner == .A {
                        Text("WINNER")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                
                VStack {
                    Text("vs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("Configuration B")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(String(format: "%.1f%%", result.resultB.metrics.overallAccuracy * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(result.winner == .B ? .green : .secondary)
                    
                    if result.winner == .B {
                        Text("WINNER")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Text("Significance Level: \(String(format: "%.3f", result.significanceLevel))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Extensions

extension LightingCondition {
    var displayName: String {
        switch self {
        case .bright: return "Bright"
        case .normal: return "Normal"
        case .dim: return "Dim"
        case .mixed: return "Mixed"
        }
    }
}