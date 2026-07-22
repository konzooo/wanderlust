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
    
    /// Maximum header height (in points, not pixels).
    private let maxHeight: CGFloat = 230
    
    // Internal
    var imageCache: any ImageCacheStrategy

    init(
        imageUrlState: AsyncValue<URL>,
        title: String,
        chips: [String],
        saveState: Bool,
        onSaveTapped: (() -> Void)? = nil,
        imageCache: any ImageCacheStrategy = InMemoryImageCacheStrategy.shared
    ) {
        self.imageUrlState = imageUrlState
        self.title = title
        self.chips = chips
        self.saveState = saveState
        self.onSaveTapped = onSaveTapped
        self.imageCache = imageCache
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Show appropriate view based on image URL state
            CacheDestinationImage(
                cacheKey: title,
                imageUrlState: imageUrlState
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
                
                Spacer()
                
                saveButton
                    .padding(.trailing, 14)
            }
        }
        .padding(.bottom, 24)
        .padding(.leading, 16)

    }
        
    var saveButton: some View {
        Button(action: {
            onSaveTapped?()
        }) {
            Image(systemName: "bookmark")
                .resizable()
                .scaledToFit()
                .tint(saveState ? .white : Color.white)
                .frame(width: 20, height: 20)
        }
        .padding(6)
        .background(
            saveState ? AnyShapeStyle(Color.green) : AnyShapeStyle(Material.thinMaterial.opacity(0.5)),
            in: Circle()
        )
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
