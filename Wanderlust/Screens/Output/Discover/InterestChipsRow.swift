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
/// enforced server-side. That tap is S8's work, so this row is gated behind
/// ``OutputFeatureFlags/interestChipsEnabled`` — a visible chip that does
/// nothing is worse than no chip, and the honest way to build content ahead of
/// its behaviour is to keep it out of a shipping build rather than to ship it
/// inert.
///
/// Visually the same capsule as ``DiscoverPillBar`` at one step down in weight:
/// these are requests, not navigation, so none of them is ever "selected".
struct InterestChipsRow: View {
    let chips: [String]
    /// Already-used interests, drawn spent rather than removed — a chip that
    /// silently vanishes reads as a bug, and the traveller has a right to see
    /// what they spent one of their three on.
    var used: Set<String> = []
    /// `nil` once the trip's three deep dives are gone, or in read-only modes.
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
        }
        .padding(.vertical, .Padding.sm2)
    }

    @ViewBuilder
    private func chipView(_ chip: String) -> some View {
        let isUsed = used.contains(chip)
        Button {
            onTap?(chip)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isUsed ? "checkmark" : "sparkles")
                    .font(.system(size: 12, weight: .semibold))
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
        .disabled(isUsed || onTap == nil)
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
