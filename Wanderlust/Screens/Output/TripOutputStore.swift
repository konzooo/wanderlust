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

    /// Owns every in-flight generation task for this screen. See
    /// `TripGenerationCoordinator` for why nothing may bypass it.
    private let coordinator = TripGenerationCoordinator()

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

            // Start every component that has never been attempted. Components
            // already running are left alone by the coordinator, and a
            // component that FAILED is left alone on purpose: re-generating it
            // silently on every re-appear would spend the traveller's quota
            // without them asking. Recovery is `.retry`.
            for component in TripComponent.automatic {
                generate(component)
            }

            // Always try to fetch Images
            fetchDestinationImage()

        case .retry:
            retryCount += 1
            // Re-runs exactly the components that need it. Previously this
            // re-ran the itinerary only, so a suggestions failure was
            // unrecoverable without regenerating the entire trip.
            for component in TripComponent.automatic where response(for: component).needsRetry {
                generate(component, restart: true)
            }
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
        /// What this trip needs to be generated. `nil` in the read-only modes
        /// (`.groupTrip`, `.sharedTrip`) and on a saved trip that is already
        /// complete — in those cases there is nothing left to ask the backend
        /// for, and the absence is what makes that structurally true rather
        /// than a runtime guard someone can forget.
        var generationRequest: TripGenerationRequest? = nil
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

    // MARK: - Generation

    /// Starts one component, honouring single-flight.
    ///
    /// With `restart: false` (the default) a component that is already running
    /// is left alone and a component that already succeeded is not re-run — the
    /// reason navigating back onto this screen mid-generation no longer buys a
    /// second copy of everything. `restart: true` is the explicit retry path: it
    /// cancels whatever is outstanding and supersedes it.
    func generate(_ component: TripComponent, restart: Bool = false) {
        guard let request = state.generationRequest else { return }
        guard restart || response(for: component).isUnstarted else { return }

        let startedAt = Date()
        let attempt = coordinator.begin(component, restart: restart) { [weak self] attempt in
            guard let self else { return }
            do {
                switch component {
                case .itinerary:
                    let itinerary = try await itineraryService.generate(request)
                    guard coordinator.isCurrent(component, attempt: attempt) else { return }
                    state.itineraryResponse = .loaded(itinerary)
                    // Re-fetch using the destination the model normalized.
                    fetchDestinationImage()
                    logResultViewedIfNeeded()

                case .suggestions:
                    let suggestions = try await suggestionsService.generate(request)
                    guard coordinator.isCurrent(component, attempt: attempt) else { return }
                    state.suggestionsResponse = .loaded(suggestions)

                case .deepDive:
                    // Interest deep dives have no client entry point yet; the
                    // server already enforces their per-trip cap.
                    return
                }
                logGeneration(
                    .tripGenerationSucceeded,
                    component: component.rawValue,
                    attempt: attempt,
                    duration: startedAt
                )
            } catch {
                // A superseded attempt writes nothing — not even its failure.
                // Otherwise a cancelled call's error would land on top of the
                // retry that replaced it.
                guard coordinator.isCurrent(component, attempt: attempt),
                      !(error is CancellationError) else { return }
                setFailure(component, error)
                logGeneration(
                    .tripGenerationFailed,
                    component: component.rawValue,
                    attempt: attempt,
                    duration: startedAt,
                    error: error
                )
            }
        }

        // `nil` means the coordinator suppressed this as a duplicate. The run
        // already in flight owns the component, so leave its state alone.
        guard let attempt else { return }
        setLoading(component)
        logGeneration(
            .tripGenerationStarted,
            component: component.rawValue,
            attempt: attempt
        )
    }

    /// This screen's live state for one component, flattened so the coordinator
    /// logic can reason about every component without caring what it holds.
    func response(for component: TripComponent) -> ComponentResponse {
        switch component {
        case .itinerary: ComponentResponse(state.itineraryResponse)
        case .suggestions: ComponentResponse(state.suggestionsResponse)
        case .deepDive: ComponentResponse(AsyncValue<Trip.Suggestions>.initial)
        }
    }

    struct ComponentResponse: Equatable {
        /// Never attempted. The only state `onAppear` may start from.
        let isUnstarted: Bool
        /// Worth re-running on an explicit retry.
        let needsRetry: Bool

        init<T: Equatable & Sendable>(_ value: AsyncValue<T>) {
            switch value {
            case .initial: (isUnstarted, needsRetry) = (true, true)
            case .loading: (isUnstarted, needsRetry) = (false, false)
            case .error: (isUnstarted, needsRetry) = (false, true)
            case .loaded: (isUnstarted, needsRetry) = (false, false)
            }
        }
    }

    private func setLoading(_ component: TripComponent) {
        switch component {
        case .itinerary: state.itineraryResponse = .loading
        case .suggestions: state.suggestionsResponse = .loading
        case .deepDive: break
        }
    }

    private func setFailure(_ component: TripComponent, _ error: Error) {
        switch component {
        case .itinerary: state.itineraryResponse = .error(error)
        case .suggestions: state.suggestionsResponse = .error(error)
        case .deepDive: break
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
    
    /// Writes the current screen state back onto an already-saved trip.
    ///
    /// Merge-on-complete: the itinerary is the baseline and must be ready, but
    /// anything still generating writes as `.absent` and is merged over what is
    /// already on disk, so a re-save triggered by (say) a favourite toggle can
    /// never wipe a component that finished in an earlier session.
    private func reSaveTrip() {
        guard let trip = currentTrip() else { return }

        Task {
             do {
                 let storage = try TripStorage()
                 let stored = try storage
                     .fetch(inGrouping: trip.groupingFolder)
                     .first { $0.duplicateIdentity == trip.duplicateIdentity }
                 try storage.save(stored.map(trip.merged(over:)) ?? trip)
             } catch {
                 // Handle error (could add error state)
                 print("Failed to save trip: \(error)")
             }
         }
    }

    /// The trip as it currently stands on screen, or `nil` if the baseline
    /// itinerary hasn't arrived yet and there is nothing worth saving.
    ///
    /// Every component is recorded as what it actually is — ready, failed, or
    /// not yet requested. Nothing is filled in with an empty stand-in, which is
    /// what used to make a still-loading suggestions call indistinguishable
    /// from a genuinely empty one for the rest of the trip's life.
    private func currentTrip() -> Trip? {
        guard case let .loaded(itinerary) = state.itineraryResponse else { return nil }
        return Trip(
            details: state.details,
            itinerary: itinerary,
            suggestionsState: state.suggestionsResponse.persisted,
            favorites: state.favorites,
            shareCode: state.shareCode,
            tripKey: state.generationRequest?.tripKey
        )
    }

    private func saveTrip(confirmOverride: Bool) {
        // Saving is permitted as soon as the baseline is ready — that fast save
        // is a flow travellers already have. A component still generating is
        // recorded as `.absent` and merged in by `reSaveTrip` when it lands.
        guard let trip = currentTrip() else {
            print("saveTrip: Data not loaded yet. itinerary: \(state.itineraryResponse), suggestions: \(state.suggestionsResponse)")
            return
        }

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
        // Deletion matches on `duplicateIdentity` (the trip's details), so it
        // only needs the baseline — a trip whose suggestions failed is still a
        // trip the traveller can delete.
        guard let trip = currentTrip() else { return }

        Task {
            do {
                let storage = try TripStorage()
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
        guard state.shareCode != nil, let trip = currentTrip() else { return }
        Task {
            do {
                let storage = try ReceivedSharedTripStorage.received()
                let stored = try storage
                    .fetch(inGrouping: trip.groupingFolder)
                    .first { $0.duplicateIdentity == trip.duplicateIdentity }
                try storage.save(stored.map(trip.merged(over:)) ?? trip)
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
