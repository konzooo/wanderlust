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
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            store.send(.navigateBack)
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Saved Trips")
                            }
                            .foregroundColor(.white)
                        }
                    }
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
        TopHeader(
            imageUrlState: store.state.imageUrlResponse,
            title: store.fullDestinationString,
            chips: [
                TripOrganizer.shared.tripDetails.month.simplified.capitalized,
                TripOrganizer.shared.tripDetails.members.groupType.rawValue.capitalized
            ],
            saveState: store.saved
        ) {
            if store.state.mode == .savedTrip && store.saved {
                store.send(.deleteTrip(confirmDeletion: false))
            } else if store.state.mode == .newTrip {
                store.send(.saveTrip(confirmOverride: false))
            }
        }
    }
    
    var retryView: some View {
        RetryErrorView(retryCount: $store.retryCount) {
            store.send(.retry)
        } restartAction: {
            router.popToRoot() // Use router for navigation
        }
    }
    
    var emptyFavoritesView: some View {
        ZStack {
            VStack {
                Spacer()
                
                Image(systemName: "heart")
                    .font(.system(size: 64))
                    .foregroundColor(.gray.opacity(0.4))

                Text("No favorites yet")
                    .font(DS.Typography.displayLight)
                    .foregroundStyle(Color.gray)
                
                Text("Tap the heart icon on items you like!")
                    .font(.kanitLight(20))
                    .foregroundStyle(Color.gray)
                    .padding(.bottom, 40)
                
                Spacer()
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

