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
    /// Favourites are a full-screen sheet reached from the header, not a tab.
    @Published var isFavouritesSheetPresented: Bool = false
    @Published var isPublishingShare: Bool = false
    /// Non-nil → present the native share sheet for this URL.
    @Published var shareSheetURL: URL?
    @Published var shareErrorMessage: String?
    /// Ephemeral UI state for the one spend-gated deep-dive call allowed at a
    /// time. The generated content itself lives in `State.deepDives`.
    @Published private(set) var deepDiveInFlightInterest: String?
    @Published private(set) var deepDiveErrorMessage: String?
    @Published private(set) var deepDiveCapReached = false

    /// Server-side duplicate/cap errors can reveal committed slots missing
    /// from this local copy. Remember them for this screen lifetime so a chip
    /// does not immediately offer the same rejected request again.
    private var blockedDeepDiveInterestKeys: Set<String> = []
    
    // Navigation
    var router: NavigationRouter?
    
    private let itineraryService: any ItineraryGenerating
    private let suggestionsService: any SuggestionsGenerating
    private let worthItService: any WorthItGenerating
    private let whereToStayService: any WhereToStayGenerating
    private let knowBeforeYouGoService: any KnowBeforeYouGoGenerating
    private let deepDiveService: any DeepDiveGenerating

    private let imageService: ImageService

    /// Which arm of the D15 experiment this store runs. Injectable so a test
    /// can exercise both without rebuilding, and so the eventual removal of the
    /// losing arm is a change in one constant rather than a hunt through here.
    private let variant: SuggestionsVariant

    /// Owns every in-flight generation task for this screen. See
    /// `TripGenerationCoordinator` for why nothing may bypass it.
    private let coordinator = TripGenerationCoordinator()

    init(
        initialState: State,
        imageService: ImageService = UnsplashService(),
        itineraryService: (any ItineraryGenerating)? = nil,
        suggestionsService: (any SuggestionsGenerating)? = nil,
        worthItService: (any WorthItGenerating)? = nil,
        whereToStayService: (any WhereToStayGenerating)? = nil,
        knowBeforeYouGoService: (any KnowBeforeYouGoGenerating)? = nil,
        deepDiveService: (any DeepDiveGenerating)? = nil,
        variant: SuggestionsVariant = OutputFeatureFlags.suggestionsVariant
    ) {
        state = initialState
        self.imageService = imageService
        self.variant = variant
        self.itineraryService = itineraryService ?? TripPlanningServices.itinerary()
        self.suggestionsService = suggestionsService ?? TripPlanningServices.suggestions()
        self.worthItService = worthItService ?? TripPlanningServices.worthIt()
        self.whereToStayService = whereToStayService ?? TripPlanningServices.whereToStay()
        self.knowBeforeYouGoService = knowBeforeYouGoService ?? TripPlanningServices.knowBeforeYouGo()
        self.deepDiveService = deepDiveService ?? TripPlanningServices.deepDive()
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
            for component in TripComponent.automatic(variant: variant) {
                generate(component)
            }

            // Always try to fetch Images
            fetchDestinationImage()

        case .retry:
            retryCount += 1
            // Re-runs exactly the components that need it. Previously this
            // re-ran the itinerary only, so a suggestions failure was
            // unrecoverable without regenerating the entire trip.
            for component in TripComponent.automatic(variant: variant)
            where response(for: component).needsRetry {
                generate(component, restart: true)
            }
            fetchDestinationImage()

        case .retryComponent(let component):
            // The in-place "Try again" on one tab. Same coordinator path as the
            // screen-level retry, so it still cancels and supersedes rather than
            // racing whatever was outstanding.
            retryCount += 1
            generate(component, restart: true)

        case .decideWorthIt(let id, let decision):
            applyWorthIt(decision, to: id)

        case .generateDeepDive(let interest):
            generate(.deepDive, interest: interest)

        case .saveTrip(let confirmOverride):
            saveTrip(confirmOverride: confirmOverride)

        case .shareTrip:
            shareTrip()


        case .removeFavorite(let id):
            removeFavourite(id)


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
        var selectedContentTab: OutputTab = .discover
        var discoverSegment: DiscoverSegment = .suggestions
        var favorites: Trip.Favorites = .init()
        var saved: Bool = false
        let mode: Mode
        /// The code this trip was published under (if the owner has shared it)
        /// or received via (if this is a locally-cached shared trip). `nil` for
        /// a trip that has never been shared.
        var shareCode: String? = nil

        var itineraryResponse: AsyncValue<Trip.Itinerary> = .initial
        var suggestionsResponse: AsyncValue<Trip.Suggestions> = .initial
        var knowBeforeYouGoResponse: AsyncValue<Trip.KnowBeforeYouGo> = .initial
        var imageUrlResponse: AsyncValue<URL> = .initial
        var didLogResultViewed = false

        /// The Worth-it/Skip cards, as their own component state.
        ///
        /// Its own `AsyncValue` even under the combined variant, where these
        /// arrive on the suggestions call: the segment needs to be able to say
        /// "still writing" and "that didn't come through" on its own, and the
        /// UI must not be able to tell which arm of the D15 experiment ran.
        var worthItResponse: AsyncValue<[Trip.WorthItItem]> = .initial

        /// The where-to-stay guide (D10).
        var whereToStayResponse: AsyncValue<[Trip.StayArea]> = .initial

        /// The three model-picked interest labels. The three fixed ones are a
        /// client-side constant and are added at the point of display.
        var interestPrompts: [String] = []

        /// The cards themselves, for the many read sites that only want the
        /// content. `nil` covers "not asked", "still running" and "failed"
        /// alike — the states the section itself distinguishes.
        var worthItItems: [Trip.WorthItItem]? { worthItResponse.data }

        /// The traveller's calls on those cards. An id with no entry is
        /// *undecided*, which is where every card starts and where Undo returns
        /// it. Always non-`nil` so a save writes what the traveller actually
        /// decided, including "nothing any more".
        var worthItDecisions: [UUID: WorthItDecision] = [:]

        /// Interest deep dives already paid for on this trip, carried so a
        /// re-save cannot drop them and so their items stay heartable.
        var deepDives: [Trip.Suggestions.Category]? = nil


        var fullDestinationString: String {
            itineraryResponse.data?.destination ?? details.destination.name
        }
        
        var nonLoaded: Bool {
            !itineraryResponse.isLoaded || !suggestionsResponse.isLoaded
        }
        
        // Dialogs & Sheets
        var alert: AlertType? = nil
    }

    enum Action: Equatable {
        case onAppear
        case closeAlert
        case retry
        /// Retry exactly one component, from that component's own error state.
        case retryComponent(TripComponent)
        /// Record (or, with `nil`, undo) a Worth-it/Skip decision.
        case decideWorthIt(UUID, WorthItDecision?)
        /// Generate one append-only category for the tapped interest chip.
        case generateDeepDive(String)
        case saveTrip(confirmOverride: Bool = false)
        case shareTrip
        /// Confirmation is the presenter's job — the favourites sheet owns its
        /// own alert, because one presented by the screen underneath would
        /// dismiss the sheet in order to appear.
        case removeFavorite(UUID)
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

// MARK: - Shell

extension TripOutputStore {
    /// The tabs this screen offers.
    ///
    /// Visibility is a product rule, not a rendering detail: Near You is
    /// personal and address-grounded, so it is absent from the read-only modes
    /// entirely and gated behind ``OutputFeatureFlags/nearYouEnabled`` until
    /// there is real grounding behind it.
    var visibleTabs: [OutputTab] {
        var tabs: [OutputTab] = [.discover]
        if OutputFeatureFlags.nearYouEnabled && !state.mode.isReadOnly {
            tabs.append(.nearYou)
        }
        if OutputFeatureFlags.knowBeforeYouGoEnabled {
            tabs.append(.knowBeforeYouGo)
        }
        return tabs
    }

    /// The pills inside Discover.
    ///
    /// Worth-it/Skip appears only when there are cards, and never on a group
    /// trip: deciding is personal, and a group trip has no personal layer to
    /// record the decision in.
    var discoverSegments: [DiscoverSegment] {
        var segments: [DiscoverSegment] = [.suggestions]
        if showsWorthItSegment { segments.append(.worthIt) }
        segments.append(.itinerary)
        return segments
    }

    /// Whether Worth-it/Skip gets a pill at all.
    ///
    /// It earns one the moment its call starts, not when the content lands, so
    /// the segment can show its own "still writing" and "that didn't come
    /// through" states rather than materialising out of nowhere partway through
    /// generation. A trip that never asked for cards — an old saved file — has
    /// no pill, and a call that came back genuinely empty loses it again.
    private var showsWorthItSegment: Bool {
        guard state.mode != .groupTrip else { return false }
        switch state.worthItResponse {
        case .initial: return false
        case .loading, .error: return true
        case .loaded(let items): return !items.isEmpty
        }
    }

    /// The Worth-it/Skip section's state, already filtered by mode.
    var worthItValue: AsyncValue<[Trip.WorthItItem]> {
        state.mode == .groupTrip ? .loaded([]) : state.worthItResponse
    }

    /// The Worth-it/Skip cards to render, already filtered by mode.
    var worthItCards: [Trip.WorthItItem] {
        guard state.mode != .groupTrip else { return [] }
        return state.worthItItems ?? []
    }

    func worthItDecision(for id: UUID) -> WorthItDecision? {
        state.worthItDecisions[id]
    }

    /// The chips offered under the suggestions feed (D8).
    ///
    /// Three from the model plus three fixed ones the app always offers. The
    /// fixed three are appended rather than interleaved so their position is
    /// stable across trips, and a model label that duplicates one of them is
    /// dropped — the backend already filters these, but a shared trip from an
    /// older build can carry a duplicate, and a chip row with "Climbing gyms"
    /// twice is a bug the traveller can see.
    static let fixedInterestChips = ["Running routes", "Remote-work cafés", "Climbing gyms"]
    static let maxDeepDives = 3

    var interestChips: [String] {
        var seen = Set<String>()
        return (state.interestPrompts + Self.fixedInterestChips).filter {
            seen.insert(Self.chipKey($0)).inserted
        }
    }

    /// The exact chip labels whose result is already committed locally.
    /// `requestedInterest` is present on S8 results; title is the migration
    /// fallback for older files that already carried a hand-built deep dive.
    var usedDeepDiveInterests: Set<String> {
        let usedKeys = Set((state.deepDives ?? []).map {
            Self.chipKey($0.requestedInterest ?? $0.title)
        }).union(blockedDeepDiveInterestKeys)
        return Set(interestChips.filter { usedKeys.contains(Self.chipKey($0)) })
    }

    /// Client courtesy only; D9's actual control remains the backend mutation.
    var canGenerateDeepDive: Bool {
        state.generationRequest != nil
            && !state.mode.isReadOnly
            && !deepDiveCapReached
            && (state.deepDives?.count ?? 0) < Self.maxDeepDives
            && deepDiveInFlightInterest == nil
    }

    /// Storage keeps dives separate for provenance and cap accounting (§10),
    /// while the feed renders them inline as additional dynamic categories.
    var suggestionsWithDeepDives: AsyncValue<Trip.Suggestions> {
        switch state.suggestionsResponse {
        case .initial:
            return .initial
        case .loading:
            return .loading
        case .error(let error):
            return .error(error)
        case .loaded(let suggestions):
            return .loaded(Trip.Suggestions(
                dynamicSuggestions: suggestions.dynamicSuggestions + (state.deepDives ?? []),
                staticSuggestions: suggestions.staticSuggestions
            ))
        }
    }

    /// Folds case, accents and punctuation, so "Remote-work cafés" and
    /// "Remote work cafes" are one chip. Mirrors `normaliseChip` in the
    /// backend's `validation.ts`.
    private static func chipKey(_ label: String) -> String {
        label
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    /// Whether this trip can never show a briefing.
    ///
    /// A trip generated before Know Before You Go existed has none stored, and
    /// a saved, group or received trip has no `generationRequest` to ask for one
    /// with — deliberately, since §4's rule is that reopening a trip never
    /// silently spends the traveller's quota. Without this the tab would sit on
    /// its loading state forever, because "never started" and "still running"
    /// are the same `AsyncValue`.
    var knowBeforeYouGoIsUnavailable: Bool {
        state.generationRequest == nil && response(for: .knowBeforeYouGo).isUnstarted
    }
}

// MARK: - Favourites

extension TripOutputStore {
    /// The trip as the favourites plumbing sees it. Built from live screen
    /// state so a favourite made seconds ago resolves, and from **one** walk of
    /// the content — the screen used to keep its own second copy of that walk,
    /// which is how the two drifted apart and place links stopped rendering
    /// in the favourites list.
    private var favouritesSourceTrip: Trip? {
        guard case let .loaded(itinerary) = state.itineraryResponse else { return nil }
        return Trip(
            details: state.details,
            itinerary: itinerary,
            suggestionsState: state.suggestionsResponse.persisted,
            knowBeforeYouGoState: state.knowBeforeYouGoResponse.persisted,
            deepDives: state.deepDives,
            worthItItems: state.worthItResponse.persistedContent,
            worthItDecisions: state.worthItDecisions,
            whereToStay: state.whereToStayResponse.persistedContent,
            interestPrompts: state.interestPrompts.isEmpty ? nil : state.interestPrompts,
            favorites: state.favorites
        )
    }

    /// Favourites grouped by their heading, in a deterministic order.
    var favouriteSections: [Trip.FavouriteSection] {
        favouritesSourceTrip?.favouriteSections(state.favorites) ?? []
    }

    var favouriteCount: Int {
        state.favorites.liked.count
    }

    /// Removes a favourite **and** clears any decision attached to it.
    ///
    /// This is the row of the invariant table that breaks if the two stores are
    /// touched independently: un-hearting a Worth-it card from the favourites
    /// screen has to return that card to undecided, or the traveller is left
    /// with a card showing "kept" that is not in their favourites. Nothing else
    /// may mutate `favorites` and `worthItDecisions` at separate call sites.
    func removeFavourite(_ id: UUID) {
        state.favorites.remove(id)
        state.worthItDecisions[id] = nil
    }

    /// Records a Worth-it/Skip decision, or undoes it with `nil`.
    ///
    /// | Action | Decision | Favourites |
    /// |---|---|---|
    /// | Add to favourites | `.kept` | insert |
    /// | Undo from `.kept` | undecided | remove |
    /// | Skip it | `.skipped` | unchanged |
    /// | Undo from `.skipped` | undecided | unchanged |
    private func applyWorthIt(_ decision: WorthItDecision?, to id: UUID) {
        let previous = state.worthItDecisions[id]
        state.worthItDecisions[id] = decision

        switch (previous, decision) {
        case (_, .kept):
            state.favorites.insert(id)
        case (.kept, _):
            // Leaving `.kept` — by undo, or by changing one's mind to `.skipped`
            // — must take the favourite with it. "Kept" and "in favourites" are
            // the same fact stored twice; they are never allowed to disagree.
            state.favorites.remove(id)
        case (.skipped, _), (nil, _):
            // Skipping, and undoing a skip, deliberately leave favourites alone.
            break
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
    func generate(
        _ requested: TripComponent,
        interest: String? = nil,
        restart: Bool = false
    ) {
        let component = owningComponent(requested)
        guard let request = state.generationRequest else { return }
        let deepDiveInterest = interest?.trimmingCharacters(in: .whitespacesAndNewlines)
        if component == .deepDive {
            guard let deepDiveInterest, !deepDiveInterest.isEmpty,
                  canGenerateDeepDive,
                  !usedDeepDiveInterests.contains(deepDiveInterest) else { return }
        } else {
            guard restart || response(for: component).isUnstarted else { return }
        }

        // Derived at call time, from what this trip currently holds (§11).
        // Never persisted: a stored copy goes stale the moment a component is
        // retried or a deep dive lands, and a stale list still looks like a
        // list. Computed here rather than inside the task so it reflects the
        // state at the moment the call was decided on.
        let context = alreadyRecommended()

        let startedAt = Date()
        let attempt = coordinator.begin(component, restart: restart) { [weak self] attempt in
            guard let self else { return }
            defer {
                if component == .deepDive,
                   coordinator.isCurrent(component, attempt: attempt) {
                    deepDiveInFlightInterest = nil
                }
            }
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
                    let payload = try await suggestionsService.generate(
                        request, alreadyRecommended: context
                    )
                    guard coordinator.isCurrent(component, attempt: attempt) else { return }
                    apply(payload)

                case .worthIt:
                    let items = try await worthItService.generate(
                        request, alreadyRecommended: context
                    )
                    guard coordinator.isCurrent(component, attempt: attempt) else { return }
                    state.worthItResponse = .loaded(items)

                case .whereToStay:
                    let areas = try await whereToStayService.generate(request)
                    guard coordinator.isCurrent(component, attempt: attempt) else { return }
                    state.whereToStayResponse = .loaded(areas)

                case .knowBeforeYouGo:
                    let briefing = try await knowBeforeYouGoService.generate(request)
                    guard coordinator.isCurrent(component, attempt: attempt) else { return }
                    state.knowBeforeYouGoResponse = .loaded(briefing)

                case .deepDive:
                    guard let deepDiveInterest else { return }
                    let category = try await deepDiveService.generate(
                        request,
                        interest: deepDiveInterest,
                        alreadyRecommended: context
                    )
                    guard coordinator.isCurrent(component, attempt: attempt) else { return }
                    // Preserve the model's display title while carrying the
                    // exact tapped label for duplicate prevention after reopen.
                    let persisted = Trip.Suggestions.Category(
                        id: category.id,
                        ID: category.ID,
                        title: category.title,
                        texts: category.texts,
                        requestedInterest: deepDiveInterest
                    )
                    state.deepDives = (state.deepDives ?? []) + [persisted]
                    if state.saved { reSaveTrip() }
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
                if component == .deepDive {
                    setDeepDiveFailure(error, interest: deepDiveInterest)
                } else {
                    setFailure(component, error)
                }
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
        if component == .deepDive {
            deepDiveInFlightInterest = deepDiveInterest
            deepDiveErrorMessage = nil
        }
        setLoading(component)
        logGeneration(
            .tripGenerationStarted,
            component: component.rawValue,
            attempt: attempt
        )
    }

    /// Which call actually produces a section, in this build's variant.
    ///
    /// Under `combined` the Worth-it cards and the where-to-stay guide have no
    /// call of their own — they arrive on the suggestions response. Every entry
    /// point routes through here so that "retry the Worth-it cards" means the
    /// same thing to the coordinator, to single-flight and to the retry
    /// affordance, whichever arm is running.
    private func owningComponent(_ component: TripComponent) -> TripComponent {
        guard variant == .combined else { return component }
        return component == .worthIt || component == .whereToStay ? .suggestions : component
    }

    /// Everything the suggestions call brought back, fanned out.
    ///
    /// Under the split variant this is only the categories and the chips; the
    /// two sections keep whatever their own calls produced. Under the combined
    /// variant it carries all four, and a section the backend had to drop
    /// lands as a genuinely-empty `.loaded([])` — not as `.initial`, which
    /// would claim it was never asked for.
    private func apply(_ payload: SuggestionsPayload) {
        state.suggestionsResponse = .loaded(payload.suggestions)
        if !payload.interestPrompts.isEmpty {
            state.interestPrompts = payload.interestPrompts
        }
        guard variant == .combined else { return }
        state.worthItResponse = .loaded(payload.worthIt ?? [])
        state.whereToStayResponse = .loaded(payload.whereToStay ?? [])
    }

    /// This screen's live state for one component, flattened so the coordinator
    /// logic can reason about every component without caring what it holds.
    func response(for component: TripComponent) -> ComponentResponse {
        switch component {
        case .itinerary: ComponentResponse(state.itineraryResponse)
        case .suggestions: ComponentResponse(state.suggestionsResponse)
        case .knowBeforeYouGo: ComponentResponse(state.knowBeforeYouGoResponse)
        case .worthIt: ComponentResponse(state.worthItResponse)
        case .whereToStay: ComponentResponse(state.whereToStayResponse)
        case .deepDive: ComponentResponse(AsyncValue<Trip.Suggestions>.initial)
        }
    }

    /// Places this trip has already put in front of the traveller (§11).
    ///
    /// Built from live screen state, not from disk, so a component that landed
    /// seconds ago counts and a component that was just retried contributes its
    /// new places rather than its old ones. Empty until the itinerary arrives,
    /// which is correct: the parallel calls that start alongside it genuinely
    /// have nothing to avoid yet.
    func alreadyRecommended() -> [String] {
        favouritesSourceTrip?.alreadyRecommended ?? []
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
        case .suggestions:
            state.suggestionsResponse = .loading
            // Under the combined variant these three share one call, so they
            // share its states too — including its failure. That coupling is
            // not an implementation detail to hide; it is precisely the cost
            // D15 weighs, and burying it would make the arm look better than
            // it is.
            if variant == .combined {
                state.worthItResponse = .loading
                state.whereToStayResponse = .loading
            }
        case .worthIt: state.worthItResponse = .loading
        case .whereToStay: state.whereToStayResponse = .loading
        case .knowBeforeYouGo: state.knowBeforeYouGoResponse = .loading
        case .deepDive: break
        }
    }

    private func setFailure(_ component: TripComponent, _ error: Error) {
        switch component {
        case .itinerary: state.itineraryResponse = .error(error)
        case .suggestions:
            state.suggestionsResponse = .error(error)
            if variant == .combined {
                state.worthItResponse = .error(error)
                state.whereToStayResponse = .error(error)
            }
        case .worthIt: state.worthItResponse = .error(error)
        case .whereToStay: state.whereToStayResponse = .error(error)
        case .knowBeforeYouGo: state.knowBeforeYouGoResponse = .error(error)
        case .deepDive: break
        }
    }

    private func setDeepDiveFailure(_ error: Error, interest: String?) {
        guard let generation = error as? TripGenerationError else {
            deepDiveErrorMessage = "Couldn't open that deep dive. Try again."
            return
        }
        switch generation {
        case .deepDiveLimit:
            deepDiveCapReached = true
            deepDiveErrorMessage = "You've opened all three deep dives for this trip."
        case .duplicateDeepDive:
            if let interest { blockedDeepDiveInterestKeys.insert(Self.chipKey(interest)) }
            deepDiveErrorMessage = "That deep dive is already part of this trip."
        case .installDailyLimit:
            deepDiveErrorMessage = "You've reached today's generation limit. Try again tomorrow."
        case .serviceBusy:
            deepDiveErrorMessage = "Deep dives are busy right now. Try again later."
        case .truncatedOutput, .backend, .transport:
            deepDiveErrorMessage = "Couldn't open that deep dive. Try again."
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
            knowBeforeYouGoState: state.knowBeforeYouGoResponse.persisted,
            deepDives: state.deepDives,
            worthItItems: state.worthItResponse.persistedContent,
            // Always written, never `nil`: the personal layer is a live edit, so
            // "the traveller undid every decision" has to reach disk as an empty
            // map rather than as "I don't know", which `merged(over:)` would
            // resolve back to the stored decisions.
            worthItDecisions: state.worthItDecisions,
            whereToStay: state.whereToStayResponse.persistedContent,
            interestPrompts: state.interestPrompts.isEmpty ? nil : state.interestPrompts,
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
                    // Destination-wide content, so it travels with the share —
                    // unlike the personal layer, which deliberately does not.
                    knowBeforeYouGo: state.knowBeforeYouGoResponse.data,
                    favorites: state.favorites,
                    deepDives: state.deepDives,
                    // Content travels; decisions do not (§4). The recipient
                    // gets the four cards undecided, because deciding is the
                    // point of the section — there is deliberately no argument
                    // here to pass `worthItDecisions` through.
                    worthItItems: state.worthItResponse.data,
                    whereToStay: state.whereToStayResponse.data,
                    interestPrompts: state.interestPrompts,
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
        case deleteTrip
        case unsavedTrip
        
        var id: String {
            switch self {
            case .override: return "override"
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
