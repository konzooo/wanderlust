//
//  TipsSection.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 15/6/25.
//

import CoreModels
import DesignSystem
import SwiftUI
import CoreArchitecture

public struct TravelTipsView: View {
    let suggestions: AsyncValue<Trip.Suggestions>
    @Binding var favorites: Trip.Favorites

    public init(suggestions: AsyncValue<Trip.Suggestions>, favorites: Binding<Trip.Favorites>) {
        self.suggestions = suggestions
        self._favorites = favorites
    }

    // MARK: - Temporary Helper (Remove when backend sends category IDs)
    private static var temporaryIDCounter = 0
    private static func temporaryAssignTipSectionID() -> Trip.Suggestions.TipSectionID {
        let availableIDs = Trip.Suggestions.TipSectionID.allCases
        let assignedID = availableIDs[temporaryIDCounter % availableIDs.count]
        temporaryIDCounter += 1
        return assignedID
    }
    // MARK: - Temporary Helper (Remove when backend sends category IDs)

    public var body: some View {
        Group {
            switch suggestions {
            case .initial, .loading:
                ProgressView()
                    .padding(.top, 30)
                    .transition(.opacity)
                Spacer()
            case .error(let error):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                    Text("Failed to load travel tips.")
                        .font(.headline)
                    if let error = error as? LocalizedError {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 30)
            case .loaded(let tripSuggestions):
                let sections = Self.mapSections(from: tripSuggestions)
                ScrollView(.vertical, showsIndicators: false) {
                    if sections.isEmpty {
                        Text("No travel tips available.")
                            .padding(.top, 30)
                    } else {
                        VStack {
                            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                                SectionView(section: section, sectionIndex: index, favorites: $favorites)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 16)
                            }
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
        }
    }

    private static func mapSections(from suggestions: Trip.Suggestions) -> [TipsSection] {
        suggestions.dynamicSuggestions.map { category in
            TipsSection(
                id: category.ID ?? Self.temporaryAssignTipSectionID(),
                title: category.title,
                cards: category.texts.map { locationText in
                    TextCard(
                        id: locationText.id,
                        text: locationText.linkedText
                    )
                }
            )
        }
        + suggestions.staticSuggestions.map { category in
            TipsSection(
                id: category.ID ?? Self.temporaryAssignTipSectionID(),
                title: category.title,
                cards: category.texts.map { locationText in
                    TextCard(
                        id: locationText.id,
                        text: locationText.linkedText
                    )
                }
            )
        }
    }
}

extension TravelTipsView {
    private struct SectionView: View {
        let section: TipsSection
        let sectionIndex: Int
        @Binding var favorites: Trip.Favorites
        
        init(section: TipsSection, sectionIndex: Int, favorites: Binding<Trip.Favorites>) {
            self.section = section
            self.sectionIndex = sectionIndex
            self._favorites = favorites
        }
        
        var body: some View {
            let sectionColor = sectionIndex.isMultiple(of: 2) ? Color.suggestionTintA : Color.suggestionTintB
            VStack(alignment: .leading, spacing: 10) {
                // ---------- Header ----------
                HStack(alignment: .firstTextBaseline, spacing:10) {
                    Image(section.id.iconName)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .offset(y: 4)
                        .foregroundColor(Color.black.opacity(0.8))
                    
                    Text(section.title)
                        .font(.kanitMedium(18))
                        .foregroundStyle(Color.black.opacity(0.7))
                }
                .foregroundColor(.primary)
                
                // ---------- Carousel ----------
                CardsCarousel(items: section.cards,
                              cardSize: CGSize(width: 300, height: 130),
                              cardSpacing: 24) { card in
                    ZStack {
                        // Alternating background colors using #586FF2
                        sectionColor
                        
                        Text(card.text)
                            .padding()
                            .padding(.trailing, 25) // Reduced from 40 to allow text closer to heart
                            .font(.kanit(16))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Heart in BOTTOM right corner
                        heartView(card: card)
                    }
                }
            }
        }
        
        private func heartView(card: TextCard) -> some View {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    Button(action: {
                        favorites.toggle(card.id)
                    }) {
                        HeartIcon(
                            size: 16.8,
                            isFavorited: favorites.contains(card.id)
                        )
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

/// A TextCard that preserves the original LocationLinkableText ID for favorites tracking
struct TextCardWithOriginalID: Identifiable, Hashable {
    public let id = UUID() // For ForEach identification
    public let text: AttributedString
    public let originalID: UUID // The original LocationLinkableText ID for favorites
    
    public init(text: AttributedString, originalID: UUID) {
        self.text = text
        self.originalID = originalID
    }
}

/// A section in the tips screen: header (icon + title) + horizontally-scrolling
/// carousel of `TextCard`s.
public struct TipsSection: Identifiable, Hashable {
    public let id: Trip.Suggestions.TipSectionID
    let title: String
    let cards: [TextCard]
}

// Sample sections to preview / demo
extension TipsSection {
    @MainActor public static let sample: [TipsSection] = [
        .init(id: .cafes,
              title: "Cafés & Restaurants with a view",
              cards: TextCard.sample),
        .init(id: .couples,
              title: "What couples love in Barcelona",
              cards: TextCard.sample),
        .init(id: .month,
              title: "June in Barcelona",
              cards: [
                  TextCard(text: "Catch the Sant Joan Festival — beach bonfires, fireworks, and all-night energy in late June.")
              ]),
        .init(id: .avoid,
              title: "What to avoid",
              cards: TextCard.sample)
    ]
}

#Preview {
    TravelTipsView(suggestions: .mock,favorites: .constant(.init()))
}

extension AsyncValue where Value == Trip.Suggestions {
    static var mock: AsyncValue<Trip.Suggestions> { .loaded(Trip.Suggestions.mock) }
}
