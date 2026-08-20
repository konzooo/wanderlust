import CoreArchitecture
import CoreModels
import DesignSystem
import Networking
import XCTest
@testable import Wanderlust

@MainActor
final class AnalyticsStoreTests: XCTestCase {
    private var recorder: RecordingAnalyticsService!

    override func setUp() async throws {
        recorder = RecordingAnalyticsService()
        AnalyticsTracker.shared.useForTesting(recorder)
    }

    override func tearDown() async throws {
        AnalyticsTracker.shared.useForTesting(nil)
        recorder = nil
    }

    func testQuestionnaireStartFiresExactlyOnce() {
        let store = QuestionnaireStore(mode: .solo)

        store.send(.start)
        store.send(.start)

        XCTAssertEqual(events(named: .questionnaireStarted).count, 1)
    }

    func testQuestionnaireCompletionCanBeEmittedExactlyOnce() {
        let store = QuestionnaireStore(mode: .solo)
        store.send(.start)

        let first = store.completionEvent(profile: nil)
        let second = store.completionEvent(profile: nil)
        if let first {
            AnalyticsTracker.shared.log(first)
        }

        XCTAssertNotNil(first)
        XCTAssertNil(second)
        XCTAssertEqual(events(named: .questionnaireCompleted).count, 1)
    }

    func testQuestionnaireAnswerLogsPartialProgressAndChoice() {
        let store = QuestionnaireStore(mode: .solo)
        store.send(.start)

        store.send(.cardSwipped(store.state.cards[0], SwipeDirection.top))

        let event = events(named: .questionnaireAnswered).first
        XCTAssertEqual(event?.properties["question_key"], .string("q01"))
        XCTAssertEqual(event?.properties["step_index"], .integer(0))
        XCTAssertEqual(event?.properties["choice"], .string("both"))
    }

    func testItineraryGenerationLogsOneStartAndOneSuccess() async {
        let store = makeTripStore(itinerary: SuccessfulItineraryGenerator())

        store.generate(.itinerary)
        await waitUntil { store.state.itineraryResponse.isLoaded }

        XCTAssertEqual(componentEvents(.tripGenerationStarted, "itinerary").count, 1)
        XCTAssertEqual(componentEvents(.tripGenerationSucceeded, "itinerary").count, 1)
        XCTAssertEqual(componentEvents(.tripGenerationFailed, "itinerary").count, 0)
        XCTAssertEqual(events(named: .tripCreated).count, 1)
    }

    func testItineraryGenerationLogsOneSanitizedFailure() async {
        let store = makeTripStore(itinerary: FailingItineraryGenerator())

        store.generate(.itinerary)
        await waitUntil { store.state.itineraryResponse.error != nil }

        XCTAssertEqual(componentEvents(.tripGenerationStarted, "itinerary").count, 1)
        XCTAssertEqual(componentEvents(.tripGenerationSucceeded, "itinerary").count, 0)
        let failures = componentEvents(.tripGenerationFailed, "itinerary")
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(
            failures.first?.properties["error_category"],
            .string("network")
        )
        XCTAssertNil(failures.first?.properties["raw_error"])
    }

    private func makeTripStore(
        itinerary: any ItineraryGenerating
    ) -> TripOutputStore {
        TripOutputStore(
            initialState: .init(
                generationRequest: .init(input: .mock),
                details: .init(
                    destination: .init(name: "Lisbon, Portugal"),
                    members: .init(groupType: .solo),
                    duration: 3,
                    month: .may
                ),
                mode: .newTrip
            ),
            imageService: StubImageService(),
            itineraryService: itinerary,
            suggestionsService: SuccessfulSuggestionsGenerator(),
            worthItService: MockWorthItService(),
            whereToStayService: MockWhereToStayService()
        )
    }

    private func events(named name: AnalyticsEventName) -> [AnalyticsEvent] {
        recorder.events.filter { $0.name == name }
    }

    private func componentEvents(
        _ name: AnalyticsEventName,
        _ component: String
    ) -> [AnalyticsEvent] {
        events(named: name).filter {
            $0.properties["component"] == .string(component)
        }
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(condition())
    }
}

private struct SuccessfulItineraryGenerator: ItineraryGenerating {
    func generate(_ request: TripGenerationRequest) async throws -> Trip.Itinerary {
        .mock
    }
}

private struct FailingItineraryGenerator: ItineraryGenerating {
    func generate(_ request: TripGenerationRequest) async throws -> Trip.Itinerary {
        throw URLError(.notConnectedToInternet)
    }
}

private struct SuccessfulSuggestionsGenerator: SuggestionsGenerating {
    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> SuggestionsPayload {
        SuggestionsPayload(suggestions: .mock)
    }
}

private struct StubImageService: ImageService {
    func fetchImageURL(for query: String) async throws -> URL {
        URL(string: "https://example.invalid/image.jpg")!
    }
}
