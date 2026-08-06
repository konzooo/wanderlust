import CoreArchitecture
import CoreModels
import XCTest
@testable import Wanderlust

/// §11: `alreadyRecommended` is derived at call time and never persisted.
///
/// The bug this is written against is a quiet one. A stored copy of this list
/// still *looks* like a list after it goes stale — nothing throws, nothing logs,
/// the model just starts repeating places the traveller has already been shown,
/// or avoiding places it no longer needs to. So the tests here are less about
/// the flattening being right and more about the three moments where a cached
/// version would have gone wrong: after a deep dive lands, after a component is
/// retried, and after an old file is migrated.
@MainActor
final class AlreadyRecommendedTests: XCTestCase {

    // MARK: - What it collects

    func testItCollectsPlaceNamesFromEveryContentType() {
        let trip = makeTrip(
            deepDives: [category("Natural wine bars", places: ["Bar Brutal, Barcelona"])],
            worthItItems: [worthItCard(place: "Sagrada Família, Barcelona")]
        )

        let names = trip.alreadyRecommended

        XCTAssertTrue(names.contains("Park Güell, Barcelona"), "itinerary")
        XCTAssertTrue(names.contains("Dr. Stravinsky, Barcelona"), "secret tip")
        XCTAssertTrue(names.contains("El Xampanyet, Barcelona"), "suggestions")
        XCTAssertTrue(names.contains("Bar Brutal, Barcelona"), "deep dive")
        XCTAssertTrue(names.contains("Sagrada Família, Barcelona"), "worth-it card")
    }

    /// Where-to-stay names neighbourhoods to sleep in, which is a different axis
    /// entirely. Suppressing El Born from the suggestions feed because it was
    /// offered as somewhere to stay removes a real recommendation to avoid a
    /// repetition that isn't one.
    func testWhereToStayIsDeliberatelyExcluded() {
        var trip = makeTrip()
        trip.whereToStay = [
            Trip.StayArea(
                area: "El Born",
                theCase: "Medieval lanes.",
                bestFor: "A first visit",
                watchOut: "Noise",
                locations: [location("El Born, Barcelona")]
            )
        ]

        XCTAssertFalse(trip.alreadyRecommended.contains("El Born, Barcelona"))
    }

    func testDuplicatesAreCollapsedCaseInsensitivelyAndOrderIsStable() {
        let trip = makeTrip(
            deepDives: [
                category("Wine", places: ["park güell, barcelona", "Bar Brutal, Barcelona"])
            ]
        )

        let names = trip.alreadyRecommended
        let parkGüellEntries = names.filter { $0.lowercased() == "park güell, barcelona" }

        XCTAssertEqual(parkGüellEntries.count, 1)
        XCTAssertEqual(
            parkGüellEntries.first, "Park Güell, Barcelona",
            "The first spelling seen wins, so the list is stable across runs"
        )
        XCTAssertEqual(names, trip.alreadyRecommended, "Deriving twice gives the same answer")
    }

    /// The plan asks for segment titles, but a title is "🏙️ Day 1: Old Streets,
    /// New Flavors" — the emoji and the day range are chrome, and sending them
    /// spends the request telling the model not to repeat the word "Day".
    func testSegmentTitlesContributeTheirSubjectWithoutTheDayPrefix() {
        XCTAssertEqual(
            Trip.segmentSubject("🏙️ Day 1: Old Streets, New Flavors"),
            "Old Streets, New Flavors"
        )
        XCTAssertEqual(
            Trip.segmentSubject("🌊 Days 4–6: Coast and Slow Mornings"),
            "Coast and Slow Mornings"
        )
        XCTAssertEqual(
            Trip.segmentSubject("Gràcia and the hills"), "Gràcia and the hills",
            "A title with no day prefix is left alone"
        )
    }

    func testTheListIsCappedSoALongTripCannotFloodTheRequest() {
        let many = (0..<400).map { "Place \($0), Barcelona" }
        let trip = makeTrip(deepDives: [category("Everything", places: many)])

        XCTAssertEqual(trip.alreadyRecommended.count, Trip.maxAlreadyRecommended)
    }

    // MARK: - The three moments a cached copy would have gone stale

    /// After a dive. A persisted list written when the trip was generated knows
    /// nothing about a category bought twenty minutes later.
    func testItIsCorrectAfterADeepDiveIsAdded() {
        var trip = makeTrip()
        XCTAssertFalse(trip.alreadyRecommended.contains("Bar Brutal, Barcelona"))

        trip.deepDives = [category("Natural wine bars", places: ["Bar Brutal, Barcelona"])]

        XCTAssertTrue(trip.alreadyRecommended.contains("Bar Brutal, Barcelona"))
    }

    /// After a retry. The replaced component's places must be gone, not merely
    /// joined by the new ones — this is the case a cache gets exactly backwards,
    /// because it accumulates.
    func testARetriedComponentReplacesItsPlacesRatherThanAddingToThem() {
        var trip = makeTrip()
        XCTAssertTrue(trip.alreadyRecommended.contains("El Xampanyet, Barcelona"))

        trip.suggestionsState = .ready(
            Trip.Suggestions(
                dynamicSuggestions: [category("Cafés", places: ["Satan's Coffee Corner, Barcelona"])],
                staticSuggestions: []
            )
        )

        let names = trip.alreadyRecommended
        XCTAssertTrue(names.contains("Satan's Coffee Corner, Barcelona"))
        XCTAssertFalse(
            names.contains("El Xampanyet, Barcelona"),
            "The retried call's old places must not linger"
        )
    }

    /// After a migration. A v1 file has no `deepDives`, no `worthItItems` and no
    /// `whereToStay`; every one of those is a `nil` array this walks straight
    /// past rather than a special case someone has to remember.
    func testAMigratedTripWithNoNewSectionsStillDerivesCleanly() throws {
        var trip = makeTrip()
        trip.deepDives = nil
        trip.worthItItems = nil
        trip.whereToStay = nil
        trip.suggestionsState = .absent

        let names = trip.alreadyRecommended

        XCTAssertFalse(names.isEmpty, "The itinerary alone still contributes")
        XCTAssertTrue(names.contains("Park Güell, Barcelona"))
    }

    // MARK: - The store derives from live state, not from disk

    func testTheStoreDerivesNothingBeforeTheItineraryLands() {
        let store = makeStore(itineraryLoaded: false)
        XCTAssertTrue(
            store.alreadyRecommended().isEmpty,
            "The calls that start alongside the itinerary genuinely have nothing to avoid yet"
        )
    }

    func testTheStoreDerivesFromLiveScreenStateOnceTheItineraryHasLanded() {
        let store = makeStore(itineraryLoaded: true)
        store.state.worthItResponse = .loaded([worthItCard(place: "Sagrada Família, Barcelona")])

        XCTAssertTrue(store.alreadyRecommended().contains("Sagrada Família, Barcelona"))
    }

    // MARK: - Fixtures

    private func makeTrip(
        deepDives: [Trip.Suggestions.Category]? = nil,
        worthItItems: [Trip.WorthItItem]? = nil
    ) -> Trip {
        Trip(
            details: .mock,
            itinerary: itinerary,
            suggestionsState: .ready(
                Trip.Suggestions(
                    dynamicSuggestions: [
                        category("Tapas", places: ["El Xampanyet, Barcelona"])
                    ],
                    staticSuggestions: []
                )
            ),
            deepDives: deepDives,
            worthItItems: worthItItems
        )
    }

    private func makeStore(itineraryLoaded: Bool) -> TripOutputStore {
        var state = TripOutputStore.State(details: .mock, mode: .newTrip)
        if itineraryLoaded { state.itineraryResponse = .loaded(itinerary) }
        return TripOutputStore(
            initialState: state,
            itineraryService: MockItineraryService(),
            suggestionsService: MockSuggestionsService(),
            worthItService: MockWorthItService(),
            whereToStayService: MockWhereToStayService()
        )
    }

    private var itinerary: Trip.Itinerary {
        Trip.Itinerary(
            name: "Barcelona",
            destination: "Barcelona, Spain",
            title: "Barcelona",
            segments: [
                Trip.Itinerary.Segment(
                    title: "🎨 Day 2: Art & Soul of the City",
                    description: .init(
                        morning: [
                            LocationLinkableText(
                                text: "Explore the colorful Park Güell.",
                                locations: [location("Park Güell, Barcelona")]
                            )
                        ],
                        afternoon: [],
                        evening: []
                    ),
                    secretTip: Trip.Itinerary.SecretTip(
                        text: "End your night at Dr. Stravinsky.",
                        locations: [location("Dr. Stravinsky, Barcelona")]
                    )
                )
            ]
        )
    }

    private func category(_ title: String, places: [String]) -> Trip.Suggestions.Category {
        Trip.Suggestions.Category(
            ID: nil,
            title: title,
            texts: places.map {
                LocationLinkableText(text: "Go to \($0).", locations: [location($0)])
            }
        )
    }

    private func worthItCard(place: String) -> Trip.WorthItItem {
        Trip.WorthItItem(
            place: place,
            theCase: "There is nothing else like it.",
            theCatch: "The queue is brutal.",
            verdict: "Worth it, but book ahead.",
            locations: [location(place)]
        )
    }

    private func location(_ placeName: String) -> Trip.Itinerary.Location {
        Trip.Itinerary.Location(
            linkSubstring: placeName.components(separatedBy: ",").first ?? placeName,
            placeName: placeName
        )
    }
}
