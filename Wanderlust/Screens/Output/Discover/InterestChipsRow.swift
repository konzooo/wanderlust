//
//  InterestChipsRow.swift
//  Wanderlust
//
//  "Anything specific?" — the deep-dive invitation (D8, D9).
//

import DesignSystem
import SwiftUI

/// The part the questionnaire could not ask about.
///
/// Seven swipe questions can tell you someone prefers street food to fine
/// dining. They can never tell you the person **climbs**, or runs, or collects
/// records. That is the bit that makes a trip theirs, and it is invisible to the
/// rest of the system — so this section asks for it directly.
///
/// **The chips are teaching material, not recommendations.** Three are picked by
/// the model for this destination and three are always the same (`Running
/// routes`, `Remote-work cafés`, `Climbing gyms`), deliberately spread across
/// unrelated domains. Their job is to be *read*, so the traveller thinks "oh,
/// that kind of thing — mine is X" and reaches for the field. That is also why
/// they wrap into view all at once instead of scrolling sideways: a chip nobody
/// scrolls to teaches nobody, and `Climbing gyms` is last.
///
/// Tapping one, or naming your own, asks for a deep dive — capped at three per
/// trip (D9) and enforced server-side. A failure returns the chip and leaves the
/// cap alone.
struct InterestChipsRow: View {
    let chips: [String]
    /// Already-used interests, drawn spent rather than removed — a chip that
    /// silently vanishes reads as a bug, and the traveller has a right to see
    /// what they spent one of their three on.
    var used: Set<String> = []
    /// The one request currently in flight. All chips pause until it settles.
    var loading: String? = nil
    /// Latest failure, or cap/permission guidance from the store.
    ///
    /// Nothing is said about the cap until it is actually reached: the section
    /// is an invitation, and a budget printed on an invitation changes what it
    /// is. At the cap it must be said, or the chips and the field simply go
    /// inert with no explanation.
    var guidance: String? = nil
    /// Once all three successful dives are used, the invitation collapses to a
    /// small, explicit completion state instead of leaving faded controls on
    /// screen.
    var capReached = false
    /// `nil` once the trip's three deep dives are gone or this viewer cannot add one.
    let onTap: ((String) -> Void)?

    @State private var customInterest = ""
    @FocusState private var fieldIsFocused: Bool

    private var isDisabled: Bool { onTap == nil || loading != nil }

    private var trimmedCustom: String {
        customInterest.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .Padding.sm2) {
            title

            if capReached {
                capReachedMessage
            } else {
                Text("Whether a unique travel interest or simply something that’s missing. Name it and you’ll get suggestions from your local guide.")
                    .font(DS.Typography.generatedBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)

                ChipFlowLayout(spacing: .Padding.sm2) {
                    ForEach(chips, id: \.self) { chip in
                        chipView(chip)
                    }
                }
                // A chip that cannot be tapped must not look tappable. This is
                // reserved for temporary loading and permission states; the
                // spent-cap state has its own compact treatment above.
                .opacity(onTap == nil ? 0.5 : 1)

                askField
                    .padding(.top, 2)

                if let guidance {
                    Text(guidance)
                        .font(.kanit(13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.Padding.sm3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .fill(Color.appTint.opacity(0.06))
        )
        // Dashed, so the block reads as an invitation to fill in rather than as
        // another card of content the model already wrote.
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .stroke(
                    Color.appTint.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                )
        )
        .padding(.horizontal, .Padding.sm3)
        .padding(.vertical, .Padding.sm2)
    }

    private var title: some View {
        HStack(spacing: .Padding.sm2) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appTint)
                .frame(width: 30, height: 30)
                .background(Color.appTint.opacity(0.12), in: Circle())

            Text("Anything specific?")
                .font(.kanitMedium(21))
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
    }

    private var capReachedMessage: some View {
        HStack(spacing: .Padding.sm2) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.appTint)

            Text(guidance ?? "You used up all 3 free deep dives.")
                .font(.kanit(15))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.appTint.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var askField: some View {
        HStack(spacing: .Padding.sm2) {
            TextField("Name your thing — anything at all", text: $customInterest)
                .font(.system(size: 14, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($fieldIsFocused)
                .onSubmit(submitCustom)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            Button("Find it", action: submitCustom)
                .font(DS.Typography.tabLabel)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.appTint)
                )
                .opacity(trimmedCustom.isEmpty || isDisabled ? 0.35 : 1)
                .disabled(trimmedCustom.isEmpty || isDisabled)
        }
        .disabled(onTap == nil)
        .opacity(onTap == nil ? 0.5 : 1)
    }

    private func submitCustom() {
        guard !trimmedCustom.isEmpty, !isDisabled else { return }
        onTap?(trimmedCustom)
        customInterest = ""
        fieldIsFocused = false
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
                           : AnyShapeStyle(Color(.systemBackground).opacity(0.85))
                )
            )
            .overlay(
                Capsule().stroke(
                    isUsed ? Color.clear : Color.appTint.opacity(0.28),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(isUsed || isDisabled)
    }
}

/// Wraps chips onto as many lines as they need.
///
/// Exists because the fixed three have to be *visible*, not merely present —
/// they are the range-setting half of D8, and a horizontal rail parked them
/// off-screen.
private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.replacingUnspecifiedDimensions().width
        var x: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: totalHeight + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("Fresh") {
    ScrollView {
        InterestChipsRow(
            chips: [
                "Natural wine bars", "Rooftop sunsets", "Modernista rooftops",
                "Running routes", "Remote-work cafés", "Climbing gyms"
            ],
            used: [],
            onTap: { _ in }
        )
    }
    .gradientBackground()
}

#Preview("Two spent") {
    ScrollView {
        InterestChipsRow(
            chips: [
                "Natural wine bars", "Rooftop sunsets", "Modernista rooftops",
                "Running routes", "Remote-work cafés", "Climbing gyms"
            ],
            used: ["Rooftop sunsets", "Climbing gyms"],
            onTap: { _ in }
        )
    }
    .gradientBackground()
}

#Preview("Cap reached") {
    ScrollView {
        InterestChipsRow(
            chips: [
                "Natural wine bars", "Rooftop sunsets", "Modernista rooftops",
                "Running routes", "Remote-work cafés", "Climbing gyms"
            ],
            used: ["Rooftop sunsets", "Climbing gyms", "Natural wine bars"],
            guidance: "You used up all 3 free deep dives.",
            capReached: true,
            onTap: nil
        )
    }
    .gradientBackground()
}
