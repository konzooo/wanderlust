//
//  NearYouMapService.swift
//  Wanderlust
//
//  Device-side grounding for Near You. No exact accommodation input crosses
//  this boundary; only the coarse centre and resulting candidate facts can be
//  persisted for a shared group result.
//

import CoreModels
import CryptoKit
import Foundation
import MapKit

struct NearYouSearchCentre: Equatable, Hashable, Sendable {
    let accommodation: CoarseAccommodation
    /// Coarse locality suitable for live search. Never the entered address.
    let researchArea: String?
    /// Exact only for the lifetime of the in-memory search. Never persisted.
    let latitude: Double
    let longitude: Double

    init(
        accommodation: CoarseAccommodation,
        latitude: Double,
        longitude: Double,
        researchArea: String? = nil
    ) {
        self.accommodation = accommodation
        self.latitude = latitude
        self.longitude = longitude
        self.researchArea = researchArea
    }

    init(persisted accommodation: CoarseAccommodation) {
        self.init(
            accommodation: accommodation,
            latitude: accommodation.latitude,
            longitude: accommodation.longitude,
            researchArea: accommodation.precision == .neighbourhood
                ? accommodation.label
                : nil
        )
    }
}

struct NearYouResolutionChoice: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    /// Ephemeral search-result label. It may show the exact result so the
    /// traveller can disambiguate, but it is never written to a `Trip`.
    let title: String
    let subtitle: String?
    let centre: NearYouSearchCentre

    init(id: UUID = UUID(), title: String, subtitle: String?, centre: NearYouSearchCentre) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.centre = centre
    }
}

enum NearYouAddressResolution: Equatable, Hashable, Sendable {
    case resolved(NearYouResolutionChoice)
    case ambiguous([NearYouResolutionChoice])
}

struct NearYouDiscovery: Equatable, Hashable, Sendable {
    let editorialCandidates: [Trip.NearYouCandidate]
    let practical: [Trip.NearYouPracticalPlace]
    let unavailablePracticalKinds: Set<Trip.NearYouPracticalKind>

    var isSparse: Bool { editorialCandidates.count < 4 }
}

enum NearYouMapError: Error, Equatable {
    case emptyQuery
    case noResults
    case missingCoordinates
    case discoveryFailed
}

protocol NearYouMapServicing {
    /// Resolves the exact completion the traveller selected. Production MapKit
    /// preserves the opaque completion object; test and alternate providers can
    /// fall back to the full display text through the default implementation.
    func resolveSuggestion(
        _ suggestion: NearYouAddressSuggestion,
        destination: String
    ) async throws -> NearYouAddressResolution

    /// Returns every plausible exact result. Ambiguity is resolved by the user,
    /// never by silently choosing the model's or MapKit's first guess.
    func resolveAddress(_ input: String, destination: String) async throws -> NearYouAddressResolution

    /// Resolves a Where-to-Stay area to a coarse neighbourhood centre.
    func resolveNeighbourhood(_ area: String, destination: String) async throws -> NearYouSearchCentre

    /// Finds real candidates and computes walking routes for each one.
    func discover(around centre: NearYouSearchCentre) async throws -> NearYouDiscovery
}

extension NearYouMapServicing {
    func resolveSuggestion(
        _ suggestion: NearYouAddressSuggestion,
        destination: String
    ) async throws -> NearYouAddressResolution {
        try await resolveAddress(suggestion.searchText, destination: destination)
    }
}

struct MapKitNearYouService: NearYouMapServicing {
    private struct SearchSeed {
        let item: MKMapItem
        let category: String
    }

    private static let editorialQueries: [(query: String, category: String)] = [
        ("cafe", "Café"),
        ("bakery", "Bakery"),
        ("restaurant", "Restaurant"),
        ("bar", "Bar"),
        ("park", "Park"),
        ("museum", "Museum"),
        ("things to do", "Local interest")
    ]

    private static let practicalQueries: [(kind: Trip.NearYouPracticalKind, query: String)] = [
        (.transport, "public transport"),
        (.grocery, "supermarket"),
        (.pharmacy, "pharmacy")
    ]

    func resolveSuggestion(
        _ suggestion: NearYouAddressSuggestion,
        destination: String
    ) async throws -> NearYouAddressResolution {
        guard let completion = suggestion.completion else {
            return try await resolveAddress(suggestion.searchText, destination: destination)
        }

        let request = MKLocalSearch.Request(completion: completion)
        if let region = await Self.searchRegion(for: destination) {
            request.region = region
        }
        request.resultTypes = [.address, .pointOfInterest]
        let items = try await MKLocalSearch(request: request).start().mapItems
        return try resolution(
            from: items,
            destination: destination,
            precision: .address
        )
    }

    func resolveAddress(
        _ input: String,
        destination: String
    ) async throws -> NearYouAddressResolution {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NearYouMapError.emptyQuery }

        let region = await Self.searchRegion(for: destination)
        let query = Self.scopedQuery(trimmed, destination: destination)

        // A traveller who bypasses autocomplete is most likely entering a full
        // street address. Search addresses first so sparse Apple POI coverage
        // cannot crowd a valid address out of the first few results.
        var items = try await search(
            query: query,
            region: region,
            resultTypes: .address
        )
        if items.isEmpty {
            items = try await search(
                query: query,
                region: region,
                resultTypes: [.address, .pointOfInterest]
            )
        }
        return try resolution(from: items, destination: destination, precision: .address)
    }

    func resolveNeighbourhood(
        _ area: String,
        destination: String
    ) async throws -> NearYouSearchCentre {
        let trimmed = area.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NearYouMapError.emptyQuery }
        let items = try await search(query: "\(trimmed), \(destination)", region: nil)
        guard !items.isEmpty else { throw NearYouMapError.noResults }

        for item in items {
            let coordinate = item.placemark.coordinate
            guard Self.isValid(coordinate) else { continue }
            let label = [trimmed, item.placemark.locality]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .reduce(into: [String]()) { result, part in
                    if !result.contains(where: { $0.caseInsensitiveCompare(part) == .orderedSame }) {
                        result.append(part)
                    }
                }
                .joined(separator: ", ")
            let accommodation = CoarseAccommodation(
                label: label.isEmpty ? trimmed : label,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                precision: .neighbourhood
            )
            return NearYouSearchCentre(
                accommodation: accommodation,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                researchArea: label.isEmpty ? destination : label
            )
        }
        throw NearYouMapError.missingCoordinates
    }

    func discover(around centre: NearYouSearchCentre) async throws -> NearYouDiscovery {
        let coordinate = CLLocationCoordinate2D(
            latitude: centre.latitude,
            longitude: centre.longitude
        )
        guard Self.isValid(coordinate) else { throw NearYouMapError.missingCoordinates }

        var editorialSeeds: [SearchSeed] = []
        var successfulSearches = 0
        for definition in Self.editorialQueries {
            do {
                let items = try await search(
                    query: definition.query,
                    region: Self.region(around: coordinate, span: 0.025)
                )
                successfulSearches += 1
                editorialSeeds += items.prefix(5).map {
                    SearchSeed(item: $0, category: definition.category)
                }
            } catch {
                // Category searches are independent. One failed MapKit query
                // must not erase the candidates the other queries grounded.
            }
        }

        var editorial = await routedCandidates(
            deduplicating: editorialSeeds,
            from: coordinate
        )

        // Rural/island fallback: broaden the real search instead of filling the
        // sparse layout with model-made places. These may be a long walk; that
        // fact remains honest because the route still comes from MapKit.
        if editorial.count < 4 {
            var broadSeeds: [SearchSeed] = []
            for definition in Self.editorialQueries {
                do {
                    let items = try await search(
                        query: definition.query,
                        region: Self.region(around: coordinate, span: 0.18)
                    )
                    successfulSearches += 1
                    broadSeeds += items.prefix(4).map {
                        SearchSeed(item: $0, category: definition.category)
                    }
                } catch { }
            }
            editorial += await routedCandidates(
                deduplicating: broadSeeds,
                excluding: Set(editorial.map(\.id)),
                from: coordinate
            )
        }

        var practical: [Trip.NearYouPracticalPlace] = []
        var unavailable = Set<Trip.NearYouPracticalKind>()
        for definition in Self.practicalQueries {
            do {
                var items = try await search(
                    query: definition.query,
                    region: Self.region(around: coordinate, span: 0.035)
                )
                if items.isEmpty {
                    items = try await search(
                        query: definition.query,
                        region: Self.region(around: coordinate, span: 0.18)
                    )
                }
                let candidates = await routedCandidates(
                    deduplicating: items.prefix(6).map {
                        SearchSeed(item: $0, category: definition.kind.title)
                    },
                    from: coordinate
                )
                if let nearest = candidates.min(by: {
                    $0.distanceMetres < $1.distanceMetres
                }) {
                    practical.append(.init(kind: definition.kind, candidate: nearest))
                } else {
                    unavailable.insert(definition.kind)
                }
            } catch {
                unavailable.insert(definition.kind)
            }
        }

        if successfulSearches == 0 && practical.isEmpty {
            throw NearYouMapError.discoveryFailed
        }

        return NearYouDiscovery(
            editorialCandidates: Array(
                editorial
                    .sorted { $0.distanceMetres < $1.distanceMetres }
                    .prefix(36)
            ),
            practical: practical.sorted { $0.kind.rawValue < $1.kind.rawValue },
            unavailablePracticalKinds: unavailable
        )
    }

    // MARK: - Search and routing

    private func search(
        query: String,
        region: MKCoordinateRegion?,
        resultTypes: MKLocalSearch.ResultType? = nil
    ) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region { request.region = region }
        if let resultTypes { request.resultTypes = resultTypes }
        return try await MKLocalSearch(request: request).start().mapItems
    }

    /// Resolve the trip destination once to give autocomplete, manual address
    /// search and the pin picker a real geographic scope. A city-sized region is
    /// deliberately broad enough for outskirts and rural accommodation.
    static func searchRegion(for destination: String) async -> MKCoordinateRegion? {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]
        do {
            guard let item = try await MKLocalSearch(request: request).start().mapItems.first,
                  Self.isValid(item.placemark.coordinate) else {
                return nil
            }
            return region(around: item.placemark.coordinate, span: 0.35)
        } catch {
            return nil
        }
    }

    static func scopedQuery(_ input: String, destination: String) -> String {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDestination.isEmpty else { return trimmedInput }

        let city = trimmedDestination.split(separator: ",", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? trimmedDestination
        if trimmedInput.localizedCaseInsensitiveContains(trimmedDestination)
            || (!city.isEmpty && trimmedInput.localizedCaseInsensitiveContains(city)) {
            return trimmedInput
        }
        return "\(trimmedInput), \(trimmedDestination)"
    }

    private func routedCandidates(
        deduplicating seeds: [SearchSeed],
        excluding excluded: Set<UUID> = [],
        from source: CLLocationCoordinate2D
    ) async -> [Trip.NearYouCandidate] {
        var seen = excluded
        var result: [Trip.NearYouCandidate] = []
        for seed in seeds {
            guard let name = seed.item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { continue }
            let destination = seed.item.placemark.coordinate
            guard Self.isValid(destination) else { continue }
            let id = Self.stableVenueID(name: name, coordinate: destination)
            guard seen.insert(id).inserted else { continue }

            let directionsRequest = MKDirections.Request()
            directionsRequest.source = MKMapItem(
                placemark: MKPlacemark(coordinate: source)
            )
            directionsRequest.destination = seed.item
            directionsRequest.transportType = .walking
            do {
                guard let route = try await MKDirections(request: directionsRequest)
                    .calculate().routes.first else { continue }
                result.append(
                    Trip.NearYouCandidate(
                        id: id,
                        name: name,
                        category: seed.category,
                        latitude: destination.latitude,
                        longitude: destination.longitude,
                        distanceMetres: Int(route.distance.rounded()),
                        walkingMinutes: max(1, Int((route.expectedTravelTime / 60).rounded())),
                        mapURL: Self.mapURL(name: name, coordinate: destination)
                    )
                )
            } catch {
                // A straight-line fallback would violate the ownership split.
                // If MapKit cannot produce a walking route, the candidate is
                // unusable and is omitted rather than shown with a guessed fact.
            }
        }
        return result
    }

    private func resolutionChoice(
        for item: MKMapItem,
        destination: String,
        precision: CoarseAccommodation.Precision
    ) -> NearYouResolutionChoice? {
        let coordinate = item.placemark.coordinate
        guard Self.isValid(coordinate) else { return nil }

        let isHotel = item.pointOfInterestCategory == .hotel
        let locality = item.placemark.subLocality ?? item.placemark.locality
        let persistedLabel: String
        if isHotel, let hotel = item.name, !hotel.isEmpty {
            persistedLabel = hotel
        } else if let locality, !locality.isEmpty {
            persistedLabel = "Your stay near \(locality)"
        } else {
            persistedLabel = "Your stay in \(destination)"
        }
        let accommodation = CoarseAccommodation(
            label: persistedLabel,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            precision: precision
        )
        return NearYouResolutionChoice(
            title: item.name ?? "This location",
            subtitle: item.placemark.title,
            centre: NearYouSearchCentre(
                accommodation: accommodation,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                researchArea: locality ?? destination
            )
        )
    }

    private func resolution(
        from items: [MKMapItem],
        destination: String,
        precision: CoarseAccommodation.Precision
    ) throws -> NearYouAddressResolution {
        guard !items.isEmpty else { throw NearYouMapError.noResults }
        let choices = items.prefix(5).compactMap {
            resolutionChoice(for: $0, destination: destination, precision: precision)
        }
        guard !choices.isEmpty else { throw NearYouMapError.missingCoordinates }
        if choices.count == 1 { return .resolved(choices[0]) }
        return .ambiguous(choices)
    }

    static func stableVenueID(name: String, coordinate: CLLocationCoordinate2D) -> UUID {
        let canonical = "\(name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil))|\(String(format: "%.6f", coordinate.latitude))|\(String(format: "%.6f", coordinate.longitude))"
        let hex = SHA256.hash(data: Data(canonical.utf8))
            .prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
        let uuid = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: uuid)!
    }

    static func isValid(_ coordinate: CLLocationCoordinate2D) -> Bool {
        CLLocationCoordinate2DIsValid(coordinate)
            && coordinate.latitude.isFinite
            && coordinate.longitude.isFinite
            && !(coordinate.latitude == 0 && coordinate.longitude == 0)
    }

    private static func region(
        around coordinate: CLLocationCoordinate2D,
        span: CLLocationDegrees
    ) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }

    private static func mapURL(name: String, coordinate: CLLocationCoordinate2D) -> URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: name),
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)")
        ]
        return components.url!
    }
}
