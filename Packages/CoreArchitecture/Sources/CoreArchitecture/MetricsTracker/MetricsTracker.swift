import Foundation
import SwiftUI

/// Manager class to handle all metrics operations
public class MetricsTracker: ObservableObject {
    private let storage: MetricsStorage
    
    /// In-memory cache of current metrics
    @Published private(set) var currentMetrics: [MetricKey: Int] = [:]
    
    public init(storage: MetricsStorage) {
        self.storage = storage
        // Initialize in-memory cache from storage
        loadMetricsFromStorage()
    }
    
    /// Check if a specific metric has reached its threshold
    /// - Parameter key: The metric key to check
    /// - Returns: True if the threshold has been reached, false otherwise
    public func thresholdReached(for key: MetricKey) -> Bool {
        return currentMetrics[key, default: 0] >= key.threshold
    }
    
    /// Increment a specific metric
    /// - Parameter key: The metric key to increment
    /// - Returns: The new value after incrementing
    @discardableResult
    public func increment(for key: MetricKey) -> Int {
        let currentValue = currentMetrics[key, default: 0]
        let newValue = currentValue + 1
        
        // Update in-memory cache
        currentMetrics[key] = newValue
        
        // Persist to storage
        storage.setValue(newValue, for: key)
        
        return newValue
    }
    
    /// Get the current value for a specific metric
    /// - Parameter key: The metric key to get the value for
    /// - Returns: The current value of the metric
    public func getValue(for key: MetricKey) -> Int {
        return currentMetrics[key, default: 0]
    }
    
    /// Reset a specific metric
    /// - Parameter key: The metric key to reset
    public func reset(for key: MetricKey) {
        // Update in-memory cache
        currentMetrics[key] = 0
        
        // Persist to storage
        storage.reset(for: key)
    }
    
    /// Get the threshold value for a specific metric
    /// - Parameter key: The metric key to get the threshold for
    /// - Returns: The threshold value
    public func getThreshold(for key: MetricKey) -> Int {
        return key.threshold
    }
    
    // MARK: - Private Methods
    
    /// Load all metrics from storage into memory
    private func loadMetricsFromStorage() {
        var newMetrics: [MetricKey: Int] = [:]
        for key in MetricKey.allCases {
            newMetrics[key] = storage.getValue(for: key)
        }
        currentMetrics = newMetrics
    }
} 
