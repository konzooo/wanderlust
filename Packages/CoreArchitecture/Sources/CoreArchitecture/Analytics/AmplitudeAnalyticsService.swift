import AmplitudeSwift
import Foundation

final class AmplitudeAnalyticsService: AnalyticsService {
    private let configuration: AnalyticsConfiguration
    private var amplitude: Amplitude?

    init(configuration: AnalyticsConfiguration) {
        self.configuration = configuration
    }

    func configure() {
        let trackingOptions = TrackingOptions()
            .disableTrackCarrier()
            .disableTrackCity()
            .disableTrackCountry()
            .disableTrackDMA()
            .disableTrackIpAddress()
            .disableTrackIDFV()
            .disableTrackRegion()

        amplitude = Amplitude(
            configuration: Configuration(
                apiKey: configuration.apiKey,
                serverZone: .EU,
                trackingOptions: trackingOptions,
                autocapture: [.sessions, .appLifecycles],
                enableAutoCaptureRemoteConfig: false,
                enableDiagnostics: false
            )
        )
    }

    func log(_ event: AnalyticsEvent) {
        amplitude?.track(
            event: BaseEvent(
                eventType: event.name.rawValue,
                eventProperties: event.properties.mapValues(\.amplitudeValue)
            )
        )
    }
}
