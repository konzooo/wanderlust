import CoreArchitecture
import SwiftUI

struct ProfileTabScreen: View {
    @EnvironmentObject private var router: NavigationRouter

    var body: some View {
        ProfilesScreen(
            showsDoneButton: false,
            showsInfoButton: false,
            automaticallyPresentsOnboarding: false,
            logsScreenViewOnAppear: false
        )
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.goToSettings(on: .profile)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .onTabRootAppear(.profile, router: router) {
            AnalyticsTracker.shared.log(.screenViewed(.profiles))
        }
    }
}
