//
//  WanderlustApp.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 10/4/24.
//

import CoreArchitecture
import SwiftUI
import DesignSystem

@main
struct WanderlustApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var metricsTracker = MetricsTracker(storage: UserDefaultsMetricsStorage())
    @StateObject private var navigationRouter = NavigationRouter()

    /// Shown once per process launch. `@State` on the `App` is initialised when
    /// the process starts and never again, so this is a cold-launch splash for
    /// free — returning from the background does not bring it back.
    @State private var showSplash = true

    init() {
        DS.applyUniformDesign()

#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-profiles") {
            TravellerProfileLibrary.shared.resetForUITesting()
            UserDefaults.standard.removeObject(forKey: "profiles.introduction.dismissed")
        }
#endif

        // Mint the install token now rather than on the first generation, so a
        // Keychain hiccup shows up at launch instead of mid-flow. There is no
        // API key to install any more — model calls happen behind the backend.
        _ = InstallIdentity.token()
    }
    
    var body: some Scene {
        WindowGroup {
            // HomeScreen owns the app's NavigationStack and destination
            // registrations. Wrapping it in a second stack bound to the same
            // path makes deep links push onto an unregistered outer stack.
            ZStack {
                HomeScreen()
                .preferredColorScheme(.light)
                .environmentObject(navigationRouter)
                .environmentObject(metricsTracker)
                .onOpenURL { url in
                    // A deep link means the user is heading somewhere specific.
                    // Get out of the way rather than making them watch the
                    // animation first.
                    showSplash = false
                    navigationRouter.handleDeepLink(url)
                }

                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
                    }
                    .transition(.opacity)
                    // Nothing on the splash is tappable, and swallowing a tap
                    // meant for Home during the cross-fade would feel broken.
                    .allowsHitTesting(false)
                    .zIndex(1)
                }
            }
            
//            NavigationStack {
//                TripOutputScreen(
//                    initialState: .init(
//                        tripSummary: """
//                            Basic Information:
//                            - Destination: tokio
//                            - Travel Mode: Solo
//                            - Number of Days: 2
//                            - Start Month: 4
//
//                            Preferences:
//                            Question 1: Right
//                            Question 2: Both
//                            Question 3: Left
//                            Question 4: Both
//                            Question 5: Right
//                            Question 6: Both
//                            Question 7: Left
//                            """,
//                        details: .mock,
//                        selectedContentTab: .itinerary,
//                        itineraryResponse: .loaded(.mock),
//                        suggestionsResponse: .loaded(.mock),
//                        imageUrlResponse: .loaded(URL(
//                            string: "https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=1080&q=80")!
//                        )
//                    )
//                )
//            }
//            .environmentObject(NavigationRouter())
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        AnalyticsTracker.shared.initialize()
        return true
    }
}
