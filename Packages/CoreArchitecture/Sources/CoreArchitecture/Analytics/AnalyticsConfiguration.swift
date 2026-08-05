import Foundation

public struct AnalyticsConfiguration: Equatable, Sendable {
    public let apiKey: String
    public let distributionChannel: String
    public let networkEnabled: Bool

    public init(
        apiKey: String,
        distributionChannel: String,
        networkEnabled: Bool
    ) {
        self.apiKey = apiKey
        self.distributionChannel = distributionChannel
        self.networkEnabled = networkEnabled && !apiKey.isEmpty
    }

    public static func appDefault(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> Self {
        let apiKey = (bundle.object(forInfoDictionaryKey: "AmplitudeAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isUITesting = processInfo.arguments.contains("-ui-testing")
            || processInfo.arguments.contains("-ui-testing-reset-profiles")

#if DEBUG
        let live = processInfo.arguments.contains("-analytics-live") && !isUITesting
        return .init(apiKey: apiKey, distributionChannel: "debug", networkEnabled: live)
#else
        let isTestFlight = bundle.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        return .init(
            apiKey: apiKey,
            distributionChannel: isTestFlight ? "testflight" : "app_store",
            networkEnabled: !isUITesting
        )
#endif
    }
}
