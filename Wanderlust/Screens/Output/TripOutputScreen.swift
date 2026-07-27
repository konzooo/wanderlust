//
//  ItineraryResultScreen.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 1/6/25.
//

import CoreModels
import CoreArchitecture
import DesignSystem
import SwiftUI

struct TripOutputScreen: View {
    @StateObject var store: TripOutputStore
    @EnvironmentObject var router: NavigationRouter
    
    @State private var isDrawerOpen = false
    @State private var showRemoveFavoriteAlert = false // Local state for alert
    @State private var hasDismissedOutputOnThisVisit = false
    @AppStorage(OnboardingPreferenceKey.newTripOutputPermanentlyDismissed) private var hasPermanentlyDismissedOutputOnboarding = false
    
    init(initialState: TripOutputStore.State) {
        self._store = StateObject(wrappedValue: TripOutputStore(initialState: initialState))
    }
    
    var body: some View {
        Group {
            if store.itineraryResponse.isLoading {
                LoadingView()
                    .background(Color.white)
            } else if store.itineraryResponse.error != nil {
                retryView
            } else {
                mainTripContent
            }
        }
        .cleanTopInsets()
        .navigationBarBackButtonHidden(true)

        // While loading loading ignore:
        // - Safe Areas -> breaks loading animations
        // - Drawer menu
        .conditional(!store.state.itineraryResponse.isLoading) { view in
            view
                .ignoresSafeArea(edges: .vertical)
                .toolbar {
                    if #available(iOS 26.0, *) {
                        ToolbarItem(placement: .navigationBarLeading) {
                            outputBackButton
                        }
                        .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .navigationBarLeading) {
                            outputBackButton
                        }
                    }
                }
        }

        .overlay {
            if shouldShowOutputOnboarding {
                TripOutputOnboardingOverlay(
                    onGotIt: { hasDismissedOutputOnThisVisit = true },
                    onDontShowAgain: {
                        hasDismissedOutputOnThisVisit = true
                        hasPermanentlyDismissedOutputOnboarding = true
                    }
                )
            }
        }

        .withAlertDialogs(store: store)

        // Successful save toast
        .toast(
            style: .success,
            title: "Trip Saved!" ,
            subtitle: nil,
            isPresented: $store.presentSaveToast,
            position: .top
        )

        // Native share sheet, presented once a share link exists.
        .sheet(item: Binding(
            get: { store.shareSheetURL.map(IdentifiableURL.init) },
            set: { store.shareSheetURL = $0?.url }
        )) { item in
            ActivityShareSheet(url: item.url)
        }

        // Share publish failure
        .alert("Couldn't share", isPresented: Binding(
            get: { store.shareErrorMessage != nil },
            set: { if !$0 { store.shareErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.shareErrorMessage = nil }
        } message: {
            Text(store.shareErrorMessage ?? "")
        }

        // On appear trigger Itinerary generation
        .onAppear {
            AnalyticsTracker.shared.log(.screenViewed(.itineraryResult))
            store.setRouter(router)
            store.send(.onAppear)
        }
    }
    
    var mainTripContent: some View {
        VStack(spacing: 0) {
            // -- HEADER
            itineraryHeader
            
            // -- TAB BAR
            DS.ContentTabBar(selection: $store.state.selectedContentTab)
            
            // -- CONTENT
            switch store.selectedContentTab {
            case .itinerary:
                ItineraryCard(tripItinerary: store.itineraryResponse, favorites: $store.state.favorites)

            case .suggestions:
                TravelTipsView(suggestions: store.suggestionsResponse, favorites: $store.state.favorites)
                    .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                
            case .favourites:
                let favouriteItems = store.favouritesWithContext
                if !favouriteItems.isEmpty {
                    FavouritesListView(
                        favorites: favouriteItems,
                        favoritesBinding: $store.state.favorites,
                        onRemoveFavorite: { favoriteId in
                            store.send(.removeFavorite(favoriteId, confirmRemoval: false))
                        }
                    )
                    // Temporarily removed transition to test touch events
                    // .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                } else {
                    emptyFavoritesView
                }
            }
        }
        .gradientBackground()
        .animation(.easeInOut, value: store.state.selectedContentTab)
    }
    
    var itineraryHeader: some View {
        // Explicit argument labels throughout (no trailing closure): TopHeader
        // has two closure-typed parameters now, and Swift's trailing-closure
        // backward-scan can silently re-bind an unlabeled trailing closure to
        // the wrong one if the parameter list is ever reordered.
        TopHeader(
            imageUrlState: store.state.imageUrlResponse,
            title: store.fullDestinationString,
            chips: headerChips,
            saveState: store.saved,
            showSaveButton: store.state.mode == .newTrip || store.state.mode == .savedTrip,
            showShareButton: store.state.mode == .newTrip || store.state.mode == .savedTrip,
            isSharing: store.isPublishingShare,
            onShareTapped: {
                store.send(.shareTrip)
            },
            onSaveTapped: {
                if store.state.mode == .savedTrip && store.saved {
                    store.send(.deleteTrip(confirmDeletion: false))
                } else if store.state.mode == .newTrip {
                    store.send(.saveTrip(confirmOverride: false))
                }
            }
        )
    }

    /// Chips come from the trip's own `details` (not the global `TripOrganizer`
    /// scratchpad) so a group trip shows its own month/party, not the solo one.
    private var headerChips: [String] {
        [
            store.state.details.month.simplified.capitalized,
            store.state.details.members.groupType.rawValue.capitalized
        ]
    }
    
    var retryView: some View {
        RetryErrorView(retryCount: $store.retryCount) {
            store.send(.retry)
        } restartAction: {
            router.popToRoot() // Use router for navigation
        }
    }
    
    var emptyFavoritesView: some View {
        VStack(spacing: 10) {
            Spacer()

            Image(systemName: "heart")
                .font(.system(size: 56))
                .foregroundStyle(Color(.systemGray3))

            Text("No favorites yet")
                .font(DS.Typography.displayLight)
                .foregroundStyle(.primary)

            Text("Tap the heart icon on items you like!")
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)

            Spacer()
        }
    }

    private var shouldShowOutputOnboarding: Bool {
        store.state.mode == .newTrip
            && store.itineraryResponse.isLoaded
            && !hasDismissedOutputOnThisVisit
            && !hasPermanentlyDismissedOutputOnboarding
    }

    private var outputBackButton: some View {
        Button {
            store.send(.navigateBack)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text(backButtonTitle)
            }
            .foregroundStyle(.white)
        }
        .accessibilityLabel("Back to \(backButtonTitle)")
    }

    private var backButtonTitle: String {
        store.state.mode == .groupTrip ? "Dashboard" : "Trips"
    }
}

private struct TripOutputOnboardingOverlay: View {
    let onGotIt: () -> Void
    let onDontShowAgain: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("How it works")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 28) {
                    onboardingRow(
                        icon: "safari",
                        tint: .appTint,
                        title: "Discover places and activities",
                        subtitle: "Explore your itinerary and personalised suggestions"
                    )
                    onboardingRow(
                        icon: "heart",
                        tint: Color(hex: "#EE6262"),
                        title: "Like your favourites",
                        subtitle: "Create your own list by tapping the heart"
                    )
                    onboardingRow(
                        icon: "bookmark",
                        tint: Color(hex: "#68C86A"),
                        title: "Save a trip to come back later",
                        subtitle: "Bookmark your trip to access it anytime."
                    )
                }

                Spacer(minLength: 44)

                VStack(spacing: 14) {
                    Button(action: onGotIt) {
                        Text("Got it")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appTint)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: onDontShowAgain) {
                        Text("Don’t show again")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityHint("Hides this introduction permanently")
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 30)
            .frame(maxWidth: 360)
            .frame(height: 500)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .padding(.horizontal, 28)
        }
    }

    private func onboardingRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.darkGray)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension View {
    func withAlertDialogs(store: TripOutputStore) -> some View {
        let alertBinding = Binding<TripOutputStore.State.AlertType?>(
            get: { store.state.alert },
            set: { store.state.alert = $0 }
        )

        return alert(
            "",
            isPresented: Binding(
                get: { store.alert != nil },
                set: { _,_ in store.send(.closeAlert) }
            ),
            presenting: alertBinding
        ) { alert in
            switch alert.wrappedValue {
            case .override:
                Button("Override", role: .destructive) { store.send(.saveTrip(confirmOverride: true)) }
                Button("Cancel", role: .cancel) { store.send(.closeAlert) }
                
            case .removeFavorite:
                Button("Remove", role: .destructive) {
                    if let favoriteId = store.state.favoriteToRemove {
                        store.send(.removeFavorite(favoriteId, confirmRemoval: true))
                    }
                }
                Button("Cancel", role: .cancel) { store.send(.closeAlert) }
                
            case .deleteTrip:
                Button("Delete", role: .destructive) { store.send(.deleteTrip(confirmDeletion: true)) }
                Button("Cancel", role: .cancel) { store.send(.closeAlert) }
                
            case .unsavedTrip:
                Button("Save Trip") { store.send(.saveAndNavigateBack) }
                Button("Discard", role: .destructive) { store.send(.discardAndNavigateBack) }
                
            case .none:
                EmptyView()
            }
        } message: { alert in
            switch alert.wrappedValue {
            case .override:
                Text("A trip with the same details already exists.\nDo you want to override it?")
            case .removeFavorite:
                Text("Are you sure you want to remove this item from your favorites?")
            case .deleteTrip:
                Text("Are you sure you want to unsave this trip?")
            case .unsavedTrip:
                Text("Trip not saved.\ndiscard or save trip?")
            case .none:
                EmptyView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        TripOutputScreen(
            initialState: .init(
                tripSummary: """
                    Basic Information:
                    - Destination: tokio
                    - Travel Mode: Solo
                    - Number of Days: 2
                    - Start Month: 4

                    Preferences:
                    Question 1: Right
                    Question 2: Both
                    Question 3: Left
                    Question 4: Both
                    Question 5: Right
                    Question 6: Both
                    Question 7: Left
                    """,
                details: .mock,
                selectedContentTab: .itinerary,
                mode: .newTrip,
                itineraryResponse: .loaded(.mock),
                suggestionsResponse: .loaded(.mock),
                imageUrlResponse: .loaded(URL(
                    string: "https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=1080&q=80")!
                )
            )
        )
    }
    .environmentObject(NavigationRouter())
}

/// Changes whenever either flag toggles
private struct ContentLoadPair: Equatable {
    let itineraryReady : Bool
    let suggestionsReady: Bool
}
