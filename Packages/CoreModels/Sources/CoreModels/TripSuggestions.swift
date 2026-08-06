//
//  Suggestions.swift
//  CoreModels
//
//  Created by Rodrigo Mato on 6/7/25.
//

import Foundation

// MARK: - Trip.Suggestions
extension Trip {
    public struct Suggestions: Codable, Equatable, Sendable, Hashable {
        public let dynamicSuggestions: [Category]
        public let staticSuggestions: [Category]
        
        public init(dynamicSuggestions: [Category] = [], staticSuggestions: [Category] = []) {
            self.dynamicSuggestions = dynamicSuggestions
            self.staticSuggestions = staticSuggestions
        }
        
        public struct Category: Codable, Equatable, Sendable, Hashable {
            /// Stable local identity. Model/backend payloads may omit it; the
            /// first decode mints one and every local save/share preserves it.
            public let id: UUID
            public let ID: TipSectionID?
            public let title: String
            public let texts: [LocationLinkableText]
            /// The chip label that requested this category, for deep dives.
            ///
            /// The model is free to write a more destination-specific `title`,
            /// so title equality cannot reliably mark the original chip as
            /// spent after save/reopen. Ordinary suggestion categories leave
            /// this `nil`. Optional for backward-compatible v3 decoding.
            public let requestedInterest: String?

            public init(
                id: UUID = UUID(),
                ID: TipSectionID?,
                title: String,
                texts: [LocationLinkableText],
                requestedInterest: String? = nil
            ) {
                self.id = id
                self.ID = ID
                self.title = title
                self.texts = texts
                self.requestedInterest = requestedInterest
            }

            /// Custom decode so an unrecognized category ID degrades to `nil`
            /// instead of throwing and failing the whole `Suggestions` decode.
            /// This matters for shared trips: their suggestions round-trip
            /// through a server that doesn't validate this shape, so a future
            /// app version's new category must not make an older client's
            /// decode blow up entirely.
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
                title = try container.decode(String.self, forKey: .title)
                texts = try container.decode([LocationLinkableText].self, forKey: .texts)
                ID = try? container.decodeIfPresent(TipSectionID.self, forKey: .ID)
                requestedInterest = try? container.decodeIfPresent(
                    String.self, forKey: .requestedInterest
                )
            }

            enum CodingKeys: String, CodingKey {
                case id, ID, title, texts, requestedInterest
            }
        }
        
        public enum TipSectionID: String, CaseIterable, Codable, Sendable {
            case cafes
            case couples
            case month
            case avoid
            case vibe
            case rainy
            case new
            case group
            case solo
            case family
            case random

            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let rawValue = try container.decode(String.self).lowercased()
                guard let value = Self(rawValue: rawValue) else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Unknown suggestion category ID: \(rawValue)"
                    )
                }
                self = value
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(rawValue)
            }
            
            public var iconName: String {
                switch self {
                case .cafes: return "section-1"
                case .couples: return "section-2"
                case .month: return "section-3"
                case .avoid: return "section-4"
                case .vibe: return "section-5"
                case .rainy: return "section-6"
                case .new: return "section-7"
                case .group: return "section-8"
                case .solo: return "section-9"
                case .family: return "section-8"
                case .random: return "section-7" // note: use a different value from .family
                }
            }
        }
    }
}

public extension Trip.Suggestions {
    static let mock: Self = Trip.Suggestions(
        dynamicSuggestions: [
            Category(
                ID: .cafes,
                title: "Cafés & Restaurants with a view",
                texts: [
                    LocationLinkableText(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis.Lore Ipsum"),
                    LocationLinkableText(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis. Lore Ipsum Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis.Lore Ipsum."),
                    LocationLinkableText(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis.Lore Ipsum")
                ]
            )
        ],
        staticSuggestions: [
            Category(
                ID: .avoid,
                title: "Must‑See Attractions",
                texts: [
                    LocationLinkableText(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis.Lore Ipsum"),
                    LocationLinkableText(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis. Lore Ipsum Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis.Lore Ipsum."),
                    LocationLinkableText(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis.Lore Ipsum")
                ]
            ),
            Category(
                ID: .new,
                title: "June in Barcelona",
                texts: [
                    LocationLinkableText(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis.Lore Ipsum"),
                    LocationLinkableText(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis. Lore Ipsum Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis.Lore Ipsum."),
                    LocationLinkableText(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultricies mollis.Lore Ipsum")
                ]
            )
        ]
    )
}
