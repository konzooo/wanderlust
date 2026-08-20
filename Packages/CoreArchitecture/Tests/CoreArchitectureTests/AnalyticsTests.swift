import XCTest
@testable import CoreArchitecture

final class AnalyticsTests: XCTestCase {
    func testEveryEventNameIsLowercaseSnakeCaseAndUnique() {
        let names = AnalyticsEventName.allCases.map(\.rawValue)
        XCTAssertEqual(Set(names).count, names.count)

        let allowed = try! NSRegularExpression(pattern: "^[a-z][a-z0-9_]*$")
        for name in names {
            let range = NSRange(name.startIndex..., in: name)
            XCTAssertNotNil(
                allowed.firstMatch(in: name, range: range),
                "Invalid analytics event name: \(name)"
            )
        }
    }

    func testSchemaVersionIsStable() {
        XCTAssertEqual(AnalyticsEvent.schemaVersion, 2)
    }

    func testEveryTypedEventDeclaresRequiredProperties() {
        for name in AnalyticsEventName.allCases {
            XCTAssertFalse(
                AnalyticsEvent.requiredProperties(for: name).isEmpty,
                "Missing required-property contract for \(name.rawValue)"
            )
        }
    }

    func testContractValidationRejectsMissingRequiredProperties() {
        XCTAssertFalse(AnalyticsEvent(.screenViewed).isContractValid)
        XCTAssertTrue(
            AnalyticsEvent(
                .screenViewed,
                properties: ["screen_name": .string("home")]
            ).isContractValid
        )
    }

    func testContractValidationRejectsUnknownAndWronglyTypedProperties() {
        XCTAssertFalse(
            AnalyticsEvent(
                .screenViewed,
                properties: [
                    "screen_name": .string("home"),
                    "arbitrary_note": .string("should never enter the schema")
                ]
            ).isContractValid
        )
        XCTAssertFalse(
            AnalyticsEvent(
                .questionnaireAnswered,
                properties: [
                    "trip_mode": .string("solo"),
                    "questionnaire_version": .string("one"),
                    "question_key": .string("q01"),
                    "step_index": .integer(0),
                    "choice": .string("left")
                ]
            ).isContractValid
        )
    }

    func testQuestionnaireAnswerAcceptsOnlyCanonicalChoices() {
        let properties: [String: AnalyticsValue] = [
            "trip_mode": .string("solo"),
            "questionnaire_version": .integer(1),
            "question_key": .string("q01"),
            "step_index": .integer(0),
            "choice": .string("both")
        ]
        XCTAssertTrue(
            AnalyticsEvent(.questionnaireAnswered, properties: properties)
                .isContractValid
        )
        var invalid = properties
        invalid["choice"] = .string("option_a")
        XCTAssertFalse(
            AnalyticsEvent(.questionnaireAnswered, properties: invalid)
                .isContractValid
        )
    }

    func testProfileStepViewedAcceptsCanonicalStepNamesForCreateAndEdit() {
        let stepNames = [
            "identity", "advice_detail", "physical_energy",
            "experience_breadth", "day_rhythm", "structure",
            "usually_skip", "must_haves", "additional_notes"
        ]

        for operation in ["create", "edit"] {
            for (index, stepName) in stepNames.enumerated() {
                let event = AnalyticsEvent(.profileStepViewed, properties: [
                    "entry_point": .string("profile_tab"),
                    "operation": .string(operation),
                    "step_name": .string(stepName),
                    "step_index": .integer(index)
                ])

                XCTAssertEqual(event.properties["step_name"], .string(stepName))
                XCTAssertTrue(
                    event.isContractValid,
                    "Rejected \(operation) profile editor event for \(stepName)"
                )
            }
        }
    }

    func testProfileStepViewedRejectsNonCanonicalStepName() {
        let event = AnalyticsEvent(.profileStepViewed, properties: [
            "entry_point": .string("profile_tab"),
            "operation": .string("edit"),
            "step_name": .string("someone's profile"),
            "step_index": .integer(0)
        ])

        XCTAssertFalse(event.isContractValid)
    }

    func testErrorTaxonomyIsExact() {
        XCTAssertEqual(
            [
                AnalyticsErrorCategory.network,
                .timeout,
                .rateLimited,
                .authentication,
                .validation,
                .notFound,
                .conflict,
                .decoding,
                .storage,
                .service,
                .unknown
            ].map(\.rawValue),
            [
                "network", "timeout", "rate_limited", "authentication",
                "validation", "not_found", "conflict", "decoding",
                "storage", "service", "unknown"
            ]
        )
    }

    func testForbiddenAndFreeFormPropertiesFailClosed() {
        let event = AnalyticsEvent(.tripDetailsSubmitted, properties: [
            "destination": .string("lisbon"),
            "share_code": .string("secret"),
            "token": .string("secret"),
            "url": .string("https://example.com"),
            "access_token": .string("secret"),
            "member_code_hash": .string("secret"),
            "notes": .string("private"),
            "raw_error": .string("private"),
            "oversized": .string(String(repeating: "x", count: 121))
        ])

        XCTAssertTrue(event.properties.isEmpty)
    }

    func testAgeBucketingNeverEmitsExactAge() {
        XCTAssertEqual(AnalyticsSanitizer.ageBucket(nil), "unknown")
        XCTAssertEqual(AnalyticsSanitizer.ageBucket(17), "under_18")
        XCTAssertEqual(AnalyticsSanitizer.ageBucket(18), "18_24")
        XCTAssertEqual(AnalyticsSanitizer.ageBucket(34), "25_34")
        XCTAssertEqual(AnalyticsSanitizer.ageBucket(44), "35_44")
        XCTAssertEqual(AnalyticsSanitizer.ageBucket(54), "45_54")
        XCTAssertEqual(AnalyticsSanitizer.ageBucket(64), "55_64")
        XCTAssertEqual(AnalyticsSanitizer.ageBucket(65), "65_plus")
    }

    func testErrorClassificationUsesFixedTaxonomy() {
        XCTAssertEqual(
            AnalyticsSanitizer.errorCategory(URLError(.notConnectedToInternet)),
            .network
        )
        XCTAssertEqual(
            AnalyticsSanitizer.errorCategory(URLError(.timedOut)),
            .timeout
        )
        XCTAssertEqual(
            AnalyticsSanitizer.errorCategory(TestError("HTTP 429")),
            .rateLimited
        )
        XCTAssertEqual(
            AnalyticsSanitizer.errorCategory(TestError("401 unauthorized")),
            .authentication
        )
        XCTAssertEqual(
            AnalyticsSanitizer.errorCategory(TestError("conflict")),
            .conflict
        )
    }

    func testConfigurationDisablesDeliveryWhenKeyIsMissing() {
        let missingKey = AnalyticsConfiguration(
            apiKey: "",
            distributionChannel: "app_store",
            networkEnabled: true
        )
        XCTAssertFalse(missingKey.networkEnabled)

        let configured = AnalyticsConfiguration(
            apiKey: "client-facing-key",
            distributionChannel: "testflight",
            networkEnabled: true
        )
        XCTAssertTrue(configured.networkEnabled)
    }

    @MainActor
    func testRecordingClientPreservesOneTypedEventPerCall() {
        let recorder = RecordingAnalyticsService()
        let event = AnalyticsEvent(.tripSaved, properties: [
            "outcome": .string("success")
        ])

        recorder.log(event)

        XCTAssertEqual(recorder.events, [event])
    }

    @MainActor
    func testAnonymousUserPropertiesUseAnExactContract() {
        let recorder = RecordingAnalyticsService()
        AnalyticsTracker.shared.useForTesting(recorder)
        defer { AnalyticsTracker.shared.useForTesting(nil) }

        AnalyticsTracker.shared.setUserProperties([
            "has_profile": .boolean(true),
            "profile_count": .integer(2),
            "profile_name": .string("private"),
            "saved_solo_trip_count": .string("wrong type")
        ])

        XCTAssertEqual(recorder.userProperties, [
            "has_profile": .boolean(true),
            "profile_count": .integer(2)
        ])
    }
}

private struct TestError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
