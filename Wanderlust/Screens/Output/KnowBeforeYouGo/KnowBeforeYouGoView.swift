//
//  KnowBeforeYouGoView.swift
//  Wanderlust
//
//  The practical half of a destination, grouped into its four buckets.
//

import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

/// Know Before You Go.
///
/// Reads top to bottom as a briefing, not as a feed: bucket heading, then the
/// sections under it, each a card. There is no heart anywhere — this is
/// reference, and "how people pay in Barcelona" is not something anyone wants a
/// saved list of (see `Trip.favouriteCandidates`).
///
/// The only conditional chrome is the source line on a `verify` section. No
/// badges, no global disclaimer: a section either reads with full confidence or
/// names the authority to check with, and nothing in between.
struct KnowBeforeYouGoView: View {
    let value: AsyncValue<Trip.KnowBeforeYouGo>
    let destination: String
    /// This trip has no briefing and no way to ask for one — a trip saved,
    /// received or generated before Know Before You Go existed. Distinct from
    /// "still loading", which is what an untouched `.initial` otherwise looks
    /// like: without this the tab would spin forever on an old trip.
    let unavailable: Bool
    /// `nil` where there is nothing to re-request (read-only trips).
    let onRetry: (() -> Void)?

    var body: some View {
        if unavailable {
            unavailableState
        } else {
            briefing
        }
    }

    private var unavailableState: some View {
        VStack(spacing: .Spacing.medium) {
            Image(systemName: "lightbulb")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.appTint)
                .padding(.top, .Padding.lg)

            Text("No briefing for this trip")
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(.primary)

            Text("Know Before You Go is written when a trip is generated, so a trip made before it existed doesn't have one. A new trip to \(destination) will.")
                .font(.kanit(15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, .Padding.md2)
    }

    private var briefing: some View {
        ComponentStateView(
            value: value,
            subject: "your briefing",
            onRetry: onRetry
        ) { briefing in
            ScrollView(.vertical, showsIndicators: false) {
                if briefing.groups.isEmpty {
                    // Reached only when the model genuinely returned nothing —
                    // a still-running or failed call never gets this far.
                    Text("Nothing practical to flag for \(destination).")
                        .font(.kanit(15))
                        .foregroundStyle(.secondary)
                        .padding(.top, .Padding.md3)
                } else {
                    VStack(alignment: .leading, spacing: .Padding.md) {
                        ForEach(briefing.groups) { group in
                            BucketView(group: group)
                        }
                    }
                    .padding(.horizontal, .Padding.sm3)
                    .padding(.vertical, .Padding.md)
                }
            }
        }
    }
}

private struct BucketView: View {
    let group: Trip.KnowBeforeYouGo.BucketGroup

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: .Spacing.small) {
                Image(systemName: group.bucket.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appTint)

                Text(group.bucket.title)
                    .font(DS.Typography.sectionHeader)
                    .foregroundStyle(.primary)
            }

            ForEach(group.sections) { section in
                SectionCard(section: section)
            }
        }
    }
}

private struct SectionCard: View {
    let section: Trip.KnowBeforeYouGo.Section

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.small) {
            // Model-written, so it renders as generated prose rather than as
            // another piece of the app's Kanit furniture — a heading the model
            // chose is still model text.
            Text(section.title)
                .font(DS.Typography.generatedTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(section.linkableBody.linkedText)
                .font(DS.Typography.generatedBody)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !section.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(section.bullets.indices), id: \.self) { index in
                        HStack(alignment: .top, spacing: .Spacing.small) {
                            Circle()
                                .fill(Color.appTint.opacity(0.5))
                                .frame(width: 4, height: 4)
                                .padding(.top, 7)

                            Text(section.linkableBullet(at: index).linkedText)
                                .font(DS.Typography.generatedBody)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)
            }

            if section.volatility == .verify {
                SourceLine(section: section)
            }
        }
        .padding(.Padding.sm3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

/// The one tinted line a `verify` section carries.
///
/// The authority becomes a link when the model was sure of its address, and
/// stays plain text when it wasn't — which is common and fine. `source` is
/// guaranteed non-`nil` here: a `verify` section without one was downgraded to
/// `stable` at decode, so this line can never read "check with nobody".
private struct SourceLine: View {
    let section: Trip.KnowBeforeYouGo.Section

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appTint)

            Group {
                if let url = section.sourceURL {
                    Text("\(lead) ") + Text(.init("[\(source)](\(url.absoluteString))"))
                } else {
                    Text("\(lead) \(source)")
                }
            }
            .font(DS.Typography.generatedBody)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.Radius.compact, style: .continuous)
                .fill(Color.appTint.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.Radius.compact, style: .continuous)
                .stroke(Color.appTint.opacity(0.18), lineWidth: 1)
        )
        .padding(.top, 2)
    }

    /// A briefing that arrived without its own lead-in still needs one — the
    /// line exists to say *why* this is worth checking.
    private var lead: String {
        section.sourceLead ?? "This one moves — check with"
    }

    private var source: String {
        section.source ?? ""
    }
}

#Preview("Ready") {
    KnowBeforeYouGoView(
        value: .loaded(.mock),
        destination: "Barcelona, Spain",
        unavailable: false,
        onRetry: {}
    )
    .gradientBackground()
}

#Preview("Failed") {
    KnowBeforeYouGoView(
        value: .error(TripGenerationError.serviceBusy),
        destination: "Barcelona, Spain",
        unavailable: false,
        onRetry: {}
    )
    .gradientBackground()
}

#Preview("Never generated") {
    KnowBeforeYouGoView(
        value: .initial,
        destination: "Barcelona, Spain",
        unavailable: true,
        onRetry: nil
    )
    .gradientBackground()
}
