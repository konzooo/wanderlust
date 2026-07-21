import Foundation

/// UserDefaults-based implementation of UsageMetricsStorage
class UserDefaultsUsageMetricsStorage: UsageMetricsStorage {
    private let userDefaults: UserDefaults
    private let calendar: Calendar
    
    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar
    }
    
    func getValue(for key: UsageMetricKey) -> Int {
        checkAndResetIfNeeded(for: key)
        return userDefaults.integer(forKey: key.userDefaultsKey)
    }
    
    func setValue(_ value: Int, for key: UsageMetricKey) {
        userDefaults.set(value, forKey: key.userDefaultsKey)
    }
    
    func increment(for key: UsageMetricKey) -> Int {
        checkAndResetIfNeeded(for: key)
        let currentValue = getValue(for: key)
        let newValue = currentValue + 1
        setValue(newValue, for: key)
        return newValue
    }
    
    func reset(for key: UsageMetricKey) {
        setValue(0, for: key)
        userDefaults.set(Date(), forKey: key.lastResetKey)
    }
    
    func isThresholdReached(for key: UsageMetricKey) -> Bool {
        return getValue(for: key) >= key.threshold
    }
    
    // MARK: - Private Methods
    
    private func checkAndResetIfNeeded(for key: UsageMetricKey) {
        guard let lastResetDate = userDefaults.object(forKey: key.lastResetKey) as? Date else {
            reset(for: key)
            return
        }
        
        if !calendar.isDateInToday(lastResetDate) {
            reset(for: key)
        }
    }
} 