import CoreArchitecture
import CoreModels
import Networking
import XCTest
@testable import Wanderlust

/// The three properties the generation coordinator exists to guarantee:
/// one call per component, an explicit retry always wins, and a superseded
/// attempt writes nothing.
@MainActor
final class TripGenerationCoordinatorTests: XCTestCase {

    // MARK: - Single-flight

    func testASecondBeginWhileInFlightIsSuppressed() async {
        let coordinator = TripGenerationCoordinator()
        let gate = Gate()
        var calls = 0

        let first = coordinator.begin(.itinerary) { _ in
            calls += 1
            await gate.wait()
        }
        let second = coordinator.begin(.itinerary) { _ in
            calls += 1
        }

        XCTAssertEqual(first, 1)
        XCTAssertNil(second, "A run was already in flight; the second must not start")
        await gate.open()
        await settle()
        XCTAssertEqual(calls, 1)
    }

    func testANewRunIsAllowedOnceTheFirstFinishes() async {
        let coordinator = TripGenerationCoordinator()
        var calls = 0

        coordinator.begin(.itinerary) { _ in calls += 1 }
        await settle()
        let second = coordinator.begin(.itinerary) { _ in calls += 1 }
        await settle()

        XCTAssertEqual(second, 2)
        XCTAssertEqual(calls, 2)
    }

    func testComponentsAreTrackedIndependently() async {
        let coordinator = TripGenerationCoordinator()
        let gate = Gate()

        let itinerary = coordinator.begin(.itinerary) { _ in await gate.wait() }
        let suggestions = coordinator.begin(.suggestions) { _ in await gate.wait() }

        XCTAssertEqual(itinerary, 1)
        XCTAssertEqual(suggestions, 1, "A busy itinerary must not block suggestions")
        await gate.open()
        await settle()
    }

    // MARK: - Retry supersedes

    func testRestartCancelsAndSupersedesTheRunInFlight() async {
        let coordinator = TripGenerationCoordinator()
        let gate = Gate()
        var staleIsStillCurrent: Bool?

        coordinator.begin(.itinerary) { attempt in
            await gate.wait()
            staleIsStillCurrent = coordinator.isCurrent(.itinerary, attempt: attempt)
        }
        let retry = coordinator.begin(.itinerary, restart: true) { _ in }

        XCTAssertEqual(retry, 2)
        await gate.open()
        await settle()

        // This is the guard that stops a slow first response from landing on
        // top of the retry that replaced it.
        XCTAssertEqual(staleIsStillCurrent, false)
        XCTAssertTrue(coordinator.isCurrent(.itinerary, attempt: 2))
    }

    func testCancelAllLeavesEveryOutstandingAttemptStale() async {
        let coordinator = TripGenerationCoordinator()
        let gate = Gate()
        var attemptSeen: Int?

        coordinator.begin(.suggestions) { attempt in
            await gate.wait()
            attemptSeen = attempt
        }
        coordinator.cancelAll()
        await gate.open()
        await settle()

        XCTAssertEqual(attemptSeen, 1)
        XCTAssertFalse(coordinator.isInFlight(.suggestions))
    }

    // MARK: - Store behaviour

    /// V3: re-appearing during generation used to fire a second paid call for
    /// every component, because "still loading" is not "loaded".
    func testReappearingDuringGenerationDoesNotCallTwice() async {
        let itinerary = CountingItineraryService()
        let suggestions = CountingSuggestionsService()
        let store = makeStore(itinerary: itinerary, suggestions: suggestions)

        store.send(.onAppear)
        store.send(.onAppear)
        store.send(.onAppear)
        await itinerary.release()
        await suggestions.release()
        await settle()

        XCTAssertEqual(itinerary.callCount, 1)
        XCTAssertEqual(suggestions.callCount, 1)
    }

    /// A component that already succeeded is not regenerated on re-appear.
    func testAFinishedComponentIsNotRegeneratedOnReappear() async {
        let itinerary = CountingItineraryService()
        let suggestions = CountingSuggestionsService()
        let store = makeStore(itinerary: itinerary, suggestions: suggestions)

        store.send(.onAppear)
        await itinerary.release()
        await suggestions.release()
        await settle()
        store.send(.onAppear)
        await settle()

        XCTAssertEqual(itinerary.callCount, 1)
        XCTAssertEqual(suggestions.callCount, 1)
    }

    /// V5: retry re-ran the itinerary only, so a suggestions failure could not
    /// be recovered without regenerating the whole trip.
    func testRetryReRunsExactlyTheFailedComponents() async {
        let itinerary = CountingItineraryService()
        let suggestions = CountingSuggestionsService(failing: true)
        let store = makeStore(itinerary: itinerary, suggestions: suggestions)

        store.send(.onAppear)
        await itinerary.release()
        await suggestions.release()
        await waitUntil {
            store.state.itineraryResponse.isLoaded
                && store.state.suggestionsResponse.error != nil
        }
        XCTAssertTrue(store.state.itineraryResponse.isLoaded)
        XCTAssertNotNil(store.state.suggestionsResponse.error)

        suggestions.failing = false
        store.send(.retry)
        await suggestions.release()
        await waitUntil {
            suggestions.callCount == 2
                && store.state.suggestionsResponse.isLoaded
        }

        XCTAssertEqual(itinerary.callCount, 1, "A succeeded component must not be re-run")
        XCTAssertEqual(suggestions.callCount, 2)
        XCTAssertTrue(store.state.suggestionsResponse.isLoaded)
    }

    /// Know Before You Go is eager (D14) — a third parallel component with the
    /// same lifecycle as the other two, not a lazy load on first tab open.
    func testTheBriefingIsGeneratedEagerlyAndOnlyOnce() async {
        let itinerary = CountingItineraryService()
        let suggestions = CountingSuggestionsService()
        let briefing = CountingKnowBeforeYouGoService()
        let store = makeStore(itinerary: itinerary, suggestions: suggestions, briefing: briefing)

        store.send(.onAppear)
        store.send(.onAppear)
        await itinerary.release()
        await suggestions.release()
        await briefing.release()
        await settle()

        XCTAssertEqual(briefing.callCount, 1)
        XCTAssertTrue(store.state.knowBeforeYouGoResponse.isLoaded)
    }

    /// One component failing must not take the others with it, and the failed
    /// one must be recoverable on its own.
    func testAFailedBriefingLeavesTheRestOfTheTripAloneAndRetriesOnItsOwn() async {
        let itinerary = CountingItineraryService()
        let suggestions = CountingSuggestionsService()
        let briefing = CountingKnowBeforeYouGoService(failing: true)
        let store = makeStore(itinerary: itinerary, suggestions: suggestions, briefing: briefing)

        store.send(.onAppear)
        await itinerary.release()
        await suggestions.release()
        await briefing.release()
        await settle()

        XCTAssertTrue(store.state.itineraryResponse.isLoaded)
        XCTAssertTrue(store.state.suggestionsResponse.isLoaded)
        XCTAssertNotNil(store.state.knowBeforeYouGoResponse.error)

        briefing.failing = false
        store.send(.retryComponent(.knowBeforeYouGo))
        await briefing.release()
        await settle()

        XCTAssertEqual(itinerary.callCount, 1, "A succeeded component must not be re-run")
        XCTAssertEqual(briefing.callCount, 2)
        XCTAssertTrue(store.state.knowBeforeYouGoResponse.isLoaded)
    }

    /// A failed component stays failed until the traveller asks for a retry —
    /// re-generating it on every re-appear would quietly spend their quota.
    func testAFailedComponentIsNotRetriedAutomaticallyOnReappear() async {
        let itinerary = CountingItineraryService()
        let suggestions = CountingSuggestionsService(failing: true)
        let store = makeStore(itinerary: itinerary, suggestions: suggestions)

        store.send(.onAppear)
        await itinerary.release()
        await suggestions.release()
        await settle()
        store.send(.onAppear)
        await settle()

        XCTAssertEqual(suggestions.callCount, 1)
    }

    // MARK: - Helpers

    private func makeStore(
        itinerary: any ItineraryGenerating,
        suggestions: any SuggestionsGenerating,
        briefing: any KnowBeforeYouGoGenerating = MockKnowBeforeYouGoService(delayNanoseconds: 0)
    ) -> TripOutputStore {
        TripOutputStore(
            initialState: .init(
                generationRequest: .init(input: .mock),
                details: .mock,
                mode: .newTrip
            ),
            imageService: StubImageService(),
            itineraryService: itinerary,
            suggestionsService: suggestions,
            // The split variant starts these two alongside the other pair, so
            // they must be injected: an omitted service here would fall
            // through to the live backend and put a unit test on the network.
            worthItService: MockWorthItService(),
            whereToStayService: MockWhereToStayService(),
            // Every component `onAppear` starts must be a double here, or the
            // store falls back to the live backend service and these tests
            // quietly make network calls.
            knowBeforeYouGoService: briefing
        )
    }

    /// Lets queued main-actor work drain. The services here suspend on an
    /// explicit gate, so a couple of hops is enough — no wall-clock waiting.
    private func settle() async {
        for _ in 0..<8 { await Task.yield() }
    }

    /// Waits for observable async state instead of assuming a fixed number of
    /// executor hops. Clean CI runners can take longer to schedule the store's
    /// child tasks even though the test doubles themselves have no delay.
    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !condition(), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(1))
        }
    }
}

// MARK: - Doubles

/// A one-shot suspension the test opens when it wants the call to return.
private actor Gate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func open() {
        isOpen = true
        let pending = continuations
        continuations.removeAll()
        for continuation in pending { continuation.resume() }
    }
}

@MainActor
private final class CountingItineraryService: ItineraryGenerating {
    private(set) var callCount = 0
    private let gate = Gate()

    func generate(_ request: TripGenerationRequest) async throws -> Trip.Itinerary {
        callCount += 1
        await gate.wait()
        return .mock
    }

    func release() async { await gate.open() }
}

@MainActor
private final class CountingSuggestionsService: SuggestionsGenerating {
    private(set) var callCount = 0
    var failing: Bool
    private let gate = Gate()

    init(failing: Bool = false) { self.failing = failing }

    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> SuggestionsPayload {
        callCount += 1
        await gate.wait()
        if failing { throw TripGenerationError.transport }
        return SuggestionsPayload(suggestions: .mock)
    }

    func release() async { await gate.open() }
}

@MainActor
private final class CountingKnowBeforeYouGoService: KnowBeforeYouGoGenerating {
    private(set) var callCount = 0
    var failing: Bool
    private let gate = Gate()

    init(failing: Bool = false) { self.failing = failing }

    func generate(_ request: TripGenerationRequest) async throws -> Trip.KnowBeforeYouGo {
        callCount += 1
        await gate.wait()
        if failing { throw TripGenerationError.transport }
        return .mock
    }

    func release() async { await gate.open() }
}

private struct StubImageService: ImageService {
    func fetchImageURL(for query: String) async throws -> URL {
        URL(string: "https://example.invalid/image.jpg")!
    }
}
