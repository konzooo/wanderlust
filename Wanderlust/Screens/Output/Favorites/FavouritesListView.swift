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
            VStack(spacing: 20) {
                ForEach(favorites, id: \.id) { favoriteItem in
                    FavoriteCard(
                        favoriteItem: favoriteItem,
                        isFavorited: favoritesBinding.contains(favoriteItem.id),
                        onRemoveFavorite: onRemoveFavorite
                    )
                }
                
                Spacer()
            }
            .padding(20)
        }
        .background(Color(red: 1.0, green: 0.97, blue: 0.97))//Color(red: 255/255, green: 250/255, blue: 240/255)) // very soft beige

    }
}

struct FavoriteCard: View {
    let favoriteItem: TripOutputStore.FavoriteWithContext
    let isFavorited: Bool
    let onRemoveFavorite: (UUID) -> Void

    var body: some View {
        ZStack {
            // Alternating background colors using #586FF2
            Color(red: 228/255, green: 227/255, blue: 254/255) // light purple-ish
            
            VStack(alignment: .leading, spacing: 4) {
                Text(favoriteItem.text.linkedText)
                    .font(.kanit(16))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Context information in grey italic text - following existing UI patterns
                Text(favoriteItem.context)
                    .font(.kanitItalic(14))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .padding(.trailing, 25) // Reduced from 40 to allow text closer to heart
            
            // Heart in BOTTOM right corner
            heartView()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.compact)) // 🔐 Needed to clip ZStack background
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.Radius.field)
                .stroke(Color.clear, lineWidth: 0) // Optional: Add border if needed
        )
    }
    
    private func heartView() -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Button(action: {
                    onRemoveFavorite(favoriteItem.id)
                }) {
                    HeartIcon(
                        size: 24, // Increased from 16.8 to 24 for better visibility
                        isFavorited: isFavorited
                    )
                    .frame(width: 44, height: 44) // Minimum tap target size
                }
                .buttonStyle(PlainButtonStyle()) // Ensure no default button styling interferes
                .padding(.trailing, 12)
                .padding(.bottom, 12)
                .background(Color.clear) // Ensure the button area is clear
                .contentShape(Rectangle()) // Make the entire button area tappable
            }
        }
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
