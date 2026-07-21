import SwiftUI
import DesignSystem
import CoreModels
import Networking
import CoreArchitecture

struct SavedTripsScreen: View {
    @StateObject var store: SavedTripsStore = SavedTripsStore()

    @EnvironmentObject var router: NavigationRouter
    @State private var isDrawerOpen = false
        
    init(store: SavedTripsStore = .init()) {
        self._store = StateObject(wrappedValue: store)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemGray6), Color(.systemYellow).opacity(0.1)]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                titleSubtitle
                
                tripsList
                    .padding(.horizontal, 16)
                
                Spacer()
            }
        }
        .gradientBackground()
        .drawerToolbar(
            isOpen: $isDrawerOpen,
            selected: .savedTrips,
            router: router,
            trailingButton: AnyView(plusButton)
        )
        
        // onAppear is only called the first time this screen is shown (not when returning via pop)
        .onAppear {
            store.send(.loadSavedTrips)
        }
        // Use onChange to detect when navigation returns to SavedTripsScreen and refresh the data.
        // (SwiftUI NavigationStack does not call onAppear again when popping back to this screen)
        .onChange(of: router.path) { _, newPath in
            // If returning to SavedTripsScreen (either as last or only screen), refresh
            if newPath.last == .savedTrips || newPath.isEmpty {
                store.send(.loadSavedTrips)
            }
        }
    }
    
    var titleSubtitle: some View {
        VStack(spacing: 0) {
            Text("Saved Trips")
                .font(.kanit(34))
        }
    }
    
    var tripsList: some View {
        ScrollView {
            VStack(spacing: 24) {
                switch store.state.savedTrips {
                case let .loaded(trips):
                    if trips.isEmpty {
                        Text("No saved trips yet.")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(trips) { trip in
                            Button(action: { navigateToTripDetails(trip) }) {
                                TripCard(trip: trip)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                case .loading, .initial:
                    ProgressView("Loading trips...")
                        .padding(.top, 40)
                    
                case let .error(error):
                    Text("Failed to load trips: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .padding(.top, 40)
                }
            }
            .padding(.top, 16)
        }
    }
    
    var plusButton: some View {
        Button(action: {
            // Navigate to new trip flow
            router.goToBasicInfo(resetStack: true)
        }) {
            Image(systemName: "plus")
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundColor(.appTint)
        }
    }
    
    // should be part of a Store Action
    func navigateToTripDetails(_ trip: Trip) {
        let suggestions: AsyncValue<Trip.Suggestions> = trip.suggestions != nil ?
            .loaded(trip.suggestions!) : .initial
        
        let state = TripOutputStore.State(
            tripSummary: trip.details.destination.name,
            details: trip.details,
            selectedContentTab: .itinerary,
            favorites: trip.favorites,
            saved: true,
            mode: .savedTrip,
            itineraryResponse: .loaded(trip.itinerary),
            suggestionsResponse: suggestions
        )
        
        router.goToItineraryResult(state, resetStack: false)
    }
}

#Preview {
    NavigationStack {
        SavedTripsScreen()
            .environmentObject(NavigationRouter())
    }
}
