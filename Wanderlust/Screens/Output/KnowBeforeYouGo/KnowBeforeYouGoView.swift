//
//  KnowBeforeYouGoView.swift
//  Wanderlust
//
//  The practical half of a destination, grouped into stable buckets.
//

import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

/// Know Before You Go.
///
/// Reads as a table of contents, not as a feed. Twelve sections of real prose
/// laid out flat is a scroll nobody finishes; collapsed under their categories
/// the whole briefing fits on one or two screens and the traveller opens the
/// three things they actually care about. There is no heart anywhere — this is
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

    /// Which sections are open, by `Section.id`.
    ///
    /// Held here rather than inside each row so it survives the buckets being
    /// rebuilt, and so the "first one starts open" rule can be applied once
    /// across the whole briefing rather than once per bucket.
    @State private var expanded: Set<UUID> = []
    @State private var hasSeededFirstSection = false

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
                            BucketView(group: group, expanded: $expanded)
                        }
                    }
                    .padding(.horizontal, .Padding.sm3)
                    .padding(.vertical, .Padding.md)
                    .onAppear { seedFirstSection(of: briefing) }
                }
            }
        }
    }

    /// Opens the very first section once, so the tab never lands as a wall of
    /// closed rows with nothing to read. Guarded by its own flag rather than by
    /// `expanded.isEmpty`, or closing that section by hand would re-open it on
    /// the next redraw.
    private func seedFirstSection(of briefing: Trip.KnowBeforeYouGo) {
        guard !hasSeededFirstSection else { return }
        hasSeededFirstSection = true
        if let first = briefing.groups.first?.sections.first {
            expanded.insert(first.id)
        }
    }
}

private struct BucketView: View {
    let group: Trip.KnowBeforeYouGo.BucketGroup
    @Binding var expanded: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.small) {
            header

            // One card per bucket, rows divided by hairlines rather than by
            // gaps: the bucket is the object, the sections are its contents.
            VStack(spacing: 0) {
                ForEach(Array(group.sections.enumerated()), id: \.element.id) { index, section in
                    if index > 0 {
                        Divider()
                            .padding(.leading, .Padding.sm3)
                    }

                    SectionRow(
                        section: section,
                        isExpanded: expanded.contains(section.id),
                        onToggle: { toggle(section.id) }
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
    }

    private var header: some View {
        HStack(spacing: .Spacing.small) {
            Image(systemName: group.bucket.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appTint)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: CGFloat.Radius.compact, style: .continuous)
                        .fill(Color.appTint.opacity(0.14))
                )

            Text(group.title)
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(.primary)

            Spacer(minLength: .Spacing.small)

            // The count is what makes a closed bucket legible — it says how
            // much is behind the rows without opening any of them.
            Text("\(group.sections.count)")
                .font(.kanitMedium(14))
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(group.sections.count) sections")
        }
        .padding(.horizontal, 2)
    }

    private func toggle(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.22)) {
            if expanded.contains(id) {
                expanded.remove(id)
            } else {
                expanded.insert(id)
            }
        }
    }
}

/// One collapsible section: always the title, and the prose only when asked for.
private struct SectionRow: View {
    let section: Trip.KnowBeforeYouGo.Section
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: .Spacing.small) {
                    // Model-written, so it renders as generated prose rather
                    // than as another piece of the app's Kanit furniture — a
                    // heading the model chose is still model text.
                    Text(section.title)
                        .font(DS.Typography.generatedTitle)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .padding(.top, 4)
                }
                .padding(.horizontal, .Padding.sm3)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(isExpanded ? "Collapses this section" : "Expands this section")

            if isExpanded {
                expandedBody(for: section)
            }
        }
    }

    private func expandedBody(for section: Trip.KnowBeforeYouGo.Section) -> some View {
        VStack(alignment: .leading, spacing: .Spacing.small) {
            if !section.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(section.linkableBody.linkedText)
                    .font(DS.Typography.generatedBody)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .Padding.sm3)
        .padding(.bottom, .Padding.sm3)
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
