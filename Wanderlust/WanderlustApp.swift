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

    init() {
        DS.applyUniformDesign()
        
        // oakey
        do { try OAKeyManager.installIfNeeded() }
        catch {
            print("❌ OpenAI key install error: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationRouter.path) {
                HomeScreen()
            }
            .preferredColorScheme(.light)
            .environmentObject(navigationRouter)
            .environmentObject(metricsTracker)
            .onOpenURL { url in
                navigationRouter.handleDeepLink(url)
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
