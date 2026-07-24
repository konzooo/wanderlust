//
//  PagedItineraryView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 3/11/25.
//

import CoreModels
import DesignSystem
import Foundation
import SwiftUI

struct SegmentItineraryView: View {
    let segment: Trip.Itinerary.Segment
    let topContentOffset: CGFloat
    @Binding var favorites: Trip.Favorites

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: topContentOffset)

            Text(segment.title.withoutLeadingEmoji)
                .font(.kanitMedium(19))
                .padding(.leading, .Padding.md)
                .padding(.trailing, .Padding.sm3)
                .padding(.bottom, .Padding.sm3)

            if let morning = segment.description.morning {
                TimeBlock(title: "Morning", icon: "sunrise.fill", items: morning, favorites: $favorites)
                    .padding(.leading, .Padding.md)
                    .padding(.trailing, .Padding.sm3)
                    .padding(.bottom, .Padding.sm2)
            }

            if let afternoon = segment.description.afternoon {
                TimeBlock(title: "Afternoon", icon: "sun.max.fill", items: afternoon, favorites: $favorites)
                    .padding(.leading, .Padding.md)
                    .padding(.trailing, .Padding.sm3)
                    .padding(.bottom, .Padding.sm2)
            }

            if let evening = segment.description.evening {
                TimeBlock(title: "Evening", icon: "moon.stars.fill", items: evening, favorites: $favorites)
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

// MARK: - Time-of-day block (Morning / Afternoon / Evening)
struct TimeBlock: View {
    let title: String
    let icon: String
    let items: [LocationLinkableText]
    @Binding var favorites: Trip.Favorites

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appTint)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }

            ForEach(items, id: \.id) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.appTint.opacity(0.5))
                        .frame(width: 5, height: 5)
                        .padding(.top, 8)

                    Text(item.linkedText)
                        .font(.system(size: 15.5, design: .rounded))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    Button {
                        favorites.toggle(item.id)
                    } label: {
                        HeartIcon(isFavorited: favorites.contains(item.id))
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.top, .Spacing.small)
    }
}

// MARK: - Secret tip card
struct SecretTipCard: View {
    let secretTip: Trip.Itinerary.SecretTip
    @Binding var favorites: Trip.Favorites

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.appTint.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appTint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Secret tip")
                    .font(.kanitMediumItalic(15))
                    .foregroundStyle(Color.appTint)
                Text(secretTip.linkedText)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .fill(Color.appTint.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .stroke(Color.appTint.opacity(0.18), lineWidth: 1)
        )
    }
}

private extension String {
    /// Drops any leading emoji / symbol characters (and following whitespace)
    /// so an LLM-supplied "🏙️ Day 1: …" renders as "Day 1: …".
    var withoutLeadingEmoji: String {
        var result = self
        while let first = result.first, !(first.isLetter || first.isNumber) {
            result.removeFirst()
        }
        return result
    }
}

#Preview {
    SegmentItineraryView(
        segment: Trip.Itinerary.Segment.mock,
        topContentOffset: 0,
        favorites: .constant(.init())
    )
}
