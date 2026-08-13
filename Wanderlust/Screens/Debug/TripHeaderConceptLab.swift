#if DEBUG

import DesignSystem
import SwiftUI

enum TripHeaderConceptStyle: String {
    case nativeLockup
    case leadingLockup
    case centeredSignature

    var rationale: String {
        switch self {
        case .nativeLockup:
            "Maximum consistency: the identity sits at exactly the same height as My Trips, Profile and Settings."
        case .leadingLockup:
            "The strongest balance: native navigation stays quiet while the flow keeps a compact, branded introduction."
        case .centeredSignature:
            "The closest evolution of today’s design, made smaller, tighter and deliberately positioned beneath the navigation bar."
        }
    }
}

private enum TripHeaderPreviewKind: String, CaseIterable {
    case nextTrip = "Next Trip"
    case groupTrip = "Group Trip"

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .nextTrip: "Your unique path starts here"
        case .groupTrip: "Different personalities — One Trip!"
        }
    }

    var symbol: String {
        switch self {
        case .nextTrip: "airplane.departure"
        case .groupTrip: "person.3.fill"
        }
    }
}

struct TripHeaderConceptLab: View {
    let style: TripHeaderConceptStyle

    @State private var kind: TripHeaderPreviewKind = .nextTrip

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 0) {
                contentHeader

                ScrollView {
                    VStack(spacing: 14) {
                        mockForm
                        rationaleCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, style == .nativeLockup ? 14 : 0)
                    .padding(.bottom, 110)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if style == .nativeLockup {
                ToolbarItem(placement: .principal) {
                    NativeTripHeader(kind: kind)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.appTint)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .accessibilityLabel("Profile preview")
            }
        }
        .safeAreaInset(edge: .bottom) {
            previewSwitcher
        }
    }

    @ViewBuilder
    private var contentHeader: some View {
        switch style {
        case .nativeLockup:
            EmptyView()
        case .leadingLockup:
            LeadingTripHeader(kind: kind)
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 14)
        case .centeredSignature:
            CenteredTripHeader(kind: kind)
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 14)
        }
    }

    private var previewSwitcher: some View {
        VStack(spacing: 7) {
            Text("PREVIEW HEADER")
                .font(.kanit(10).weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            Picker("Preview header", selection: $kind) {
                ForEach(TripHeaderPreviewKind.allCases, id: \.self) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var mockForm: some View {
        DS.GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                mockSectionLabel("Where to?", symbol: "mappin.circle.fill")

                HStack {
                    Image(systemName: "mappin")
                        .foregroundStyle(Color.appTint.opacity(0.72))
                    Text("Lisbon")
                        .font(.kanit(16).weight(.medium))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 14))

                Divider().overlay(.white.opacity(0.55))

                mockSectionLabel(
                    kind == .nextTrip ? "Travel companions?" : "Trip duration?",
                    symbol: kind == .nextTrip ? "person.2.fill" : "clock.fill"
                )

                HStack(spacing: 8) {
                    ForEach(kind == .nextTrip ? ["Solo", "Couple", "Group"] : ["3 days", "5 days", "7 days"], id: \.self) { label in
                        Text(label)
                            .font(.kanit(12).weight(.medium))
                            .foregroundStyle(label == (kind == .nextTrip ? "Solo" : "5 days") ? Color.appTint : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(
                                label == (kind == .nextTrip ? "Solo" : "5 days")
                                    ? Color.appTint.opacity(0.10)
                                    : Color.white.opacity(0.50),
                                in: Capsule()
                            )
                    }
                }

                Divider().overlay(.white.opacity(0.55))

                mockSectionLabel("Start of your trip?", symbol: "calendar")
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.appTint.opacity(0.18))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.appTint)
                            .frame(width: 112, height: 8)
                    }
            }
        }
    }

    private var rationaleCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color.appTint)
            Text(style.rationale)
                .font(.kanit(13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
    }

    private func mockSectionLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(DS.Typography.fieldLabel)
            .foregroundStyle(.primary)
            .labelStyle(TripHeaderLabLabelStyle())
    }
}

private struct NativeTripHeader: View {
    let kind: TripHeaderPreviewKind

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appTint)
                Text(kind.title)
                    .font(.kanitMedium(17))
            }

            Text(kind.subtitle)
                .font(.kanit(10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LeadingTripHeader: View {
    let kind: TripHeaderPreviewKind

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.appTint)
                .frame(width: 40, height: 40)
                .background(Color.appTint.opacity(0.11), in: Circle())
                .overlay { Circle().stroke(.white.opacity(0.72), lineWidth: 1) }

            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title)
                    .font(.kanitMedium(23))
                Text(kind.subtitle)
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct CenteredTripHeader: View {
    let kind: TripHeaderPreviewKind

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 7) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appTint)
                Text(kind.title)
                    .font(.kanitMedium(22))
            }

            Text(kind.subtitle)
                .font(.kanit(13))
                .foregroundStyle(.secondary)

            Capsule()
                .fill(Color.appTint.opacity(0.42))
                .frame(width: 28, height: 2)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct TripHeaderLabLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appTint)
            configuration.title
        }
    }
}

#endif
