import CoreModels
import XCTest
@testable import Wanderlust

/// Favourites plumbing.
///
/// New content types are not discovered automatically — each one needs an
/// explicit arm in the candidate walk. The failure mode is quiet: a favourite
/// that can be created but never listed, or listed as a bare string with its
/// place links stripped off. These tests pin the three things that were
/// actually wrong: dropped locations, an undefined order, and content types
/// with no arm at all.
final class FavouritesPlumbingTests: XCTestCase {

    // MARK: - Place links survive the trip into favourites

    /// The favourites list used to rebuild each row from a bare `String`, which
    /// threw `locations` away — so a place that linked in the itinerary stopped
    /// linking the moment it appeared in favourites.
    func testFavouritesCarryTheirLocations() {
        let location = Trip.Itinerary.Location(
            linkSubstring: "Can Majó",
            placeName: "Can Majó, Barcelona",
            latitude: "41.377",
            longitude: "2.190"
        )
        let item = LocationLinkableText(text: "Lunch at Can Majó.", locations: [location])
        let trip = trip(
            itinerary: itinerary(afternoon: [item]),
            favorites: Trip.Favorites(liked: [item.id])
        )

        let favourites = trip.orderedFavourites(trip.favorites)

        XCTAssertEqual(favourites.count, 1)
        XCTAssertEqual(favourites[0].text.locations?.first?.placeName, "Can Majó, Barcelona")
    }

    /// A secret tip is a different type with the same job; it must arrive with
    /// its locations too, not just its text.
    func testSecretTipsAreHeartableAndKeepTheirLocations() {
        let tip = Trip.Itinerary.SecretTip(
            text: "A quiet drink at Dr. Stravinsky.",
            locations: [.init(linkSubstring: "Dr. Stravinsky", placeName: "Dr. Stravinsky, Barcelona")]
        )
        let trip = trip(
            itinerary: itinerary(afternoon: [], secretTip: tip),
            favorites: Trip.Favorites(liked: [tip.id])
        )

        let favourites = trip.orderedFavourites(trip.favorites)

        XCTAssertEqual(favourites.first?.context, "Secret Tip")
        XCTAssertEqual(favourites.first?.text.locations?.count, 1)
    }

    // MARK: - Ordering is defined

    /// `Favorites.liked` is a `Set`, so there is no insertion order to preserve
    /// and the old "in the order they were added" was never true. The order is
    /// derived from the trip instead: grouped by context, source order within.
    func testOrderIsGroupedByContextThenSourceOrder() {
        let morningA = LocationLinkableText(text: "Morning A")
        let morningB = LocationLinkableText(text: "Morning B")
        let evening = LocationLinkableText(text: "Evening A")
        let trip = trip(
            itinerary: itinerary(morning: [morningA, morningB], evening: [evening]),
            favorites: Trip.Favorites(liked: [evening.id, morningB.id, morningA.id])
        )

        let order = trip.orderedFavourites(trip.favorites).map(\.text.text)

        XCTAssertEqual(order, ["Morning A", "Morning B", "Evening A"])
    }

    /// Same input, same output, every time — the point of deriving the order
    /// rather than reading it off an unordered `Set`.
    func testOrderIsStableAcrossRepeatedReads() {
        let items = (1...6).map { LocationLinkableText(text: "Item \($0)") }
        let trip = trip(
            itinerary: itinerary(morning: Array(items.prefix(3)), evening: Array(items.suffix(3))),
            favorites: Trip.Favorites(liked: Set(items.map(\.id)))
        )

        let first = trip.orderedFavourites(trip.favorites).map(\.id)
        for _ in 0..<20 {
            XCTAssertEqual(trip.orderedFavourites(trip.favorites).map(\.id), first)
        }
    }

    func testSectionsGroupUnderTheirHeadingInFirstAppearanceOrder() {
        let morning = LocationLinkableText(text: "Morning A")
        let evening = LocationLinkableText(text: "Evening A")
        let trip = trip(
            itinerary: itinerary(morning: [morning], evening: [evening]),
            favorites: Trip.Favorites(liked: [morning.id, evening.id])
        )

        let sections = trip.favouriteSections(trip.favorites)

        XCTAssertEqual(sections.map(\.context), ["Morning", "Evening"])
        XCTAssertEqual(sections.map { $0.items.count }, [1, 1])
    }

    // MARK: - Every heartable type has an arm

    func testSuggestionsAreHeartableUnderTheirCategoryTitle() {
        let text = LocationLinkableText(text: "A café with a view.")
        var trip = trip(itinerary: itinerary(), favorites: Trip.Favorites(liked: [text.id]))
        trip.suggestionsState = .ready(
            Trip.Suggestions(
                dynamicSuggestions: [.init(ID: .cafes, title: "Cafés with a view", texts: [text])]
            )
        )

        XCTAssertEqual(trip.orderedFavourites(trip.favorites).first?.context, "Cafés with a view")
    }

    /// Deep dives are stored apart from `dynamicSuggestions` so they keep their
    /// own provenance — which means they need their own arm, or they'd be
    /// heartable and then invisible.
    func testDeepDiveResultsAreHeartableUnderTheirOwnTitle() {
        let text = LocationLinkableText(text: "A bouldering gym in Poblenou.")
        var trip = trip(itinerary: itinerary(), favorites: Trip.Favorites(liked: [text.id]))
        trip.deepDives = [.init(ID: nil, title: "Climbing gyms", texts: [text])]

        XCTAssertEqual(trip.orderedFavourites(trip.favorites).first?.context, "Climbing gyms")
    }

    func testWorthItCardsAreHeartableUnderOneHeading() {
        let card = Trip.WorthItItem.mockSet[0]
        var trip = trip(itinerary: itinerary(), favorites: Trip.Favorites(liked: [card.id]))
        trip.worthItItems = Trip.WorthItItem.mockSet

        let favourite = trip.orderedFavourites(trip.favorites).first

        XCTAssertEqual(favourite?.context, "Worth it or skip")
        XCTAssertTrue(favourite?.text.text.contains(card.place) == true)
    }

    // MARK: - Old trips

    /// A trip saved before any of this existed has `nil` everywhere new. It must
    /// contribute no candidates and, above all, not crash.
    func testAnOldTripWithNoOptionalSectionsContributesNothingExtra() {
        let trip = trip(itinerary: itinerary(), favorites: Trip.Favorites(liked: [UUID()]))

        XCTAssertNil(trip.suggestions)
        XCTAssertNil(trip.deepDives)
        XCTAssertNil(trip.worthItItems)
        XCTAssertTrue(trip.favouriteCandidates.isEmpty)
        XCTAssertTrue(trip.orderedFavourites(trip.favorites).isEmpty)
    }

    /// A favourite whose content is gone — a component that failed, or content
    /// dropped in a migration — simply doesn't resolve. It must not appear as a
    /// blank row.
    func testAFavouriteWithNoMatchingContentIsSkipped() {
        let present = LocationLinkableText(text: "Still here.")
        let trip = trip(
            itinerary: itinerary(morning: [present]),
            favorites: Trip.Favorites(liked: [present.id, UUID()])
        )

        XCTAssertEqual(trip.orderedFavourites(trip.favorites).count, 1)
    }

    // MARK: - Stable ids

    /// Decisions and favourites are keyed by id, so a Worth-it card that
    /// regenerated its id on decode would silently lose both.
    func testWorthItIdsSurviveARoundTrip() throws {
        let original = Trip.WorthItItem.mockSet
        let decoded = try JSONDecoder().decode(
            [Trip.WorthItItem].self, from: JSONEncoder().encode(original)
        )

        XCTAssertEqual(decoded.map(\.id), original.map(\.id))
    }

    func testWorthItItemsAndDecisionsSurviveATripRoundTrip() throws {
        let card = Trip.WorthItItem.mockSet[0]
        var original = trip(itinerary: itinerary(), favorites: Trip.Favorites(liked: [card.id]))
        original.worthItItems = Trip.WorthItItem.mockSet
        original.worthItDecisions = [card.id: .kept]

        let decoded = try JSONDecoder().decode(
            Trip.self, from: JSONEncoder().encode(original)
        )

        XCTAssertEqual(decoded.worthItItems?.count, 4)
        XCTAssertEqual(decoded.worthItDecisions?[card.id], .kept)
        XCTAssertEqual(decoded.orderedFavourites(decoded.favorites).first?.context, "Worth it or skip")
    }

    // MARK: - Helpers

    private func trip(
        itinerary: Trip.Itinerary,
        favorites: Trip.Favorites
    ) -> Trip {
        Trip(
            details: .mock,
            itinerary: itinerary,
            suggestionsState: .absent,
            favorites: favorites
        )
    }

    private func itinerary(
        morning: [LocationLinkableText] = [],
        afternoon: [LocationLinkableText] = [],
        evening: [LocationLinkableText] = [],
        secretTip: Trip.Itinerary.SecretTip? = nil
    ) -> Trip.Itinerary {
        Trip.Itinerary(
            name: "Test",
            destination: "Barcelona, Spain",
            title: "Test",
            segments: [
                .init(
                    title: "Day 1",
                    description: .init(morning: morning, afternoon: afternoon, evening: evening),
                    secretTip: secretTip
                )
            ]
        )
    }
}
