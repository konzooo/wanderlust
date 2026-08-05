import CoreArchitecture
import CoreModels
import XCTest
@testable import Wanderlust

/// The Worth-it/Skip invariant table.
///
/// `Favorites` is a `Set<UUID>` and can only say liked-or-not, so a decision
/// lives in a second store. The two are one fact written twice, and the failure
/// mode is that they disagree — a card showing "Added to favourites" that isn't
/// in the favourites list, or the reverse. Every row of the plan's table is one
/// test here, driven through the store rather than by poking state, because the
/// rule is precisely that nothing may mutate the two stores separately.
@MainActor
final class WorthItDecisionTests: XCTestCase {

    // MARK: - Deciding

    func testAddToFavouritesKeepsAndInserts() {
        let store = makeStore()
        let card = store.state.worthItItems![0]

        store.send(.decideWorthIt(card.id, .kept))

        XCTAssertEqual(store.worthItDecision(for: card.id), .kept)
        XCTAssertTrue(store.state.favorites.contains(card.id))
    }

    func testSkipDecidesWithoutTouchingFavourites() {
        let store = makeStore()
        let card = store.state.worthItItems![0]

        store.send(.decideWorthIt(card.id, .skipped))

        XCTAssertEqual(store.worthItDecision(for: card.id), .skipped)
        XCTAssertFalse(store.state.favorites.contains(card.id))
    }

    // MARK: - Undo

    func testUndoFromKeptReturnsToUndecidedAndRemovesTheFavourite() {
        let store = makeStore()
        let card = store.state.worthItItems![0]

        store.send(.decideWorthIt(card.id, .kept))
        store.send(.decideWorthIt(card.id, nil))

        XCTAssertNil(store.worthItDecision(for: card.id))
        XCTAssertFalse(store.state.favorites.contains(card.id))
    }

    /// Undoing a skip must not resurrect a favourite that was never created.
    func testUndoFromSkippedReturnsToUndecidedAndLeavesFavouritesAlone() {
        let store = makeStore()
        let card = store.state.worthItItems![0]

        store.send(.decideWorthIt(card.id, .skipped))
        store.send(.decideWorthIt(card.id, nil))

        XCTAssertNil(store.worthItDecision(for: card.id))
        XCTAssertFalse(store.state.favorites.contains(card.id))
    }

    /// The row that breaks when the two stores are updated at separate call
    /// sites: un-hearting from the favourites list has to clear the decision, or
    /// the card is left claiming a decision the traveller has undone.
    func testRemovingFromTheFavouritesScreenClearsTheDecision() {
        let store = makeStore()
        let card = store.state.worthItItems![0]

        store.send(.decideWorthIt(card.id, .kept))
        store.send(.removeFavorite(card.id))

        XCTAssertNil(store.worthItDecision(for: card.id))
        XCTAssertFalse(store.state.favorites.contains(card.id))
    }

    /// "Kept" and "in favourites" must never disagree, even by the route the UI
    /// doesn't currently offer.
    func testChangingKeptToSkippedRemovesTheFavourite() {
        let store = makeStore()
        let card = store.state.worthItItems![0]

        store.send(.decideWorthIt(card.id, .kept))
        store.send(.decideWorthIt(card.id, .skipped))

        XCTAssertEqual(store.worthItDecision(for: card.id), .skipped)
        XCTAssertFalse(store.state.favorites.contains(card.id))
    }

    /// Deciding is idempotent — a double tap must not toggle the favourite off.
    func testDecidingKeptTwiceLeavesTheFavouriteInPlace() {
        let store = makeStore()
        let card = store.state.worthItItems![0]

        store.send(.decideWorthIt(card.id, .kept))
        store.send(.decideWorthIt(card.id, .kept))

        XCTAssertTrue(store.state.favorites.contains(card.id))
    }

    // MARK: - Ordinary favourites are untouched

    /// A suggestion has no decision state and needs none. Removing one must not
    /// invent an entry in the decision map.
    func testRemovingAnOrdinaryFavouriteDoesNotCreateADecision() {
        let store = makeStore()
        let suggestion = Trip.Suggestions.mock.dynamicSuggestions[0].texts[0]

        store.state.favorites.insert(suggestion.id)
        store.send(.removeFavorite(suggestion.id))

        XCTAssertFalse(store.state.favorites.contains(suggestion.id))
        XCTAssertTrue(store.state.worthItDecisions.isEmpty)
    }

    // MARK: - Segment visibility

    /// A group trip has no personal layer to record a decision in, so the
    /// segment is not offered at all — rather than offered and silently inert.
    func testWorthItSegmentIsHiddenOnAGroupTrip() {
        let store = makeStore(mode: .groupTrip)

        XCTAssertTrue(store.worthItCards.isEmpty)
        XCTAssertFalse(store.discoverSegments.contains(.worthIt))
    }

    func testWorthItSegmentIsHiddenWhenThereAreNoCards() {
        let store = makeStore(items: nil)

        XCTAssertFalse(store.discoverSegments.contains(.worthIt))
        XCTAssertEqual(store.discoverSegments, [.suggestions, .itinerary])
    }

    func testWorthItSegmentSitsBetweenSuggestionsAndTheItinerary() {
        let store = makeStore()
        XCTAssertEqual(store.discoverSegments, [.suggestions, .worthIt, .itinerary])
    }

    // MARK: - Helpers

    private func makeStore(
        mode: TripOutputStore.State.Mode = .newTrip,
        items: [Trip.WorthItItem]? = Trip.WorthItItem.mockSet
    ) -> TripOutputStore {
        var state = TripOutputStore.State(details: .mock, mode: mode)
        state.itineraryResponse = .loaded(.mock)
        state.suggestionsResponse = .loaded(.mock)
        state.worthItItems = items
        return TripOutputStore(
            initialState: state,
            itineraryService: MockItineraryService(),
            suggestionsService: MockSuggestionsService()
        )
    }
}
