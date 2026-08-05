import CoreArchitecture
import CoreModels
import XCTest
@testable import Wanderlust

/// Know Before You Go v1.
///
/// Two things are worth testing here and the rest is layout. First, the
/// persistence contract every component shares: a trip saved before the
/// briefing existed must still decode, and empty, absent and failed must stay
/// three different things. Second — and specific to this component — the
/// conditional rule that strict JSON Schema cannot express: *a `verify` section
/// must name a source*. That one is enforced after decode, so it needs a test
/// per branch or it silently stops holding.
@MainActor
final class KnowBeforeYouGoTests: XCTestCase {

    // MARK: - Persistence contract

    /// A v2 file — written by the build before this component existed — has no
    /// `knowBeforeYouGoState` key at all. It must decode, and it must decode as
    /// "never asked", not as an empty briefing.
    func testATripSavedBeforeTheBriefingExistedDecodesAsAbsent() throws {
        let decoded = try decode(v2JSONWithoutBriefing())

        XCTAssertTrue(decoded.knowBeforeYouGoState.isAbsent)
        XCTAssertNil(decoded.knowBeforeYouGo)
        // And the rest of the trip is untouched by its absence.
        XCTAssertEqual(decoded.itinerary.destination, "Barcelona, Spain")
        XCTAssertTrue(decoded.suggestionsState.isReady)
    }

    func testEmptyAbsentAndFailedBriefingsAreDistinctAcrossARoundTrip() throws {
        let empty = try roundTrip(trip(briefing: .ready(Trip.KnowBeforeYouGo())))
        let absent = try roundTrip(trip(briefing: .absent))
        let failed = try roundTrip(trip(briefing: .failed(code: "incomplete_max_output_tokens")))

        // Asked, answered, and the answer was nothing.
        XCTAssertTrue(empty.knowBeforeYouGoState.isReady)
        XCTAssertEqual(empty.knowBeforeYouGo?.sections.count, 0)

        XCTAssertTrue(absent.knowBeforeYouGoState.isAbsent)
        XCTAssertEqual(failed.knowBeforeYouGoState.failureCode, "incomplete_max_output_tokens")

        XCTAssertNotEqual(empty.knowBeforeYouGoState, absent.knowBeforeYouGoState)
        XCTAssertNotEqual(absent.knowBeforeYouGoState, failed.knowBeforeYouGoState)
    }

    /// Section ids are minted once and then persisted. A regenerated id is the
    /// bug that silently resets anything keyed to it.
    func testSectionIdsSurviveARoundTrip() throws {
        let original = trip(briefing: .ready(.mock))
        let ids = original.knowBeforeYouGo!.sections.map(\.id)

        let decoded = try roundTrip(try roundTrip(original))

        XCTAssertEqual(decoded.knowBeforeYouGo?.sections.map(\.id), ids)
    }

    /// The backend never sends ids — strict Structured Outputs has no place for
    /// one — so the first decode has to mint them.
    func testABackendPayloadWithoutIdsDecodes() throws {
        let briefing = try decodeBriefing("""
        {
          "sections": [
            {
              "bucket": "money",
              "title": "Cards everywhere",
              "body": "Card works nearly everywhere, including buses.",
              "bullets": ["Keep €20 for market stalls"],
              "volatility": "stable",
              "sourceLead": null,
              "source": null,
              "sourceURL": null,
              "locations": []
            }
          ]
        }
        """)

        XCTAssertEqual(briefing.sections.count, 1)
        XCTAssertEqual(briefing.sections[0].bullets, ["Keep €20 for market stalls"])
        XCTAssertEqual(briefing.sections[0].locations?.count, 0)
    }

    /// Merge-on-complete: a briefing still generating writes as `.absent`, and a
    /// re-save triggered by anything else must not let that erase what landed.
    func testAnAbsentBriefingNeverErasesAStoredOne() {
        let stored = trip(briefing: .ready(.mock))
        let inFlight = trip(briefing: .absent)

        let merged = inFlight.merged(over: stored)

        XCTAssertTrue(merged.knowBeforeYouGoState.isReady)
        XCTAssertEqual(merged.knowBeforeYouGo?.sections.count, Trip.KnowBeforeYouGo.mock.sections.count)
    }

    // MARK: - "source required when volatility == verify"

    /// The rule §3 says cannot live in the schema. Without a source there is
    /// nobody to check with, so the honest fallback is to stop claiming the
    /// section is volatile at all — not to render "confirm with ()".
    func testAVerifySectionWithoutASourceIsDowngradedToStable() throws {
        let briefing = try decodeBriefing(sectionJSON(
            volatility: "verify",
            sourceLead: "\"Entry rules change — confirm with\"",
            source: "null",
            sourceURL: "null"
        ))
        let section = briefing.sections[0]

        XCTAssertEqual(section.volatility, .stable)
        XCTAssertNil(section.source)
        XCTAssertNil(section.sourceLead, "A lead-in with nothing to lead into is chrome for nothing")
    }

    func testAVerifySectionWithABlankSourceIsAlsoDowngraded() throws {
        let briefing = try decodeBriefing(sectionJSON(
            volatility: "verify",
            sourceLead: "\"Confirm with\"",
            source: "\"   \"",
            sourceURL: "null"
        ))

        XCTAssertEqual(briefing.sections[0].volatility, .stable)
    }

    func testAVerifySectionWithASourceKeepsIt() throws {
        let briefing = try decodeBriefing(sectionJSON(
            volatility: "verify",
            sourceLead: "\"Entry rules change — confirm with\"",
            source: "\"the Spanish Ministry of Foreign Affairs\"",
            sourceURL: "\"https://www.exteriores.gob.es\""
        ))
        let section = briefing.sections[0]

        XCTAssertEqual(section.volatility, .verify)
        XCTAssertEqual(section.source, "the Spanish Ministry of Foreign Affairs")
        XCTAssertEqual(section.sourceLead, "Entry rules change — confirm with")
        XCTAssertEqual(section.sourceURL?.absoluteString, "https://www.exteriores.gob.es")
    }

    /// A stable section reads with full confidence. A source line attached to
    /// one is hedging with extra steps, so it is dropped rather than rendered.
    func testAStableSectionDropsAnySourceItArrivedWith() throws {
        let briefing = try decodeBriefing(sectionJSON(
            volatility: "stable",
            sourceLead: "\"Check with\"",
            source: "\"some authority\"",
            sourceURL: "\"https://example.org\""
        ))
        let section = briefing.sections[0]

        XCTAssertEqual(section.volatility, .stable)
        XCTAssertNil(section.source)
        XCTAssertNil(section.sourceLead)
        XCTAssertNil(section.sourceURL)
    }

    /// The link is the part a traveller trusts, so anything that isn't a plain
    /// secure web address is dropped — the section still names the authority.
    func testANonHTTPSSourceURLIsDroppedButTheSourceSurvives() throws {
        for raw in ["\"http://example.org\"", "\"javascript:alert(1)\"", "\"not a url\""] {
            let briefing = try decodeBriefing(sectionJSON(
                volatility: "verify",
                sourceLead: "\"Confirm with\"",
                source: "\"TMB\"",
                sourceURL: raw
            ))
            let section = briefing.sections[0]

            XCTAssertNil(section.sourceURL, "\(raw) must not become a link")
            XCTAssertEqual(section.volatility, .verify)
            XCTAssertEqual(section.source, "TMB")
        }
    }

    /// The resolved values are what gets written, so a downgraded section stays
    /// downgraded across a save — the rule is applied once, not re-litigated.
    func testTheResolvedConfidenceIsWhatPersists() throws {
        let section = Trip.KnowBeforeYouGo.Section(
            bucket: .money,
            title: "Tourist tax",
            body: "Added per night, per person.",
            volatility: .verify,
            sourceLead: "Rates change — check with",
            source: nil
        )
        let decoded = try roundTrip(trip(briefing: .ready(.init(sections: [section]))))

        XCTAssertEqual(decoded.knowBeforeYouGo?.sections[0].volatility, .stable)
    }

    // MARK: - Grouping and forward compatibility

    func testSectionsAreGroupedIntoBucketsInCanonicalOrder() {
        let briefing = Trip.KnowBeforeYouGo(sections: [
            .init(bucket: .onTheGround, title: "Meal times", body: "Late."),
            .init(bucket: .beforeYouLeave, title: "Entry", body: "90/180."),
            .init(bucket: .onTheGround, title: "Tap water", body: "Fine."),
            .init(bucket: .money, title: "Cards", body: "Everywhere.")
        ])

        XCTAssertEqual(briefing.groups.map(\.bucket), [.beforeYouLeave, .money, .onTheGround])
        XCTAssertEqual(briefing.groups.last?.sections.count, 2, "Sections keep their order within a bucket")
        XCTAssertEqual(briefing.groups.last?.sections.first?.title, "Meal times")
    }

    /// A bucket this build doesn't know must not take the whole briefing down
    /// with it — the same tolerance suggestion category IDs already have.
    func testAnUnknownBucketDegradesInsteadOfFailingTheDecode() throws {
        let briefing = try decodeBriefing("""
        {
          "sections": [
            {
              "bucket": "paperwork",
              "title": "Something new",
              "body": "From a newer backend.",
              "bullets": [],
              "volatility": "stable",
              "sourceLead": null, "source": null, "sourceURL": null,
              "locations": []
            }
          ]
        }
        """)

        XCTAssertEqual(briefing.sections[0].bucket, .other)
        XCTAssertEqual(briefing.groups.map(\.bucket), [.other], "Unknown buckets read last")
    }

    // MARK: - Lane boundaries

    /// Reference, not a collection. "How people pay in Barcelona" is not a
    /// favourite, and `favouriteCandidates` only discovers types with an
    /// explicit arm — so this is the test that the omission is deliberate.
    func testBriefingSectionsAreNotHeartable() {
        var subject = trip(briefing: .ready(.mock))
        let sectionIDs = Set(subject.knowBeforeYouGo!.sections.map(\.id))
        // Even if something managed to like one, it must not surface.
        subject.favorites = Trip.Favorites(liked: sectionIDs)

        let candidateIDs = Set(subject.favouriteCandidates.map(\.id))

        XCTAssertTrue(candidateIDs.isDisjoint(with: sectionIDs))
        XCTAssertTrue(subject.favouriteSections(subject.favorites).isEmpty)
    }

    // MARK: - Screen state

    /// A trip with no briefing and no way to ask for one has to say so.
    /// "Never started" and "still running" are the same `AsyncValue`, so
    /// without this the tab would sit on its loading state forever.
    func testAnOldSavedTripReportsTheBriefingAsUnavailable() {
        var state = TripOutputStore.State(details: .mock, mode: .savedTrip)
        state.itineraryResponse = .loaded(.mock)

        XCTAssertTrue(makeStore(state).knowBeforeYouGoIsUnavailable)
    }

    func testANewTripIsNotReportedAsUnavailable() {
        var state = TripOutputStore.State(
            generationRequest: .init(input: .mock),
            details: .mock,
            mode: .newTrip
        )
        state.itineraryResponse = .loaded(.mock)

        XCTAssertFalse(makeStore(state).knowBeforeYouGoIsUnavailable)
    }

    func testATripThatHasABriefingIsNotReportedAsUnavailable() {
        var state = TripOutputStore.State(details: .mock, mode: .sharedTrip)
        state.itineraryResponse = .loaded(.mock)
        state.knowBeforeYouGoResponse = .loaded(.mock)

        XCTAssertFalse(makeStore(state).knowBeforeYouGoIsUnavailable)
    }

    // MARK: - Helpers

    private func makeStore(_ state: TripOutputStore.State) -> TripOutputStore {
        TripOutputStore(
            initialState: state,
            itineraryService: MockItineraryService(),
            suggestionsService: MockSuggestionsService(),
            knowBeforeYouGoService: MockKnowBeforeYouGoService()
        )
    }

    private func trip(briefing: ComponentState<Trip.KnowBeforeYouGo>) -> Trip {
        Trip(
            details: .mock,
            itinerary: .mock,
            suggestionsState: .ready(.mock),
            knowBeforeYouGoState: briefing
        )
    }

    private func roundTrip(_ trip: Trip) throws -> Trip {
        try JSONDecoder().decode(Trip.self, from: JSONEncoder().encode(trip))
    }

    private func decode(_ json: String) throws -> Trip {
        try JSONDecoder().decode(Trip.self, from: Data(json.utf8))
    }

    private func decodeBriefing(_ json: String) throws -> Trip.KnowBeforeYouGo {
        try JSONDecoder().decode(Trip.KnowBeforeYouGo.self, from: Data(json.utf8))
    }

    /// One section, exactly as the backend sends it — every key present, absent
    /// values as JSON `null`, which is what strict Structured Outputs produces.
    private func sectionJSON(
        volatility: String,
        sourceLead: String,
        source: String,
        sourceURL: String
    ) -> String {
        """
        {
          "sections": [
            {
              "bucket": "beforeYouLeave",
              "title": "Entry and documents",
              "body": "Ninety days in any one hundred and eighty for most visitors.",
              "bullets": [],
              "volatility": "\(volatility)",
              "sourceLead": \(sourceLead),
              "source": \(source),
              "sourceURL": \(sourceURL),
              "locations": []
            }
          ]
        }
        """
    }

    /// A trip as the previous build wrote it: `suggestionsState` present,
    /// `knowBeforeYouGoState` not yet a thing.
    private func v2JSONWithoutBriefing() -> String {
        """
        {
          "schemaVersion": 2,
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
            "segments": []
          },
          "suggestionsState": {
            "state": "ready",
            "value": { "dynamicSuggestions": [], "staticSuggestions": [] }
          },
          "favorites": { "liked": [] }
        }
        """
    }
}
