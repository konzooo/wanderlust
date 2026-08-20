import Combine
import ConvexMobile
import CoreArchitecture
import CoreModels
import Foundation

/// Centralizes the share-link URL so it can't drift from the deep-link parser
/// in `NavigationRouter.handleDeepLink`.
enum SharedTripLink {
    static let host = "https://wanderlust.get-catalyst.app"
    static func url(for code: String) -> URL { URL(string: "\(host)/t/\(code)")! }
}

/// Thin wrapper around the Convex client for solo trip sharing. Mirrors
/// `GroupTripService`'s shape. Unlike groups, a shared trip has no ongoing
/// subscription on the reading side: once fetched, the trip becomes a durable
/// local file (`ReceivedSharedTripStorage`) and is never fetched again.
final class SharedTripService {
    static let shared = SharedTripService()

    private let client: ConvexClient

    init(deploymentURL: String = ConvexConfiguration.deploymentURL) {
        client = ConvexClient(deploymentUrl: deploymentURL)
    }

    private struct PublishedTrip: Decodable, Equatable {
        let code: String
    }

    /// Publishes a generated trip. Returns the share code. Only the fields
    /// needed to render the trip are sent — see `ConvexBackend/convex/sharedTrips.ts`.
    func publish(
        title: String,
        destination: String,
        durationDays: Int,
        startMonth: String,
        groupType: String,
        itinerary: Trip.Itinerary,
        suggestions: Trip.Suggestions?,
        knowBeforeYouGo: Trip.KnowBeforeYouGo?,
        favorites: Trip.Favorites,
        deepDives: [Trip.Suggestions.Category]?,
        worthItItems: [Trip.WorthItItem]?,
        whereToStay: [Trip.StayArea]?,
        interestPrompts: [String],
        imageUrl: String?
    ) async throws -> String {
        // Convex `v.number()` is float64; Swift's native `Int` would encode as
        // Convex's int64 wire format, which the validator rejects. Send `Double`.
        var args: [String: ConvexEncodable?] = [
            "installToken": InstallIdentity.token(),
            "title": title,
            "destination": destination,
            "durationDays": Double(durationDays),
            "startMonth": startMonth,
            "groupType": groupType,
            "itinerary": itinerary,
            "favorites": favorites,
            "imageUrl": imageUrl
        ]
        if let suggestions {
            args["suggestions"] = suggestions
        }
        if let deepDives, !deepDives.isEmpty {
            args["deepDives"] = deepDives as [(any ConvexEncodable)?]
        }
        // Content travels in a share; the sender's decisions never do (§4).
        // `worthItDecisions` is absent here by design, not by omission — a
        // recipient who receives the cards pre-skipped has been handed a
        // verdict instead of the question the section exists to ask.
        if let worthItItems, !worthItItems.isEmpty {
            args["worthItItems"] = worthItItems as [(any ConvexEncodable)?]
        }
        if let whereToStay, !whereToStay.isEmpty {
            args["whereToStay"] = whereToStay as [(any ConvexEncodable)?]
        }
        if !interestPrompts.isEmpty {
            args["interestPrompts"] = interestPrompts as [(any ConvexEncodable)?]
        }
        if let knowBeforeYouGo {
            args["knowBeforeYouGo"] = knowBeforeYouGo
        }
        let result: PublishedTrip = try await client.mutation("sharedTrips:publishTrip", with: args)
        return result.code
    }

    /// One-shot fetch: subscribes, takes the first value, then cancels. There
    /// is deliberately no ongoing subscription — once the trip is cached
    /// locally, later opens never hit the network again.
    func fetchOnce(code: String) async throws -> SharedTripDTO? {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = client
                .subscribe(to: "sharedTrips:getSharedTrip", with: ["code": code], yielding: SharedTripDTO?.self)
                .first()
                .sink(
                    receiveCompletion: { completion in
                        if case let .failure(error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { dto in
                        continuation.resume(returning: dto)
                        cancellable?.cancel()
                    }
                )
        }
    }
}

/// A published trip's public data. Hand-written decoder (rather than
/// synthesized) for two reasons: counts arrive as Convex float64 (`Double`
/// behind `durationDaysRaw`, mirroring `GroupDTO`'s pattern), and — critically —
/// `suggestions`/`favorites` must degrade to `nil` instead of throwing if the
/// server echoes a shape an older client doesn't fully recognize (the shared
/// trip should still open with a missing section, not fail outright).
struct SharedTripDTO: Decodable, Equatable {
    let code: String
    let title: String
    let destination: String
    let startMonth: String
    let groupType: String
    let itinerary: Trip.Itinerary
    let suggestions: Trip.Suggestions?
    let knowBeforeYouGo: Trip.KnowBeforeYouGo?
    let favorites: Trip.Favorites?
    let deepDives: [Trip.Suggestions.Category]?
    /// Shared content. The sender's `worthItDecisions` are never published, so
    /// there is nothing here to receive them into — the recipient decides.
    let worthItItems: [Trip.WorthItItem]?
    let whereToStay: [Trip.StayArea]?
    let interestPrompts: [String]?
    let imageUrl: String?

    private let durationDaysRaw: Double
    var durationDays: Int { Int(durationDaysRaw) }

    /// `CaseIterable` so a test can assert on the whole set of keys. The rule
    /// worth guarding is a negative one — that no decision field ever appears
    /// here — and a negative is only testable against an enumerable list.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case code, title, destination, startMonth, groupType, itinerary, suggestions, favorites
        case knowBeforeYouGo, deepDives, worthItItems, whereToStay, interestPrompts, imageUrl
        case durationDaysRaw = "durationDays"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        title = try container.decode(String.self, forKey: .title)
        destination = try container.decode(String.self, forKey: .destination)
        startMonth = try container.decode(String.self, forKey: .startMonth)
        groupType = try container.decode(String.self, forKey: .groupType)
        itinerary = try container.decode(Trip.Itinerary.self, forKey: .itinerary)
        durationDaysRaw = try container.decode(Double.self, forKey: .durationDaysRaw)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        suggestions = try? container.decodeIfPresent(Trip.Suggestions.self, forKey: .suggestions)
        knowBeforeYouGo = try? container.decodeIfPresent(
            Trip.KnowBeforeYouGo.self, forKey: .knowBeforeYouGo
        )
        favorites = try? container.decodeIfPresent(Trip.Favorites.self, forKey: .favorites)
        // Same degrade-don't-throw rule as the two above: a section this build
        // doesn't recognise must cost the recipient that section, never the
        // whole trip.
        worthItItems = try? container.decodeIfPresent(
            [Trip.WorthItItem].self, forKey: .worthItItems
        )
        deepDives = try? container.decodeIfPresent(
            [Trip.Suggestions.Category].self, forKey: .deepDives
        )
        whereToStay = try? container.decodeIfPresent([Trip.StayArea].self, forKey: .whereToStay)
        interestPrompts = try? container.decodeIfPresent([String].self, forKey: .interestPrompts)
    }
}

// Neither graph contains a numeric field (Location lat/long are Strings), so
// these are safe from the Int-vs-Double wire gotcha without extra handling.
extension Trip.Itinerary: @retroactive ConvexEncodable {}
extension Trip.Suggestions: @retroactive ConvexEncodable {}
extension Trip.Suggestions.Category: @retroactive ConvexEncodable {}
extension Trip.KnowBeforeYouGo: @retroactive ConvexEncodable {}
extension Trip.Favorites: @retroactive ConvexEncodable {}
extension Trip.WorthItItem: @retroactive ConvexEncodable {}
extension Trip.StayArea: @retroactive ConvexEncodable {}
