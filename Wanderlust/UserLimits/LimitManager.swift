import Foundation
import SwiftUI

/// Manager class to handle all usage metrics operations
class MetricsTracker: ObservableObject {
    private let storage: UsageMetricsStorage
    
    @Published private(set) var currentMetrics: [UsageMetricKey: Int] = [:]
    
    init(storage: UsageMetricsStorage = UserDefaultsUsageMetricsStorage()) {
        self.storage = storage
        updateCurrentMetrics()
    }
    
    /// Check if a specific metric has reached its threshold
    /// - Parameter key: The metric key to check
    /// - Returns: True if the threshold has been reached, false otherwise
    func isThresholdReached(for key: UsageMetricKey) -> Bool {
        return storage.isThresholdReached(for: key)
    }
    
    /// Increment a specific metric
    /// - Parameter key: The metric key to increment
    /// - Returns: The new value after incrementing
    @discardableResult
    func increment(for key: UsageMetricKey) -> Int {
        let newValue = storage.increment(for: key)
        updateCurrentMetrics()
        return newValue
    }
    
    /// Get the current value for a specific metric
    /// - Parameter key: The metric key to get the value for
    /// - Returns: The current value of the metric
    func getValue(for key: UsageMetricKey) -> Int {
        return storage.getValue(for: key)
    }
    
    /// Reset a specific metric
    /// - Parameter key: The metric key to reset
    func reset(for key: UsageMetricKey) {
        storage.reset(for: key)
        updateCurrentMetrics()
    }
    
    /// Get the threshold value for a specific metric
    /// - Parameter key: The metric key to get the threshold for
    /// - Returns: The threshold value
    func getThreshold(for key: UsageMetricKey) -> Int {
        return key.threshold
    }
    
    // MARK: - Private Methods
    
    private func updateCurrentMetrics() {
        var newMetrics: [UsageMetricKey: Int] = [:]
        for key in UsageMetricKey.allCases {
            newMetrics[key] = storage.getValue(for: key)
        }
        currentMetrics = newMetrics
    }
}

// MARK: - UsageMetricKey Extension

extension UsageMetricKey: CaseIterable {} 