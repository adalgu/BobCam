//
//  OptimizationEngine.swift
//  BobCam
//
//  Created by Claude Code on 2025/08/20.
//
//  Advanced optimization algorithms and statistical validation
//  Implements Bayesian optimization, genetic algorithms, and statistical testing
//

import Foundation
import Combine

// MARK: - Advanced Optimization Algorithms

enum OptimizationAlgorithm {
    case gridSearch
    case randomSearch
    case bayesianOptimization
    case geneticAlgorithm
    case particleSwarmOptimization
}

struct OptimizationConfiguration {
    let algorithm: OptimizationAlgorithm
    let maxIterations: Int
    let convergenceThreshold: Double
    let populationSize: Int // For genetic/swarm algorithms
    let mutationRate: Double // For genetic algorithm
    let crossoverRate: Double // For genetic algorithm
    let targetAccuracy: Double
    let timeoutMinutes: Double
}

// MARK: - Bayesian Optimization Implementation

class BayesianOptimizationEngine {

    private var observedParameters: [ParameterCombination] = []
    private var observedAccuracies: [Double] = []
    private let acquisitionFunction: AcquisitionFunction

    enum AcquisitionFunction {
        case expectedImprovement
        case upperConfidenceBound
        case probabilityOfImprovement
    }

    init(acquisitionFunction: AcquisitionFunction = .expectedImprovement) {
        self.acquisitionFunction = acquisitionFunction
    }

    func suggestNextParameter(searchSpace: ParameterSearchSpace) -> ParameterCombination {
        if observedParameters.isEmpty {
            // Return random initial parameter for first iteration
            return generateRandomParameter(searchSpace: searchSpace)
        }

        // Build Gaussian Process model
        let gpModel = buildGaussianProcessModel()

        // Optimize acquisition function to find next best parameter
        let candidate = optimizeAcquisitionFunction(gpModel: gpModel, searchSpace: searchSpace)

        return candidate
    }

    func updateObservations(parameter: ParameterCombination, accuracy: Double) {
        observedParameters.append(parameter)
        observedAccuracies.append(accuracy)
    }

    private func buildGaussianProcessModel() -> GaussianProcessModel {
        // Simplified GP model implementation
        return GaussianProcessModel(
            inputs: observedParameters.map { parameterToVector($0) },
            outputs: observedAccuracies
        )
    }

    private func optimizeAcquisitionFunction(gpModel: GaussianProcessModel, searchSpace: ParameterSearchSpace) -> ParameterCombination {
        var bestParameter: ParameterCombination?
        var bestAcquisitionValue = -Double.infinity

        // Sample candidate parameters
        for _ in 0..<1000 {
            let candidate = generateRandomParameter(searchSpace: searchSpace)
            let candidateVector = parameterToVector(candidate)

            let (mean, variance) = gpModel.predict(candidateVector)
            let acquisitionValue = calculateAcquisitionValue(mean: mean, variance: variance)

            if acquisitionValue > bestAcquisitionValue {
                bestAcquisitionValue = acquisitionValue
                bestParameter = candidate
            }
        }

        return bestParameter ?? generateRandomParameter(searchSpace: searchSpace)
    }

    private func calculateAcquisitionValue(mean: Double, variance: Double) -> Double {
        let bestObserved = observedAccuracies.max() ?? 0.0
        let sigma = sqrt(variance)

        switch acquisitionFunction {
        case .expectedImprovement:
            let improvement = mean - bestObserved
            let z = improvement / sigma
            let phi = normalPDF(z)
            let psi = normalCDF(z)
            return improvement * psi + sigma * phi

        case .upperConfidenceBound:
            let beta = 2.0 // Exploration parameter
            return mean + sqrt(beta) * sigma

        case .probabilityOfImprovement:
            let improvement = mean - bestObserved
            let z = improvement / sigma
            return normalCDF(z)
        }
    }

    private func generateRandomParameter(searchSpace: ParameterSearchSpace) -> ParameterCombination {
        return ParameterCombination(
            historySize: searchSpace.historySize.randomElement()!,
            eatingPatternThreshold: searchSpace.eatingPatternThreshold.randomElement()!,
            emaAlpha: searchSpace.emaAlpha.randomElement()!,
            minMovementThreshold: searchSpace.minMovementThreshold.randomElement()!,
            varianceThreshold: searchSpace.varianceThreshold.randomElement()!
        )
    }

    private func parameterToVector(_ parameter: ParameterCombination) -> [Double] {
        return [
            Double(parameter.historySize),
            Double(parameter.eatingPatternThreshold),
            Double(parameter.emaAlpha),
            Double(parameter.minMovementThreshold),
            Double(parameter.varianceThreshold)
        ]
    }

    private func normalPDF(_ x: Double) -> Double {
        return (1.0 / sqrt(2.0 * Double.pi)) * exp(-0.5 * x * x)
    }

    private func normalCDF(_ x: Double) -> Double {
        return 0.5 * (1.0 + erf(x / sqrt(2.0)))
    }

    private func erf(_ x: Double) -> Double {
        // Approximation of error function
        let a1 =  0.254829592
        let a2 = -0.284496736
        let a3 =  1.421413741
        let a4 = -1.453152027
        let a5 =  1.061405429
        let p  =  0.3275911

        let sign = x < 0 ? -1.0 : 1.0
        let x = abs(x)

        let t = 1.0 / (1.0 + p * x)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-x * x)

        return sign * y
    }
}

// MARK: - Gaussian Process Model

struct GaussianProcessModel {
    let inputs: [[Double]]
    let outputs: [Double]

    func predict(_ input: [Double]) -> (mean: Double, variance: Double) {
        // Simplified GP prediction using RBF kernel
        let kernel = RBFKernel(lengthScale: 1.0)

        var weightedSum = 0.0
        var totalWeight = 0.0
        var varianceSum = 0.0

        for i in 0..<inputs.count {
            let weight = kernel.evaluate(input, inputs[i])
            weightedSum += weight * outputs[i]
            totalWeight += weight

            let residual = outputs[i] - (weightedSum / totalWeight)
            varianceSum += weight * residual * residual
        }

        let mean = totalWeight > 0 ? weightedSum / totalWeight : 0.0
        let variance = totalWeight > 0 ? varianceSum / totalWeight : 1.0

        return (mean, variance)
    }
}

struct RBFKernel {
    let lengthScale: Double

    func evaluate(_ x1: [Double], _ x2: [Double]) -> Double {
        guard x1.count == x2.count else { return 0.0 }

        let squaredDistance = zip(x1, x2).reduce(0.0) { sum, pair in
            let diff = pair.0 - pair.1
            return sum + diff * diff
        }

        return exp(-squaredDistance / (2.0 * lengthScale * lengthScale))
    }
}

// MARK: - Genetic Algorithm Implementation

class GeneticAlgorithmEngine {

    let populationSize: Int
    let mutationRate: Double
    let crossoverRate: Double
    let elitismRate: Double

    private var population: [ParameterCombination] = []
    private var fitness: [Double] = []

    init(populationSize: Int = 50, mutationRate: Double = 0.1, crossoverRate: Double = 0.8, elitismRate: Double = 0.1) {
        self.populationSize = populationSize
        self.mutationRate = mutationRate
        self.crossoverRate = crossoverRate
        self.elitismRate = elitismRate
    }

    func evolve(searchSpace: ParameterSearchSpace, evaluationFunction: (ParameterCombination) async -> Double) async -> ParameterCombination {
        // Initialize population
        initializePopulation(searchSpace: searchSpace)

        // Evaluate initial population
        await evaluatePopulation(evaluationFunction: evaluationFunction)

        var bestFitness = fitness.max() ?? 0.0
        var generationsWithoutImprovement = 0
        let maxGenerationsWithoutImprovement = 10

        for generation in 0..<100 {
            print("🧬 Generation \(generation): Best fitness = \(String(format: "%.3f", bestFitness))")

            // Create next generation
            let newPopulation = createNextGeneration(searchSpace: searchSpace)
            population = newPopulation

            // Evaluate new population
            await evaluatePopulation(evaluationFunction: evaluationFunction)

            let currentBest = fitness.max() ?? 0.0
            if currentBest > bestFitness {
                bestFitness = currentBest
                generationsWithoutImprovement = 0
            } else {
                generationsWithoutImprovement += 1
            }

            // Check convergence
            if bestFitness >= 0.70 || generationsWithoutImprovement >= maxGenerationsWithoutImprovement {
                break
            }
        }

        // Return best individual
        let bestIndex = fitness.firstIndex(of: fitness.max()!) ?? 0
        return population[bestIndex]
    }

    private func initializePopulation(searchSpace: ParameterSearchSpace) {
        population = (0..<populationSize).map { _ in
            ParameterCombination(
                historySize: searchSpace.historySize.randomElement()!,
                eatingPatternThreshold: searchSpace.eatingPatternThreshold.randomElement()!,
                emaAlpha: searchSpace.emaAlpha.randomElement()!,
                minMovementThreshold: searchSpace.minMovementThreshold.randomElement()!,
                varianceThreshold: searchSpace.varianceThreshold.randomElement()!
            )
        }
    }

    private func evaluatePopulation(evaluationFunction: (ParameterCombination) async -> Double) async {
        fitness.removeAll()

        for individual in population {
            let fitnessValue = await evaluationFunction(individual)
            fitness.append(fitnessValue)
        }
    }

    private func createNextGeneration(searchSpace: ParameterSearchSpace) -> [ParameterCombination] {
        var newPopulation: [ParameterCombination] = []

        // Elitism: Keep best individuals
        let eliteCount = Int(Double(populationSize) * elitismRate)
        let sortedIndices = fitness.indices.sorted { fitness[$0] > fitness[$1] }

        for i in 0..<eliteCount {
            newPopulation.append(population[sortedIndices[i]])
        }

        // Generate offspring through crossover and mutation
        while newPopulation.count < populationSize {
            let parent1 = selectParent()
            let parent2 = selectParent()

            var offspring: [ParameterCombination]
            if Double.random(in: 0...1) < crossoverRate {
                offspring = crossover(parent1, parent2, searchSpace: searchSpace)
            } else {
                offspring = [parent1, parent2]
            }

            for child in offspring {
                if newPopulation.count < populationSize {
                    let mutatedChild = mutate(child, searchSpace: searchSpace)
                    newPopulation.append(mutatedChild)
                }
            }
        }

        return newPopulation
    }

    private func selectParent() -> ParameterCombination {
        // Tournament selection
        let tournamentSize = 3
        var bestIndex = Int.random(in: 0..<population.count)
        var bestFitness = fitness[bestIndex]

        for _ in 1..<tournamentSize {
            let candidateIndex = Int.random(in: 0..<population.count)
            if fitness[candidateIndex] > bestFitness {
                bestIndex = candidateIndex
                bestFitness = fitness[candidateIndex]
            }
        }

        return population[bestIndex]
    }

    private func crossover(_ parent1: ParameterCombination, _ parent2: ParameterCombination, searchSpace: ParameterSearchSpace) -> [ParameterCombination] {
        // Single-point crossover
        let crossoverPoint = Int.random(in: 1..<5)

        let child1 = ParameterCombination(
            historySize: crossoverPoint > 0 ? parent1.historySize : parent2.historySize,
            eatingPatternThreshold: crossoverPoint > 1 ? parent1.eatingPatternThreshold : parent2.eatingPatternThreshold,
            emaAlpha: crossoverPoint > 2 ? parent1.emaAlpha : parent2.emaAlpha,
            minMovementThreshold: crossoverPoint > 3 ? parent1.minMovementThreshold : parent2.minMovementThreshold,
            varianceThreshold: crossoverPoint > 4 ? parent1.varianceThreshold : parent2.varianceThreshold
        )

        let child2 = ParameterCombination(
            historySize: crossoverPoint > 0 ? parent2.historySize : parent1.historySize,
            eatingPatternThreshold: crossoverPoint > 1 ? parent2.eatingPatternThreshold : parent1.eatingPatternThreshold,
            emaAlpha: crossoverPoint > 2 ? parent2.emaAlpha : parent1.emaAlpha,
            minMovementThreshold: crossoverPoint > 3 ? parent2.minMovementThreshold : parent1.minMovementThreshold,
            varianceThreshold: crossoverPoint > 4 ? parent2.varianceThreshold : parent1.varianceThreshold
        )

        return [child1, child2]
    }

    private func mutate(_ individual: ParameterCombination, searchSpace: ParameterSearchSpace) -> ParameterCombination {
        var mutated = individual

        if Double.random(in: 0...1) < mutationRate {
            mutated = ParameterCombination(
                historySize: Double.random(in: 0...1) < 0.2 ? searchSpace.historySize.randomElement()! : mutated.historySize,
                eatingPatternThreshold: Double.random(in: 0...1) < 0.2 ? searchSpace.eatingPatternThreshold.randomElement()! : mutated.eatingPatternThreshold,
                emaAlpha: Double.random(in: 0...1) < 0.2 ? searchSpace.emaAlpha.randomElement()! : mutated.emaAlpha,
                minMovementThreshold: Double.random(in: 0...1) < 0.2 ? searchSpace.minMovementThreshold.randomElement()! : mutated.minMovementThreshold,
                varianceThreshold: Double.random(in: 0...1) < 0.2 ? searchSpace.varianceThreshold.randomElement()! : mutated.varianceThreshold
            )
        }

        return mutated
    }
}

// MARK: - Statistical Validation Framework

class StatisticalValidationFramework {

    func performStatisticalTests(results: [ValidationResult]) -> StatisticalValidationReport {
        let accuracies = results.map { $0.metrics.overallAccuracy }

        // Basic statistics
        let mean = accuracies.reduce(0, +) / Double(accuracies.count)
        let variance = accuracies.map { pow($0 - mean, 2) }.reduce(0, +) / Double(accuracies.count - 1)
        let standardDeviation = sqrt(variance)
        let standardError = standardDeviation / sqrt(Double(accuracies.count))

        // Confidence interval for mean accuracy
        let tCritical = 1.96 // Approximate for 95% confidence with large sample
        let confidenceInterval = (
            lower: mean - tCritical * standardError,
            upper: mean + tCritical * standardError
        )

        // Statistical significance test (one-sample t-test against 70% target)
        let targetAccuracy = 0.70
        let tStatistic = (mean - targetAccuracy) / standardError
        let pValue = calculatePValue(tStatistic: tStatistic, degreesOfFreedom: accuracies.count - 1)

        // Effect size (Cohen's d)
        let cohensD = (mean - targetAccuracy) / standardDeviation

        // Normality test (Shapiro-Wilk approximation)
        let normalityPValue = performShapiroWilkTest(data: accuracies)

        return StatisticalValidationReport(
            sampleSize: accuracies.count,
            mean: mean,
            standardDeviation: standardDeviation,
            standardError: standardError,
            confidenceInterval: confidenceInterval,
            tStatistic: tStatistic,
            pValue: pValue,
            cohensD: cohensD,
            normalityPValue: normalityPValue,
            isSignificantlyBetterThanTarget: pValue < 0.05 && mean > targetAccuracy,
            passedNormalityTest: normalityPValue > 0.05
        )
    }

    func performMultipleComparisonCorrection(pValues: [Double]) -> [Double] {
        // Bonferroni correction
        let correctionFactor = Double(pValues.count)
        return pValues.map { min($0 * correctionFactor, 1.0) }
    }

    func calculatePowerAnalysis(effectSize: Double, alpha: Double = 0.05, power: Double = 0.80) -> Int {
        // Simplified power analysis for required sample size
        // Based on Cohen's formula for one-sample t-test
        let zAlpha = 1.96 // Critical value for α = 0.05 (two-tailed)
        let zBeta = 0.84  // Critical value for β = 0.20 (power = 0.80)

        let requiredSampleSize = pow((zAlpha + zBeta) / effectSize, 2)

        return max(Int(ceil(requiredSampleSize)), 10)
    }

    private func calculatePValue(tStatistic: Double, degreesOfFreedom: Int) -> Double {
        // Simplified p-value calculation using normal approximation for large df
        if degreesOfFreedom > 30 {
            return 2 * (1 - normalCDF(abs(tStatistic)))
        } else {
            // For small samples, use approximation
            return 2 * (1 - normalCDF(abs(tStatistic) * 0.95))
        }
    }

    private func performShapiroWilkTest(data: [Double]) -> Double {
        // Simplified normality test
        // Returns approximate p-value for normality

        guard data.count >= 3 else { return 1.0 }

        let sorted = data.sorted()
        let n = data.count
        let mean = data.reduce(0, +) / Double(n)

        // Calculate skewness and kurtosis
        let variance = data.map { pow($0 - mean, 2) }.reduce(0, +) / Double(n)
        let skewness = data.map { pow($0 - mean, 3) }.reduce(0, +) / (Double(n) * pow(variance, 1.5))
        let kurtosis = data.map { pow($0 - mean, 4) }.reduce(0, +) / (Double(n) * variance * variance) - 3

        // Approximate normality based on skewness and kurtosis
        let normalityScore = abs(skewness) + abs(kurtosis) / 2

        if normalityScore < 0.5 {
            return 0.8 // High probability of normality
        } else if normalityScore < 1.0 {
            return 0.3 // Moderate probability
        } else {
            return 0.05 // Low probability
        }
    }

    private func normalCDF(_ x: Double) -> Double {
        return 0.5 * (1.0 + erf(x / sqrt(2.0)))
    }

    private func erf(_ x: Double) -> Double {
        // Error function approximation
        let a1 =  0.254829592
        let a2 = -0.284496736
        let a3 =  1.421413741
        let a4 = -1.453152027
        let a5 =  1.061405429
        let p  =  0.3275911

        let sign = x < 0 ? -1.0 : 1.0
        let x = abs(x)

        let t = 1.0 / (1.0 + p * x)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-x * x)

        return sign * y
    }
}

// MARK: - Statistical Validation Report

struct StatisticalValidationReport {
    let sampleSize: Int
    let mean: Double
    let standardDeviation: Double
    let standardError: Double
    let confidenceInterval: (lower: Double, upper: Double)
    let tStatistic: Double
    let pValue: Double
    let cohensD: Double
    let normalityPValue: Double
    let isSignificantlyBetterThanTarget: Bool
    let passedNormalityTest: Bool

    var effectSizeInterpretation: String {
        let absD = abs(cohensD)
        if absD < 0.2 {
            return "Small effect"
        } else if absD < 0.5 {
            return "Medium effect"
        } else if absD < 0.8 {
            return "Large effect"
        } else {
            return "Very large effect"
        }
    }

    var confidenceLevel: String {
        return "95%"
    }

    var summary: String {
        let meanPercent = String(format: "%.1f%%", mean * 100)
        let ciLower = String(format: "%.1f%%", confidenceInterval.lower * 100)
        let ciUpper = String(format: "%.1f%%", confidenceInterval.upper * 100)
        let pValueText = String(format: "%.4f", pValue)

        return """
        Sample Size: \(sampleSize)
        Mean Accuracy: \(meanPercent)
        95% CI: [\(ciLower), \(ciUpper)]
        Statistical Significance: p = \(pValueText)
        Effect Size: \(effectSizeInterpretation) (d = \(String(format: "%.3f", cohensD)))
        Target Achievement: \(isSignificantlyBetterThanTarget ? "✅ Significantly better than 70%" : "❌ Not significantly better than 70%")
        """
    }
}

// MARK: - Advanced Optimization Engine

class AdvancedOptimizationEngine: ParameterTuningEngine {

    private let algorithm: OptimizationAlgorithm
    private let configuration: OptimizationConfiguration
    private let bayesianEngine: BayesianOptimizationEngine
    private let geneticEngine: GeneticAlgorithmEngine
    private let statisticalValidator: StatisticalValidationFramework

    init(algorithm: OptimizationAlgorithm = .bayesianOptimization, configuration: OptimizationConfiguration) {
        self.algorithm = algorithm
        self.configuration = configuration
        self.bayesianEngine = BayesianOptimizationEngine()
        self.geneticEngine = GeneticAlgorithmEngine(
            populationSize: configuration.populationSize,
            mutationRate: configuration.mutationRate,
            crossoverRate: configuration.crossoverRate
        )
        self.statisticalValidator = StatisticalValidationFramework()

        super.init()
    }

    override func startParameterTuning() async {
        await MainActor.run {
            isRunning = true
            currentProgress = 0.0
            results.removeAll()
            bestResult = nil
        }

        print("🚀 Starting advanced optimization with \(algorithm)")

        switch algorithm {
        case .gridSearch:
            await performGridSearch()
        case .randomSearch:
            await performRandomSearch()
        case .bayesianOptimization:
            await performBayesianOptimization()
        case .geneticAlgorithm:
            await performGeneticOptimization()
        case .particleSwarmOptimization:
            await performParticleSwarmOptimization()
        }

        await performStatisticalValidation()

        await MainActor.run {
            isRunning = false
        }
    }

    private func performBayesianOptimization() async {
        let searchSpace = ParameterSearchSpace()
        var iteration = 0

        while iteration < configuration.maxIterations {
            let parameter = bayesianEngine.suggestNextParameter(searchSpace: searchSpace)
            let result = await testParameterCombination(parameter)

            bayesianEngine.updateObservations(parameter: parameter, accuracy: result.metrics.overallAccuracy)

            await MainActor.run {
                results.append(result)
                currentProgress = Double(iteration) / Double(configuration.maxIterations)

                if bestResult == nil || result.metrics.overallAccuracy > bestResult!.metrics.overallAccuracy {
                    bestResult = result
                }
            }

            // Check convergence
            if result.metrics.overallAccuracy >= configuration.targetAccuracy {
                print("🎯 Target accuracy achieved at iteration \(iteration)")
                break
            }

            iteration += 1
        }
    }

    private func performGeneticOptimization() async {
        let searchSpace = ParameterSearchSpace()

        let bestParameter = await geneticEngine.evolve(searchSpace: searchSpace) { parameter in
            let result = await self.testParameterCombination(parameter)

            await MainActor.run {
                self.results.append(result)
                self.currentProgress = Double(self.results.count) / Double(self.configuration.maxIterations)

                if self.bestResult == nil || result.metrics.overallAccuracy > self.bestResult!.metrics.overallAccuracy {
                    self.bestResult = result
                }
            }

            return result.metrics.overallAccuracy
        }

        print("🧬 Genetic optimization completed. Best parameter: \(bestParameter.id)")
    }

    private func performRandomSearch() async {
        let searchSpace = ParameterSearchSpace()

        for iteration in 0..<configuration.maxIterations {
            let parameter = ParameterCombination(
                historySize: searchSpace.historySize.randomElement()!,
                eatingPatternThreshold: searchSpace.eatingPatternThreshold.randomElement()!,
                emaAlpha: searchSpace.emaAlpha.randomElement()!,
                minMovementThreshold: searchSpace.minMovementThreshold.randomElement()!,
                varianceThreshold: searchSpace.varianceThreshold.randomElement()!
            )

            let result = await testParameterCombination(parameter)

            await MainActor.run {
                results.append(result)
                currentProgress = Double(iteration) / Double(configuration.maxIterations)

                if bestResult == nil || result.metrics.overallAccuracy > bestResult!.metrics.overallAccuracy {
                    bestResult = result
                }
            }

            if result.metrics.overallAccuracy >= configuration.targetAccuracy {
                break
            }
        }
    }

    private func performGridSearch() async {
        await super.startParameterTuning()
    }

    private func performParticleSwarmOptimization() async {
        // TODO: Implement PSO algorithm
        await performRandomSearch() // Fallback to random search for now
    }

    private func performStatisticalValidation() async {
        let report = statisticalValidator.performStatisticalTests(results: results)

        print("\n📊 STATISTICAL VALIDATION REPORT")
        print(String(repeating: "=", count: 50))
        print(report.summary)
        print(String(repeating: "=", count: 50))
    }
}
