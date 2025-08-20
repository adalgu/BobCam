//
//  AccuracyCalculator.swift
//  Utility for computing accuracy metrics.
//

import Foundation

/// Calculates the accuracy of predictions against ground truth
/// - Parameters:
///   - predictions: Array of predicted labels or values.
///   - groundTruth: Array of true labels or values.
/// - Returns: Accuracy as a value between 0.0 and 1.0.
func calculateAccuracy<T: Equatable>(predictions: [T], groundTruth: [T]) -> Double {
    guard predictions.count == groundTruth.count, !predictions.isEmpty else {
        return 0.0
    }
    let correct = zip(predictions, groundTruth).filter { $0 == $1 }.count
    return Double(correct) / Double(predictions.count)
}
