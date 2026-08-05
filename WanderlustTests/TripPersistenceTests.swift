import CoreArchitecture
import CoreModels
import XCTest
@testable import Wanderlust

/// Persistence-contract tests for `Trip`.
///
/// A saved trip is JSON read back with `try?`, so a decoding mistake here does
/// not throw — it makes the traveller's trip silently disappear from the list.
/// These tests exist to make that failure mode loud.
final class TripPersistenceTests: XCTestCase {

    // MARK: - Old trips still decode

    /// A v1 file: no `schemaVersion`, suggestions stored as a bare value, and
    /// none of the fields added since.
    func testV1TripDecodes() throws {
        let trip = try decode(legacyV1JSON(includeSuggestions: true))

        XCTAssertEqual(trip.schemaVersion, 1)
        XCTAssertEqual(trip.itinerary.destination, "Barcelona, Spain")
        XCTAssertTrue(trip.suggestionsState.isReady)
        XCTAssertEqual(trip.suggestions?.staticSuggestions.first?.title, "What to Avoid")
        XCTAssertNil(trip.tripKey)
        XCTAssertNil(trip.deepDives)
        XCTAssertNil(trip.worthItDecisions)
        XCTAssertNil(trip.accommodation)
        XCTAssertTrue(trip.knowBeforeYouGoState.isAbsent)
    }

    /// A v1 file whose suggestions key was simply never written. "There are
    /// none" is `.absent`, not an empty result.
    func testV1TripWithoutSuggestionsDecodesAsAbsent() throws {
        let trip = try decode(legacyV1JSON(includeSuggestions: false))

        XCTAssertTrue(trip.suggestionsState.isAbsent)
        XCTAssertNil(trip.suggestions)
    }

    /// The old `shareCode`-less shape keeps working, unchanged.
    func testV1TripWithoutShareCodeDecodesToNil() throws {
        let trip = try decode(legacyV1JSON(includeSuggestions: true))
        XCTAssertNil(trip.shareCode)
    }

    // MARK: - empty ≠ absent ≠ failed

    /// The bug this whole contract exists for: a trip saved mid-generation used
    /// to store `Suggestions()`, which is byte-identical to a genuinely empty
    /// result. All three states must survive a round-trip as distinct values.
    func testEmptyAbsentAndFailedAreDistinctAcrossARoundTrip() throws {
        let empty = try roundTrip(trip(suggestions: .ready(Trip.Suggestions())))
        let absent = try roundTrip(trip(suggestions: .absent))
        let failed = try roundTrip(trip(suggestions: .failed(code: "openai_http_429")))

        // Genuinely empty: we asked, we got an answer, the answer was nothing.
        XCTAssertTrue(empty.suggestionsState.isReady)
        XCTAssertEqual(empty.suggestions?.dynamicSuggestions.count, 0)
        XCTAssertEqual(empty.suggestions?.staticSuggestions.count, 0)

        // Never requested (or still running): nothing was lost.
        XCTAssertTrue(absent.suggestionsState.isAbsent)
        XCTAssertNil(absent.suggestions)

        // Failed: retryable, and we can say why.
        XCTAssertEqual(failed.suggestionsState.failureCode, "openai_http_429")
        XCTAssertNil(failed.suggestions)

        XCTAssertNotEqual(empty.suggestionsState, absent.suggestionsState)
        XCTAssertNotEqual(absent.suggestionsState, failed.suggestionsState)
        XCTAssertNotEqual(empty.suggestionsState, failed.suggestionsState)
    }

    func testSavedTripIsWrittenAtTheCurrentSchemaVersion() throws {
        let saved = try roundTrip(trip(suggestions: .ready(.mock)))
        XCTAssertEqual(saved.schemaVersion, Trip.currentSchemaVersion)
    }

    func testTripKeyAndPersonalLayerRoundTrip() throws {
        let id = UUID()
        var original = trip(suggestions: .ready(.mock))
        original.tripKey = "trip-key-1"
        original.worthItDecisions = [id: .skipped]
        original.accommodation = CoarseAccommodation(
            label: "El Born, Barcelona",
            latitude: 41.385_063_9,
            longitude: 2.173_403_1,
            precision: .address
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.tripKey, "trip-key-1")
        XCTAssertEqual(decoded.worthItDecisions?[id], .skipped)
        // Stored coarse on purpose: enough to re-run a nearby search, not a
        // record of where someone slept.
        XCTAssertEqual(decoded.accommodation?.latitude, 41.385)
        XCTAssertEqual(decoded.accommodation?.longitude, 2.173)
        XCTAssertEqual(decoded.accommodation?.precision, .address)
    }

    // MARK: - Merge-on-complete

    /// The rule the save policy rests on: a component still generating writes
    /// as `.absent`, and re-saving must not let that erase what already landed.
    func testAbsentNeverErasesAStoredResult() {
        let stored = trip(suggestions: .ready(.mock))
        let inFlight = trip(suggestions: .absent)

        let merged = inFlight.merged(over: stored)

        XCTAssertTrue(merged.suggestionsState.isReady)
        XCTAssertEqual(merged.suggestions, Trip.Suggestions.mock)
    }

    func testACompletedComponentReplacesAStoredFailure() {
        let stored = trip(suggestions: .failed(code: "network_error"))
        let completed = trip(suggestions: .ready(.mock))

        let merged = completed.merged(over: stored)

        XCTAssertTrue(merged.suggestionsState.isReady)
    }

    /// Deep dives are paid for once. Re-saving after a favourite toggle — which
    /// carries no dives in memory — must not drop them from the file.
    func testMergePreservesStoredDeepDivesAndDecisions() {
        let id = UUID()
        var stored = trip(suggestions: .ready(.mock))
        stored.deepDives = [
            Trip.Suggestions.Category(ID: nil, title: "Climbing gyms", texts: [])
        ]
        stored.worthItDecisions = [id: .kept]
        stored.tripKey = "trip-key-1"

        let merged = trip(suggestions: .ready(.mock)).merged(over: stored)

        XCTAssertEqual(merged.deepDives?.count, 1)
        XCTAssertEqual(merged.worthItDecisions?[id], .kept)
        XCTAssertEqual(merged.tripKey, "trip-key-1")
    }

    /// Favourites are the traveller's live edit, so the in-memory copy wins
    /// outright rather than merging — otherwise un-hearting something would
    /// never stick.
    func testMergeTakesTheInMemoryFavourites() {
        var stored = trip(suggestions: .ready(.mock))
        stored.favorites = Trip.Favorites(liked: [UUID()])

        let merged = trip(suggestions: .ready(.mock)).merged(over: stored)

        XCTAssertTrue(merged.favorites.liked.isEmpty)
    }

    // MARK: - Screen state → persisted state

    func testInFlightGenerationIsPersistedAsAbsentRatherThanEmpty() {
        let loading: AsyncValue<Trip.Suggestions> = .loading
        let initial: AsyncValue<Trip.Suggestions> = .initial

        XCTAssertTrue(loading.persisted.isAbsent)
        XCTAssertTrue(initial.persisted.isAbsent)
    }

    func testAFailedGenerationCarriesItsBackendCodeToDisk() {
        let failed: AsyncValue<Trip.Suggestions> = .error(TripGenerationError.truncatedOutput)
        XCTAssertEqual(failed.persisted.failureCode, "output_incomplete")
    }

    // MARK: - Helpers

    private func trip(suggestions: ComponentState<Trip.Suggestions>) -> Trip {
        Trip(
            details: .mock,
            itinerary: .mock,
            suggestionsState: suggestions
        )
    }

    private func roundTrip(_ trip: Trip) throws -> Trip {
        try JSONDecoder().decode(Trip.self, from: JSONEncoder().encode(trip))
    }

    private func decode(_ json: String) throws -> Trip {
        try JSONDecoder().decode(Trip.self, from: Data(json.utf8))
    }

    /// A trip exactly as v1 of the app wrote it: no `schemaVersion`, no
    /// `suggestionsState`, no `shareCode`, no fields added since.
    private func legacyV1JSON(includeSuggestions: Bool) -> String {
        let suggestions = includeSuggestions ? """
        ,
          "suggestions": {
            "dynamicSuggestions": [],
            "staticSuggestions": [
              {
                "ID": "avoid",
                "title": "What to Avoid",
                "texts": [{ "text": "Skip the Ramblas restaurants." }]
              }
            ]
          }
        """ : ""

        return """
        {
          "details": {
            "destination": { "name": "Barcelona, Spain" },
            "members": { "groupType": "couple" },
            "duration": 3,
            "month": "may"
          },
          "itinerary": {
            "name": "Hidden Gems",
            "destination": "Barcelona, Spain",
            "title": "Three days in Barcelona",
            "segments": [
              {
                "title": "🏙️ Day 1",
                "description": {
                  "morning": [{ "text": "Walk Barceloneta Beach." }],
                  "afternoon": [{ "text": "Lunch at Can Majó." }],
                  "evening": [{ "text": "Sunset at Port Olímpic." }]
                },
                "secret_tip": { "text": "Quiet drink at Dr. Stravinsky." }
              }
            ]
          },
          "favorites": { "liked": [] }\(suggestions)
        }
        """
    }
}
