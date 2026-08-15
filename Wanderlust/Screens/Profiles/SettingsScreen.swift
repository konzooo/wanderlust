import DesignSystem
import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var router: NavigationRouter
    @Environment(\.navigationTab) private var navigationTab

    private static let supportURL = URL(string: "https://wanderlust.get-catalyst.app/support")!
    private static let privacyURL = URL(string: "https://wanderlust.get-catalyst.app/privacy")!

    /// The numeric App Store ID (the digits after `id` in the product URL).
    private static let appStoreID = "6746957492"

    /// `action=write-review` opens the App Store with the review sheet already
    /// up, rather than dropping the traveller on the product page.
    private static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }

    var body: some View {
        List {
            Section("Support") {
                Button {
                    router.goToFeedback(on: navigationTab)
                } label: {
                    Label("Help & feedback", systemImage: "bubble.left.and.bubble.right")
                }

                Link(destination: Self.supportURL) {
                    Label("Support page", systemImage: "questionmark.circle")
                }
            }

            Section("Privacy") {
                Label("Traveller profiles are stored on this device", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)

                Link(destination: Self.privacyURL) {
                    Label("Privacy policy", systemImage: "hand.raised")
                }
            }

            Section("About") {
                Link(destination: Self.writeReviewURL) {
                    Label("Rate Wanderlust", systemImage: "star")
                }

                LabeledContent {
                    Text(Self.versionString)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Version", systemImage: "info.circle")
                }
            }
        }
        .tint(Color.appTint)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
