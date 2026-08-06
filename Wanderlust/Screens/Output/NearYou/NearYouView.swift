//
//  NearYouView.swift
//  Wanderlust
//
//  The complete solo/group Near You flow: device-side grounding, adaptive
//  editorial picks, and a visually separate deterministic practical layer.
//

import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

struct NearYouWalkingFacts: Equatable {
    let distance: String
    let duration: String
    let isApproximate: Bool

    static func make(
        candidate: Trip.NearYouCandidate,
        precision: CoarseAccommodation.Precision
    ) -> Self {
        let distance: String
        if candidate.distanceMetres < 1_000 {
            distance = "\(candidate.distanceMetres) m"
        } else {
            distance = String(format: "%.1f km", Double(candidate.distanceMetres) / 1_000)
        }
        return Self(
            distance: precision == .neighbourhood ? "≈ \(distance)" : distance,
            duration: precision == .neighbourhood
                ? "≈ \(candidate.walkingMinutes) min walk"
                : "\(candidate.walkingMinutes) min walk",
            isApproximate: precision == .neighbourhood
        )
    }
}

struct NearYouView: View {
    let accommodation: CoarseAccommodation?
    let result: AsyncValue<Trip.NearYou>
    let addressResolution: AsyncValue<NearYouAddressResolution>
    let whereToStay: AsyncValue<[Trip.StayArea]>
    let destination: String
    let isGroup: Bool
    let setBy: String?
    let canReplace: Bool
    @Binding var favorites: Trip.Favorites
    let onSearchAddress: (String) -> Void
    let onChooseResolution: (NearYouResolutionChoice) -> Void
    let onChooseArea: (Trip.StayArea) -> Void
    let onRetryWhereToStay: (() -> Void)?
    let onRetryNearYou: () -> Void
    let onRegenerate: () -> Void
    let onChangeStay: () -> Void

    @State private var address = ""

    var body: some View {
        if let accommodation {
            groundedContent(accommodation: accommodation)
        } else {
            ungroundedContent
        }
    }

    private var ungroundedContent: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: .Spacing.small) {
                Text("What's around your stay?")
                    .font(DS.Typography.sectionHeader)
                    .foregroundStyle(.primary)

                Text(isGroup
                     ? "Apple Maps resolves the address or hotel on this device. The exact input is never sent or saved; only the coarse stay and grounded result are shared with the group."
                     : "Your address or hotel is resolved by Apple Maps on this device. The exact input is never sent or saved.")
                    .font(.kanit(14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    TextField("Address or hotel", text: $address)
                        .textContentType(.fullStreetAddress)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit(submitAddress)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )

                    Button(action: submitAddress) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appTint)
                    .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                resolutionFeedback
            }
            .padding(.horizontal, .Padding.sm3)
            .padding(.top, .Padding.md)
            .padding(.bottom, .Padding.sm3)

            Divider().padding(.horizontal, .Padding.sm3)

            WhereToStayView(
                areas: whereToStay,
                destination: destination,
                onRetry: onRetryWhereToStay,
                onChoose: onChooseArea
            )
        }
    }

    @ViewBuilder
    private var resolutionFeedback: some View {
        switch addressResolution {
        case .initial:
            EmptyView()
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Finding that stay in Apple Maps…")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }
        case .error:
            Label(
                "We couldn't pin that down. Add the city or hotel name and try again.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.kanit(13))
            .foregroundStyle(.secondary)
        case .loaded(.resolved):
            EmptyView()
        case .loaded(.ambiguous(let choices)):
            VStack(alignment: .leading, spacing: 8) {
                Text("Which one did you mean?")
                    .font(DS.Typography.eyebrow)
                    .foregroundStyle(Color.appTint)

                ForEach(choices) { choice in
                    Button {
                        onChooseResolution(choice)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(choice.title)
                                .font(.kanitMedium(15))
                                .foregroundStyle(.primary)
                            if let subtitle = choice.subtitle {
                                Text(subtitle)
                                    .font(.kanit(12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.appTint.opacity(0.06))
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func groundedContent(accommodation: CoarseAccommodation) -> some View {
        switch result {
        case .initial:
            VStack(spacing: .Spacing.small) {
                Image(systemName: "location.magnifyingglass")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(Color.appTint)
                Text("Ready to check around \(accommodation.label)")
                    .font(DS.Typography.sectionHeader)
                    .multilineTextAlignment(.center)
                Text("This saved stay has no Near You result yet. Nothing will be generated until you ask.")
                    .font(.kanit(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Find places", action: onRegenerate)
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false, internalPadding: 8))
                Button("Change stay", action: onChangeStay)
                    .font(.kanitMedium(14))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, .Padding.md)
            .padding(.top, .Padding.md3)
            Spacer()

        case .loading:
            VStack(spacing: .Spacing.small) {
                ProgressView()
                Text("Checking what is genuinely near \(accommodation.label)…")
                    .font(DS.Typography.tabLabel)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, .Padding.md3)
            Spacer()

        case .error:
            VStack(spacing: .Spacing.small) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.appTint)
                Text("Near You didn't come through")
                    .font(DS.Typography.sectionHeader)
                Text(isGroup
                     ? "The shared result was not changed. The rest of the group trip is unaffected."
                     : "Your stay stays on this device. The rest of the trip is unaffected.")
                    .font(.kanit(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try again", action: onRetryNearYou)
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false, internalPadding: 8))
                Button("Change stay", action: onChangeStay)
                    .font(.kanitMedium(14))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, .Padding.md)
            .padding(.top, .Padding.md3)
            Spacer()

        case .loaded(let output):
            NearYouResultsView(
                output: output,
                accommodation: accommodation,
                isGroup: isGroup,
                setBy: setBy,
                canReplace: canReplace,
                favorites: $favorites,
                onRegenerate: onRegenerate,
                onChangeStay: onChangeStay
            )
        }
    }

    private func submitAddress() {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        onSearchAddress(value)
    }
}

private struct NearYouResultsView: View {
    let output: Trip.NearYou
    let accommodation: CoarseAccommodation
    let isGroup: Bool
    let setBy: String?
    let canReplace: Bool
    @Binding var favorites: Trip.Favorites
    let onRegenerate: () -> Void
    let onChangeStay: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: .Padding.md) {
                header

                if let sparse = output.sparseMessage {
                    Label(sparse, systemImage: "leaf")
                        .font(.kanit(14))
                        .foregroundStyle(.secondary)
                        .padding(.Padding.sm3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall)
                                .fill(Color.appTint.opacity(0.06))
                        )
                }

                ForEach(output.sections) { section in
                    editorialSection(section)
                }

                if output.sections.isEmpty {
                    Text("There aren't enough grounded places here for an editorial list. The practical results below are everything MapKit could verify.")
                        .font(DS.Typography.generatedBody)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                practicalLayer

                if canReplace {
                    HStack(spacing: 12) {
                        Button(isGroup ? "Change shared stay" : "Change stay", action: onChangeStay)
                            .buttonStyle(SecondaryButtonStyle(fullWidth: true, internalPadding: 8))
                        Button(isGroup ? "Regenerate once" : "Regenerate", action: onRegenerate)
                            .buttonStyle(SecondaryButtonStyle(fullWidth: true, internalPadding: 8))
                    }
                    .padding(.top, .Padding.sm)
                } else if isGroup {
                    Label("The group's one regeneration has been used.", systemImage: "checkmark.seal")
                        .font(.kanit(14))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, .Padding.sm)
                }
            }
            .padding(.horizontal, .Padding.sm3)
            .padding(.vertical, .Padding.md)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Near \(accommodation.label)")
                .font(DS.Typography.sectionHeader)
            if accommodation.precision == .neighbourhood {
                Label(
                    "Neighbourhood centre — all distances and walking times are approximate.",
                    systemImage: "scope"
                )
                .font(.kanit(13))
                .foregroundStyle(Color.appTint)
            } else {
                Text("Walking facts come directly from Apple Maps.")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }
            if isGroup, let setBy {
                Text("Shared by \(setBy)")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func editorialSection(_ section: Trip.NearYouSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(DS.Typography.sectionHeader)
            ForEach(section.picks) { pick in
                NearYouPlaceCard(
                    candidate: pick.candidate,
                    explanation: pick.explanation,
                    precision: accommodation.precision,
                    isHeartable: true,
                    isFavorited: favorites.contains(pick.id),
                    onHeart: { favorites.toggle(pick.id) }
                )
            }
        }
    }

    private var practicalLayer: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Practical, no editorialising")
                    .font(DS.Typography.sectionHeader)
                Text("Nearest transport, grocery and pharmacy from Apple Maps only.")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }

            ForEach(output.practical) { item in
                NearYouPlaceCard(
                    candidate: item.candidate,
                    explanation: item.kind.title,
                    precision: accommodation.precision,
                    isHeartable: false,
                    isFavorited: false,
                    onHeart: nil
                )
            }

            ForEach(
                Trip.NearYouPracticalKind.allCases.filter {
                    output.unavailablePracticalKinds.contains($0)
                },
                id: \.self
            ) { kind in
                Text("No \(kind.title.lowercased()) result with a verified walking route.")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.Padding.sm3)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardLarge, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardLarge, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
    }
}

private struct NearYouPlaceCard: View {
    let candidate: Trip.NearYouCandidate
    let explanation: String
    let precision: CoarseAccommodation.Precision
    let isHeartable: Bool
    let isFavorited: Bool
    let onHeart: (() -> Void)?

    private var facts: NearYouWalkingFacts {
        .make(candidate: candidate, precision: precision)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Link(destination: candidate.mapURL) {
                    HStack(spacing: 5) {
                        Text(candidate.name)
                            .font(DS.Typography.generatedTitle)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "map")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.appTint)
                }

                Spacer(minLength: 8)

                if isHeartable, let onHeart {
                    Button(action: onHeart) {
                        HeartIcon(size: 18, isFavorited: isFavorited)
                    }
                    .accessibilityLabel(isFavorited ? "Remove from favourites" : "Add to favourites")
                }
            }

            Text(explanation)
                .font(DS.Typography.generatedBody)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Label(facts.distance, systemImage: "figure.walk")
                Text("·")
                Text(facts.duration)
            }
            .font(.kanitMedium(13))
            .foregroundStyle(.secondary)
            .accessibilityLabel(
                facts.isApproximate
                    ? "Approximate distance \(facts.distance), \(facts.duration)"
                    : "Distance \(facts.distance), \(facts.duration)"
            )
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
