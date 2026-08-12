//
//  FavouritesListView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 15/7/25.
//

import CoreModels
import DesignSystem
import SwiftUI

/// The favourites list, grouped by where each item came from.
///
/// The heading carries the context, so the cards no longer repeat it under every
/// row. Order is derived from the trip (see `Trip.favouriteSections`) rather
/// than from the `Set` behind `Favorites`, which never had one.
///
/// **Scrolls in its container, not on its own.** It sits under the sheet's hero
/// photo, and a scroll view nested inside that one would fight it for the drag.
struct FavouritesListView: View {
    let sections: [Trip.FavouriteSection]
    var onRemoveFavorite: (UUID) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: .Padding.md) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: .Padding.sm2) {
                    // A quiet index label rather than a section header: the
                    // items are the content here, and a Kanit heading per group
                    // competed with them for attention.
                    Text(section.context)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .kerning(0.9)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.appTint)
                        .padding(.leading, 4)

                    ForEach(section.items) { item in
                        FavoriteCard(item: item, onRemoveFavorite: onRemoveFavorite)
                    }
                }
            }
        }
        .padding(.Padding.md)
    }
}

struct FavoriteCard: View {
    let item: Trip.FavouriteCandidate
    let onRemoveFavorite: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: .Padding.sm2) {
            // The whole `LocationLinkableText` reaches this view, locations
            // included, so a place that links in the itinerary still links here.
            Text(item.text.linkedText)
                .font(DS.Typography.generatedListItem)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onRemoveFavorite(item.id)
            } label: {
                HeartIcon(size: 22, isFavorited: true)
                    .frame(width: 44, height: 44) // Minimum tap target size
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            .accessibilityLabel("Remove from favourites")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    ScrollView { FavouritesListView(
        sections: [
            Trip.FavouriteSection(
                context: "Morning",
                items: [
                    .init(
                        id: UUID(),
                        text: LocationLinkableText(text: "Grab a coffee at Surf House Barcelona."),
                        context: "Morning"
                    )
                ]
            ),
            Trip.FavouriteSection(
                context: "Worth it or skip",
                items: [
                    .init(
                        id: Trip.WorthItItem.mockSet[0].id,
                        text: Trip.WorthItItem.mockSet[0].favouriteText,
                        context: "Worth it or skip"
                    )
                ]
            )
        ],
        onRemoveFavorite: { _ in }
    ) }
    .gradientBackground()
}
