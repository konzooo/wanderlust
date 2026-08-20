//
//  ItineraryHeader.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 10/6/25.
//

import CoreArchitecture
import DesignSystem
import SwiftUI

// MARK: - Static hero header for non-scroll context.
struct TopHeader: View {
    /// Image URL state from the store
    let imageUrlState: AsyncValue<URL>
    /// Big title overlay.
    let title: String
    /// Short chips shown under the title.
    let chips: [String]
    /// State of the save button
    var saveState: Bool
    /// Save button callback
    let onSaveTapped: (() -> Void)?
    /// Whether to show the save/bookmark button. Group and shared trips hide
    /// it — they aren't personal saved trips.
    var showSaveButton: Bool
    /// Whether to show the share button. Hidden for received (shared-with-me)
    /// and group trips — they are view-only and not the viewer's to re-share.
    var showShareButton: Bool
    /// Shows a spinner in place of the share icon while publishing.
    var isSharing: Bool
    /// Share button callback
    let onShareTapped: (() -> Void)?
    /// How many things the traveller has hearted, shown on the favourites pill.
    var favouriteCount: Int
    /// Whether to show the favourites pill. This is the only entry point to the
    /// favourites list now that it isn't a tab, so it stays visible at zero —
    /// hiding it until the first heart would hide the feature from exactly the
    /// people who haven't found it.
    var showFavouritesButton: Bool
    /// Favourites pill callback
    let onFavouritesTapped: (() -> Void)?

    /// Maximum header height (in points, not pixels).
    private let maxHeight: CGFloat = 230

    // Internal
    var imageCache: any ImageCacheStrategy

    init(
        imageUrlState: AsyncValue<URL>,
        title: String,
        chips: [String],
        saveState: Bool,
        showSaveButton: Bool = true,
        showShareButton: Bool = false,
        isSharing: Bool = false,
        favouriteCount: Int = 0,
        showFavouritesButton: Bool = false,
        onShareTapped: (() -> Void)? = nil,
        onSaveTapped: (() -> Void)? = nil,
        onFavouritesTapped: (() -> Void)? = nil,
        imageCache: any ImageCacheStrategy = PersistentImageCacheStrategy.shared
    ) {
        self.imageUrlState = imageUrlState
        self.title = title
        self.chips = chips
        self.saveState = saveState
        self.showSaveButton = showSaveButton
        self.showShareButton = showShareButton
        self.isSharing = isSharing
        self.favouriteCount = favouriteCount
        self.showFavouritesButton = showFavouritesButton
        self.onShareTapped = onShareTapped
        self.onSaveTapped = onSaveTapped
        self.onFavouritesTapped = onFavouritesTapped
        self.imageCache = imageCache
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Show appropriate view based on image URL state
            CacheDestinationImage(
                cacheKey: title,
                imageUrlState: imageUrlState,
                imageCache: imageCache
            )
            .frame(height: maxHeight)
            // Bottom gradient for legibility.
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .trailing,
                    endPoint: .leading
                )
            }
            // Title + chips pinned to bottom-leading corner.
            .overlay(alignment: .bottomLeading) {
                titleAndChipsView
            }
        }
        .frame(height: maxHeight)
        .clipped()
    }
    
    var titleAndChipsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DS.Typography.displayMedium)
                .foregroundColor(.white)
                .shadow(radius: 4)
            
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { Chip(text: $0) }

                if showFavouritesButton {
                    favouritesPill
                }

                Spacer()

                HStack(spacing: 10) {
                    if showShareButton {
                        shareButton
                    }
                    if showSaveButton {
                        saveButton
                    }
                }
                .padding(.trailing, 14)
            }
        }
        .padding(.bottom, 24)
        .padding(.leading, 16)

    }
        
    /// Sits with the chips rather than with the share/save icons: it opens
    /// content, it doesn't act on the trip.
    var favouritesPill: some View {
        Button(action: { onFavouritesTapped?() }) {
            HStack(spacing: 5) {
                Image(systemName: favouriteCount > 0 ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(favouriteCount)")
                    .font(.kanitLight(16))
            }
            .foregroundStyle(favouriteCount > 0 ? Color.red : Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(.thinMaterial.opacity(0.5), in: Capsule())
        }
        .accessibilityLabel("Favourites, \(favouriteCount) saved")
    }

    var saveButton: some View {
        Button(action: {
            onSaveTapped?()
        }) {
            Image(systemName: saveState ? "bookmark.fill" : "bookmark")
                .resizable()
                .scaledToFit()
                .tint(.white)
                .frame(width: 20, height: 20)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: saveState)
        }
        .padding(6)
        .background(
            saveState
                ? AnyShapeStyle(Color.appTint)
                : AnyShapeStyle(Material.thinMaterial.opacity(0.5)),
            in: Circle()
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: saveState)
    }

    var shareButton: some View {
        Button(action: {
            onShareTapped?()
        }) {
            if isSharing {
                ProgressView()
                    .tint(.white)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "square.and.arrow.up")
                    .resizable()
                    .scaledToFit()
                    .tint(.white)
                    .frame(width: 20, height: 20)
            }
        }
        .disabled(isSharing)
        .padding(6)
        .background(Material.thinMaterial.opacity(0.5), in: Circle())
    }

}

#Preview("HeaderImage Preview") {
    VStack {
        TopHeader(
            imageUrlState: .loaded(URL(string: "https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=1080&q=80")!),
            title: "Barcelona, Spain",
            chips: ["May", "Couple"],
            saveState: true
        )
        
//        Color.red
    }
}

#Preview("Placeholder Gradient") {
    TopHeader(
        imageUrlState: .initial,
        title: "Barcelona, Spain",
        chips: ["May", "Couple"],
        saveState: false
    )
}
