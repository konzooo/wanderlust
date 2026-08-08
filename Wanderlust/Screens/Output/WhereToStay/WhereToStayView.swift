//
//  WhereToStayView.swift
//  Wanderlust
//
//  "Don't have a place booked yet?" — the neighbourhood guide (D10).
//

import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

/// The where-to-stay guide, presented from Near You's empty state.
///
/// Its home is the Near You tab's un-grounded state (§7): a traveller who has
/// not booked anywhere yet cannot have an address, so Near You has nothing to
/// ground against and offers this to read instead.
///
/// **It is reading material, not a way into Near You.** The "I'm staying here"
/// shortcut this used to carry is deliberately gone: it grounded Near You on a
/// neighbourhood centroid, and a centroid cannot honestly support "four minutes
/// from your door". Near You now asks for a real address, and this guide answers
/// a different question — which area to book in the first place.
///
/// **No hearts.** §9 files where-to-stay under reference rather than under
/// things a traveller wants a list of, so these cards are deliberately not
/// heartable and have no arm in `Trip.favouriteCandidates`.
struct WhereToStaySheet: View {
    let areas: AsyncValue<[Trip.StayArea]>
    let destination: String
    /// `nil` in read-only modes, where there is nothing to re-request.
    let onRetry: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            WhereToStayView(areas: areas, destination: destination, onRetry: onRetry)
                .gradientBackground()
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Where to stay")
                            .font(DS.Typography.sheetTitle)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done", action: onClose)
                            .font(DS.Typography.tabLabel)
                    }
                }
        }
    }
}

struct WhereToStayView: View {
    let areas: AsyncValue<[Trip.StayArea]>
    let destination: String
    /// `nil` in read-only modes, where there is nothing to re-request.
    let onRetry: (() -> Void)?

    var body: some View {
        ComponentStateView(
            value: areas,
            subject: "the neighbourhood guide",
            onRetry: onRetry
        ) { areas in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: .Padding.sm3) {
                    header

                    ForEach(areas) { area in
                        StayAreaCard(area: area)
                    }
                }
                .padding(.horizontal, .Padding.sm3)
                .padding(.vertical, .Padding.md)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Where to sleep in \(destination)")
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("There is no best one — there is the one that matches what you came for. Best fit for you first.")
                .font(.kanit(14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StayAreaCard: View {
    let area: Trip.StayArea

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.medium) {
            Text(area.linkableTitle.linkedText)
                .font(DS.Typography.generatedTitle)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Trip.StayArea.Field.allCases, id: \.self) { field in
                VStack(alignment: .leading, spacing: 4) {
                    Text(field.label)
                        .font(DS.Typography.eyebrow)
                        .foregroundStyle(Color.appTint)

                    Text(area.linkable(field).linkedText)
                        .font(DS.Typography.generatedBody)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview("Sheet") {
    WhereToStaySheet(
        areas: .loaded(Trip.StayArea.mockSet),
        destination: "Barcelona",
        onRetry: nil,
        onClose: {}
    )
}

#Preview("Content") {
    WhereToStayView(
        areas: .loaded(Trip.StayArea.mockSet),
        destination: "Barcelona",
        onRetry: nil
    )
    .gradientBackground()
}
