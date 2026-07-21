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
        /// Set of `UUID`s the user liked
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
        
        public func contains(_ id: UUID) -> Bool {
            liked.contains(id)
        }
    }
    
    /// Flatten everything into `[UUID : LocationLinkableText]`
    var allFavouriteCandidates: [UUID : String] {
        var result: [UUID:String] = [:]
        
        // Itinerary
        for segment in itinerary.segments {
            for bucket in [segment.description.morning,
                           segment.description.afternoon,
                           segment.description.evening] {
                bucket?.forEach { result[$0.id] = $0.text }
            }
            if let tip = segment.secretTip { result[tip.id] = tip.text }
        }

        // Suggestions
        if let suggestions {
            for cat in suggestions.dynamicSuggestions + suggestions.staticSuggestions {
                cat.texts.forEach { result[$0.id] = $0.text }
            }
        }

        return result
    }

    /// Flatten everything into `[UUID : (text: String, context: String)]` with contextual information
    public var allFavouriteCandidatesWithContext: [UUID : (text: String, context: String)] {
        var result: [UUID: (text: String, context: String)] = [:]
        
        // Itinerary
        for segment in itinerary.segments {
            if let morning = segment.description.morning {
                morning.forEach { result[$0.id] = ($0.text, "Morning") }
            }
            if let afternoon = segment.description.afternoon {
                afternoon.forEach { result[$0.id] = ($0.text, "Afternoon") }
            }
            if let evening = segment.description.evening {
                evening.forEach { result[$0.id] = ($0.text, "Evening") }
            }
            if let tip = segment.secretTip { 
                result[tip.id] = (tip.text, "Secret Tip") 
            }
        }

        // Suggestions
        if let suggestions {
            for cat in suggestions.dynamicSuggestions + suggestions.staticSuggestions {
                cat.texts.forEach { result[$0.id] = ($0.text, cat.title) }
            }
        }

        return result
    }
    
    /// Texts the user starred, in the order they were added
    func favouriteTexts(orderedBy favourites: Favorites) -> [String] {
        favourites.liked.compactMap { allFavouriteCandidates[$0] }
    }
    
    func favouritesDictionary(orderedBy favourites: Favorites) -> [UUID: String] {
        var result: [UUID: String] = [:]
        for id in favourites.liked {
            if let text = allFavouriteCandidates[id] {
                result[id] = text
            }
        }
        return result
    }

}
