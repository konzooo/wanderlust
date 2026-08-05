import CoreArchitecture
import CoreModels
import Networking
import XCTest
@testable import Wanderlust

/// The S5 content: Worth-it/Skip, the where-to-stay guide and the interest
/// chips — how they persist, how they reach the screen under either arm of the
/// D15 experiment, and what does and does not travel in a share.
@MainActor
final class DiscoverContentTests: XCTestCase {

    // MARK: - Persistence

    func testTheNewSectionsRoundTripThroughDisk() throws {
        var original = Trip(details: .mock, itinerary: .mock, suggestions: .mock)
        original.worthItItems = Trip.WorthItItem.mockSet
        original.whereToStay = Trip.StayArea.mockSet
        original.interestPrompts = ["Natural wine bars", "Rooftop sunsets"]

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.schemaVersion, 3)
        XCTAssertEqual(decoded.worthItItems?.count, 4)
        XCTAssertEqual(decoded.whereToStay?.count, 5)
        XCTAssertEqual(decoded.interestPrompts, ["Natural wine bars", "Rooftop sunsets"])
    }

    /// A `StayArea`'s id must survive the round trip for the same reason a
    /// `LocationLinkableText`'s does: a `ForEach` whose identity is regenerated
    /// on every decode animates each reload as a full replacement.
    func testStayAreaIdsArePersistedRatherThanRegenerated() throws {
        var original = Trip(details: .mock, itinerary: .mock, suggestions: .mock)
        original.whereToStay = Trip.StayArea.mockSet

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.whereToStay?.map(\.id), original.whereToStay?.map(\.id))
    }

    /// A v2 file predates all three sections. §4's rule is that a missing
    /// section is simply absent — never regenerated, never a crash.
    func testAV2TripWithoutTheNewSectionsDecodesToNil() throws {
        let json = """
        {
          "schemaVersion": 2,
          "details": \(try encoded(Trip.Details.mock)),
          "itinerary": \(try encoded(Trip.Itinerary.mock)),
          "suggestionsState": {"state": "absent"},
          "favorites": {"liked": []}
        }
        """

        let trip = try JSONDecoder().decode(Trip.self, from: Data(json.utf8))

        XCTAssertEqual(trip.schemaVersion, 2)
        XCTAssertNil(trip.whereToStay)
        XCTAssertNil(trip.interestPrompts)
        XCTAssertNil(trip.worthItItems)
    }

    /// Merge-on-complete: a section still generating writes as `nil` and must
    /// not erase one that finished in an earlier session.
    func testAnUnfinishedSectionDoesNotEraseAStoredOne() {
        var stored = Trip(details: .mock, itinerary: .mock, suggestions: .mock)
        stored.whereToStay = Trip.StayArea.mockSet
        stored.interestPrompts = ["Natural wine bars"]

        let inFlight = Trip(details: .mock, itinerary: .mock, suggestions: .mock)
        let merged = inFlight.merged(over: stored)

        XCTAssertEqual(merged.whereToStay?.count, 5)
        XCTAssertEqual(merged.interestPrompts, ["Natural wine bars"])
    }

    // MARK: - Both arms produce the same screen

    func testTheSplitVariantRequestsEachSectionSeparately() {
        XCTAssertEqual(
            TripComponent.automatic(variant: .split),
            [.itinerary, .suggestions, .knowBeforeYouGo, .worthIt, .whereToStay]
        )
        XCTAssertEqual(
            TripComponent.automatic(variant: .combined),
            [.itinerary, .suggestions, .knowBeforeYouGo]
        )
    }

    func testTheCombinedVariantFansTheSuggestionsResponseOutIntoEachSection() async {
        let store = makeStore(
            variant: .combined,
            suggestions: CombinedSuggestionsService()
        )

        store.send(.onAppear)
        await waitUntil { store.state.worthItResponse.data != nil }

        XCTAssertEqual(store.state.worthItResponse.data?.count, 4)
        XCTAssertEqual(store.state.whereToStayResponse.data?.count, 5)
        XCTAssertEqual(store.state.interestPrompts, ["Natural wine bars"])
    }

    /// The cost D15 weighs, made visible: under the combined variant one failed
    /// call takes all three sections with it, and each has to be able to say so.
    func testACombinedFailureFailsEverySectionItCarried() async {
        let store = makeStore(variant: .combined, suggestions: FailingSuggestionsService())

        store.send(.onAppear)
        await waitUntil { store.state.suggestionsResponse.error != nil }

        XCTAssertNotNil(store.state.worthItResponse.error)
        XCTAssertNotNil(store.state.whereToStayResponse.error)
    }

    /// …and the split variant's whole point: a failure that costs one section.
    func testASplitFailureLeavesTheOtherSectionsAlone() async {
        let store = makeStore(variant: .split, suggestions: FailingSuggestionsService())

        store.send(.onAppear)
        await waitUntil { store.state.suggestionsResponse.error != nil }

        XCTAssertNil(store.state.worthItResponse.error)
        XCTAssertNil(store.state.whereToStayResponse.error)
    }

    /// Retrying Worth-it/Skip under the combined variant has to re-run the call
    /// that actually produces it, or the button does nothing.
    func testRetryingASectionUnderTheCombinedVariantRerunsTheSuggestionsCall() async {
        let suggestions = CountingCombinedService()
        let store = makeStore(variant: .combined, suggestions: suggestions)

        store.send(.onAppear)
        await waitUntil { suggestions.callCount == 1 }
        store.send(.retryComponent(.worthIt))
        await waitUntil { suggestions.callCount == 2 }

        XCTAssertEqual(suggestions.callCount, 2)
    }

    // MARK: - Chips

    func testTheChipRowIsThreeModelPicksFollowedByTheThreeFixedOnes() {
        let store = makeStore(variant: .split, suggestions: MockSuggestionsService())
        store.state.interestPrompts = ["Natural wine bars", "Rooftop sunsets", "Sunday markets"]

        XCTAssertEqual(
            store.interestChips,
            [
                "Natural wine bars", "Rooftop sunsets", "Sunday markets",
                "Running routes", "Remote-work cafés", "Climbing gyms"
            ]
        )
    }

    /// A shared trip from an older build can carry a model pick that duplicates
    /// a fixed chip. Two "Climbing gyms" in one row is a bug you can see.
    func testAModelPickThatDuplicatesAFixedChipIsDropped() {
        let store = makeStore(variant: .split, suggestions: MockSuggestionsService())
        store.state.interestPrompts = ["Climbing Gyms", "Remote work cafes", "Sunday markets"]

        XCTAssertEqual(store.interestChips.count, 4)
        XCTAssertEqual(
            store.interestChips.filter { $0.lowercased().contains("climbing") }.count, 1
        )
    }

    // MARK: - Sharing

    /// §4: content travels, decisions do not. The recipient gets the cards
    /// undecided, because deciding is the point of the section.
    func testWorthItDecisionsAreNotPartOfTheSharedTripPayload() {
        // The rule is a negative — no field on the received payload may carry
        // the sender's decisions — so it is asserted against the whole key set
        // rather than against one absence. Adding one later fails here.
        let keys = SharedTripDTO.CodingKeys.allCases.map(\.stringValue)
        XCTAssertTrue(keys.contains("worthItItems"))
        XCTAssertTrue(keys.contains("whereToStay"))
        XCTAssertTrue(keys.contains("interestPrompts"))
        XCTAssertFalse(keys.contains("worthItDecisions"))
    }

    // MARK: - The bundled evaluation output

    /// The debug browser's samples are raw model output, so they decode through
    /// exactly the same path a real response does. If a schema changes and this
    /// file stops decoding, the browser silently shows an empty list — which is
    /// indistinguishable from "the run produced nothing" and would quietly
    /// remove the only surface for judging factuality.
    func testTheBundledEvaluationSamplesStillDecode() throws {
        let samples = EvalSample.all

        XCTAssertEqual(samples.count, 8, "One per §13 destination archetype")
        for sample in samples {
            XCTAssertFalse(sample.itinerary.segments.isEmpty, sample.id)
            XCTAssertFalse(sample.suggestions.staticSuggestions.isEmpty, sample.id)
            XCTAssertEqual(sample.worthIt.count, 4, "\(sample.id): D7 asks for four")
            XCTAssertGreaterThanOrEqual(sample.whereToStay.count, 3, sample.id)
            XCTAssertEqual(sample.interestPrompts.count, 3, "\(sample.id): D8 asks for three")
        }
    }

    /// The month a sample renders is read back from its fixture, and `Month`'s
    /// raw values are mixed case — `August` and `September` are capitalised and
    /// the rest are not. A plain `Month(rawValue:)` would label two of the eight
    /// samples January.
    func testSampleMonthsSurviveTheMixedCaseRawValues() {
        let months = EvalSample.all.map(\.outputState.details.month)
        XCTAssertTrue(months.contains(.August), "barcelona-family-summer is an August trip")
        XCTAssertEqual(
            months.filter { $0 == .january }.count, 1,
            "Only Cape Verde is a January trip; more than one means a fallback fired"
        )
    }

    // MARK: - Helpers

    private func makeStore(
        variant: SuggestionsVariant,
        suggestions: any SuggestionsGenerating
    ) -> TripOutputStore {
        TripOutputStore(
            initialState: .init(
                generationRequest: .init(input: .mock),
                details: .mock,
                mode: .newTrip
            ),
            imageService: StubImageService(),
            // Instant rather than `MockItineraryService`, whose deliberate
            // delay exists to exercise the loading state and would make these
            // tests wait on a clock for something they are not asserting.
            itineraryService: InstantItineraryService(),
            suggestionsService: suggestions,
            worthItService: InstantWorthItService(),
            whereToStayService: InstantWhereToStayService(),
            variant: variant
        )
    }

    /// Waits for a condition instead of spinning a fixed number of yields.
    ///
    /// Yield-spinning is a race dressed up as synchronisation: it passes on an
    /// idle machine and fails under a full suite, which is the worst way for a
    /// test to fail — it looks like the code broke. These stores drive real
    /// `Task`s through a coordinator, so the only honest wait is on the state
    /// the test is actually asserting about.
    private func waitUntil(
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for the store to settle", file: file, line: line)
    }

    private func roundTrip(_ trip: Trip) throws -> Trip {
        try JSONDecoder().decode(Trip.self, from: JSONEncoder().encode(trip))
    }

    private func encoded<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }
}

// MARK: - Doubles

private struct CombinedSuggestionsService: SuggestionsGenerating {
    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> SuggestionsPayload {
        SuggestionsPayload(
            suggestions: .mock,
            interestPrompts: ["Natural wine bars"],
            worthIt: Trip.WorthItItem.mockSet,
            whereToStay: Trip.StayArea.mockSet
        )
    }
}

private final class CountingCombinedService: SuggestionsGenerating {
    private(set) var callCount = 0

    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> SuggestionsPayload {
        callCount += 1
        return SuggestionsPayload(
            suggestions: .mock,
            worthIt: Trip.WorthItItem.mockSet,
            whereToStay: Trip.StayArea.mockSet
        )
    }
}

private struct FailingSuggestionsService: SuggestionsGenerating {
    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> SuggestionsPayload {
        throw TripGenerationError.transport
    }
}

private struct InstantItineraryService: ItineraryGenerating {
    func generate(_ request: TripGenerationRequest) async throws -> Trip.Itinerary { .mock }
}

private struct InstantWorthItService: WorthItGenerating {
    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> [Trip.WorthItItem] {
        Trip.WorthItItem.mockSet
    }
}

private struct InstantWhereToStayService: WhereToStayGenerating {
    func generate(_ request: TripGenerationRequest) async throws -> [Trip.StayArea] {
        Trip.StayArea.mockSet
    }
}

private struct StubImageService: ImageService {
    func fetchImageURL(for query: String) async throws -> URL {
        URL(string: "https://example.invalid/image.jpg")!
    }
}
