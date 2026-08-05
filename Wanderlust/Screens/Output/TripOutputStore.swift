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
@MainActor
class TripOutputStore: ObservableStore {
    @Published var state: State

    // UI Bindings
    @Published var retryCount: Int = 0
    @Published var presentSaveToast: Bool = false
    @Published var isPublishingShare: Bool = false
    /// Non-nil → present the native share sheet for this URL.
    @Published var shareSheetURL: URL?
    @Published var shareErrorMessage: String?
    
    // Navigation
    var router: NavigationRouter?
    
    private let itineraryService: any ItineraryGenerating
    private let suggestionsService: any SuggestionsGenerating

    private let imageService: ImageService

    init(
        initialState: State,
        imageService: ImageService = UnsplashService(),
        itineraryService: (any ItineraryGenerating)? = nil,
        suggestionsService: (any SuggestionsGenerating)? = nil
    ) {
        state = initialState
        self.imageService = imageService
        self.itineraryService = itineraryService ?? Self.makeItineraryService()
        self.suggestionsService = suggestionsService ?? Self.makeSuggestionsService()
    }

    /// Builds the itinerary service, substituting mock data when the debug flag is on.
    private static func makeItineraryService() -> any ItineraryGenerating {
        if DebugSettings.useMockTripData {
            return MockItineraryService()
        }
        return TripPlanningServices.itinerary()
    }

    /// Builds the suggestions service, substituting mock data when the debug flag is on.
    private static func makeSuggestionsService() -> any SuggestionsGenerating {
        if DebugSettings.useMockTripData {
            return MockSuggestionsService()
        }
        return TripPlanningServices.suggestions()
    }
    
    func setRouter(_ router: NavigationRouter) {
        self.router = router
    }

    /// Entry point for all user actions. Triggers parallel data fetching.
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            // Group and shared trips are display-only: their itinerary/
            // suggestions come pre-loaded (from the Convex action, or from a
            // locally-cached received trip), so we must NEVER invoke the
            // on-device LLM (that path reads the bundled OpenAI key).
            if state.mode.isReadOnly {
                // A pre-loaded (server- or locally-cache-supplied) image must
                // win: refetching would silently swap it for a different
                // Unsplash pick every time this screen reappears.
                if !state.imageUrlResponse.isLoaded {
                    fetchDestinationImage()
                }
                return
            }

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
            retryCount += 1
            generateItinerary()
            fetchDestinationImage()
            
        case .saveTrip(let confirmOverride):
            saveTrip(confirmOverride: confirmOverride)

        case .shareTrip:
            shareTrip()


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
            if state.mode == .sharedTrip {
                // Unlike `.groupTrip` (no local file, favorite toggles are
                // silently discarded), a shared trip IS a real local file —
                // persist any favorite changes to the recipient's own copy.
                persistReceivedTripFavorites()
                router?.pop()
            } else if state.mode == .groupTrip {
                router?.pop()
            } else if state.saved {
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
        /// The code this trip was published under (if the owner has shared it)
        /// or received via (if this is a locally-cached shared trip). `nil` for
        /// a trip that has never been shared.
        var shareCode: String? = nil

        var itineraryResponse: AsyncValue<Trip.Itinerary> = .initial
        var suggestionsResponse: AsyncValue<Trip.Suggestions> = .initial
        var imageUrlResponse: AsyncValue<URL> = .initial
        var didLogResultViewed = false
        
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
        case shareTrip
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

    /// Fetches and processes itinerary data from the configured LLM provider.
    /// Updates state independently on the main thread.
    func generateItinerary() {
        state.itineraryResponse = .loading
        let startedAt = Date()
        let attempt = retryCount + 1
        logGeneration(.tripGenerationStarted, component: "itinerary", attempt: attempt)
        Task {
            do {
                // Fetch and process the itinerary data
                let response = try await itineraryService.generate(userMessage: state.tripSummary)
                
                // Fetch the image again using the destination normalized by the LLM.
                fetchDestinationImage()
                
                // Save itinerary response
                await MainActor.run {
                    state.itineraryResponse = .loaded(response)
                    logGeneration(
                        .tripGenerationSucceeded,
                        component: "itinerary",
                        attempt: attempt,
                        duration: startedAt
                    )
                    logResultViewedIfNeeded()
                }
            } catch {
                // Handle any errors during the process
                await MainActor.run {
                    state.itineraryResponse = .error(error)
                    logGeneration(
                        .tripGenerationFailed,
                        component: "itinerary",
                        attempt: attempt,
                        duration: startedAt,
                        error: error
                    )
                }
            }
        }
    }

    func generateSuggestions() {
        state.suggestionsResponse = .loading
        let startedAt = Date()
        let attempt = retryCount + 1
        logGeneration(.tripGenerationStarted, component: "suggestions", attempt: attempt)
        Task {
            do {
                // Fetch and process the itinerary data
                let response = try await suggestionsService.generate(userMessage: state.tripSummary)
                await MainActor.run {
                    state.suggestionsResponse = .loaded(response)
                    logGeneration(
                        .tripGenerationSucceeded,
                        component: "suggestions",
                        attempt: attempt,
                        duration: startedAt
                    )
                }
            } catch {
                // Handle any errors during the process
                await MainActor.run {
                    state.suggestionsResponse = .error(error)
                    logGeneration(
                        .tripGenerationFailed,
                        component: "suggestions",
                        attempt: attempt,
                        duration: startedAt,
                        error: error
                    )
                }
            }
        }
    }

    /// Fetches the destination image URL from the image service.
    /// Updates state independently on the main thread. (Read-only modes guard
    /// the *call site* in `onAppear` against refetching a pre-loaded image —
    /// this function itself stays unconditional, since `.newTrip`/`.savedTrip`
    /// intentionally call it a second time once generation normalizes the
    /// destination name.)
    func fetchDestinationImage() {
        let startedAt = Date()
        let attempt = retryCount + 1
        logGeneration(.tripGenerationStarted, component: "image", attempt: attempt)
        Task {
            do {
                // Get destination name and fetch corresponding image. The
                // fallback is this trip's OWN details — never the global solo
                // scratchpad (`TripOrganizer.shared`), which would show the
                // wrong destination for a group or shared trip.
                let destinationName = state.itineraryResponse.data?.destination ?? state.details.destination.name
                let response = try await imageService.fetchImageURL(for: destinationName)
                await MainActor.run {
                    state.imageUrlResponse = .loaded(response)
                    logGeneration(
                        .tripGenerationSucceeded,
                        component: "image",
                        attempt: attempt,
                        duration: startedAt
                    )
                }
            } catch {
                // Handle any errors during the image fetch
                await MainActor.run {
                    state.imageUrlResponse = .error(error)
                    logGeneration(
                        .tripGenerationFailed,
                        component: "image",
                        attempt: attempt,
                        duration: startedAt,
                        error: error
                    )
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
            favorites: state.favorites,
            shareCode: state.shareCode
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
            favorites: state.favorites,
            shareCode: state.shareCode
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
                    AnalyticsTracker.shared.log(
                        .outcome(
                            .tripSaved,
                            outcome: "success",
                            properties: analyticsTripProperties
                        )
                    )
                }
            } catch {
                await MainActor.run {
                    AnalyticsTracker.shared.log(
                        .outcome(
                            .tripSaved,
                            outcome: "failure",
                            error: error,
                            properties: analyticsTripProperties
                        )
                    )
                }
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
                    favorites: state.favorites,
                    shareCode: state.shareCode
                )
                try storage.delete(trip)
                await MainActor.run {
                    state.alert = nil
                    AnalyticsTracker.shared.log(
                        .outcome(
                            .tripDeleted,
                            outcome: "success",
                            properties: analyticsTripProperties
                        )
                    )
                    router?.pop()
                }
            } catch {
                await MainActor.run {
                    AnalyticsTracker.shared.log(
                        .outcome(
                            .tripDeleted,
                            outcome: "failure",
                            error: error,
                            properties: analyticsTripProperties
                        )
                    )
                }
                print("Failed to delete trip: \(error)")
            }
        }
    }

    private func shareTrip() {
        AnalyticsTracker.shared.log(
            .init(.tripShareRequested, properties: analyticsTripProperties)
        )
        // Already published: content is immutable once generated, so
        // re-sharing is a pure client-side reopen — no network, no new code.
        if let code = state.shareCode {
            shareSheetURL = SharedTripLink.url(for: code)
            AnalyticsTracker.shared.log(
                .outcome(
                    .tripShareSucceeded,
                    outcome: "reopened",
                    properties: analyticsTripProperties
                )
            )
            return
        }

        guard case let .loaded(itinerary) = state.itineraryResponse, !isPublishingShare else { return }
        isPublishingShare = true
        shareErrorMessage = nil

        Task { @MainActor in
            defer { isPublishingShare = false }
            do {
                let code = try await SharedTripService.shared.publish(
                    title: itinerary.title ?? state.fullDestinationString,
                    destination: state.fullDestinationString,
                    durationDays: state.details.duration,
                    startMonth: state.details.month.rawValue,
                    groupType: state.details.members.groupType.rawValue,
                    itinerary: itinerary,
                    suggestions: state.suggestionsResponse.data,
                    favorites: state.favorites,
                    imageUrl: state.imageUrlResponse.data?.absoluteString
                )
                state.shareCode = code
                // Persist the code onto the saved file, if there is one. If the
                // trip isn't saved yet, the code still lives in `state` and
                // will land on disk the next time `saveTrip`/`reSaveTrip` runs.
                if state.saved {
                    reSaveTrip()
                }
                shareSheetURL = SharedTripLink.url(for: code)
                AnalyticsTracker.shared.log(
                    .outcome(
                        .tripShareSucceeded,
                        outcome: "published",
                        properties: analyticsTripProperties
                    )
                )
            } catch {
                shareErrorMessage = "Couldn't create a share link. Check your connection and try again."
                AnalyticsTracker.shared.log(
                    .outcome(
                        .tripShareFailed,
                        outcome: "failure",
                        error: error,
                        properties: analyticsTripProperties
                    )
                )
            }
        }
    }

    func logResultViewedIfNeeded() {
        guard !state.didLogResultViewed, state.itineraryResponse.isLoaded else { return }
        state.didLogResultViewed = true
        let name: AnalyticsEventName = state.mode == .groupTrip
            ? .groupResultViewed
            : .tripResultViewed
        AnalyticsTracker.shared.log(.init(name, properties: analyticsTripProperties))
    }

    func logFavoriteChange(action: String) {
        var properties = analyticsTripProperties
        properties["action"] = .string(action)
        properties["favorite_count"] = .integer(state.favorites.liked.count)
        AnalyticsTracker.shared.log(.init(.favoriteChanged, properties: properties))
    }

    private var analyticsTripProperties: [String: AnalyticsValue] {
        var properties: [String: AnalyticsValue] = [
            "trip_type": .string(state.mode.analyticsName),
            "duration_days": .integer(state.details.duration)
        ]
        if let destination = AnalyticsSanitizer.destination(state.fullDestinationString) {
            properties["destination"] = .string(destination)
        }
        return properties
    }

    private func logGeneration(
        _ name: AnalyticsEventName,
        component: String,
        attempt: Int,
        duration startedAt: Date? = nil,
        error: Error? = nil
    ) {
        var properties = analyticsTripProperties
        properties["component"] = .string(component)
        properties["attempt"] = .integer(attempt)
        properties["trip_mode"] = .string(
            state.mode == .groupTrip ? "group" : "solo"
        )
        if let startedAt {
            properties["duration_ms"] = .integer(
                Int(Date().timeIntervalSince(startedAt) * 1_000)
            )
        }
        if let error {
            properties["error_category"] = .string(
                AnalyticsSanitizer.errorCategory(error).rawValue
            )
        }
        AnalyticsTracker.shared.log(.init(name, properties: properties))
    }

    /// Saves the recipient's current favorite selections back onto their local
    /// copy of a received shared trip. Fire-and-forget, mirroring `reSaveTrip`.
    private func persistReceivedTripFavorites() {
        guard case let .loaded(itinerary) = state.itineraryResponse, let code = state.shareCode else { return }
        let trip = Trip(
            details: state.details,
            itinerary: itinerary,
            suggestions: state.suggestionsResponse.data,
            favorites: state.favorites,
            shareCode: code
        )
        Task {
            do {
                let storage = try ReceivedSharedTripStorage.received()
                try storage.save(trip)
            } catch {
                print("Failed to persist received trip favorites: \(error)")
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
        /// Read-only display of a group's generated trip. Never triggers
        /// on-device generation (the itinerary/suggestions are produced by the
        /// Convex action and passed in pre-loaded) and hides personal
        /// save/delete affordances.
        case groupTrip
        /// Read-only display of a trip received via a share link. The content
        /// is already a durable local copy (`ReceivedSharedTripStorage`), so —
        /// unlike `.groupTrip` — there is nothing to re-fetch on later opens.
        /// Never triggers on-device generation; hides save/delete (nothing to
        /// save, it's already saved) and hides the share button (not the
        /// viewer's trip to re-share).
        case sharedTrip
    }
}

extension TripOutputStore.State.Mode {
    /// Server- or locally-cache-supplied, display-only. Gates on-device LLM
    /// generation and back-navigation semantics. (`Mode` has no associated
    /// values, so it already conforms to `Equatable` for free — no explicit
    /// declaration needed, and adding one would be a redundant-conformance error.)
    var isReadOnly: Bool {
        self == .groupTrip || self == .sharedTrip
    }

    var analyticsName: String {
        switch self {
        case .newTrip: "new"
        case .savedTrip: "saved"
        case .groupTrip: "group"
        case .sharedTrip: "received"
        }
    }
}
