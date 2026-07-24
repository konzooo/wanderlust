//
//  FestivalCard.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 15/7/25.
//

import CoreModels
import DesignSystem
import SwiftUI

struct FavouritesListView: View {
    // Updated to use contextual favorites with removal functionality
    var favorites: [TripOutputStore.FavoriteWithContext]
    @Binding var favoritesBinding: Trip.Favorites
    var onRemoveFavorite: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(favorites, id: \.id) { favoriteItem in
                    FavoriteCard(
                        favoriteItem: favoriteItem,
                        isFavorited: favoritesBinding.contains(favoriteItem.id),
                        onRemoveFavorite: onRemoveFavorite
                    )
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct FavoriteCard: View {
    let favoriteItem: TripOutputStore.FavoriteWithContext
    let isFavorited: Bool
    let onRemoveFavorite: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(favoriteItem.text.linkedText)
                    .font(.system(size: 15.5, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(favoriteItem.context)
                    .font(.kanitItalic(14))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 8)

            Button {
                onRemoveFavorite(favoriteItem.id)
            } label: {
                HeartIcon(size: 22, isFavorited: isFavorited)
                    .frame(width: 44, height: 44) // Minimum tap target size
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
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
    FavouritesListView(
        favorites: [
            TripOutputStore.FavoriteWithContext(
                id: UUID(),
                text: LocationLinkableText(text: "Catch the Sant Joan Festival — beach bonfires, fireworks, and all-night energy in late June."),
                context: "Evening"
            ),
            TripOutputStore.FavoriteWithContext(
                id: UUID(),
                text: LocationLinkableText(text: "Visit the Picasso Museum."),
                context: "Afternoon"
            ),
            TripOutputStore.FavoriteWithContext(
                id: UUID(),
                text: LocationLinkableText(text: "Grab a coffee at Surf House Barcelona."),
                context: "Morning"
            ),
            TripOutputStore.FavoriteWithContext(
                id: UUID(),
                text: LocationLinkableText(text: "Try the hot chocolate with churros at La Nena."),
                context: "Secret Tip"
            )
        ],
        favoritesBinding: .constant(.init()),
        onRemoveFavorite: { _ in }
    )
}
