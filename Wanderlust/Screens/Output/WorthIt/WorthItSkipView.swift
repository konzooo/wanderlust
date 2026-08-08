//
//  WorthItSkipView.swift
//  Wanderlust
//
//  The four things you already half-decided to do, argued both ways.
//

import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

/// Worth-it/Skip.
///
/// Deliberately **no counter and no progress bar**: four cards is not a task to
/// complete, and a "1 of 4" turns a nice argument with a friend into homework.
/// Undecided is a perfectly good place to leave a card.
struct WorthItSkipView: View {
    /// The section's own state. Its own call under the split variant, and a
    /// share of the suggestions call's under the combined one — either way the
    /// segment shows its own progress and its own way back.
    let items: AsyncValue<[Trip.WorthItItem]>
    /// `nil` for an undecided card.
    let decision: (UUID) -> WorthItDecision?
    /// `nil` undoes, returning the card to undecided.
    let onDecide: (UUID, WorthItDecision?) -> Void
    /// `nil` in read-only modes, where there is nothing to re-request.
    let onRetry: (() -> Void)?

    var body: some View {
        ComponentStateView(
            value: items,
            subject: "the calls worth arguing about",
            onRetry: onRetry
        ) { cards in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: .Padding.sm3) {
                    ForEach(cards) { item in
                        WorthItCard(
                            item: item,
                            decision: decision(item.id),
                            onDecide: { onDecide(item.id, $0) }
                        )
                    }
                }
                .padding(.horizontal, .Padding.sm3)
                .padding(.vertical, .Padding.md)
            }
        }
    }
}

private struct WorthItCard: View {
    let item: Trip.WorthItItem
    let decision: WorthItDecision?
    let onDecide: (WorthItDecision?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.medium) {
            Text(item.linkableTitle.linkedText)
                .font(DS.Typography.generatedTitle)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Trip.WorthItItem.Field.allCases, id: \.self) { field in
                VStack(alignment: .leading, spacing: 4) {
                    Text(field.label)
                        .font(DS.Typography.eyebrow)
                        .foregroundStyle(Color.appTint)

                    Text(item.linkable(field).linkedText)
                        .font(DS.Typography.generatedBody)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().opacity(0.4)

            actions
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

    @ViewBuilder
    private var actions: some View {
        if let decision {
            HStack(spacing: .Spacing.small) {
                Label(
                    decision == .kept ? "Added to favourites" : "Skipped",
                    systemImage: decision == .kept ? "heart.fill" : "xmark.circle"
                )
                .font(DS.Typography.tabLabel)
                .foregroundStyle(decision == .kept ? Color.red : Color(.systemGray))

                Spacer()

                Button("Undo") { onDecide(nil) }
                    .font(DS.Typography.tabLabel)
                    .foregroundStyle(Color.appTint)
            }
            .padding(.vertical, 4)
        } else {
            HStack(spacing: .Spacing.small) {
                Button {
                    onDecide(.skipped)
                } label: {
                    Text("Skip it")
                        .foregroundStyle(Color(.darkGray))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorthItTextActionStyle())

                Button {
                    onDecide(.kept)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                            .foregroundStyle(Color.red)
                        Text("Add to favourites")
                            .foregroundStyle(Color(.darkGray))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorthItTextActionStyle())
            }
        }
    }
}

/// Text actions deliberately have no capsule or filled background. The heart's
/// red outline distinguishes the keep action while both labels stay neutral.
private struct WorthItTextActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.tabLabel)
            .padding(.vertical, .Padding.sm2)
            .padding(.horizontal, .Padding.sm2)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    @Previewable @State var decisions: [UUID: WorthItDecision] = [:]
    return WorthItSkipView(
        items: .loaded(Trip.WorthItItem.mockSet),
        decision: { decisions[$0] },
        onDecide: { decisions[$0] = $1 },
        onRetry: nil
    )
    .gradientBackground()
}
