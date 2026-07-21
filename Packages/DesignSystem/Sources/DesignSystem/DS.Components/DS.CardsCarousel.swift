//
//  CarouselCard.swift
//  DesignSystem
//
//  Created by Rodrigo Mato on 15/6/25.
//

import SwiftUI

/// A simple text-only card model used by the preview and, optionally, in apps
/// that don’t need a richer domain object.
/// Conforms to `Identifiable` (for `ForEach`) and `Hashable` (for diffing /
/// ScrollViewReader etc.).
public struct TextCard: Identifiable, Hashable {
    // Unique identifier generated once at creation time.
    public let id: UUID
    /// The body text shown inside the rounded rectangle.
    public let text: AttributedString
    /// The original LocationLinkableText ID for favorites tracking (if any)

    /// Designated initialiser.
    /// - Parameters:
    ///   - text: The text to display.
    ///   - originalID: The original ID for favorites tracking (optional).
    public init(id: UUID = UUID(), text: AttributedString) {
        self.text = text
        self.id = id
    }

    // Sample data for Xcode previews / playgrounds.
    @MainActor public static let sample: [TextCard] = [
        TextCard(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec feugiat ultrices mollis."),
        TextCard(text: "Second card — Vitae ridiculus mus parturient montes, nascetur ridiculus mus."),
        TextCard(text: "Third card — Nunc viverra, elit at cursus vehicula, libero tortor viverra tortor.")
    ]
}

// MARK: - Generic carousel component -----------------------------------------

/// A **horizontal, scroll-able carousel** of cards with rounded corners.
/// Internally uses `ScrollView(.horizontal)` + `LazyHGrid` so only the cards
/// on-screen are rendered.
///
/// The carousel is generic over:
///  * `Item`  – your data model (must be `Identifiable & Hashable`)
///  * `CardContent`  – the SwiftUI view you supply for each card
public struct CardsCarousel<Item: Identifiable & Hashable,
                            CardContent: View>: View {
    private let items: [Item]
    private let cardContent: (Item) -> CardContent   // View-builder closure
    private let cardSize: CGSize                     // Fixed size for each card
    private let cardSpacing: CGFloat

    /// Creates a new carousel.
    ///
    /// - Parameters:
    ///   - items:       Data source.  Order defines the visual order.
    ///   - cardSize:    Size of every card.  Defaults to 300 × 160 pt.
    ///   - cardContent: View-builder that turns an `Item` into a card view.
    public init(
        items: [Item],
        cardSize: CGSize = .init(width: 300, height: 160),
        cardSpacing: CGFloat = 24,
        @ViewBuilder cardContent: @escaping (Item) -> CardContent
    ) {
        self.items        = items
        self.cardSize     = cardSize
        self.cardSpacing  = cardSpacing
        self.cardContent  = cardContent
    }

    /// `LazyHGrid` needs an array of `GridItem`s to define its rows.
    /// We want **one** row whose height equals the card height.
    private var row: [GridItem] { [GridItem(.fixed(cardSize.height))] }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: row, spacing: cardSpacing) {
                ForEach(items) { item in
                    cardContent(item)
                        .frame(width: cardSize.width, height: cardSize.height)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.indigo.opacity(0.25))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2) ,radius: 8, x: 0, y: 6)
                        .scrollTargetLayout()
                }
            }
            .frame(height: cardSize.height)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

// MARK: - Live preview --------------------------------------------------------

#Preview {
    CardsCarousel(items: TextCard.sample) { card in
        ZStack(alignment: .topLeading) {
            // Background tint
            Color.indigo.opacity(0.25)

            // The actual text
            Text(card.text)
                .padding(20)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    .padding()                              // show outer margin in preview
    .background(Color(.systemBackground))   // neutral backdrop
    .previewLayout(.sizeThatFits)           // compact canvas export
}
