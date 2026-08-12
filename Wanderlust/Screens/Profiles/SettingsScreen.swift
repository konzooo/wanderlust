import DesignSystem
import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var router: NavigationRouter
    @Environment(\.navigationTab) private var navigationTab

    var body: some View {
        List {
            Section("Account") {
                Label("Account settings coming soon", systemImage: "person.crop.circle")
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Label("Traveller profiles are stored on this device", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
            }

            Section("Support") {
                Button {
                    router.goToFeedback(on: navigationTab)
                } label: {
                    Label("Help & feedback", systemImage: "bubble.left.and.bubble.right")
                }
            }

#if DEBUG
            Section("Developer") {
                Button {
                    router.goToDebugMenu(on: navigationTab)
                } label: {
                    Label("Debug Menu", systemImage: "ladybug")
                }
            }
#endif
        }
        .tint(Color.appTint)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
