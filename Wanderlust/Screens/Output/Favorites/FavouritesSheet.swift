//
//  FavouritesSheet.swift
//  Wanderlust
//
//  Favourites, as a full-screen sheet rather than a tab.
//

import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

/// "Your Favourites in {destination}".
///
/// Favourites left the tab bar because it is not a fourth kind of content — it
/// is a view *of* the other three, and giving it a permanent third of the tab
/// bar cost the actual content a tab. As a sheet it stays one tap away from
/// anywhere, and the tab bar is free for Discover, Know Before You Go and Near
/// You.
///
/// It opens on the trip's own destination photo rather than on a navigation
/// bar. This is the list someone carries around the city and the one they show
/// other people, so it earns a cover; a plain inline title made the most
/// personal surface in the app look like a settings pane. The photo is the same
/// one the trip header uses — same cache key, so it is already resident and does
/// not flash — warmed toward the heart red so the two read as related surfaces
/// rather than as the same screen twice.
struct FavouritesSheet: View {
    let destination: String
    /// The trip's cover image, shared with `TopHeader`.
    let imageUrlState: AsyncValue<URL>
    let sections: [Trip.FavouriteSection]
    let privacyNote: String?
    /// Called once the traveller has confirmed. Confirmation is owned here, not
    /// by the screen underneath: an alert presented on the screen dismisses this
    /// sheet in order to show itself, so un-hearting one item would throw the
    /// traveller out of the list they were editing.
    let onRemoveFavorite: (UUID) -> Void
    let onClose: () -> Void

    @State private var pendingRemoval: UUID?

    private let heartRed = Color(hex: "#EE6262")
    private let heroHeight: CGFloat = 232

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    hero

                    if let privacyNote {
                        Text(privacyNote)
                            .font(.kanit(13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, .Padding.md)
                            .padding(.top, .Padding.sm3)
                    }

                    if sections.isEmpty {
                        emptyState
                    } else {
                        FavouritesListView(
                            sections: sections,
                            onRemoveFavorite: { pendingRemoval = $0 }
                        )
                    }
                }
            }

            closeButton
                .padding(.top, .Padding.sm3)
                .padding(.trailing, .Padding.sm3)
        }
        .gradientBackground()
        .ignoresSafeArea(edges: .top)
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

    // MARK: - Hero

    private var hero: some View {
        CacheDestinationImage(
            cacheKey: destination,
            imageUrlState: imageUrlState
        )
        .frame(height: heroHeight)
        // Legibility first, identity second: the dark ramp carries the text,
        // the red wash carries the fact that this is the favourites surface.
        .overlay {
            LinearGradient(
                colors: [.black.opacity(0.10), .black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay {
            LinearGradient(
                colors: [heartRed.opacity(0.46), heartRed.opacity(0.04)],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        }
        .overlay(alignment: .bottomLeading) { heroTitle }
        .frame(height: heroHeight)
        .clipped()
    }

    private var heroTitle: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Your Favourites in \(shortDestination)")
                .font(.kanitMedium(27))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 12, y: 2)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: sections.isEmpty ? "heart" : "heart.fill")
                    .font(.system(size: 12, weight: .bold))

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.95))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 1)
        }
        .padding(.horizontal, .Padding.md)
        .padding(.bottom, .Padding.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Text("Done")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                // A solid scrim rather than a material: the pill sits on an
                // arbitrary photo, and a translucent one goes unreadable the
                // moment the image behind it is pale.
                .background(Color.black.opacity(0.36), in: Capsule())
                .overlay(
                    Capsule().stroke(.white.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close favourites")
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: .Spacing.medium) {
            Image(systemName: "heart")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(heartRed.opacity(0.45))
                .padding(.top, .Padding.lg)

            Text("Nothing saved yet")
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(.primary)

            Text("Tap the heart on anything that sounds like you. This becomes the list you actually carry around \(shortDestination) — and the one you share.")
                .font(.kanit(15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, .Padding.md2)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, .Padding.lg3)
    }

    // MARK: - Copy

    /// "Barcelona, Spain" is the right label for a trip header and the wrong one
    /// for a possessive sentence, so the title takes the city alone.
    private var shortDestination: String {
        destination
            .split(separator: ",", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? destination
    }

    private var subtitle: String {
        let count = sections.reduce(0) { $0 + $1.items.count }
        guard count > 0 else { return "Nothing saved yet" }
        return "\(count) saved · ready for the trip"
    }
}

#Preview("With favourites") {
    FavouritesSheet(
        destination: "Barcelona, Spain",
        imageUrlState: .loaded(URL(
            string: "https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=1080&q=80")!
        ),
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
        privacyNote: nil,
        onRemoveFavorite: { _ in },
        onClose: {}
    )
}

#Preview("Empty") {
    FavouritesSheet(
        destination: "Barcelona, Spain",
        imageUrlState: .loaded(URL(
            string: "https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=1080&q=80")!
        ),
        sections: [],
        privacyNote: "These favourites are yours on this device. They are not shared with the group.",
        onRemoveFavorite: { _ in },
        onClose: {}
    )
}
