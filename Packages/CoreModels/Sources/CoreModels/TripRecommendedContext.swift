//
//  TripRecommendedContext.swift
//  CoreModels
//
//  What this trip has already recommended, derived at call time.
//

import Foundation

public extension Trip {
    /// Ceiling on how many names travel with a request.
    ///
    /// Matches `MAX_ALREADY_RECOMMENDED_ITEMS` in the backend's validators. The
    /// server truncates anyway; truncating here too means the app knows what it
    /// actually sent, and a long trip's tail is dropped in one place rather
    /// than silently in two.
    static let maxAlreadyRecommended = 200

    /// Every place this trip has already put in front of the traveller.
    ///
    /// **Derived, never stored** (§11). A persisted copy of this goes stale the
    /// moment a deep dive is added, a component is retried, or an old file is
    /// migrated — and the failure is silent, because a stale list still looks
    /// like a list. Recomputing it is a walk over structures already in memory,
    /// which is cheap enough that caching it would be trading correctness for
    /// nothing measurable.
    ///
    /// What is included, and why:
    /// - **Itinerary**: the activities and secret tips, plus the segment titles,
    ///   which often name the neighbourhood a day is built around.
    /// - **Suggestions and deep dives**: the feed's own places, so a second dive
    ///   doesn't hand back the first one's list.
    /// - **Worth-it/Skip**: a card has already argued about a place at length.
    ///   Seeing it again in a deep dive is the most conspicuous repetition the
    ///   app can produce.
    ///
    /// What is deliberately excluded:
    /// - **Where-to-stay** names neighbourhoods to sleep in, which is a
    ///   different axis entirely. Suppressing El Born from the suggestions feed
    ///   because it was offered as a place to stay would remove a real
    ///   recommendation to avoid a repetition that isn't one.
    /// - **Where-to-stay** remains excluded; grounded Near You editorial picks
    ///   are included once they land, while its practical layer is not a
    ///   recommendation and contributes nothing.
    var alreadyRecommended: [String] {
        var seen = Set<String>()
        var result: [String] = []

        func add(_ raw: String) {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            let key = name.lowercased()
            guard seen.insert(key).inserted else { return }
            result.append(name)
        }

        func add(_ locations: [Itinerary.Location]?) {
            for location in locations ?? [] { add(location.placeName) }
        }

        for segment in itinerary.segments {
            add(Self.segmentSubject(segment.title))
            let buckets = [
                segment.description.morning,
                segment.description.afternoon,
                segment.description.evening
            ]
            for bucket in buckets {
                for item in bucket ?? [] { add(item.locations) }
            }
            add(segment.secretTip?.locations)
        }

        // A `nil` section — an older saved trip, a component that failed —
        // contributes nothing and must not be a special case anywhere.
        for category in (suggestions.map { $0.dynamicSuggestions + $0.staticSuggestions } ?? [])
            + (deepDives ?? []) {
            for text in category.texts { add(text.locations) }
        }

        for item in worthItItems ?? [] { add(item.locations) }

        for pick in nearYou?.editorialPicks ?? [] { add(pick.candidate.name) }

        return Array(result.prefix(Self.maxAlreadyRecommended))
    }

    /// Strips a segment title down to the part that might name a place.
    ///
    /// Titles arrive as "🏙️ Day 1: Old Streets, New Flavors". The emoji and the
    /// day range are chrome — sending them would spend the request's budget
    /// telling the model not to repeat the word "Day".
    static func segmentSubject(_ title: String) -> String {
        let withoutDayPrefix = title.range(of: #"^\s*\P{L}*\s*Days?\s*[\d–—-]+\s*:\s*"#,
                                           options: [.regularExpression, .caseInsensitive])
            .map { String(title[$0.upperBound...]) } ?? title
        return withoutDayPrefix.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        )
    }
}
