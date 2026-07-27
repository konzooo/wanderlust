import Combine
import ConvexMobile
import CoreModels
import Foundation

/// Centralizes the share-link URL so it can't drift from the deep-link parser
/// in `NavigationRouter.handleDeepLink`.
enum SharedTripLink {
    static let host = "https://www.get-catalyst.app"
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
        favorites: Trip.Favorites,
        imageUrl: String?
    ) async throws -> String {
        // Convex `v.number()` is float64; Swift's native `Int` would encode as
        // Convex's int64 wire format, which the validator rejects. Send `Double`.
        var args: [String: ConvexEncodable?] = [
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
    let favorites: Trip.Favorites?
    let imageUrl: String?

    private let durationDaysRaw: Double
    var durationDays: Int { Int(durationDaysRaw) }

    enum CodingKeys: String, CodingKey {
        case code, title, destination, startMonth, groupType, itinerary, suggestions, favorites, imageUrl
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
        favorites = try? container.decodeIfPresent(Trip.Favorites.self, forKey: .favorites)
    }
}

// Neither graph contains a numeric field (Location lat/long are Strings), so
// these are safe from the Int-vs-Double wire gotcha without extra handling.
extension Trip.Itinerary: @retroactive ConvexEncodable {}
extension Trip.Suggestions: @retroactive ConvexEncodable {}
extension Trip.Favorites: @retroactive ConvexEncodable {}
