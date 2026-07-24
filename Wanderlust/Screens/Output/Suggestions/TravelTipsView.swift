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
                        VStack(spacing: 22) {
                            ForEach(sections) { section in
                                SectionView(section: section, favorites: $favorites)
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
                cards: category.texts.map { TextCard(id: $0.id, text: $0.linkedText) }
            )
        }
        + suggestions.staticSuggestions.map { category in
            TipsSection(
                id: category.ID ?? Self.temporaryAssignTipSectionID(),
                title: category.title,
                cards: category.texts.map { TextCard(id: $0.id, text: $0.linkedText) }
            )
        }
    }
}

extension TravelTipsView {
    private struct SectionView: View {
        let section: TipsSection
        @Binding var favorites: Trip.Favorites

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // ---------- Header ----------
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(section.id.iconName)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .offset(y: 4)
                        .foregroundStyle(Color.appTint)

                    Text(section.title)
                        .font(.kanitMedium(18))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)

                // ---------- Carousel ----------
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(section.cards) { card in
                            SuggestionCard(card: card, favorites: $favorites)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private struct SuggestionCard: View {
        let card: TextCard
        @Binding var favorites: Trip.Favorites

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                Text(card.text)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(14)
                    .padding(.trailing, 6)
                    .frame(width: 270, height: 130, alignment: .topLeading)

                Button {
                    favorites.toggle(card.id)
                } label: {
                    HeartIcon(size: 18, isFavorited: favorites.contains(card.id))
                }
                .padding(10)
            }
            .frame(width: 270, height: 130)
            .background(
                RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
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
    TravelTipsView(suggestions: .mock, favorites: .constant(.init()))
}

extension AsyncValue where Value == Trip.Suggestions {
    static var mock: AsyncValue<Trip.Suggestions> { .loaded(Trip.Suggestions.mock) }
}
