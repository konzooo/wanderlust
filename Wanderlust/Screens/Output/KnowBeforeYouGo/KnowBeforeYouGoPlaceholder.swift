//
//  KnowBeforeYouGoPlaceholder.swift
//  Wanderlust
//
//  The Know Before You Go tab, before it has anything to say.
//

import DesignSystem
import SwiftUI

/// Placeholder for the Know Before You Go tab.
///
/// The tab is part of the shell and ships visible, so this has one job: be
/// honest. It describes what the tab will hold and says plainly that it isn't
/// generated yet — rather than rendering an empty feed, which reads as a bug, or
/// promising a date nobody has committed to.
struct KnowBeforeYouGoPlaceholder: View {
    let destination: String

    var body: some View {
        ScrollView {
            VStack(spacing: .Spacing.medium) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.appTint)
                    .padding(.top, .Padding.lg)

                Text("Know Before You Go")
                    .font(DS.Typography.sectionHeader)
                    .foregroundStyle(.primary)

                Text("The practical half of a trip to \(destination) — entry rules, how people pay, getting in from the airport, when everyone actually eats.")
                    .font(.kanit(15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Not generated yet")
                    .font(DS.Typography.eyebrow)
                    .foregroundStyle(Color.appTint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.appTint.opacity(0.07)))
                    .overlay(Capsule().stroke(Color.appTint.opacity(0.18), lineWidth: 1))
                    .padding(.top, .Padding.sm)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, .Padding.md2)
            .padding(.bottom, .Padding.lg)
        }
    }
}

#Preview {
    KnowBeforeYouGoPlaceholder(destination: "Barcelona, Spain")
        .gradientBackground()
}
