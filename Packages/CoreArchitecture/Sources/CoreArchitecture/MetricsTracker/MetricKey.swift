import Foundation

/// Enum defining all possible metrics and their thresholds
public enum MetricKey: String, CaseIterable {
    case dailyItineraries = "daily_itineraries"
    case dailyPluginUsage = "daily_plugin_usage"
    case dailyShares = "daily_shares"
    
    /// The threshold value for this metric
    public var threshold: Int {
        switch self {
        case .dailyItineraries:
#if DEBUG
            return 999
#else
            return 10
#endif
        case .dailyPluginUsage:
            return 20
        case .dailyShares:
            return 5
        }
    }
    
    /// The UserDefaults key for this metric
    public var userDefaultsKey: String {
        return "metric_\(rawValue)"
    }
    
    /// The UserDefaults key for the last reset date
    public var lastResetKey: String {
        return "metric_\(rawValue)_last_reset"
    }
} 
