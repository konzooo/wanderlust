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
}
