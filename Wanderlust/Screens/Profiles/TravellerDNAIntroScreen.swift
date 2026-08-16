//
//  TravellerDNAIntroScreen.swift
//  Wanderlust
//
//  The first-time explanation of Traveller DNA.
//
//  Moved out of `TravellerProfiles.swift` when the Profile tab started
//  presenting it too: it now has two callers (`ProfilesScreen` and
//  `ProfileTabScreen`), and it was file-private in a file already past a
//  thousand lines.
//
//  Note the three exits are not interchangeable. "Create" and "Don't show again"
//  are decisions and persist; "Maybe later" is a deferral and deliberately
//  persists nothing — see `OnboardingSession` for what stops that from meaning
//  "ask me again immediately".
//

import DesignSystem
import SwiftUI

struct TravellerDNAIntroScreen: View {
    let onCreate: () -> Void
    let onMaybeLater: () -> Void
    let onDontShowAgain: () -> Void

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView {
                VStack(spacing: 13) {
                    TravellerDNABlob(answers: [], animated: true, progress: 0)
                        .frame(width: 175, height: 175)
                        .padding(.top, 14)

                    Text("Meet your Traveller DNA")
                        .font(DS.Typography.displayRegular)
                        .multilineTextAlignment(.center)

                    Text("A lasting travel profile that helps Wanderlust understand how you like to explore.")
                        .font(DS.Typography.subtitle)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)

                    DS.GlassCard {
                        VStack(alignment: .leading, spacing: 11) {
                            introPoint("Your lasting travel preferences")
                            introPoint("Trip answers always come first")
                            introPoint("Private, local, and optional")
                        }
                    }

                    Button("Create my Traveller DNA", action: onCreate)
                        .buttonStyle(PrimaryButtonStyle(fullWidth: true))

                    Button("Maybe later", action: onMaybeLater)
                        .font(.kanit(15).weight(.medium))
                        .foregroundStyle(Color.appTint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 14))

                    Button("Don’t show again", action: onDontShowAgain)
                        .font(.kanit(13))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func introPoint(_ title: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.appTint)
            Text(title)
                .font(.kanit(14).weight(.medium))
        }
    }
}

#if DEBUG
#Preview("Traveller DNA intro") {
    TravellerDNAIntroScreen(onCreate: {}, onMaybeLater: {}, onDontShowAgain: {})
}
#endif
