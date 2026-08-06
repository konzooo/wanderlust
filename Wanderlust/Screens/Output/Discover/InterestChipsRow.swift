//
//  InterestChipsRow.swift
//  Wanderlust
//
//  The interest chips under the suggestions feed (D8).
//

import DesignSystem
import SwiftUI

/// Three model-picked interests plus three the app always offers.
///
/// Tapping one asks for a deep dive on it, capped at three per trip (D9) and
/// enforced server-side. The row also makes the one in-flight request visible;
/// a failure returns the chip to its tappable state and leaves the cap alone.
///
/// Visually the same capsule as ``DiscoverPillBar`` at one step down in weight:
/// these are requests, not navigation, so none of them is ever "selected".
struct InterestChipsRow: View {
    let chips: [String]
    /// Already-used interests, drawn spent rather than removed — a chip that
    /// silently vanishes reads as a bug, and the traveller has a right to see
    /// what they spent one of their three on.
    var used: Set<String> = []
    /// The one request currently in flight. All chips pause until it settles.
    var loading: String? = nil
    /// Latest safe failure or permission/cap guidance from the store.
    var errorMessage: String? = nil
    /// `nil` once the trip's three deep dives are gone or this viewer cannot add one.
    let onTap: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: .Padding.sm2) {
            Text("More on…")
                .font(DS.Typography.eyebrow)
                .foregroundStyle(Color.appTint)
                .padding(.horizontal, .Padding.sm3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .Padding.sm2) {
                    ForEach(chips, id: \.self) { chip in
                        chipView(chip)
                    }
                }
                .padding(.horizontal, .Padding.sm3)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, .Padding.sm3)
            }
        }
        .padding(.vertical, .Padding.sm2)
    }

    @ViewBuilder
    private func chipView(_ chip: String) -> some View {
        let isUsed = used.contains(chip)
        let isLoading = loading == chip
        Button {
            onTap?(chip)
        } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: isUsed ? "checkmark" : "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(chip)
                    .font(DS.Typography.tabLabel)
            }
            .foregroundStyle(isUsed ? Color.secondary : Color.appTint)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(
                    isUsed ? AnyShapeStyle(Color(.systemGray5).opacity(0.5))
                           : AnyShapeStyle(Color.appTint.opacity(0.07))
                )
            )
            .overlay(
                Capsule().stroke(
                    isUsed ? Color.clear : Color.appTint.opacity(0.18),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(isUsed || loading != nil || onTap == nil)
    }
}

#Preview {
    VStack {
        InterestChipsRow(
            chips: [
                "Natural wine bars", "Rooftop sunsets", "Modernista rooftops",
                "Running routes", "Remote-work cafés", "Climbing gyms"
            ],
            used: ["Rooftop sunsets"],
            onTap: { _ in }
        )
        Spacer()
    }
    .gradientBackground()
}
