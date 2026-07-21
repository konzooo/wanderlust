import Foundation

/// Protocol defining the interface for storing and retrieving metrics
public protocol MetricsStorage {
    /// Get the current value for a specific metric
    /// - Parameter key: The key identifying the metric
    /// - Returns: The current value of the metric
    func getValue(for key: MetricKey) -> Int
    
    /// Set a new value for a specific metric
    /// - Parameters:
    ///   - value: The new value to set
    ///   - key: The key identifying the metric
    func setValue(_ value: Int, for key: MetricKey)
    
    /// Increment the current value for a specific metric
    /// - Parameter key: The key identifying the metric
    /// - Returns: The new value after incrementing
    func increment(for key: MetricKey) -> Int
    
    /// Reset the value for a specific metric
    /// - Parameter key: The key identifying the metric
    func reset(for key: MetricKey)
    
    /// Check if a metric has reached its threshold
    /// - Parameter key: The key identifying the metric
    /// - Returns: True if the threshold has been reached, false otherwise
    func isThresholdReached(for key: MetricKey) -> Bool
}
