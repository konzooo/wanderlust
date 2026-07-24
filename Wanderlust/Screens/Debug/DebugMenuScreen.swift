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

    var body: some View {
        List {
            Section("Data") {
                Toggle(isOn: $useMockTripData) {
                    Label("Mock trip data (no API)", systemImage: "ladybug.fill")
                }
                .tint(Color.appTint)
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
}

#Preview {
    NavigationStack {
        DebugMenuScreen()
    }
    .environmentObject(NavigationRouter())
}
