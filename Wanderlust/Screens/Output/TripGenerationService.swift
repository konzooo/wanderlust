import ConvexMobile
import CoreArchitecture
import CoreModels
import Foundation

/// Which piece of a trip to generate. Raw values are the wire format shared
/// with `generationComponent` in `ConvexBackend/convex/lib/components.ts`.
enum TripComponent: String, CaseIterable, Sendable {
    case itinerary
    case suggestions
    case knowBeforeYouGo
    case deepDive
    case worthIt
    case whereToStay
    /// Manual and explicit. Never part of eager solo or group generation.
    case nearYou

    /// A required component's failure fails the whole generation; everything
    /// else is best-effort and the trip still opens without it. The split is
    /// declared here and enforced identically on the backend.
    var isRequired: Bool { self == .itinerary }

    /// The components a trip screen generates on its own when it opens.
    ///
    /// Know Before You Go is eager (D14), with the same lifecycle as the other
    /// automatic components. A deep dive is deliberately absent: one is only
    /// ever generated because the traveller tapped a chip. The rest depends on
    /// which arm of the D15 experiment is running — under
    /// ``SuggestionsVariant/combined`` the
    /// Worth-it cards and the where-to-stay guide ride on the suggestions call
    /// rather than being requested separately.
    static func automatic(
        variant: SuggestionsVariant = OutputFeatureFlags.suggestionsVariant
    ) -> [TripComponent] {
        switch variant {
        case .combined: [.itinerary, .suggestions, .knowBeforeYouGo]
        case .split: [.itinerary, .suggestions, .knowBeforeYouGo, .worthIt, .whereToStay]
        }
    }
}

/// Which shape the suggestions call takes — D15, as the client sees it.
///
/// Mirrors `SuggestionsVariant` in `ConvexBackend/convex/lib/components.ts` and
/// is sent explicitly with every request. The client has to be the one that
/// decides: it is the only side that knows what else it is about to ask for,
/// and asking for the enlarged shape *and* calling `worthIt` separately would
/// generate — and bill for — the same four cards twice.
enum SuggestionsVariant: String, Sendable {
    /// One enlarged suggestions call carrying the Worth-it cards and the
    /// where-to-stay guide alongside the themed categories.
    case combined
    /// The pre-S5 suggestions call, with the two new sections as their own
    /// focused calls running in parallel.
    case split
}

/// One trip's generation inputs plus the key its server-side caps are scoped to.
struct TripGenerationRequest: Equatable, Hashable, Sendable {
    /// Opaque per-trip key. Stable for the life of the trip so the deep-dive
    /// cap follows the trip rather than resetting on every screen open.
    let tripKey: String
    let input: TripGenerationInput

    init(tripKey: String = TripKey.mint(), input: TripGenerationInput) {
        self.tripKey = tripKey
        self.input = input
    }
}

/// Failures a generation call can return. Every case maps to a stable code the
/// backend chose deliberately — the app never parses a provider message.
enum TripGenerationError: Error, Equatable {
    /// This install has generated a lot today.
    case installDailyLimit
    /// The backend as a whole is at its daily budget.
    case serviceBusy
    /// All three interest deep dives for this trip are used up.
    case deepDiveLimit
    /// This exact interest has already been explored for this trip.
    case duplicateDeepDive
    /// The model ran out of room. Distinct because it means the request was too
    /// big, not that anything went wrong.
    case truncatedOutput
    /// Anything else, carrying the backend's code for logging.
    case backend(code: String)
    /// The call never reached the backend.
    case transport

    init(code: String) {
        switch code {
        case "quota_install_daily": self = .installDailyLimit
        case "quota_global_daily": self = .serviceBusy
        case "quota_component_cap": self = .deepDiveLimit
        case "duplicate_deep_dive": self = .duplicateDeepDive
        case let c where c.hasPrefix("incomplete_"): self = .truncatedOutput
        case "validation_incomplete_itinerary", "validation_empty_itinerary":
            self = .truncatedOutput
        default: self = .backend(code: code)
        }
    }

    /// The stable code, for analytics. Never user-facing copy.
    var code: String {
        switch self {
        case .installDailyLimit: "quota_install_daily"
        case .serviceBusy: "quota_global_daily"
        case .deepDiveLimit: "quota_component_cap"
        case .duplicateDeepDive: "duplicate_deep_dive"
        case .truncatedOutput: "output_incomplete"
        case .backend(let code): code
        case .transport: "transport"
        }
    }
}

/// Calls the backend's generation action. Mirrors `GroupTripService`'s shape.
///
/// This type is the whole reason there is no OpenAI key in the app any more: it
/// sends trip *data* and receives structured output. It owns no prompt, no
/// schema and no model name — all three live in the Convex backend, once, for
/// both the solo and the group path.
final class TripGenerationService {
    static let shared = TripGenerationService()

    private let client: ConvexClient

    init(deploymentURL: String = ConvexConfiguration.deploymentURL) {
        client = ConvexClient(deploymentUrl: deploymentURL)
    }

    func generate<T: Decodable>(
        _ component: TripComponent,
        for request: TripGenerationRequest,
        interest: String? = nil,
        alreadyRecommended: [String]? = nil,
        nearYouCandidates: [NearYouBackendCandidate]? = nil,
        nearYouLocation: NearYouLocationContext? = nil,
        variant: SuggestionsVariant = OutputFeatureFlags.suggestionsVariant
    ) async throws -> T {
        var args: [String: ConvexEncodable?] = [
            "installToken": InstallIdentity.token(),
            "tripKey": request.tripKey,
            "component": component.rawValue,
            "input": request.input,
            "variant": variant.rawValue
        ]
        // Only send the optional arguments that apply — a `nil` value in this
        // dictionary is transmitted as JSON `null`, not as an absent key.
        if let interest { args["interest"] = interest }
        if let alreadyRecommended, !alreadyRecommended.isEmpty {
            args["alreadyRecommended"] = alreadyRecommended as [(any ConvexEncodable)?]
        }
        if let nearYouCandidates {
            args["nearYouCandidates"] = nearYouCandidates.map {
                $0 as (any ConvexEncodable)?
            }
        }
        if let nearYouLocation {
            args["nearYouLocation"] = nearYouLocation
        }

        do {
            return try await client.action("trips:generateComponent", with: args)
        } catch let error as ClientError {
            throw Self.mapped(error)
        }
    }

    /// Turns the Convex transport error into a typed generation error. A
    /// `ConvexError` payload is the JSON-encoded value the backend threw — for
    /// us always a bare string code, so the quotes come off before matching.
    static func mapped(_ error: ClientError) -> TripGenerationError {
        switch error {
        case .ConvexError(let data):
            let code = (try? JSONDecoder().decode(String.self, from: Data(data.utf8)))
                ?? data.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return TripGenerationError(code: code)
        case .ServerError, .InternalError:
            return .transport
        }
    }
}

// Rides as a nested Convex action argument; the default `Encodable` path
// JSON-encodes it, so `durationDays` arrives as a plain number matching
// `v.number()` rather than Convex's int64 wire format.
extension TripGenerationInput: @retroactive ConvexEncodable {}
