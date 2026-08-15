//
//  DS.EmptyState.swift
//  DesignSystem
//
//  The card a tab shows before it has anything in it.
//

import SwiftUI

extension DS {
    /// An empty state shaped as an invitation rather than a notice.
    ///
    /// The pattern it replaces — a 92pt tinted circle, a 34pt light title and a
    /// hand-rolled capsule, floating directly on the gradient — is the default
    /// iOS placeholder, and it read as one: bigger than any real content on the
    /// screen, and the only surface in the app with no card under it.
    ///
    /// This is built to the proportions of the Profile tab's Traveller DNA
    /// card, which solves the same problem well: a card the traveller could
    /// mistake for content, an eyebrow naming what the section is, a title at
    /// heading size rather than display size, and body copy at a weight that
    /// survives being set on a soft gradient.
    public struct EmptyState: View {
        private let eyebrow: String
        private let symbol: String
        private let title: String
        private let message: String
        private let actionTitle: String?
        private let action: (() -> Void)?
        private let secondaryTitle: String?
        private let secondaryAction: (() -> Void)?

        public init(
            eyebrow: String,
            symbol: String,
            title: String,
            message: String,
            actionTitle: String? = nil,
            action: (() -> Void)? = nil,
            secondaryTitle: String? = nil,
            secondaryAction: (() -> Void)? = nil
        ) {
            self.eyebrow = eyebrow
            self.symbol = symbol
            self.title = title
            self.message = message
            self.actionTitle = actionTitle
            self.action = action
            self.secondaryTitle = secondaryTitle
            self.secondaryAction = secondaryAction
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(eyebrow.uppercased())
                    .font(.kanit(10).weight(.semibold))
                    .tracking(1.45)
                    .foregroundStyle(Color.appTint)

                HStack(alignment: .top, spacing: 15) {
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Color.appTint)
                        .frame(width: 60, height: 60)
                        .background(
                            .white.opacity(0.80),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.appTint.opacity(0.12), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.kanit(22).weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(message)
                            .font(.kanit(13).weight(.medium))
                            .foregroundStyle(Color.primary.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 16)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                        .padding(.top, 18)
                }

                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                        .font(.kanitMedium(13))
                        .foregroundStyle(Color.appTint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, actionTitle == nil ? 16 : 12)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .white.opacity(0.70),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.76), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.045), radius: 16, y: 8)
        }
    }
}

#Preview("With action") {
    ZStack {
        LinearGradient(
            colors: [.gradientTop, .gradientBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        DS.EmptyState(
            eyebrow: "My trips",
            symbol: "suitcase.rolling",
            title: "Your trips live here",
            message: "Plan one and it stays on this device — itinerary, favourites and all.",
            actionTitle: "Plan a trip",
            action: {}
        )
        .padding(16)
    }
}

#Preview("Secondary only") {
    ZStack {
        LinearGradient(
            colors: [.gradientTop, .gradientBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        DS.EmptyState(
            eyebrow: "Shared",
            symbol: "paperplane",
            title: "Trips friends send you",
            message: "Open a share link and the whole trip lands here, their picks already marked.",
            secondaryTitle: "Join a group trip with a code",
            secondaryAction: {}
        )
        .padding(16)
    }
}
