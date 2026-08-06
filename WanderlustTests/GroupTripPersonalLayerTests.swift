import CoreModels
import XCTest
@testable import Wanderlust

@MainActor
final class GroupTripPersonalLayerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var persistence: GroupTripPersonalStore!

    override func setUp() {
        super.setUp()
        let suite = "GroupTripPersonalLayerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        persistence = GroupTripPersonalStore(defaults: defaults)
    }

    func testLayerSurvivesReopenAndStaysPerGroup() {
        let favorite = UUID()
        let decision = UUID()
        persistence.save(
            GroupTripPersonalLayer(
                favorites: .init(liked: [favorite]),
                worthItDecisions: [decision: .skipped]
            ),
            groupId: "group-a"
        )

        let reopened = persistence.load(groupId: "group-a")
        XCTAssertTrue(reopened.favorites.contains(favorite))
        XCTAssertEqual(reopened.worthItDecisions[decision], .skipped)
        XCTAssertEqual(persistence.load(groupId: "group-b"), .init())
    }

    func testStorePersistsGroupHeartsAndWorthItDecisions() {
        let worthIt = Trip.WorthItItem.mockSet[0]
        var state = TripOutputStore.State(details: .mock, mode: .groupTrip)
        state.groupId = "group-a"
        state.itineraryResponse = .loaded(.mock)
        state.worthItResponse = .loaded([worthIt])
        let store = TripOutputStore(
            initialState: state,
            groupPersonalStore: persistence
        )

        var favorites = store.state.favorites
        favorites.insert(worthIt.id)
        store.send(.setFavorites(favorites))
        store.send(.decideWorthIt(worthIt.id, .kept))

        let reopened = TripOutputStore(
            initialState: state,
            groupPersonalStore: persistence
        )
        XCTAssertTrue(reopened.state.favorites.contains(worthIt.id))
        XCTAssertEqual(reopened.state.worthItDecisions[worthIt.id], .kept)
    }

    func testRemovingFavoriteClearsKeptDecisionInPersistedLayer() {
        let item = Trip.WorthItItem.mockSet[0]
        var state = TripOutputStore.State(details: .mock, mode: .groupTrip)
        state.groupId = "group-a"
        state.itineraryResponse = .loaded(.mock)
        state.worthItResponse = .loaded([item])
        let store = TripOutputStore(
            initialState: state,
            groupPersonalStore: persistence
        )
        store.send(.decideWorthIt(item.id, .kept))

        store.send(.removeFavorite(item.id))

        let layer = persistence.load(groupId: "group-a")
        XCTAssertFalse(layer.favorites.contains(item.id))
        XCTAssertNil(layer.worthItDecisions[item.id])
    }

    func testOnlyOrganizerCanGenerateSharedGroupDeepDive() async throws {
        let generated = Trip.Suggestions.Category(
            ID: nil,
            title: "Shared running routes",
            texts: [LocationLinkableText(text: "Run the river path.")],
            requestedInterest: "Running routes"
        )
        let service = GroupDeepDiveServiceStub(result: generated)
        let credentials = GroupTripCredentials(
            groupId: "group-a",
            code: "12345",
            memberId: "member-a",
            memberToken: "member-token",
            adminToken: "admin-token"
        )
        var state = TripOutputStore.State(details: .mock, mode: .groupTrip)
        state.groupId = "group-a"
        state.groupViewerIsAdmin = true
        state.itineraryResponse = .loaded(.mock)
        let store = TripOutputStore(
            initialState: state,
            groupPersonalStore: persistence,
            groupDeepDiveService: service,
            groupCredentials: credentials
        )

        store.send(.generateDeepDive("Running routes"))
        try await waitUntil { store.state.deepDives?.count == 1 }

        XCTAssertEqual(store.state.deepDives?.first?.title, generated.title)
        let serviceCalls = await service.calls()
        XCTAssertEqual(serviceCalls, 1)

        state.groupViewerIsAdmin = false
        let memberStore = TripOutputStore(
            initialState: state,
            groupPersonalStore: persistence,
            groupDeepDiveService: service,
            groupCredentials: GroupTripCredentials(
                groupId: "group-a",
                code: "12345",
                memberId: "member-b",
                memberToken: "member-token-b",
                adminToken: nil
            )
        )
        XCTAssertFalse(memberStore.canGenerateDeepDive)
        XCTAssertEqual(
            memberStore.deepDiveGuidanceMessage,
            "Only the trip organizer can add a shared deep dive."
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + .nanoseconds(Int64(timeoutNanoseconds))
        while !condition() {
            if ContinuousClock.now >= deadline { XCTFail("Timed out waiting for state"); return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private actor GroupDeepDiveServiceStub: GroupDeepDiveGenerating {
    let result: Trip.Suggestions.Category
    private var callCount = 0

    init(result: Trip.Suggestions.Category) {
        self.result = result
    }

    func generateGroupDeepDive(
        groupId: String,
        adminToken: String,
        interest: String
    ) async throws -> Trip.Suggestions.Category {
        callCount += 1
        return result
    }

    func calls() -> Int { callCount }
}
