//
//  Suggestions.swift
//  CoreModels
//
//  Created by Rodrigo Mato on 6/7/25.
//

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
            public let ID: TipSectionID?
            public let title: String
            public let texts: [LocationLinkableText]
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
