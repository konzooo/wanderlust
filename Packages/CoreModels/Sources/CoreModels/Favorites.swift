//
//  Favorites.swift
//  CoreModels
//
//  Created by Rodrigo Mato on 13/7/25.
//
import Foundation

extension Trip {
    /// User–specific state, persisted alongside the trip
    public struct Favorites: Codable, Hashable, Sendable {
        /// Set of `UUID`s the user liked. A `Set` cannot express order, which is
        /// why the display order is derived from the trip itself rather than
        /// from this — see ``Trip/orderedFavourites(_:)``.
        public private(set) var liked: Set<UUID>

        public init(liked: Set<UUID> = []) {
            self.liked = liked
        }

        public mutating func toggle(_ id: UUID) {
            if liked.contains(id) {
                liked.remove(id)
            } else {
                liked.insert(id)
            }
        }

        /// Idempotent insert. `toggle` is wrong for the Worth-it/Skip path,
        /// where "kept" must always mean present, never "flip whatever it was".
        public mutating func insert(_ id: UUID) {
            liked.insert(id)
        }

        /// Idempotent removal, for the same reason.
        public mutating func remove(_ id: UUID) {
            liked.remove(id)
        }

        public func contains(_ id: UUID) -> Bool {
            liked.contains(id)
        }
    }

    /// One heartable thing, with the heading it belongs under.
    ///
    /// Carries the whole ``LocationLinkableText`` rather than its `text`. The
    /// favourites list used to rebuild these from a bare string, which dropped
    /// `locations` on the floor — so every place link that rendered in the
    /// itinerary and the suggestions feed silently stopped being a link the
    /// moment the same item appeared in favourites.
    public struct FavouriteCandidate: Identifiable, Hashable, Sendable {
        public let id: UUID
        public let text: LocationLinkableText
        /// The group heading this appears under, e.g. "Morning", "Worth it or skip".
        public let context: String

        public init(id: UUID, text: LocationLinkableText, context: String) {
            self.id = id
            self.text = text
            self.context = context
        }
    }

    /// A heading plus the favourites filed under it.
    public struct FavouriteSection: Identifiable, Hashable, Sendable {
        public var id: String { context }
        public let context: String
        public let items: [FavouriteCandidate]

        public init(context: String, items: [FavouriteCandidate]) {
            self.context = context
            self.items = items
        }
    }

    /// Every heartable item in this trip, in the order it appears in the trip.
    ///
    /// New content types are **not** discovered automatically — each one needs
    /// an explicit arm here, and that is deliberate: a type that forgets to add
    /// one produces favourites that can be created but never listed. A section
    /// that is `nil` (an older saved trip, a component that failed) simply
    /// contributes nothing.
    ///
    /// Not everything generated is heartable. The Near You practical layer
    /// (nearest pharmacy, nearest metro) and the where-to-stay options are
    /// deliberately excluded — they are reference, not things you'd want a list
    /// of. Neither exists yet; both get their arm here when they do.
    public var favouriteCandidates: [FavouriteCandidate] {
        var result: [FavouriteCandidate] = []

        // Itinerary, day by day, in time-of-day order.
        for segment in itinerary.segments {
            let buckets: [(String, [LocationLinkableText]?)] = [
                ("Morning", segment.description.morning),
                ("Afternoon", segment.description.afternoon),
                ("Evening", segment.description.evening)
            ]
            for (context, items) in buckets {
                for item in items ?? [] {
                    result.append(.init(id: item.id, text: item, context: context))
                }
            }
            if let tip = segment.secretTip {
                result.append(
                    .init(
                        id: tip.id,
                        text: LocationLinkableText(
                            text: tip.text, locations: tip.locations, id: tip.id
                        ),
                        context: "Secret Tip"
                    )
                )
            }
        }

        // Suggestions.
        if let suggestions {
            for category in suggestions.dynamicSuggestions + suggestions.staticSuggestions {
                for text in category.texts {
                    result.append(.init(id: text.id, text: text, context: category.title))
                }
            }
        }

        // Interest deep dives keep their own provenance — they are stored apart
        // from `dynamicSuggestions` precisely so they stay distinguishable.
        for category in deepDives ?? [] {
            for text in category.texts {
                result.append(.init(id: text.id, text: text, context: category.title))
            }
        }

        // Worth-it/Skip. Only cards the traveller kept are favourites at all,
        // but every card is a *candidate*: the lookup has to resolve the id
        // before it can be shown, and `Favorites` is what decides membership.
        for item in worthItItems ?? [] {
            result.append(
                .init(id: item.id, text: item.favouriteText, context: "Worth it or skip")
            )
        }

        return result
    }

    /// The traveller's favourites in a defined order: grouped by context in the
    /// order each context first appears, and within a context in the order the
    /// items appear in the trip.
    ///
    /// `Favorites.liked` is a `Set`, so it has no order to preserve — the old
    /// "in the order they were added" comment described something the type
    /// could never have done. Rather than start persisting an insertion order,
    /// the order is derived from the trip, which is stable across launches,
    /// identical on every device, and survives a re-save.
    public func orderedFavourites(_ favourites: Favorites) -> [FavouriteCandidate] {
        favouriteSections(favourites).flatMap(\.items)
    }

    /// The same ordering, already grouped for a sectioned list.
    public func favouriteSections(_ favourites: Favorites) -> [FavouriteSection] {
        let liked = favouriteCandidates.filter { favourites.contains($0.id) }

        var order: [String] = []
        var grouped: [String: [FavouriteCandidate]] = [:]
        for candidate in liked {
            if grouped[candidate.context] == nil { order.append(candidate.context) }
            grouped[candidate.context, default: []].append(candidate)
        }

        return order.map { FavouriteSection(context: $0, items: grouped[$0] ?? []) }
    }
}
