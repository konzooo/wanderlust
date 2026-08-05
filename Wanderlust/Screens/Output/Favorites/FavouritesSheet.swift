//
//  FavouritesSheet.swift
//  Wanderlust
//
//  Favourites, as a full-screen sheet rather than a tab.
//

import CoreModels
import DesignSystem
import SwiftUI

/// "Your Favourites in {destination}".
///
/// Favourites left the tab bar because it is not a fourth kind of content — it
/// is a view *of* the other three, and giving it a permanent third of the tab
/// bar cost the actual content a tab. As a sheet it stays one tap away from
/// anywhere, and the tab bar is free for Discover, Near You and Know Before You Go.
struct FavouritesSheet: View {
    let destination: String
    let sections: [Trip.FavouriteSection]
    /// Called once the traveller has confirmed. Confirmation is owned here, not
    /// by the screen underneath: an alert presented on the screen dismisses this
    /// sheet in order to show itself, so un-hearting one item would throw the
    /// traveller out of the list they were editing.
    let onRemoveFavorite: (UUID) -> Void
    let onClose: () -> Void

    @State private var pendingRemoval: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty {
                    emptyState
                } else {
                    FavouritesListView(
                        sections: sections,
                        onRemoveFavorite: { pendingRemoval = $0 }
                    )
                }
            }
            .gradientBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Your Favourites in \(destination)")
                        .font(DS.Typography.sheetTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                        .font(DS.Typography.tabLabel)
                }
            }
            .alert(
                "Remove from favourites?",
                isPresented: Binding(
                    get: { pendingRemoval != nil },
                    set: { if !$0 { pendingRemoval = nil } }
                )
            ) {
                Button("Remove", role: .destructive) {
                    if let id = pendingRemoval { onRemoveFavorite(id) }
                    pendingRemoval = nil
                }
                Button("Cancel", role: .cancel) { pendingRemoval = nil }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var emptyState: some View {
        VStack(spacing: .Spacing.small) {
            Spacer()

            Image(systemName: "heart")
                .font(.system(size: 56))
                .foregroundStyle(Color(.systemGray3))

            Text("No favourites yet")
                .font(DS.Typography.displayLight)
                .foregroundStyle(.primary)

            Text("Tap the heart on anything you like and it lands here.")
                .font(.kanit(16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .Padding.md)
                .padding(.bottom, .Padding.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("With favourites") {
    FavouritesSheet(
        destination: "Barcelona, Spain",
        sections: [
            Trip.FavouriteSection(
                context: "Afternoon",
                items: [
                    .init(
                        id: UUID(),
                        text: LocationLinkableText(text: "Visit the Picasso Museum."),
                        context: "Afternoon"
                    )
                ]
            )
        ],
        onRemoveFavorite: { _ in },
        onClose: {}
    )
}

#Preview("Empty") {
    FavouritesSheet(
        destination: "Barcelona, Spain",
        sections: [],
        onRemoveFavorite: { _ in },
        onClose: {}
    )
}
