import Foundation

/// Enum defining all possible usage metric keys and their thresholds
enum UsageMetricKey: String {
    case dailyItineraries = "daily_itineraries"
    case dailyPluginUsage = "daily_plugin_usage"
    case dailyShares = "daily_shares"
    
    /// The threshold value for this metric
    var threshold: Int {
        switch self {
        case .dailyItineraries:
            return 10
        case .dailyPluginUsage:
            return 20
        case .dailyShares:
            return 5
        }
    }
    
    /// The UserDefaults key for this metric
    var userDefaultsKey: String {
        return "metric_\(rawValue)"
    }
    
    /// The UserDefaults key for the last reset date
    var lastResetKey: String {
        return "metric_\(rawValue)_last_reset"
    }
} 