//
//  TripKnowBeforeYouGo.swift
//  CoreModels
//
//  Know Before You Go: the practical half of a destination.
//

import Foundation

extension Trip {
    /// Destination-wide practical preparation — entry, arrival, on-the-ground
    /// setup, money, transport, culture, health and safety. Deliberately **not**
    /// another feed of places:
    /// it may name an airport or a metro line where the fact is about that
    /// place, but "what to skip" and "where to eat" belong to the suggestions
    /// feed and stay there.
    ///
    /// Stable topic IDs make the category contract testable without forcing the
    /// model into one visual shape inside each collapsible row.
    public struct KnowBeforeYouGo: Codable, Equatable, Hashable, Sendable {
        public let sections: [Section]

        public init(sections: [Section] = []) {
            self.sections = sections
        }

        /// The sections grouped under their bucket, in the canonical bucket
        /// order, skipping buckets this destination produced nothing for.
        ///
        /// Order comes from ``Bucket/allCases`` rather than from the model's
        /// output order: the buckets are the app's structure, and a run
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

            /// All category headings are app-owned except the one deliberate
            /// destination-specific slot. Its backend-provided title lets the
            /// same position read "Island hopping" or "Altitude" without
            /// turning every heading into unstable generated chrome.
            public var title: String {
                guard bucket == .destinationEssential else { return bucket.title }
                return sections.compactMap(\.bucketTitle).first(where: { !$0.isEmpty })
                    ?? bucket.title
            }
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

        /// The buckets, in the order they are read.
        public enum Bucket: String, Codable, CaseIterable, Sendable {
            case beforeYouLeave
            case onTheGround
            case money
            case gettingAround
            case culture
            case destinationEssential
            case healthAndSafety
            case otherTips
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
                case .onTheGround: "On the ground"
                case .money: "Money"
                case .gettingAround: "Getting around"
                case .culture: "Culture"
                case .destinationEssential: "Destination essential"
                case .healthAndSafety: "Health and safety"
                case .otherTips: "Other tips"
                case .other: "Also worth knowing"
                }
            }

            /// SF Symbols, per the design system — the `section-N` PNGs belong
            /// to the suggestions feed's fixed categories.
            public var iconName: String {
                switch self {
                case .beforeYouLeave: "suitcase"
                case .onTheGround: "network"
                case .money: "creditcard"
                case .gettingAround: "tram"
                case .culture: "person.2"
                case .destinationEssential: "sparkles"
                case .healthAndSafety: "cross.case"
                case .otherTips: "lightbulb"
                case .other: "lightbulb"
                }
            }
        }

        /// Stable semantic identity for a subcategory. Titles remain natural
        /// model prose; this value is what validation, evaluation and future UI
        /// behavior can safely depend on.
        public enum Topic: String, Codable, Sendable {
            case entryRequirements
            case arrivalTransport
            case monthPacking
            case simInternet
            case apps
            case electricity
            case onGroundWildcard
            case currencyExchange
            case costSnapshot
            case tipping
            case paymentMethods
            case localTransport
            case culture
            case language
            case destinationEssential
            case healthSafety
            case otherTips
            /// Older saved briefings have no topic; newer backends may add one
            /// this build has not learned yet. Both remain readable.
            case other

            public init(from decoder: Decoder) throws {
                let raw = try decoder.singleValueContainer().decode(String.self)
                self = Topic(rawValue: raw) ?? .other
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
            public let topic: Topic
            /// Generated only for ``Topic/destinationEssential``. Nil on every
            /// fixed bucket and on briefings saved before this field existed.
            public let bucketTitle: String?
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
                topic: Topic = .other,
                bucketTitle: String? = nil,
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
                self.topic = topic
                self.bucketTitle = Self.nonEmpty(bucketTitle)
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
                case id, bucket, topic, bucketTitle, title, body, bullets, volatility
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
                topic = try container.decodeIfPresent(Topic.self, forKey: .topic) ?? .other
                bucketTitle = Self.nonEmpty(
                    try container.decodeIfPresent(String.self, forKey: .bucketTitle)
                )
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
                try container.encode(topic, forKey: .topic)
                try container.encodeIfPresent(bucketTitle, forKey: .bucketTitle)
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
            topic: .entryRequirements,
            title: "Entry and documents",
            body: "German citizens can enter Spain with a valid passport or national ID card for this trip.",
            volatility: .verify,
            sourceLead: "Entry rules — check current with",
            source: "the Spanish Ministry of Foreign Affairs",
            sourceURL: URL(string: "https://www.exteriores.gob.es")
        ),
        .init(
            bucket: .beforeYouLeave,
            topic: .arrivalTransport,
            title: "Getting in from El Prat",
            body: "Aerobús is the easiest first transfer with luggage: it runs to Plaça Catalunya in about 35 minutes. Metro and train cost less; a taxi makes sense late at night or for a family.",
            bullets: ["Aerobús: direct and frequent", "Taxi: roughly €35 (about US$39)"],
            locations: [
                .init(linkSubstring: "El Prat", placeName: "Josep Tarradellas Barcelona–El Prat Airport")
            ]
        ),
        .init(
            bucket: .beforeYouLeave,
            topic: .monthPacking,
            title: "What May feels like",
            body: "Days are usually warm and evenings cooler, with occasional showers and growing crowds.",
            bullets: ["Pack breathable layers", "Bring a light rain shell", "Add comfortable walking shoes"]
        ),
        .init(
            bucket: .onTheGround,
            topic: .simInternet,
            title: "Your phone will just work",
            body: "EU roaming usually covers Spain. Other visitors can buy an eSIM before arrival or a prepaid SIM from a staffed carrier shop; city coverage is strong."
        ),
        .init(
            bucket: .onTheGround,
            topic: .apps,
            title: "Two useful downloads",
            body: "TMB App helps with live public-transport planning; Free Now or Cabify is useful when you need a licensed ride."
        ),
        .init(
            bucket: .onTheGround,
            topic: .electricity,
            title: "Plugs and power",
            body: "Spain uses type C and F plugs at 230V; North American and British devices need an adapter."
        ),
        .init(
            bucket: .onTheGround,
            topic: .onGroundWildcard,
            title: "Sundays run differently",
            body: "Many independent shops close on Sunday, while restaurants and central convenience stores keep more flexible hours. Do essential shopping on Saturday."
        ),
        .init(
            bucket: .money,
            topic: .currencyExchange,
            title: "Euros at a glance",
            body: "Spain uses the euro. €1 is approximately US$1.10 and, naturally, €1.",
            volatility: .verify,
            sourceLead: "Approximate rate — check current with",
            source: "the European Central Bank",
            sourceURL: URL(string: "https://www.ecb.europa.eu")
        ),
        .init(
            bucket: .money,
            topic: .costSnapshot,
            title: "What things cost",
            body: "",
            bullets: ["Coffee: €1.50–3 (about US$2–3)", "Casual meal: €12–20 (about US$13–22)", "Museum ticket: €10–18 (about US$11–20)", "Private room: €70–120 (about US$77–132) basic; €180–300 (about US$198–330) upper end"]
        ),
        .init(
            bucket: .money,
            topic: .tipping,
            title: "Tipping is modest",
            body: "Round up or leave 5–10% for notably good table service; tipping is not obligatory."
        ),
        .init(
            bucket: .money,
            topic: .paymentMethods,
            title: "Cards first, some cash",
            body: "Contactless cards are the default. Keep €20–30 (about US$22–33) for markets and very small purchases, and decline dynamic currency conversion at terminals and ATMs."
        ),
        .init(
            bucket: .gettingAround,
            topic: .localTransport,
            title: "Walk the compact center",
            body: "Best for the old city and Eixample blocks. Walking is free, but distances and summer heat add up; comfortable shoes matter."
        ),
        .init(
            bucket: .gettingAround,
            topic: .localTransport,
            title: "Metro for cross-city hops",
            body: "Fastest for longer urban journeys. Tap or validate the correct ticket before travel, and keep bags closed on busy platforms."
        ),
        .init(
            bucket: .gettingAround,
            topic: .localTransport,
            title: "Use buses for the gaps",
            body: "Buses reach hills and neighborhoods the metro misses. Board at marked stops, validate on entry, and allow extra time in traffic."
        ),
        .init(
            bucket: .culture,
            topic: .culture,
            title: "Meals happen late",
            body: "Lunch commonly starts around 14:00 and dinner around 21:00. An afternoon snack makes the local rhythm much easier."
        ),
        .init(
            bucket: .culture,
            topic: .culture,
            title: "Catalan identity matters",
            body: "Barcelona is Catalonia's capital. Treat Catalan as a living local language and identity, not a decorative version of Spanish."
        ),
        .init(
            bucket: .culture,
            topic: .culture,
            title: "Keep residential nights quiet",
            body: "Dense neighborhoods place homes directly above bars. Lower your voice in stairwells and streets late at night."
        ),
        .init(
            bucket: .culture,
            topic: .language,
            title: "Four Catalan phrases",
            body: "",
            bullets: ["Hello — Hola (OH-lah)", "Thank you — Gràcies (GRAH-see-uhs)", "Goodbye — Adéu (uh-DEH-oo)", "Very good! — Molt bé! (molt BEH)"]
        ),
        .init(
            bucket: .destinationEssential,
            topic: .destinationEssential,
            bucketTitle: "Tourist-pressure etiquette",
            title: "Travel gently in lived-in areas",
            body: "",
            bullets: ["Keep doorways and narrow lanes clear", "Choose licensed accommodation", "Treat markets as working food spaces, not photo sets"]
        ),
        .init(
            bucket: .healthAndSafety,
            topic: .healthSafety,
            title: "Pickpockets are the main risk",
            body: "Use a closed cross-body bag on crowded transport and terraces; never hang a phone or bag over a chair back."
        ),
        .init(
            bucket: .otherTips,
            topic: .otherTips,
            title: "Two small wins",
            body: "",
            bullets: ["Reserve major timed-entry sights before the weekend", "Carry a refillable bottle; public fountains are common"]
        )
    ])
}
