//
//  ComponentStateView.swift
//  Wanderlust
//
//  One component's loading / failed / ready states, in place.
//

import CoreArchitecture
import DesignSystem
import SwiftUI

/// Wraps one generated component in its own loading and failure states.
///
/// The whole screen used to block on the itinerary and there was no recovery UI
/// below that: a component that failed on its own left its tab permanently
/// empty with nothing to press. Components arrive independently, so they fail
/// independently, and each one has to be able to say so and offer its own way
/// back — without taking the rest of the trip down with it.
struct ComponentStateView<Value: Equatable & Sendable, Content: View>: View {
    let value: AsyncValue<Value>
    /// What failed, in the traveller's words: "your suggestions".
    let subject: String
    /// `nil` in read-only modes, where there is nothing to re-request.
    let onRetry: (() -> Void)?
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch value {
        case .initial, .loading:
            VStack(spacing: .Spacing.small) {
                ProgressView()
                Text("Writing \(subject)…")
                    .font(DS.Typography.tabLabel)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, .Padding.md3)
            .transition(.opacity)

            Spacer()

        case .error:
            VStack(spacing: .Spacing.small) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.appTint)

                Text("Couldn't load \(subject)")
                    .font(DS.Typography.sectionHeader)
                    .foregroundStyle(.primary)

                Text("The rest of your trip is fine — just this part didn't come through.")
                    .font(.kanit(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, .Padding.md)

                if let onRetry {
                    Button("Try again", action: onRetry)
                        .buttonStyle(SecondaryButtonStyle(fullWidth: false, internalPadding: 8))
                        .padding(.top, .Padding.sm)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, .Padding.md3)

            Spacer()

        case .loaded(let value):
            content(value)
        }
    }
}
