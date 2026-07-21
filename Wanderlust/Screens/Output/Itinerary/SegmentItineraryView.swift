//
//  PagedItineraryView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 3/11/25.
//

import CoreModels
import Foundation
import SwiftUI

struct SegmentItineraryView: View {
    let segment: Trip.Itinerary.Segment
    let topContentOffset: CGFloat
    @Binding var favorites: Trip.Favorites

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: topContentOffset)
            Text(segment.title)
                .font(.kanitMedium(19))
                .padding(.leading, .Padding.md)
                .padding(.trailing, .Padding.sm3)
                .padding(.bottom, .Padding.sm3)

            if let morning = segment.description.morning {
                ItinerarySegmentView(title: "Morning:", segments: morning, favorites: $favorites)
                    .padding(.leading, .Padding.md)
                    .padding(.trailing, .Padding.sm3)
                    .padding(.bottom, .Padding.sm2)
            }

            if let afternoon = segment.description.afternoon {
                ItinerarySegmentView(title: "Afternoon:", segments: afternoon, favorites: $favorites)
                    .padding(.leading, .Padding.md)
                    .padding(.trailing, .Padding.sm3)
                    .padding(.bottom, .Padding.sm2)
            }

            if let evening = segment.description.evening {
                ItinerarySegmentView(title: "Evening:", segments: evening, favorites: $favorites)
                    .padding(.leading, .Padding.md)
                    .padding(.trailing, .Padding.sm3)
                    .padding(.bottom, .Padding.lg)
            }

            if let secretTip = segment.secretTip {
                SecretTipCard(secretTip: secretTip, favorites: $favorites)
                    .padding(.horizontal, .Padding.md2)
            }

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Segment list
struct ItinerarySegmentView: View {
    let title: String
    let daySegments: [LocationLinkableText]
    @Binding var favorites: Trip.Favorites

    init(title: String, segments: [LocationLinkableText], favorites: Binding<Trip.Favorites>) {
        self.title = title
        self.daySegments = segments
        self._favorites = favorites
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.kanit(18))

            ForEach(daySegments, id: \.text) { segment in
                ZStack(alignment: .topLeading) {
                    Text("• \(segment.linkedText)")
                        .font(.kanit(16))
                        .padding(.leading, .Spacing.medium)
                        .padding(.trailing, 30) // Reduced from 60 to allow text closer to heart
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            favorites.toggle(segment.id)
                        }) {
                            HeartIcon(isFavorited: favorites.contains(segment.id))
                        }
                        .padding(.trailing, -8) // Move 20px more to the right so it's better aligned to the outside (was 12)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Secret tip card
struct SecretTipCard: View {
    let secretTip: Trip.Itinerary.SecretTip
    @Binding var favorites: Trip.Favorites

    init(secretTip: Trip.Itinerary.SecretTip, favorites: Binding<Trip.Favorites>) {
        self.secretTip = secretTip
        self._favorites = favorites
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("☝🏻")
                .font(.system(size: 28))
                .padding(.leading, .Spacing.medium)
                .padding(.top, .Padding.md2)

            VStack(alignment: .leading, spacing: 0) {
                Text("Secret Tip")
                    .font(.kanitMediumItalic(18))

                Text(secretTip.linkedText)
                    .font(.kanit(16))
            }
            .padding(.trailing, .Spacing.medium)
            .padding(.vertical, .Spacing.medium)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.infoCardBkg)
                .shadow(color: .black.opacity(0.15), radius: 4, x: -5, y: -3)
        )
    }
}

struct TextWithLink: View {
    var body: some View {
        // Compose the sentence with a tappable link using AttributedString
        Text(buildAttributedString())
            .font(.body)
    }

    private func buildAttributedString() -> AttributedString {
        var string = AttributedString("End your night with a quiet drink at Dr. Stravinsky, a hidden cocktail bar in El Born.")

        if let range = string.range(of: "Dr. Stravinsky") {
            string[range].link = URL(string: "https://www.google.com/search?q=Dr.+Stravinsky+Barcelona")
            string[range].foregroundColor = .blue
            string[range].underlineStyle = .single
        }

        return string
    }
}

#Preview {
    SegmentItineraryView(
        segment: Trip.Itinerary.Segment.mock,
        topContentOffset: 0,
        favorites: .constant(.init())
    )
}
