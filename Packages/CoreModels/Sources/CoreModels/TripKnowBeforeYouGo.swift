//
//  TripKnowBeforeYouGo.swift
//  CoreModels
//
//  Know Before You Go v1: the practical half of a destination.
//

import Foundation

extension Trip {
    /// Destination-wide practical preparation — entry rules, money, transport,
    /// food and etiquette basics. Deliberately **not** another feed of places:
    /// it may name an airport or a metro line where the fact is about that
    /// place, but "what to skip" and "where to eat" belong to the suggestions
    /// feed and stay there.
    ///
    /// **v1 is explicitly provisional.** The taxonomy below — four buckets, six
    /// always-present sections, 8–14 total — is a complete and testable feature,
    /// not a researched end state. Expect it to be reworked once there is real
    /// usage behind it; nothing else in the app should grow a dependency on the
    /// specific bucket set.
    public struct KnowBeforeYouGo: Codable, Equatable, Hashable, Sendable {
        public let sections: [Section]

        public init(sections: [Section] = []) {
            self.sections = sections
        }

        /// The sections grouped under their bucket, in the canonical bucket
        /// order, skipping buckets this destination produced nothing for.
        ///
        /// Order comes from ``Bucket/allCases`` rather than from the model's
        /// output order: the four buckets are the app's structure, and a run
        /// that happens to emit them out of order should still read the same.
        public var groups: [BucketGroup] {
            Bucket.allCases.compactMap { bucket in
                let matching = sections.filter { $0.bucket == bucket }
                return matching.isEmpty ? nil : BucketGroup(bucket: bucket, sections: matching)
            }
        }

        /// One bucket's worth of sections.
        public struct BucketGroup: Identifiable, Equatable, Hashable, Sendable {
            public var id: Bucket { bucket }
            public let bucket: Bucket
            public let sections: [Section]
        }

        /// How much a section's facts move.
        ///
        /// This replaces both a global disclaimer and a per-section badge. A
        /// ``stable`` section is written with full confidence and shows nothing
        /// extra; a ``verify`` section carries one line naming the authority to
        /// check. The prompt pushes hard against over-hedging, so a run where
        /// most sections come back `verify` is a prompt regression, not a
        /// cautious model — see the evaluation script in `Tools/`.
        public enum Volatility: String, Codable, Sendable {
            case stable
            case verify
        }

        /// The four buckets, in the order they are read.
        public enum Bucket: String, Codable, CaseIterable, Sendable {
            case beforeYouLeave
            case money
            case gettingAround
            case onTheGround
            /// Anything a newer backend sends that this build doesn't know.
            /// Present so one unrecognised bucket degrades to a trailing group
            /// instead of failing the whole component's decode — the same
            /// tolerance `Trip.Suggestions.Category` has for section IDs.
            case other

            public init(from decoder: Decoder) throws {
                let raw = try decoder.singleValueContainer().decode(String.self)
                self = Bucket(rawValue: raw) ?? .other
            }

            public var title: String {
                switch self {
                case .beforeYouLeave: "Before you leave"
                case .money: "Money"
                case .gettingAround: "Getting around"
                case .onTheGround: "On the ground"
                case .other: "Also worth knowing"
                }
            }

            /// SF Symbols, per the design system — the `section-N` PNGs belong
            /// to the suggestions feed's fixed categories.
            public var iconName: String {
                switch self {
                case .beforeYouLeave: "suitcase"
                case .money: "creditcard"
                case .gettingAround: "tram"
                case .onTheGround: "fork.knife"
                case .other: "lightbulb"
                }
            }
        }

        /// One thing to know.
        public struct Section: Codable, Equatable, Hashable, Sendable, Identifiable {
            /// Stable across save, share and reopen. The backend never sends
            /// one; a saved file always does. Same discipline as
            /// ``LocationLinkableText`` — an id regenerated on decode would
            /// break anything keyed to it.
            public let id: UUID
            public let bucket: Bucket
            /// Written by the model, so it renders as generated prose, not as
            /// app chrome.
            public let title: String
            public let body: String
            /// Short specifics. Required-with-`[]` on the wire; a section with
            /// nothing to itemise sends an empty array rather than omitting it.
            public let bullets: [String]
            public let volatility: Volatility
            /// The lead-in to the source line ("Entry rules change — confirm
            /// with"). `nil` on every ``Volatility/stable`` section.
            public let sourceLead: String?
            /// The authority worth checking. Guaranteed non-`nil` when
            /// ``volatility`` is ``Volatility/verify`` — see the decoder.
            public let source: String?
            /// The authority's official address, when the model was sure of it.
            /// `nil` is normal and expected: a fabricated official URL is worse
            /// than no link, because the link is the part a traveller trusts.
            public let sourceURL: URL?
            /// Places named in `body` or `bullets`.
            public let locations: [Itinerary.Location]?

            public init(
                bucket: Bucket,
                title: String,
                body: String,
                bullets: [String] = [],
                volatility: Volatility = .stable,
                sourceLead: String? = nil,
                source: String? = nil,
                sourceURL: URL? = nil,
                locations: [Itinerary.Location]? = nil,
                id: UUID = UUID()
            ) {
                self.id = id
                self.bucket = bucket
                self.title = title
                self.body = body
                self.bullets = bullets
                let resolved = Self.resolveConfidence(
                    volatility: volatility,
                    sourceLead: sourceLead,
                    source: source,
                    sourceURL: sourceURL
                )
                self.volatility = resolved.volatility
                self.sourceLead = resolved.sourceLead
                self.source = resolved.source
                self.sourceURL = resolved.sourceURL
                self.locations = locations
            }

            private enum CodingKeys: String, CodingKey {
                case id, bucket, title, body, bullets, volatility
                case sourceLead, source, sourceURL, locations
            }

            /// Decoding is where the conditional rule strict JSON Schema cannot
            /// express gets enforced (§3 of the plan): *`source` is required
            /// when `volatility == "verify"`*. It is applied here rather than at
            /// a call site so it holds for every path a section arrives by —
            /// the backend, a saved file, and a received share alike.
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
                bucket = try container.decodeIfPresent(Bucket.self, forKey: .bucket) ?? .other
                title = try container.decode(String.self, forKey: .title)
                body = try container.decode(String.self, forKey: .body)
                bullets = try container.decodeIfPresent([String].self, forKey: .bullets) ?? []
                locations = try container.decodeIfPresent(
                    [Itinerary.Location].self, forKey: .locations
                )

                let resolved = Self.resolveConfidence(
                    volatility: try container.decodeIfPresent(
                        Volatility.self, forKey: .volatility
                    ) ?? .stable,
                    sourceLead: try container.decodeIfPresent(String.self, forKey: .sourceLead),
                    source: try container.decodeIfPresent(String.self, forKey: .source),
                    sourceURL: try container.decodeIfPresent(String.self, forKey: .sourceURL)
                        .flatMap(Self.httpsURL)
                )
                volatility = resolved.volatility
                sourceLead = resolved.sourceLead
                source = resolved.source
                sourceURL = resolved.sourceURL
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(id, forKey: .id)
                try container.encode(bucket, forKey: .bucket)
                try container.encode(title, forKey: .title)
                try container.encode(body, forKey: .body)
                try container.encode(bullets, forKey: .bullets)
                try container.encode(volatility, forKey: .volatility)
                try container.encodeIfPresent(sourceLead, forKey: .sourceLead)
                try container.encodeIfPresent(source, forKey: .source)
                try container.encodeIfPresent(sourceURL?.absoluteString, forKey: .sourceURL)
                try container.encodeIfPresent(locations, forKey: .locations)
            }

            /// The defined fallback for the rule the schema cannot carry.
            ///
            /// - A `verify` section with no usable `source` becomes `stable`.
            ///   The alternative is a tinted line telling the traveller to check
            ///   with nobody in particular, which is hedging with extra steps —
            ///   exactly what the volatility flag exists to avoid.
            /// - A `stable` section drops any source fields it arrived with, so
            ///   "reads with full confidence" is true of the rendered section
            ///   and not just of the prompt.
            private static func resolveConfidence(
                volatility: Volatility,
                sourceLead: String?,
                source: String?,
                sourceURL: URL?
            ) -> (volatility: Volatility, sourceLead: String?, source: String?, sourceURL: URL?) {
                guard volatility == .verify, let source = nonEmpty(source) else {
                    return (.stable, nil, nil, nil)
                }
                return (.verify, nonEmpty(sourceLead), source, sourceURL)
            }

            private static func nonEmpty(_ value: String?) -> String? {
                guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !trimmed.isEmpty else { return nil }
                return trimmed
            }

            /// Only `https` links are kept. The model is asked for an official
            /// site and nothing else; anything that isn't a plain secure web
            /// address is a mistake worth dropping rather than opening.
            private static func httpsURL(_ raw: String) -> URL? {
                guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                      url.scheme?.lowercased() == "https",
                      url.host != nil else { return nil }
                return url
            }

            /// The prose with its place links attached, ready to render.
            public var linkableBody: LocationLinkableText {
                LocationLinkableText(text: body, locations: locations, id: id)
            }

            /// One bullet, linked the same way. Bullets are plain strings on the
            /// wire — they share the section's `locations` — so the id is
            /// derived from the section plus the bullet's position rather than
            /// minted fresh, which would make it unstable across reloads.
            public func linkableBullet(at index: Int) -> LocationLinkableText {
                LocationLinkableText(
                    text: bullets[index],
                    locations: locations,
                    id: Self.bulletID(section: id, index: index)
                )
            }

            /// Deterministic, derived, and never persisted: a UUID built from
            /// the section id with the bullet index folded into its last byte.
            /// Bullets are not heartable, so this only ever needs to be stable
            /// within a render pass — but stable is cheaper than "regenerated
            /// every time SwiftUI diffs the list".
            static func bulletID(section: UUID, index: Int) -> UUID {
                var bytes = section.uuid
                bytes.15 = bytes.15 ^ UInt8(truncatingIfNeeded: index &+ 1)
                return UUID(uuid: bytes)
            }
        }
    }
}

public extension Trip.KnowBeforeYouGo {
    /// A Barcelona briefing, for previews and for the loading/empty states to
    /// be exercised without a backend. Content only — nothing here is claimed
    /// to be current, and the app never ships it to a traveller.
    static let mock = Trip.KnowBeforeYouGo(sections: [
        .init(
            bucket: .beforeYouLeave,
            title: "Entry and documents",
            body: "EU and Schengen travellers need nothing beyond an ID card. Everyone else enters on the Schengen 90/180 rule, and from 2026 non-EU visitors register with the EU's new entry system at the border, which adds time at El Prat on arrival.",
            bullets: ["Passport valid 3 months beyond departure", "90 days in any 180 for most non-EU visitors"],
            volatility: .verify,
            sourceLead: "Entry rules move — confirm with",
            source: "the Spanish Ministry of Foreign Affairs",
            sourceURL: URL(string: "https://www.exteriores.gob.es")
        ),
        .init(
            bucket: .beforeYouLeave,
            title: "What May is actually like",
            body: "Warm without being punishing — mid-20s by day, cool enough at night that a light jacket earns its place. The sea is still bracing, the terraces are already full, and the crowds have not reached their July weight.",
            bullets: ["Pack layers for evenings", "Rain is brief when it comes"]
        ),
        .init(
            bucket: .money,
            title: "Cards everywhere, cash for the small stuff",
            body: "Card works nearly everywhere including buses and most bars. Keep twenty or thirty euros for the odd market stall and the bakery that has never taken a card and never will.",
            bullets: ["Two people, mid-range: €120–180 a day", "ATMs in bank branches, not the standalone ones on La Rambla"]
        ),
        .init(
            bucket: .gettingAround,
            title: "Getting in from El Prat",
            body: "The Aerobús runs to Plaça Catalunya every five minutes and takes about 35 minutes, which beats the metro for anyone with luggage. A taxi is roughly €35 and worth it late at night or with children.",
            bullets: ["Aerobús about €7", "Metro L9 Sud needs a separate airport ticket"],
            locations: [
                .init(linkSubstring: "El Prat", placeName: "Josep Tarradellas Barcelona–El Prat Airport")
            ]
        ),
        .init(
            bucket: .gettingAround,
            title: "The city is smaller than it looks",
            body: "Most of what you came for sits inside a walkable core, and the metro covers the rest in under twenty minutes. Buy a T-casual for ten journeys rather than paying single fares.",
            bullets: ["T-casual: 10 journeys, shareable"],
            volatility: .verify,
            sourceLead: "Fares change each January — check with",
            source: "TMB, the Barcelona transport operator",
            sourceURL: URL(string: "https://www.tmb.cat")
        ),
        .init(
            bucket: .onTheGround,
            title: "Nobody eats when you do",
            body: "Lunch runs from two, dinner rarely starts before nine, and a kitchen that opens at seven is cooking for tourists. Plan an afternoon coffee and pastry so the gap does not defeat you.",
            bullets: ["Menú del día at lunch is the best value meal of the day"]
        )
    ])
}
