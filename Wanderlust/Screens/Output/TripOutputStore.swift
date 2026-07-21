//
//  ItineraryResultStore.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 1/6/25.
//

import CoreModels
import CoreArchitecture
import DesignSystem
import Foundation
import Networking
import UIKit

/// Manages the state and business logic for the itinerary result screen.
/// Handles parallel fetching of itinerary data and destination images.
@dynamicMemberLookup
class TripOutputStore: ObservableStore {
    @Published var state: State
    
    // UI Bindings
    @Published var retryCount: Int = 0
    @Published var presentSaveToast: Bool = false
    
    // Navigation
    var router: NavigationRouter?
    
    private let assistantsService: ItineraryAssistant<Trip.Itinerary> = ItineraryAssistant(
        openAIClient: OpenAIClient(keyProvider: { try OAKeyManager.fetchAPIKey() }),
        assistantId: OpenAIConstant.itineraryAssistantID
    )
    
    private let suggestionsService: ItineraryAssistant<Trip.Suggestions> = ItineraryAssistant(
        openAIClient: OpenAIClient(keyProvider: { try OAKeyManager.fetchAPIKey() }),
        assistantId: OpenAIConstant.suggestionsAssistantID
    )
    
    private let openAIService: OpenAIService
    private let imageService: ImageService
    
    init(
        initialState: State,
        openAIService: OpenAIService = OpenAIService(),
        imageService: ImageService = UnsplashService()
    ) {
        state = initialState
        self.openAIService = openAIService
        self.imageService = imageService
    }
    
    func setRouter(_ router: NavigationRouter) {
        self.router = router
    }

    /// Entry point for all user actions. Triggers parallel data fetching.
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            // Just fetch Itinerary and Suggestions if they are not leaded yet
            if !state.itineraryResponse.isLoaded {
                generateItinerary()
            }
            if !state.suggestionsResponse.isLoaded {
                generateSuggestions()
            }
            
            // Always try to fetch Images
            fetchDestinationImage()
            
        case .retry:
            generateItinerary()
            fetchDestinationImage()
            retryCount+=1
            
        case .saveTrip(let confirmOverride):
            saveTrip(confirmOverride: confirmOverride)
            
        case .removeFavorite(let id, let confirmRemoval):
            if confirmRemoval {
                state.favorites.toggle(id)
                state.alert = nil
                state.favoriteToRemove = nil
            } else {
                state.favoriteToRemove = id
                state.alert = .removeFavorite
            }
            
        case .navigateBack:
            if state.saved {
                if state.mode == .savedTrip {
                    // Trip is already saved, save changes and navigate back directly
                    reSaveTrip()
                }
                router?.pop()

            } else {
                // Trip is not saved, show confirmation dialog
                state.alert = .unsavedTrip
            }
            
        case .saveAndNavigateBack:
            // Save the trip first, then navigate back
            saveTrip(confirmOverride: false)
            
        case .discardAndNavigateBack:
            // Discard changes and navigate back
            state.alert = nil
            router?.pop()
            
        case .deleteTrip(let confirmDeletion):
            if confirmDeletion {
                deleteTrip()
            } else {
                state.alert = .deleteTrip
            }
        
        case .closeAlert:
            state.alert = nil
        }
    }
}

// MARK: ---- STATE ----
extension TripOutputStore {
    struct State: Hashable, Equatable, KeyPathMutable {
        var tripSummary: String
        var details: Trip.Details
        var selectedContentTab: OutputTab = .itinerary
        var favorites: Trip.Favorites = .init()
        var saved: Bool = false
        let mode: Mode

        var itineraryResponse: AsyncValue<Trip.Itinerary> = .initial
        var suggestionsResponse: AsyncValue<Trip.Suggestions> = .initial
        var imageUrlResponse: AsyncValue<URL> = .initial
        
        var fullDestinationString: String {
            itineraryResponse.data?.destination ?? details.destination.name
        }
        
        var nonLoaded: Bool {
            !itineraryResponse.isLoaded || !suggestionsResponse.isLoaded
        }
        
        // Dialogs & Sheets
        var showRemoveFavoriteDialog: Bool = false {
            didSet {
                print("showRemoveFavoriteDialog changed from \(oldValue) to \(showRemoveFavoriteDialog)")
            }
        }
        var favoriteToRemove: UUID?
    
        var alert: AlertType? = nil
    }

    enum Action: Equatable {
        case onAppear
        case closeAlert
        case retry
        case saveTrip(confirmOverride: Bool = false)
        case removeFavorite(UUID, confirmRemoval: Bool = false)
        case navigateBack
        case saveAndNavigateBack
        case discardAndNavigateBack
        case deleteTrip(confirmDeletion: Bool = false)
    }
    
    // Dynamic Member Lookup -> State
    subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> T {
        state[keyPath: keyPath]
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
        get { state[keyPath: keyPath] }
        set { state[keyPath: keyPath] = newValue }
    }
}

extension TripOutputStore {
    /// Returns a dictionary of favorited UUIDs to their LocationLinkableText, built from the current loaded itinerary and/or suggestions.
    var favouritesDictionary: [UUID: LocationLinkableText]? {
        // Try to extract loaded itinerary and suggestions, if available
        let itinerary: Trip.Itinerary?
        if case .loaded(let loadedItinerary) = state.itineraryResponse {
            itinerary = loadedItinerary
        } else {
            itinerary = nil
        }

        let suggestions: Trip.Suggestions?
        if case .loaded(let loadedSuggestions) = state.suggestionsResponse {
            suggestions = loadedSuggestions
        } else {
            suggestions = nil
        }

        // If neither is loaded, return nil
        if itinerary == nil && suggestions == nil {
            return nil
        }

        var result: [UUID: LocationLinkableText] = [:]

        // Itinerary
        for segment in itinerary!.segments {
            for bucket in [segment.description.morning, segment.description.afternoon, segment.description.evening] {
                bucket?.forEach { result[$0.id] = $0 }
            }
            if let tip = segment.secretTip {
                // Convert SecretTip to LocationLinkableText for consistency
                result[tip.id] = LocationLinkableText(text: tip.text, id: tip.id)
            }
        }

        // Suggestions
        if let suggestions = suggestions {
            for cat in suggestions.dynamicSuggestions + suggestions.staticSuggestions {
                cat.texts.forEach { result[$0.id] = $0 }
            }
        }

        // Only return those that are actually favorited
        return state.favorites.liked.reduce(into: [UUID: LocationLinkableText]()) { dict, id in
            if let text = result[id] {
                dict[id] = text
            }
        }
    }

    /// Structure to hold favorite item information with context for display
    struct FavoriteWithContext {
        let id: UUID
        let text: LocationLinkableText
        let context: String
    }

    /// Returns favorited items with their contextual information (Morning/Afternoon/Evening for itinerary, section title for suggestions)
    var favouritesWithContext: [FavoriteWithContext] {
        guard case let .loaded(itinerary) = state.itineraryResponse else {
            return []
        }
        
        let trip = Trip(details: state.details, itinerary: itinerary, suggestions: state.suggestionsResponse.data, favorites: state.favorites)
        let allCandidatesWithContext = trip.allFavouriteCandidatesWithContext
        
        return state.favorites.liked.compactMap { favoriteId in
            guard let (text, context) = allCandidatesWithContext[favoriteId] else { return nil }
            
            // Create LocationLinkableText from the text
            let locationLinkableText = LocationLinkableText(text: text, id: favoriteId)
            return FavoriteWithContext(id: favoriteId, text: locationLinkableText, context: context)
        }
    }

    /// Fetches and processes the itinerary data from OpenAI.
    /// Updates state independently on the main thread.
    func generateItinerary() {
        state.itineraryResponse = .loading
        Task {
            do {
                // Fetch and process the itinerary data
                let response = try await assistantsService.run(userMessage: state.tripSummary) //openAIService.processAssistants(data: state.tripSummary)
                
                // Fetch destination Image again with the recognized destination from openAI
                fetchDestinationImage()
                
                // Save itinerary response
                await MainActor.run {
                    state.itineraryResponse = .loaded(response)
                }
            } catch {
                // Handle any errors during the process
                await MainActor.run {
                    state.itineraryResponse = .error(error)
                }
            }
        }
    }

    func generateSuggestions() {
        state.suggestionsResponse = .loading
        Task {
            do {
                // Fetch and process the itinerary data
                let response = try await suggestionsService.run(userMessage: state.tripSummary)
                await MainActor.run {
                    state.suggestionsResponse = .loaded(response)
                }
            } catch {
                // Handle any errors during the process
                await MainActor.run {
                    state.suggestionsResponse = .error(error)
                }
            }
        }
    }

    /// Fetches the destination image URL from the image service.
    /// Updates state independently on the main thread.
    func fetchDestinationImage() {
        Task {
            do {
                // Get destination name and fetch corresponding image
                let destinationName = state.itineraryResponse.data?.destination ?? TripOrganizer.shared.tripDetails.destination.name
                let response = try await imageService.fetchImageURL(for: destinationName)
                await MainActor.run {
                    state.imageUrlResponse = .loaded(response)
                }
            } catch {
                // Handle any errors during the image fetch
                await MainActor.run {
                    state.imageUrlResponse = .error(error)
                }
            }
        }
    }
    
    private func reSaveTrip() {
        guard case let .loaded(itinerary) = state.itineraryResponse,
              case let .loaded(suggestions) = state.suggestionsResponse else {
            return
        }
        
        // Build the full Trip with all the data in the current statae
        let trip = Trip(
            details: state.details,
            itinerary: itinerary,
            suggestions: suggestions,
            favorites: state.favorites
        )
        
        Task {
             do {
                 let storage = try TripStorage()
                 try storage.save(trip)
             } catch {
                 // Handle error (could add error state)
                 print("Failed to save trip: \(error)")
             }
         }
    }

    private func saveTrip(confirmOverride: Bool) {
        guard case let .loaded(itinerary) = state.itineraryResponse else {
            print("saveTrip: Data not loaded yet. itinerary: \(state.itineraryResponse), suggestions: \(state.suggestionsResponse)")
            return 
        }
                
        // Build the full Trip with all the data in the current statae
        let trip = Trip(
            details: state.details,
            itinerary: itinerary,
            suggestions: state.suggestionsResponse.data ?? .init(),
            favorites: state.favorites
        )
       
        // Save
        Task {
            do {
                let storage = try TripStorage()
                let existing = try storage.fetch(inGrouping: trip.groupingFolder).first { $0.duplicateIdentity == trip.duplicateIdentity }
                if existing != nil && !confirmOverride {
                    // Show dialog to confirm override
                    await MainActor.run {
                        state.alert = .override
                    }
                    return
                }
                
                // Save trip (override if needed)
                try storage.save(trip)
                await MainActor.run {
                    presentSaveToast = true
                    state.saved = true
                    
                    // If the unsaved trip dialog was showing, navigate back after saving
                    if state.alert == .unsavedTrip {
                        router?.pop()
                    }
                    
                    state.alert = nil
                }
            } catch {
                // Handle error (could add error state)
                print("Failed to save trip: \(error)")
            }
        }
    }

    private func deleteTrip() {
        guard case let .loaded(itinerary) = state.itineraryResponse,
              case let .loaded(suggestions) = state.suggestionsResponse else { return }
        
        Task {
            do {
                let storage = try TripStorage()
                let trip = Trip(
                    details: state.details,
                    itinerary: itinerary,
                    suggestions: suggestions,
                    favorites: state.favorites
                )
                try storage.delete(trip)
                await MainActor.run {
                    state.alert = nil
                    router?.pop()
                }
            } catch {
                print("Failed to delete trip: \(error)")
            }
        }
    }
}

extension TripOutputStore.State {
    enum AlertType: Identifiable {
        case override
        case removeFavorite
        case deleteTrip
        case unsavedTrip
        
        var id: String {
            switch self {
            case .override: return "override"
            case .removeFavorite: return "removeFavorite"
            case .deleteTrip: return "deleteTrip"
            case .unsavedTrip: return "unsavedTrip"
            }
        }
    }
    
    enum Mode {
        case newTrip
        case savedTrip
    }
}

private enum OpenAIConstant {
//    static let APIKey = "REDACTED_OPENAI_KEY_1"
    
#if DEBUG
    static let itineraryAssistantID = "asst_6eZs6kr3eOhrhl03aBfRu5Pu"
#else
    static let itineraryAssistantID = "asst_TcB4WiN4enei0jZRqShdJZW6"
#endif
    
#if DEBUG
    static let suggestionsAssistantID = "asst_h37N5cPCsTH9shtYrPystV7k"
#else
    static let suggestionsAssistantID = "asst_HRaOX8m3cHczvden1N1B6Cko"
#endif
}


