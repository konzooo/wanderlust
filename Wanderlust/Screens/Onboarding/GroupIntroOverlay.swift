//
//  GroupIntroOverlay.swift
//  Wanderlust
//
//  Shown once when someone first opens the group create/join screen.
//
//  It shares a screen flow with `GroupOnboardingOverlay`, which appears later on
//  the swipe screen, so the two have to divide the work cleanly or the second
//  one reads as a repeat:
//
//    - This one answers "how does this work at all" — the shape of the process,
//      from invite to finished trip. It never mentions swiping.
//    - The swipe overlay answers "what do I do right now", on the screen where
//      the answer is needed.
//
//  If you add a line here that could equally live there, it belongs there.
//

import DesignSystem
import SwiftUI

struct GroupIntroOverlay: View {
    let onGotIt: () -> Void
    let onDontShowAgain: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                // No subtitle: the screen behind this one is already headed
                // "Different personalities — One Trip!", and any second line
                // here landed as an echo of it.
                Text("Planning together")
                    .font(.kanitLight(25))
                    .foregroundStyle(Color(hex: "#2A2F45"))
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 18) {
                    row(
                        icon: "square.and.arrow.up",
                        tint: Color.appTint,
                        title: "Invite your group",
                        subtitle: "Share a code or a link. No accounts, and nobody needs the app to join."
                    )
                    row(
                        icon: "lock",
                        tint: Color(hex: "#8B6BF6"),
                        title: "Everyone answers privately",
                        subtitle: "Each person picks what they want, without seeing anyone else's choices."
                    )
                    row(
                        icon: "sparkles",
                        tint: Color(hex: "#68C86A"),
                        title: "One trip, built from the overlap",
                        subtitle: "We find the plan that actually works for all of you."
                    )
                }

                VStack(spacing: 10) {
                    Button("Got it", action: onGotIt)
                        .buttonStyle(PrimaryButtonStyle(fullWidth: true))

                    Button("Don't show again", action: onDontShowAgain)
                        .font(.kanit(13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityHint("Hides this introduction permanently")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: 350)
            .fixedSize(horizontal: false, vertical: true)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.6), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.2), radius: 22, y: 10)
            .padding(.horizontal, 26)
        }
    }

    private func row(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.kanit(15).weight(.semibold))
                    .foregroundStyle(Color(hex: "#2A2F45"))
                Text(subtitle)
                    .font(.kanit(12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
#Preview("Group intro") {
    ZStack {
        AuroraBackground()
        GroupIntroOverlay(onGotIt: {}, onDontShowAgain: {})
    }
}
#endif
