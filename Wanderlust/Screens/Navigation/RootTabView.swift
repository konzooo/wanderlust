import DesignSystem
import Networking
import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var router: NavigationRouter
    @StateObject private var feedbackStore = FeedbackStore()
    @State private var feedbackToastResult: FeedbackResult?
    @State private var isFeedbackToastPresented = false

    var body: some View {
        TabView(selection: selection) {
            NavigationStack(path: $router.homePath) {
                HomeScreen()
                    .withAppDestinations()
            }
            .environment(\.navigationTab, .home)
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack(path: $router.tripsPath) {
                SavedTripsScreen()
                    .withAppDestinations()
            }
            .environment(\.navigationTab, .trips)
            .tabItem { Label("My Trips", systemImage: "suitcase") }
            .tag(AppTab.trips)

            NavigationStack(path: $router.profilePath) {
                ProfileTabScreen()
                    .withAppDestinations()
            }
            .environment(\.navigationTab, .profile)
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .tint(Color.appTint)
        .statusBarHidden(true)
        .environmentObject(feedbackStore)
        .toast(
            style: feedbackToastResult == .error ? .error : .success,
            title: feedbackToastResult == .error
                ? "Couldn't send feedback"
                : "Thanks for the feedback",
            subtitle: feedbackToastResult == .error
                ? "Check your connection and try again."
                : "It means a lot to us 🫶🏻",
            isPresented: $isFeedbackToastPresented,
            position: .top
        )
        .onChange(of: feedbackStore.submissionResult) { _, result in
            guard let result else { return }
            feedbackToastResult = result
            isFeedbackToastPresented = true
            feedbackStore.submissionResult = nil
        }
    }

    private var selection: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { router.select($0) }
        )
    }
}
