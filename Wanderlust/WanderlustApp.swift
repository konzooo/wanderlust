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

    @AppStorage(OnboardingPreferenceKey.welcomeCompleted) private var welcomeCompleted = false

    init() {
        DS.applyUniformDesign()

#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("-ui-testing-reset-profiles") {
            TravellerProfileLibrary.shared.resetForUITesting()
            UserDefaults.standard.removeObject(forKey: ProfilePreferenceKey.introductionDismissed)
        }

        // Tests that drive the app proper must not have to walk the welcome
        // flow first — `testTravellerDNAEntryFromNewTrip` taps a Home chip
        // within seconds of launch. Suppress rather than reset: resetting is
        // what the argument below is for.
        if arguments.contains("-ui-testing") || arguments.contains("-ui-testing-reset-profiles") {
            UserDefaults.standard.set(true, forKey: OnboardingPreferenceKey.welcomeCompleted)
        }

        if arguments.contains("-ui-testing-reset-onboarding") {
            OnboardingPreferenceKey.all.forEach {
                UserDefaults.standard.removeObject(forKey: $0)
            }
        }
#endif

        // Mint the install token now rather than on the first generation, so a
        // Keychain hiccup shows up at launch instead of mid-flow. There is no
        // API key to install any more — model calls happen behind the backend.
        _ = InstallIdentity.token()
    }

#if DEBUG
    /// The Design Playground entry named by `-design-variant <id>`, if any.
    private static var requestedDesignVariant: DesignVariant? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-design-variant"),
              arguments.index(after: flag) < arguments.endIndex
        else { return nil }

        let id = arguments[arguments.index(after: flag)]
        return DesignPlayground.variants.first { $0.id == id }
    }
#endif
    
    var body: some Scene {
        WindowGroup {
            ZStack {
#if DEBUG
                // `-design-variant <id>` boots straight into one Design
                // Playground entry. The playground is otherwise behind a
                // triple-tap on the Home logo, which a human can do and an
                // automated screenshot run cannot.
                if let variant = Self.requestedDesignVariant {
                    NavigationStack { variant.destination }
                        .preferredColorScheme(.light)
                        .environmentObject(navigationRouter)
                        .environmentObject(metricsTracker)
                        .zIndex(3)
                }
#endif

                RootTabView()
                .preferredColorScheme(.light)
                .environmentObject(navigationRouter)
                .environmentObject(metricsTracker)
                .onOpenURL { url in
                    // A deep link means the user is heading somewhere specific.
                    // Get out of the way rather than making them watch the
                    // animation first — and that includes the welcome flow: an
                    // invited joiner gets the invite, not the general pitch.
                    showSplash = false
                    welcomeCompleted = true
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

                // Gated on the splash being finished rather than raced against
                // `onOpenURL`: the deep link arrives well inside the splash's
                // window, so by the time this can appear the flag is already set
                // and there is no welcome flash on an invite.
                if !showSplash, !welcomeCompleted {
                    WelcomeScreen {
                        withAnimation(.easeInOut(duration: 0.4)) { welcomeCompleted = true }
                    }
                    .transition(.opacity)
                    .zIndex(2)
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
