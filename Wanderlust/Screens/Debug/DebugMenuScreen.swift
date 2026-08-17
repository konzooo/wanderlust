//
//  DebugMenuScreen.swift
//  Wanderlust
//
//  Internal-only screen for QA toggles and design-in-progress previews.
//  Reached via a triple-tap on the Home screen logo (DEBUG builds only).
//

import CoreArchitecture
import DesignSystem
import SwiftUI

struct DebugMenuScreen: View {
    @AppStorage(DebugSettings.useMockTripDataKey) private var useMockTripData = false
    @State private var didResetOnboarding = false

    var body: some View {
        List {
            Section("Data") {
                Toggle(isOn: $useMockTripData) {
                    Label("Mock trip data (no API)", systemImage: "ladybug.fill")
                }
                .tint(Color.appTint)
            }

            Section {
                Button(action: resetOnboarding) {
                    Label(
                        didResetOnboarding ? "Onboarding reset" : "Reset onboarding",
                        systemImage: didResetOnboarding ? "checkmark.circle.fill" : "arrow.counterclockwise"
                    )
                }
                .disabled(didResetOnboarding)
            } footer: {
                Text("Clears the welcome, group, joiner, questionnaire, trip output and Traveller DNA flags. The welcome flow is gated on cold launch, so quit and relaunch to see it.")
            }

            Section {
                ForEach(DesignPlayground.variants) { variant in
                    NavigationLink(destination: variant.destination) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(variant.title)
                                .font(.kanit(15).weight(.medium))
                            Text(variant.subtitle)
                                .font(.kanit(12))
                                .foregroundColor(Color(.systemGray))
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Design Playground")
            } footer: {
                Text("In-progress redesigns. Add or remove entries in DesignPlayground.swift.")
            }
        }
        .navigationTitle("Debug Menu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resetOnboarding() {
        OnboardingPreferenceKey.all.forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        OnboardingSession.shared.reset()
        didResetOnboarding = true
    }
}

#Preview {
    NavigationStack {
        DebugMenuScreen()
    }
    .environmentObject(NavigationRouter())
}
