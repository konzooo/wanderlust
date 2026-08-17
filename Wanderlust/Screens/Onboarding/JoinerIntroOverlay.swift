//
//  JoinerIntroOverlay.swift
//  Wanderlust
//
//  What an invited joiner sees before the roster.
//
//  This is often someone's entire first impression of Wanderlust — they tapped a
//  friend's link and would otherwise land on a list of names with no idea what
//  the app is. It is also the most conversion-sensitive screen in the product,
//  so it stays at three lines: they came for a specific thing, and everything
//  between the tap and that thing costs.
//
//  It waits for the invite to resolve so it can name the trip. A generic version
//  of this screen would not be worth showing.
//

import DesignSystem
import SwiftUI

struct JoinerIntroOverlay: View {
    let groupName: String
    let destination: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.appTint.opacity(0.12))
                            .frame(width: 62, height: 62)
                        PinPlaneMark(size: 30)
                    }

                    VStack(spacing: 5) {
                        Text("You're invited")
                            .font(.kanit(11).weight(.semibold))
                            .tracking(1.6)
                            .foregroundStyle(Color.appTint)

                        Text(groupName)
                            .font(.kanitLight(25))
                            .foregroundStyle(Color(hex: "#2A2F45"))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        Text(destination)
                            .font(.kanit(13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 14) {
                    line("Your friends are planning a trip and want your take.")
                    line("Pick your name, then answer a few quick questions.")
                    line("The plan comes back built around everyone.")
                }

                Button("Let's go", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle(fullWidth: true))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
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

    private func line(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(Color.appTint.opacity(0.4))
                .frame(width: 5, height: 5)
                .padding(.top, 7)

            Text(text)
                .font(.kanit(14))
                .foregroundStyle(Color(hex: "#2A2F45").opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
#Preview("Joiner intro") {
    ZStack {
        AuroraBackground()
        JoinerIntroOverlay(
            groupName: "Sardinia '26",
            destination: "Sardinia · 5 days in June",
            onContinue: {}
        )
    }
}
#endif
