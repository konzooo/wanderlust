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
    @Environment(\.navigationTab) private var navigationTab
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var isDrawerOpen = false
    @State private var hasDismissedOutputOnThisVisit = false
    @State private var previousFavoriteCount = 0
    @State private var pendingGroupNearYouReplacement: GroupNearYouReplacementAction?
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
                .ignoresSafeArea(.container, edges: .vertical)
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
            title: "Saved to My Trips",
            subtitle: nil,
            isPresented: $store.presentSaveToast,
            position: .bottom
        )
        .sensoryFeedback(.success, trigger: store.presentSaveToast)

        // Favourites: a full-screen sheet off the header pill, not a tab.
        .sheet(isPresented: $store.isFavouritesSheetPresented) {
            FavouritesSheet(
                destination: store.fullDestinationString,
                imageUrlState: store.state.imageUrlResponse,
                sections: store.favouriteSections,
                privacyNote: store.state.mode == .groupTrip
                    ? "These favourites are yours on this device. They are not shared with the group."
                    : nil,
                onRemoveFavorite: { favoriteId in
                    store.send(.removeFavorite(favoriteId))
                },
                onClose: { store.isFavouritesSheetPresented = false }
            )
        }

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

        .alert("This is the group's only regeneration", isPresented: Binding(
            get: { pendingGroupNearYouReplacement != nil },
            set: { if !$0 { pendingGroupNearYouReplacement = nil } }
        )) {
            Button("Continue", role: .destructive) {
                let action = pendingGroupNearYouReplacement
                pendingGroupNearYouReplacement = nil
                performGroupNearYouReplacement(action)
            }
            Button("Cancel", role: .cancel) {
                pendingGroupNearYouReplacement = nil
            }
        } message: {
            Text("The shared Near You result can be replaced successfully only once. After this, nobody in the group can regenerate it again.")
        }

        // On appear trigger Itinerary generation
        .onAppear {
            AnalyticsTracker.shared.log(.screenViewed(.tripOutput))
            store.setRouter(router, tab: navigationTab)
            store.send(.onAppear)
            store.logResultViewedIfNeeded()
            store.logCurrentSectionViewed()
            previousFavoriteCount = store.state.favorites.liked.count
        }
        .onChange(of: store.state.itineraryResponse.isLoaded) { _, isLoaded in
            guard isLoaded else { return }
            store.logTripCreatedIfNeeded()
            store.logResultViewedIfNeeded()
            store.logCurrentSectionViewed()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            store.send(.applicationDidEnterBackground)
        }
        .onChange(of: store.state.selectedContentTab) { _, _ in
            store.logCurrentSectionViewed()
        }
        .onChange(of: store.state.discoverSegment) { _, _ in
            store.logCurrentSectionViewed()
        }
        .onChange(of: store.state.favorites.liked.count) { oldCount, newCount in
            guard newCount != previousFavoriteCount else { return }
            store.logFavoriteChange(action: newCount > oldCount ? "added" : "removed")
            previousFavoriteCount = newCount
        }
    }
    
    var mainTripContent: some View {
        VStack(spacing: 0) {
            // -- HEADER
            itineraryHeader

            // -- TAB BAR
            DS.ContentTabBar(
                selection: $store.state.selectedContentTab,
                tabs: store.visibleTabs
            )

            outputTabSubtitle

            // -- CONTENT
            switch store.selectedContentTab {
            case .discover:
                discoverTab

            case .nearYou:
                NearYouView(
                    accommodation: store.state.accommodation,
                    result: store.state.nearYouResponse,
                    addressResolution: store.state.nearYouAddressResolution,
                    whereToStay: store.state.whereToStayResponse,
                    destination: store.fullDestinationString,
                    isGroup: store.state.mode == .groupTrip,
                    setBy: store.state.groupNearYouSetBy,
                    canReplace: store.canReplaceGroupNearYou,
                    favorites: favoritesBinding,
                    onSearchAddress: { store.send(.resolveNearYouAddress($0)) },
                    onSearchSuggestion: { store.send(.resolveNearYouSuggestion($0)) },
                    onResetLocationSearch: { store.send(.resetNearYouLocationSearch) },
                    onChooseResolution: { store.send(.chooseNearYouResolution($0)) },
                    onRetryWhereToStay: canRetry
                        ? { store.send(.retryComponent(.whereToStay)) }
                        : nil,
                    onRetryNearYou: { store.send(.retryNearYou) },
                    onRegenerate: { requestGroupNearYouReplacement(.regenerate) },
                    onChangeStay: { requestGroupNearYouReplacement(.changeStay) }
                )

            case .knowBeforeYouGo:
                KnowBeforeYouGoView(
                    value: store.state.knowBeforeYouGoResponse,
                    destination: store.fullDestinationString,
                    unavailable: store.knowBeforeYouGoIsUnavailable,
                    onRetry: canRetry ? { store.send(.retryComponent(.knowBeforeYouGo)) } : nil
                )
            }
        }
        .gradientBackground()
        .animation(.easeInOut, value: store.state.selectedContentTab)
    }

    private var outputTabSubtitle: some View {
        Text(outputTabSubtitleText)
            .font(.kanit(14))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, .Padding.sm3)
            .padding(.top, 12)
            .padding(.bottom, 2)
            .id(store.selectedContentTab)
            .transition(.opacity)
    }

    private var outputTabSubtitleText: String {
        switch store.selectedContentTab {
        case .discover:
            "Ideas shaped around your unique profile and preferences"
        case .knowBeforeYouGo:
            "The practical brief for \(store.fullDestinationString) — all in one overview"
        case .nearYou:
            "Your neighborhood, vibes, and practical essentials"
        }
    }

    /// Discover: the quiet section navigation, then whichever output it selected.
    /// The navigation lives outside the content's scroll view so it stays put.
    @ViewBuilder
    var discoverTab: some View {
        DiscoverSectionNavigation(
            selection: $store.state.discoverSegment,
            segments: store.discoverSegments
        )

        switch store.state.discoverSegment {
        case .suggestions:
            TravelTipsView(
                suggestions: store.suggestionsWithDeepDives,
                favorites: favoritesBinding,
                deepDiveLoadingInterest: store.deepDiveInFlightInterest,
                isCompletingSuggestions: store.isSuggestionsTopUpInFlight,
                suggestionsCompletionFailed: store.suggestionsTopUpFailed,
                onRetryCompletion: {
                    store.send(.retrySuggestionsTopUp)
                },
                onRetry: canRetry ? { store.send(.retryComponent(.suggestions)) } : nil
            ) {
                // This is the end of the suggestions feed, not a second view
                // competing with it for screen height. It appears only after
                // the traveller scrolls past all generated sections.
                if OutputFeatureFlags.interestChipsEnabled && store.state.mode != .sharedTrip {
                    InterestChipsRow(
                        chips: store.interestChips,
                        used: store.usedDeepDiveInterests,
                        loading: store.deepDiveInFlightInterest,
                        guidance: store.deepDiveGuidanceMessage,
                        capReached: store.isDeepDiveCapReached,
                        onTap: store.canGenerateDeepDive
                            ? { store.send(.generateDeepDive($0)) }
                            : nil
                    )
                }
            }
            .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))

        case .worthIt:
            WorthItSkipView(
                items: store.worthItValue,
                decision: { store.worthItDecision(for: $0) },
                onDecide: { store.send(.decideWorthIt($0, $1)) },
                onRetry: canRetry ? { store.send(.retryComponent(.worthIt)) } : nil
            )
            .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))

        case .itinerary:
            // No inline retry here on purpose: the itinerary is the *required*
            // component, so this screen never gets as far as the tabs without
            // it. Its loading and its recovery are the screen-level `LoadingView`
            // and `RetryErrorView` above — an inline "Try again" inside a
            // segment you can only reach once it succeeded would be unreachable.
            ItineraryCard(
                tripItinerary: store.itineraryResponse,
                favorites: favoritesBinding
            )
        }
    }

    /// A read-only trip has nothing to re-request — its content was generated
    /// elsewhere and simply arrived, so offering "Try again" would be a button
    /// that does nothing.
    private var canRetry: Bool {
        !store.state.mode.isReadOnly
    }

    private var favoritesBinding: Binding<Trip.Favorites> {
        Binding(
            get: { store.state.favorites },
            set: { store.send(.setFavorites($0)) }
        )
    }

    private func requestGroupNearYouReplacement(_ action: GroupNearYouReplacementAction) {
        if store.groupNearYouRequiresReplacementWarning {
            pendingGroupNearYouReplacement = action
        } else {
            performGroupNearYouReplacement(action)
        }
    }

    private func performGroupNearYouReplacement(_ action: GroupNearYouReplacementAction?) {
        switch action {
        case .regenerate: store.send(.regenerateNearYou)
        case .changeStay: store.send(.changeNearYouStay)
        case nil: break
        }
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
            favouriteCount: store.favouriteCount,
            showFavouritesButton: true,
            onShareTapped: {
                store.send(.shareTrip)
            },
            onSaveTapped: {
                if store.state.mode == .savedTrip && store.saved {
                    store.send(.deleteTrip(confirmDeletion: false))
                } else if store.state.mode == .newTrip {
                    store.send(.saveTrip(confirmOverride: false))
                }
            },
            onFavouritesTapped: {
                store.isFavouritesSheetPresented = true
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
        RetryErrorView(
            retryCount: $store.retryCount,
            message: itineraryFailureMessage
        ) {
            store.send(.retry)
        } restartAction: {
            router.popToRoot(on: navigationTab)
        }
    }

    private var itineraryFailureMessage: String {
        guard let error = store.itineraryResponse.error as? TripGenerationError else {
            return "We couldn’t finish building your itinerary.\nPlease try again."
        }

        switch error {
        case .transport:
            return "We couldn’t reach the trip service.\nCheck your connection and try again."
        case .installDailyLimit:
            return "You’ve reached today’s trip-generation limit.\nPlease try again tomorrow."
        case .serviceBusy:
            return "Trip generation is busy right now.\nPlease try again shortly."
        case .truncatedOutput:
            return "Your itinerary came back incomplete.\nPlease try again."
        case .deepDiveLimit, .duplicateDeepDive, .backend:
            return "We couldn’t finish building your itinerary.\nPlease try again."
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

private enum GroupNearYouReplacementAction {
    case regenerate
    case changeStay
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
    var state = TripOutputStore.State(
        generationRequest: .init(input: .mock),
        details: .mock,
        selectedContentTab: .discover,
        mode: .newTrip,
        itineraryResponse: .loaded(.mock),
        suggestionsResponse: .loaded(.mock),
        knowBeforeYouGoResponse: .loaded(.mock),
        imageUrlResponse: .loaded(URL(
            string: "https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=1080&q=80")!
        )
    )
    state.worthItResponse = .loaded(Trip.WorthItItem.mockSet)
    state.whereToStayResponse = .loaded(Trip.StayArea.mockSet)
    state.interestPrompts = ["Natural wine bars", "Rooftop sunsets", "Modernista rooftops"]

    return NavigationStack {
        TripOutputScreen(initialState: state)
    }
    .environmentObject(NavigationRouter())
}
