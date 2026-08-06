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

/// The where-to-stay guide.
///
/// Its home is the Near You tab's un-grounded state (§7): a traveller who has
/// not booked anywhere yet cannot have an address, so Near You has nothing to
/// ground against and offers this instead. Choosing "I'm staying here" resolves
/// the area through MapKit and starts the neighbourhood-level Near You path.
///
/// **No hearts.** §9 files where-to-stay under reference rather than under
/// things a traveller wants a list of, so these cards are deliberately not
/// heartable and have no arm in `Trip.favouriteCandidates`.
struct WhereToStayView: View {
    let areas: AsyncValue<[Trip.StayArea]>
    let destination: String
    /// `nil` in read-only modes, where there is nothing to re-request.
    let onRetry: (() -> Void)?
    /// Picking an area is what hands Near You a coarse search centre (§7).
    var onChoose: ((Trip.StayArea) -> Void)?

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
                        StayAreaCard(area: area, onChoose: onChoose)
                    }
                }
                .padding(.horizontal, .Padding.sm3)
                .padding(.vertical, .Padding.md)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Don't have a place booked yet?")
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(.primary)

            Text("Where to sleep in \(destination), best fit for you first.")
                .font(.kanit(14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StayAreaCard: View {
    let area: Trip.StayArea
    let onChoose: ((Trip.StayArea) -> Void)?

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

            if let onChoose {
                Divider().opacity(0.4)

                Button {
                    onChoose(area)
                } label: {
                    Label("I'm staying here", systemImage: "mappin.and.ellipse")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true, internalPadding: 8))
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

#Preview {
    WhereToStayView(
        areas: .loaded(Trip.StayArea.mockSet),
        destination: "Barcelona",
        onRetry: nil
    )
    .gradientBackground()
}
