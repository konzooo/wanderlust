import CoreArchitecture
import CoreModels
import Combine
import ConvexMobile
import MapKit
import Networking
import XCTest
@testable import Wanderlust

@MainActor
final class NearYouTests: XCTestCase {
    func testAddressSuggestionPreservesMapCompletionContext() {
        let suggestion = NearYouAddressSuggestion(
            title: "Carrer de Mallorca, 166",
            subtitle: "Barcelona, Spain"
        )

        XCTAssertEqual(
            suggestion.searchText,
            "Carrer de Mallorca, 166, Barcelona, Spain"
        )
    }

    func testAddressSuggestionDoesNotDuplicateContainedSubtitle() {
        let suggestion = NearYouAddressSuggestion(
            title: "Hotel Example, Barcelona",
            subtitle: "Barcelona"
        )

        XCTAssertEqual(suggestion.searchText, "Hotel Example, Barcelona")
    }

    func testBackendCandidatePayloadCannotContainExactAccommodation() throws {
        let exactAddress = "Carrer de Mallorca 166, 2A"
        let data = try JSONEncoder().encode(NearYouBackendCandidate(candidate: candidate()))
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(json.contains(exactAddress))
        XCTAssertFalse(json.contains("latitude"))
        XCTAssertFalse(json.contains("longitude"))
        XCTAssertFalse(json.contains("mapURL"))
        XCTAssertTrue(json.contains("distanceMetres"))
        XCTAssertTrue(json.contains("walkingMinutes"))
    }

    func testGroupPayloadCannotContainExactAccommodationInput() throws {
        let exactAddress = "Carrer de Mallorca 166, 2A"
        let payload = GroupNearYouActionPayload(
            accommodation: centre(precision: .address).accommodation,
            discovery: discovery(),
            researchArea: "Eixample, Barcelona",
            replace: false
        )
        let json = String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)

        XCTAssertFalse(json.contains(exactAddress))
        XCTAssertFalse(json.contains("rawAddress"))
        XCTAssertTrue(json.contains("Hotel Example"))
        XCTAssertTrue(json.contains("\"latitude\":41.385"))
    }

    func testUnknownModelCandidateIDCannotMaterialize() {
        let unknown = UUID()
        let payload = NearYouSelectionPayload(
            sections: [
                .init(
                    title: "Your kind of morning",
                    picks: [.init(candidateID: unknown, explanation: "A good fit.")]
                )
            ],
            sparseMessage: nil
        )

        XCTAssertThrowsError(try payload.materialize(discovery: discovery())) { error in
            XCTAssertEqual(error as? NearYouSelectionError, .unknownCandidateID(unknown))
        }
    }

    func testDisplayedDistanceAndTimeComeFromMapKitCandidate() {
        let candidate = candidate(distance: 1_240, minutes: 17)
        let exact = NearYouWalkingFacts.make(candidate: candidate, precision: .address)
        let approximate = NearYouWalkingFacts.make(
            candidate: candidate,
            precision: .neighbourhood
        )

        XCTAssertEqual(exact.distance, "1.2 km")
        XCTAssertEqual(exact.duration, "17 min walk")
        XCTAssertFalse(exact.isApproximate)
        XCTAssertEqual(approximate.distance, "≈ 1.2 km")
        XCTAssertEqual(approximate.duration, "≈ 17 min walk")
        XCTAssertTrue(approximate.isApproximate)
    }

    func testMapKitVenueIdentityIsStableAndAccommodationIsCoarse() {
        let coordinate = CLLocationCoordinate2D(latitude: 41.385_123, longitude: 2.173_987)
        let first = MapKitNearYouService.stableVenueID(
            name: "Café Grounded",
            coordinate: coordinate
        )
        let second = MapKitNearYouService.stableVenueID(
            name: "CAFÉ GROUNDED",
            coordinate: coordinate
        )
        let accommodation = CoarseAccommodation(
            label: "Hotel Example",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            precision: .address
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(accommodation.latitude, 41.385)
        XCTAssertEqual(accommodation.longitude, 2.174)
    }

    func testAddressLevelPathResolvesLocallyAndGenerates() async {
        let map = StubNearYouMapService()
        map.addressResult = .resolved(.init(
            title: "Hotel Example",
            subtitle: "Carrer de Mallorca",
            centre: centre(precision: .address, researchArea: "Eixample")
        ))
        let model = StubNearYouGenerator()
        let store = makeStore(map: map, model: model)

        store.send(.resolveNearYouAddress("Carrer de Mallorca 166"))
        await settle()

        XCTAssertEqual(map.addressInputs, ["Carrer de Mallorca 166"])
        XCTAssertEqual(model.callCount, 1)
        XCTAssertEqual(model.locations, [.init(area: "Eixample", city: "Destination, Country")])
        XCTAssertFalse(model.locations.description.contains("Carrer de Mallorca 166"))
        XCTAssertEqual(store.state.accommodation?.precision, .address)
        XCTAssertTrue(store.state.nearYouResponse.isLoaded)
        XCTAssertEqual(store.state.nearYouResponse.data?.editorialPicks.first?.id, candidate().id)
    }

    func testWhereToStayPathUsesNeighbourhoodCentre() async {
        let map = StubNearYouMapService()
        map.neighbourhoodCentre = centre(precision: .neighbourhood)
        let model = StubNearYouGenerator()
        let store = makeStore(map: map, model: model)

        store.send(.chooseNearYouArea(Trip.StayArea.mockSet[0]))
        await settle()

        XCTAssertEqual(map.neighbourhoodInputs, [Trip.StayArea.mockSet[0].area])
        XCTAssertEqual(store.state.accommodation?.precision, .neighbourhood)
        XCTAssertTrue(store.state.nearYouResponse.isLoaded)
    }

    func testAnyGroupMemberCanSetAddressLevelSharedNearYou() async {
        let map = StubNearYouMapService()
        map.addressResult = .resolved(.init(
            title: "Hotel Example",
            subtitle: "Carrer de Mallorca",
            centre: centre(precision: .address)
        ))
        let group = StubGroupNearYouGenerator(output: nearYou())
        let store = makeGroupStore(map: map, group: group)
        XCTAssertTrue(store.visibleTabs.contains(.nearYou))

        store.send(.resolveNearYouAddress("Carrer de Mallorca 166"))
        await settle()

        XCTAssertEqual(map.addressInputs, ["Carrer de Mallorca 166"])
        XCTAssertEqual(group.payloads.count, 1)
        XCTAssertFalse(group.payloads[0].replace)
        XCTAssertEqual(store.state.accommodation?.precision, .address)
        XCTAssertEqual(store.state.groupNearYouGenerationCount, 1)
        XCTAssertEqual(store.state.groupNearYouSetBy, "Alex")
        XCTAssertTrue(store.state.nearYouResponse.isLoaded)
    }

    func testGroupWhereToStayUsesSharedNeighbourhoodCentre() async {
        let map = StubNearYouMapService()
        map.neighbourhoodCentre = centre(precision: .neighbourhood)
        let group = StubGroupNearYouGenerator(output: nearYou())
        let store = makeGroupStore(map: map, group: group)

        store.send(.chooseNearYouArea(Trip.StayArea.mockSet[0]))
        await settle()

        XCTAssertEqual(map.neighbourhoodInputs, [Trip.StayArea.mockSet[0].area])
        XCTAssertEqual(group.payloads.first?.accommodation.precision, "neighbourhood")
        XCTAssertEqual(store.state.accommodation?.precision, .neighbourhood)
    }

    func testGroupGetsOneWarnedSuccessfulReplacementOnly() async {
        let map = StubNearYouMapService()
        let group = StubGroupNearYouGenerator(output: nearYou())
        let store = makeGroupStore(map: map, group: group)

        store.send(.chooseNearYouResolution(.init(
            title: "Stay",
            subtitle: nil,
            centre: centre(precision: .address)
        )))
        await settle()
        XCTAssertTrue(store.groupNearYouRequiresReplacementWarning)
        XCTAssertEqual(store.state.groupNearYouGenerationCount, 1)

        // The screen presents the warning before dispatching this action.
        store.send(.regenerateNearYou)
        await settle()
        XCTAssertEqual(group.payloads.map(\.replace), [false, true])
        XCTAssertEqual(store.state.groupNearYouGenerationCount, 2)
        XCTAssertFalse(store.canReplaceGroupNearYou)

        store.send(.regenerateNearYou)
        await settle()
        XCTAssertEqual(group.payloads.count, 2)
    }

    func testFailedGroupNearYouRetriesOnlyExplicitlyAndDoesNotConsumeReplacement() async {
        let map = StubNearYouMapService()
        let group = StubGroupNearYouGenerator(output: nearYou())
        group.failuresRemaining = 1
        let store = makeGroupStore(map: map, group: group)

        store.send(.chooseNearYouResolution(.init(
            title: "Stay",
            subtitle: nil,
            centre: centre(precision: .address)
        )))
        await settle()
        XCTAssertNotNil(store.state.nearYouResponse.error)
        XCTAssertEqual(group.payloads.count, 1)
        XCTAssertEqual(store.state.groupNearYouGenerationCount, 0)

        store.send(.onAppear)
        await settle()
        XCTAssertEqual(group.payloads.count, 1)

        store.send(.retryNearYou)
        await settle()
        XCTAssertEqual(group.payloads.count, 2)
        XCTAssertTrue(store.state.nearYouResponse.isLoaded)
        XCTAssertEqual(store.state.groupNearYouGenerationCount, 1)
    }

    func testReopenedGroupNearYouDoesNotRegenerate() async {
        let map = StubNearYouMapService()
        let group = StubGroupNearYouGenerator(output: nearYou())
        var state = TripOutputStore.State(
            details: .mock,
            mode: .groupTrip,
            itineraryResponse: .loaded(.mock),
            suggestionsResponse: .loaded(.mock),
            nearYouResponse: .loaded(nearYou()),
            accommodation: centre(precision: .address).accommodation
        )
        state.groupId = "group-a"
        state.groupNearYouGenerationCount = 1
        let store = TripOutputStore(
            initialState: state,
            imageService: StubImageService(),
            nearYouMapService: map,
            groupNearYouService: group,
            groupTripObserver: EmptyGroupObserver(),
            groupCredentials: GroupTripCredentials(
                groupId: "group-a",
                code: "12345",
                memberId: "member-a",
                memberToken: "member-token",
                adminToken: nil
            )
        )

        store.send(.onAppear)
        await settle()

        XCTAssertTrue(store.state.nearYouResponse.isLoaded)
        XCTAssertTrue(group.payloads.isEmpty)
        XCTAssertEqual(map.discoveryCallCount, 0)
    }

    func testSharedNearYouArrivesLiveForAnotherMember() async throws {
        let observer = GroupObserverStub()
        var state = TripOutputStore.State(
            details: .mock,
            mode: .groupTrip,
            itineraryResponse: .loaded(.mock),
            suggestionsResponse: .loaded(.mock)
        )
        state.groupId = "group-a"
        let store = TripOutputStore(
            initialState: state,
            imageService: StubImageService(),
            groupTripObserver: observer,
            groupCredentials: GroupTripCredentials(
                groupId: "group-a",
                code: "12345",
                memberId: "member-b",
                memberToken: "member-token-b",
                adminToken: nil
            )
        )
        store.send(.onAppear)

        observer.send(try groupDTO(
            accommodation: centre(precision: .address).accommodation,
            nearYou: nearYou(),
            count: 1
        ))
        await settle()

        XCTAssertTrue(store.state.nearYouResponse.isLoaded)
        XCTAssertEqual(store.state.groupNearYouSetBy, "Alex")
        XCTAssertEqual(store.state.groupNearYouGenerationCount, 1)
    }

    func testAmbiguousAddressWaitsForExplicitChoice() async {
        let map = StubNearYouMapService()
        let first = NearYouResolutionChoice(
            title: "First",
            subtitle: nil,
            centre: centre(precision: .address)
        )
        let second = NearYouResolutionChoice(
            title: "Second",
            subtitle: nil,
            centre: centre(precision: .address, latitude: 41.40)
        )
        map.addressResult = .ambiguous([first, second])
        let model = StubNearYouGenerator()
        let store = makeStore(map: map, model: model)

        store.send(.resolveNearYouAddress("Ambiguous Hotel"))
        await settle()
        XCTAssertEqual(model.callCount, 0)
        XCTAssertEqual(store.state.nearYouAddressResolution.data, .ambiguous([first, second]))

        store.send(.chooseNearYouResolution(second))
        await settle()
        XCTAssertEqual(model.callCount, 1)
        XCTAssertTrue(store.state.nearYouResponse.isLoaded)
    }

    func testMissingCoordinatesProducesIndependentAddressFailure() async {
        let map = StubNearYouMapService()
        map.addressError = NearYouMapError.missingCoordinates
        let model = StubNearYouGenerator()
        let store = makeStore(map: map, model: model)

        store.send(.resolveNearYouAddress("Missing coordinates"))
        await settle()

        XCTAssertNotNil(store.state.nearYouAddressResolution.error)
        XCTAssertEqual(model.callCount, 0)
        XCTAssertTrue(store.state.suggestionsResponse.isLoaded)
    }

    func testSparseDiscoveryDoesNotPadCandidates() async {
        let sparseCandidate = candidate()
        let map = StubNearYouMapService()
        map.discovery = NearYouDiscovery(
            editorialCandidates: [sparseCandidate],
            practical: [],
            unavailablePracticalKinds: Set(Trip.NearYouPracticalKind.allCases)
        )
        let model = StubNearYouGenerator()
        model.payload = NearYouSelectionPayload(
            sections: [
                .init(
                    title: "One real fit",
                    picks: [.init(candidateID: sparseCandidate.id, explanation: "Fits your pace.")]
                )
            ],
            sparseMessage: nil
        )
        let store = makeStore(map: map, model: model)

        store.send(.chooseNearYouResolution(.init(
            title: "Stay",
            subtitle: nil,
            centre: centre(precision: .address)
        )))
        await settle()

        XCTAssertEqual(store.state.nearYouResponse.data?.editorialPicks.count, 1)
        XCTAssertNotNil(store.state.nearYouResponse.data?.sparseMessage)
    }

    func testPartialFailureDoesNotRetryUntilExplicitAction() async {
        let map = StubNearYouMapService()
        let model = StubNearYouGenerator()
        model.failuresRemaining = 1
        let store = makeStore(map: map, model: model)

        store.send(.chooseNearYouResolution(.init(
            title: "Stay",
            subtitle: nil,
            centre: centre(precision: .address)
        )))
        await settle()
        XCTAssertNotNil(store.state.nearYouResponse.error)
        XCTAssertEqual(model.callCount, 1)
        XCTAssertTrue(store.state.suggestionsResponse.isLoaded)

        store.send(.onAppear)
        await settle()
        XCTAssertEqual(model.callCount, 1, "Reappearing must not spend another call")

        store.send(.retryNearYou)
        await settle()
        XCTAssertEqual(model.callCount, 2)
        XCTAssertTrue(store.state.nearYouResponse.isLoaded)
        XCTAssertEqual(map.discoveryCallCount, 1, "Backend-only retry reuses grounded candidates")
    }

    func testSavedResultReopensWithoutRegenerationAndKeepsFavouriteIdentity() async throws {
        let grounded = nearYou()
        var trip = Trip(
            details: .mock,
            itinerary: .mock,
            suggestionsState: .ready(.mock),
            accommodation: centre(precision: .address).accommodation,
            nearYouState: .ready(grounded),
            generationInput: .mock,
            favorites: .init(liked: [candidate().id]),
            tripKey: "near-you-trip"
        )
        trip = try JSONDecoder().decode(Trip.self, from: JSONEncoder().encode(trip))
        let model = StubNearYouGenerator()
        var state = TripOutputStore.State(
            nearYouGenerationRequest: .init(
                tripKey: trip.tripKey!,
                input: trip.generationInput!
            ),
            details: trip.details,
            favorites: trip.favorites,
            saved: true,
            mode: .savedTrip,
            itineraryResponse: .loaded(trip.itinerary),
            suggestionsResponse: .loaded(trip.suggestions!),
            nearYouResponse: trip.nearYouState.asyncValue,
            accommodation: trip.accommodation
        )
        state.whereToStayResponse = .loaded([])
        let store = TripOutputStore(
            initialState: state,
            imageService: StubImageService(),
            nearYouMapService: StubNearYouMapService(),
            nearYouService: model
        )

        store.send(.onAppear)
        await settle()

        XCTAssertEqual(model.callCount, 0)
        XCTAssertEqual(trip.nearYou?.editorialPicks.first?.id, candidate().id)
        XCTAssertTrue(trip.favorites.contains(candidate().id))
        XCTAssertEqual(trip.favouriteCandidates.last?.context, "Near you")
    }

    func testNearYouJoinsAlreadyRecommendedButPracticalDoesNot() {
        let editorial = candidate(name: "Editorial Place")
        let practical = candidate(id: UUID(), name: "Practical Pharmacy")
        let live = liveFind(name: "One-night Ceramics Market")
        var trip = Trip(details: .mock, itinerary: .mock, suggestions: nil)
        trip.nearYouState = .ready(Trip.NearYou(
            sections: [
                .init(
                    title: "For you",
                    picks: [.init(candidate: editorial, explanation: "Fits your taste.")]
                )
            ],
            liveFinds: [live],
            practical: [.init(kind: .pharmacy, candidate: practical)]
        ))

        XCTAssertTrue(trip.alreadyRecommended.contains("Editorial Place"))
        XCTAssertTrue(trip.alreadyRecommended.contains("One-night Ceramics Market"))
        XCTAssertFalse(trip.alreadyRecommended.contains("Practical Pharmacy"))
    }

    func testLiveFindSurvivesSaveReopenWithFavouriteIdentityAndSource() throws {
        let live = liveFind()
        var trip = Trip(
            details: .mock,
            itinerary: .mock,
            suggestionsState: .ready(.mock),
            nearYouState: .ready(Trip.NearYou(
                sections: [],
                liveFinds: [live],
                practical: []
            )),
            favorites: .init(liked: [live.id])
        )

        trip = try JSONDecoder().decode(Trip.self, from: JSONEncoder().encode(trip))

        XCTAssertEqual(trip.nearYou?.liveFinds.first?.id, live.id)
        XCTAssertEqual(trip.nearYou?.liveFinds.first?.sourceURL, live.sourceURL)
        XCTAssertTrue(trip.favorites.contains(live.id))
        XCTAssertEqual(trip.favouriteCandidates.last?.context, "Near you — live finds")
    }

    func testOlderNearYouPayloadWithoutLiveFindsStillDecodes() throws {
        var object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(nearYou()))
                as? [String: Any]
        )
        object.removeValue(forKey: "liveFinds")

        let decoded = try JSONDecoder().decode(
            Trip.NearYou.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertTrue(decoded.liveFinds.isEmpty)
        XCTAssertEqual(decoded.editorialPicks.first?.candidate.id, candidate().id)
    }

    func testSoloShareContractHasNoAccommodationOrNearYouKeys() {
        let keys = Set(SharedTripDTO.CodingKeys.allCases.map(\.rawValue))
        XCTAssertFalse(keys.contains("accommodation"))
        XCTAssertFalse(keys.contains("nearYou"))
        XCTAssertFalse(keys.contains("nearYouState"))
    }

    func testOldTripDecodesWithNearYouAbsent() throws {
        let legacy = try JSONSerialization.data(withJSONObject: [
            "details": try object(Trip.Details.mock),
            "itinerary": try object(Trip.Itinerary.mock),
            "favorites": ["liked": []]
        ])
        let trip = try JSONDecoder().decode(Trip.self, from: legacy)

        XCTAssertTrue(trip.nearYouState.isAbsent)
        XCTAssertNil(trip.generationInput)
        XCTAssertNil(trip.accommodation)
    }

    // MARK: - Helpers

    private func makeStore(
        map: StubNearYouMapService,
        model: StubNearYouGenerator
    ) -> TripOutputStore {
        var state = TripOutputStore.State(
            generationRequest: .init(input: .mock),
            details: .mock,
            mode: .newTrip,
            itineraryResponse: .loaded(.mock),
            suggestionsResponse: .loaded(.mock),
            knowBeforeYouGoResponse: .loaded(.mock)
        )
        state.whereToStayResponse = .loaded(Trip.StayArea.mockSet)
        state.worthItResponse = .loaded([])
        return TripOutputStore(
            initialState: state,
            imageService: StubImageService(),
            nearYouMapService: map,
            nearYouService: model
        )
    }

    private func makeGroupStore(
        map: StubNearYouMapService,
        group: StubGroupNearYouGenerator
    ) -> TripOutputStore {
        var state = TripOutputStore.State(
            details: .mock,
            mode: .groupTrip,
            itineraryResponse: .loaded(.mock),
            suggestionsResponse: .loaded(.mock),
            knowBeforeYouGoResponse: .loaded(.mock)
        )
        state.groupId = "group-a"
        state.whereToStayResponse = .loaded(Trip.StayArea.mockSet)
        state.worthItResponse = .loaded([])
        return TripOutputStore(
            initialState: state,
            imageService: StubImageService(),
            nearYouMapService: map,
            groupNearYouService: group,
            groupTripObserver: EmptyGroupObserver(),
            groupCredentials: GroupTripCredentials(
                groupId: "group-a",
                code: "12345",
                memberId: "member-a",
                memberToken: "member-token",
                adminToken: nil
            )
        )
    }

    private func candidate(
        id: UUID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        name: String = "Grounded Cafe",
        distance: Int = 430,
        minutes: Int = 6
    ) -> Trip.NearYouCandidate {
        Trip.NearYouCandidate(
            id: id,
            name: name,
            category: "Café",
            latitude: 41.385,
            longitude: 2.173,
            distanceMetres: distance,
            walkingMinutes: minutes,
            mapURL: URL(string: "https://maps.apple.com/?q=Grounded%20Cafe")!
        )
    }

    private func discovery() -> NearYouDiscovery {
        NearYouDiscovery(
            editorialCandidates: [candidate()],
            practical: [],
            unavailablePracticalKinds: []
        )
    }

    private func nearYou() -> Trip.NearYou {
        Trip.NearYou(
            sections: [
                .init(
                    title: "Your kind of morning",
                    picks: [.init(candidate: candidate(), explanation: "Fits your taste.")]
                )
            ],
            practical: []
        )
    }

    private func liveFind(
        id: UUID = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!,
        name: String = "Weekend Makers Market"
    ) -> Trip.NearYouLiveFind {
        Trip.NearYouLiveFind(
            id: id,
            name: name,
            category: "Temporary market",
            locationHint: "Eixample, Barcelona",
            explanation: "A timely match for your interest in independent craft.",
            accessNote: "Check the organizer's current directions.",
            sourceTitle: "Official market programme",
            sourceURL: URL(string: "https://example.com/market")!
        )
    }

    private func centre(
        precision: CoarseAccommodation.Precision,
        latitude: Double = 41.385,
        researchArea: String? = nil
    ) -> NearYouSearchCentre {
        NearYouSearchCentre(
            accommodation: CoarseAccommodation(
                label: precision == .address ? "Hotel Example" : "El Born, Barcelona",
                latitude: latitude,
                longitude: 2.173,
                precision: precision
            ),
            latitude: latitude,
            longitude: 2.173,
            researchArea: researchArea
        )
    }

    private func object<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }

    private func groupDTO(
        accommodation: CoarseAccommodation,
        nearYou: Trip.NearYou,
        count: Int
    ) throws -> GroupDTO {
        let data = try JSONSerialization.data(withJSONObject: [
            "groupId": "group-a",
            "code": "12345",
            "name": "Friends",
            "destination": "Barcelona",
            "durationDays": 4.0,
            "startMonth": "may",
            "status": "ready",
            "viewerIsAdmin": false,
            "canAutoGenerate": false,
            "members": [],
            "completedCount": 2.0,
            "memberCount": 2.0,
            "accommodation": try object(accommodation),
            "nearYou": try object(nearYou),
            "nearYouSetBy": "Alex",
            "nearYouGenerationCount": Double(count),
            "nearYouOperationState": ["state": "ready"]
        ])
        return try JSONDecoder().decode(GroupDTO.self, from: data)
    }

    private func settle() async {
        for _ in 0..<30 { await Task.yield() }
    }
}

@MainActor
private final class StubNearYouMapService: NearYouMapServicing {
    var addressResult: NearYouAddressResolution?
    var addressError: Error?
    var neighbourhoodCentre: NearYouSearchCentre?
    var discovery: NearYouDiscovery
    private(set) var addressInputs: [String] = []
    private(set) var neighbourhoodInputs: [String] = []
    private(set) var discoveryCallCount = 0

    init() {
        let candidate = Trip.NearYouCandidate(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            name: "Grounded Cafe",
            category: "Café",
            latitude: 41.385,
            longitude: 2.173,
            distanceMetres: 430,
            walkingMinutes: 6,
            mapURL: URL(string: "https://maps.apple.com/?q=Grounded%20Cafe")!
        )
        discovery = NearYouDiscovery(
            editorialCandidates: [candidate],
            practical: [],
            unavailablePracticalKinds: []
        )
    }

    func resolveAddress(
        _ input: String,
        destination: String
    ) async throws -> NearYouAddressResolution {
        addressInputs.append(input)
        if let addressError { throw addressError }
        return addressResult ?? .resolved(.init(
            title: "Hotel Example",
            subtitle: nil,
            centre: neighbourhoodCentre ?? defaultCentre(.address)
        ))
    }

    func resolveNeighbourhood(
        _ area: String,
        destination: String
    ) async throws -> NearYouSearchCentre {
        neighbourhoodInputs.append(area)
        return neighbourhoodCentre ?? defaultCentre(.neighbourhood)
    }

    func discover(around centre: NearYouSearchCentre) async throws -> NearYouDiscovery {
        discoveryCallCount += 1
        return discovery
    }

    private func defaultCentre(
        _ precision: CoarseAccommodation.Precision
    ) -> NearYouSearchCentre {
        NearYouSearchCentre(
            accommodation: CoarseAccommodation(
                label: precision == .address ? "Hotel Example" : "El Born, Barcelona",
                latitude: 41.385,
                longitude: 2.173,
                precision: precision
            ),
            latitude: 41.385,
            longitude: 2.173
        )
    }
}

@MainActor
private final class StubNearYouGenerator: NearYouGenerating {
    private(set) var callCount = 0
    private(set) var locations: [NearYouLocationContext] = []
    var failuresRemaining = 0
    var payload: NearYouSelectionPayload?

    func generate(
        _ request: TripGenerationRequest,
        candidates: [Trip.NearYouCandidate],
        location: NearYouLocationContext,
        alreadyRecommended: [String]
    ) async throws -> NearYouSelectionPayload {
        callCount += 1
        locations.append(location)
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw TripGenerationError.transport
        }
        if let payload { return payload }
        return NearYouSelectionPayload(
            sections: [
                .init(
                    title: "Your kind of morning",
                    picks: candidates.prefix(1).map {
                        .init(candidateID: $0.id, explanation: "Fits your taste.")
                    }
                )
            ],
            sparseMessage: candidates.count < 4 ? "A short, grounded list." : nil
        )
    }
}

@MainActor
private final class StubGroupNearYouGenerator: GroupNearYouGenerating {
    let output: Trip.NearYou
    var failuresRemaining = 0
    private(set) var payloads: [GroupNearYouActionPayload] = []

    init(output: Trip.NearYou) {
        self.output = output
    }

    func generateGroupNearYou(
        groupId: String,
        memberToken: String,
        payload: GroupNearYouActionPayload
    ) async throws -> GroupNearYouResultDTO {
        payloads.append(payload)
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw TripGenerationError.transport
        }
        return GroupNearYouResultDTO(
            accommodation: CoarseAccommodation(
                label: payload.accommodation.label,
                latitude: payload.accommodation.latitude,
                longitude: payload.accommodation.longitude,
                precision: CoarseAccommodation.Precision(
                    rawValue: payload.accommodation.precision
                )!
            ),
            nearYou: output,
            nearYouSetBy: "Alex",
            generationCount: payload.replace ? 2 : 1
        )
    }
}

private struct EmptyGroupObserver: GroupTripObserving {
    func observeGroup(
        groupId: String,
        memberToken: String
    ) -> AnyPublisher<GroupDTO, ClientError> {
        Empty(completeImmediately: false).eraseToAnyPublisher()
    }
}

private final class GroupObserverStub: GroupTripObserving {
    private let subject = PassthroughSubject<GroupDTO, ClientError>()

    func observeGroup(
        groupId: String,
        memberToken: String
    ) -> AnyPublisher<GroupDTO, ClientError> {
        subject.eraseToAnyPublisher()
    }

    func send(_ group: GroupDTO) {
        subject.send(group)
    }
}

private struct StubImageService: ImageService {
    func fetchImageURL(for query: String) async throws -> URL {
        URL(string: "https://example.invalid/image.jpg")!
    }
}
