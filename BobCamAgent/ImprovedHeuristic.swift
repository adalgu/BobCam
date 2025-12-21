//
//  ImprovedHeuristic.swift
//  A snippet demonstrating an improved heuristic algorithm.
//
//  This heuristic applies a weighted moving average and adaptive threshold.
//

import Foundation

struct ImprovedHeuristic {
    /// Window size for moving average
    let windowSize: Int
    /// Base threshold for detection
    let baseThreshold: Double

    init(windowSize: Int = 5, baseThreshold: Double = 0.5) {
        self.windowSize = windowSize
        self.baseThreshold = baseThreshold
    }

    /// Compute weighted moving average over the data
    private func weightedMovingAverage(_ data: [Double]) -> [Double] {
        let weights = (1...windowSize).map { Double($0) }
        let weightSum = weights.reduce(0, +)
        var result: [Double] = []
        for i in 0..<data.count {
            let start = max(0, i - windowSize + 1)
            let segment = data[start...i]
            let segmentWeights = weights.suffix(segment.count)
            let weightedSum = zip(segment, segmentWeights).map(*).reduce(0, +)
            result.append(weightedSum / weightSum)
        }
        return result
    }

    /// Evaluate data using adaptive threshold on moving average
    func evaluate(_ data: [Double]) -> [Bool] {
        let smoothed = weightedMovingAverage(data)
        let dynamicThreshold = baseThreshold * (1.0 + variance(of: smoothed))
        return smoothed.map { $0 > dynamicThreshold }
    }

    /// Simple variance calculation
    private func variance(of data: [Double]) -> Double {
        guard data.count > 1 else { return 0 }
        let mean = data.reduce(0, +) / Double(data.count)
        let sumSquared = data.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
        return sumSquared / Double(data.count - 1)
    }
}
