import SwiftUI
import DesignSystem
import CoreModels
import Networking
import CoreArchitecture

struct SavedTripsScreen: View {
    @StateObject var store: SavedTripsStore = SavedTripsStore()

    @EnvironmentObject var router: NavigationRouter
    @State private var isDrawerOpen = false
    @State private var segment: Segment = .myTrips
    @State private var groupSummaries: [GroupTripSummary] = []
    @State private var sharedTrips: [Trip] = []
    @State private var didLogView = false

    // Shortened labels so all three fit the segmented control on small
    // devices and at larger Dynamic Type sizes ("My Group Trips" / "Shared
    // with me" would truncate). The feature itself is still called "My Group
    // Trips" everywhere else.
    private enum Segment: String, CaseIterable {
        case myTrips = "My Trips"
        case myGroupTrips = "Group Trips"
        case shared = "Shared"
    }

    @MainActor
    init(store: SavedTripsStore? = nil) {
        self._store = StateObject(wrappedValue: store ?? SavedTripsStore())
    }

    var body: some View {
        VStack(spacing: 0) {
            titleSubtitle

            Picker("View", selection: $segment) {
                ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            switch segment {
            case .myTrips:
                tripsList
                    .padding(.horizontal, 16)
            case .myGroupTrips:
                groupTripsList
                    .padding(.horizontal, 16)
            case .shared:
                sharedTripsList
                    .padding(.horizontal, 16)
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
            AnalyticsTracker.shared.log(.screenViewed(.savedTrips))
            store.send(.loadSavedTrips)
            groupSummaries = GroupTripCredentialsStore.summaries
            sharedTrips = (try? ReceivedSharedTripStorage.received().fetchAll()) ?? []
        }
        // Use onChange to detect when navigation returns to SavedTripsScreen and refresh the data.
        // (SwiftUI NavigationStack does not call onAppear again when popping back to this screen)
        .onChange(of: router.path) { _, newPath in
            // If returning to SavedTripsScreen (either as last or only screen), refresh
            if newPath.last == .savedTrips || newPath.isEmpty {
                store.send(.loadSavedTrips)
                groupSummaries = GroupTripCredentialsStore.summaries
                sharedTrips = (try? ReceivedSharedTripStorage.received().fetchAll()) ?? []
            }
        }
        .onChange(of: store.state.savedTrips) { _, value in
            guard !didLogView, case let .loaded(trips) = value else { return }
            didLogView = true
            AnalyticsTracker.shared.log(
                .init(.savedTripsViewed, properties: [
                    "personal_count": .integer(trips.count),
                    "group_count": .integer(groupSummaries.count),
                    "received_count": .integer(sharedTrips.count)
                ])
            )
        }
    }

    var groupTripsList: some View {
        ScrollView {
            VStack(spacing: 14) {
                if groupSummaries.isEmpty {
                    emptyGroupState
                } else {
                    ForEach(groupSummaries) { summary in
                        Button {
                            var properties: [String: AnalyticsValue] = [
                                "trip_type": .string("group")
                            ]
                            if let destination = AnalyticsSanitizer.destination(summary.destination) {
                                properties["destination"] = .string(destination)
                            }
                            AnalyticsTracker.shared.log(
                                .init(.savedTripOpened, properties: properties)
                            )
                            router.goToGroupDashboard(summary.groupId)
                        } label: {
                            groupSummaryCard(summary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    private func groupSummaryCard(_ summary: GroupTripSummary) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.appTint.opacity(0.12)).frame(width: 48, height: 48)
                Image(systemName: "person.3.fill").foregroundStyle(Color.appTint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.name).font(.kanitMedium(17)).foregroundColor(.primary)
                Text(summary.destination).font(DS.Typography.subtitle).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Color(.systemGray3))
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous))
    }

    private var emptyGroupState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 60)
            ZStack {
                Circle().fill(Color.appTint.opacity(0.12)).frame(width: 92, height: 92)
                Image(systemName: "person.3").font(.system(size: 38)).foregroundStyle(Color.appTint)
            }
            Text("No group trips yet").font(DS.Typography.displayLight)
            Text("Start or join a group trip and it’ll live here.")
                .font(DS.Typography.subtitle).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button { router.goToGroupCreate(resetStack: true) } label: {
                HStack(spacing: 6) { Image(systemName: "person.3.fill"); Text("Group trip") }
                    .font(.kanit(17)).foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Capsule().fill(Color.appTint))
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }

    var titleSubtitle: some View {
        VStack(spacing: 2) {
            Text("My trips")
                .font(.kanit(34))

            if case let .loaded(trips) = store.state.savedTrips, !trips.isEmpty {
                Text(trips.count == 1 ? "1 trip" : "\(trips.count) trips")
                    .font(DS.Typography.subtitle)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    var tripsList: some View {
        ScrollView {
            VStack(spacing: 18) {
                switch store.state.savedTrips {
                case let .loaded(trips):
                    if trips.isEmpty {
                        emptyState
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
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 60)
            ZStack {
                Circle()
                    .fill(Color.appTint.opacity(0.12))
                    .frame(width: 92, height: 92)
                Image(systemName: "suitcase.rolling")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Color.appTint)
            }
            Text("No trips yet")
                .font(DS.Typography.displayLight)
            Text("Plan your first adventure and it’ll live here.")
                .font(DS.Typography.subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                router.goToBasicInfo(resetStack: true)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Plan a trip")
                }
                .font(.kanit(17))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.appTint))
                .shadow(color: Color.appTint.opacity(0.3), radius: 12, y: 6)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }

    var plusButton: some View {
        Group {
            // Nothing to create on "Shared" — links only arrive from friends.
            if segment != .shared {
                Button(action: {
                    // Context-aware: match the active segment.
                    switch segment {
                    case .myTrips:
                        router.goToBasicInfo(resetStack: true)
                    case .myGroupTrips:
                        router.goToGroupCreate(resetStack: true)
                    case .shared:
                        break
                    }
                }) {
                    Image(systemName: "plus")
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundColor(.appTint)
                }
            }
        }
    }

    var sharedTripsList: some View {
        ScrollView {
            VStack(spacing: 18) {
                if sharedTrips.isEmpty {
                    sharedEmptyState
                } else {
                    ForEach(sharedTrips) { trip in
                        Button(action: { navigateToSharedTripDetails(trip) }) {
                            TripCard(trip: trip)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    var sharedEmptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 60)
            ZStack {
                Circle().fill(Color.appTint.opacity(0.12)).frame(width: 92, height: 92)
                Image(systemName: "paperplane.fill").font(.system(size: 36)).foregroundStyle(Color.appTint)
            }
            Text("No shared trips yet").font(DS.Typography.displayLight)
            Text("Trips your friends share with you will land here.")
                .font(DS.Typography.subtitle).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }

    // should be part of a Store Action
    func navigateToTripDetails(_ trip: Trip) {
        var properties: [String: AnalyticsValue] = ["trip_type": .string("personal")]
        if let destination = AnalyticsSanitizer.destination(trip.destination) {
            properties["destination"] = .string(destination)
        }
        AnalyticsTracker.shared.log(.init(.savedTripOpened, properties: properties))
        let suggestions: AsyncValue<Trip.Suggestions> = trip.suggestions != nil ?
            .loaded(trip.suggestions!) : .initial

        var state = TripOutputStore.State(
            details: trip.details,
            selectedContentTab: .discover,
            favorites: trip.favorites,
            saved: true,
            mode: .savedTrip,
            shareCode: trip.shareCode,
            itineraryResponse: .loaded(trip.itinerary),
            suggestionsResponse: suggestions,
            knowBeforeYouGoResponse: trip.knowBeforeYouGo.map { .loaded($0) } ?? .initial
        )
        // The traveller's own trip: their decisions and their paid-for deep
        // dives come back with it. Anything missing on an older file is simply
        // absent, never regenerated — `.initial` here means "there are none",
        // and with no `generationRequest` on a saved trip nothing will go and
        // charge for them.
        state.worthItResponse = trip.worthItItems.map(AsyncValue.loaded) ?? .initial
        state.whereToStayResponse = trip.whereToStay.map(AsyncValue.loaded) ?? .initial
        state.interestPrompts = trip.interestPrompts ?? []
        state.worthItDecisions = trip.worthItDecisions ?? [:]
        state.deepDives = trip.deepDives
        state.accommodation = trip.accommodation
        state.nearYouResponse = trip.nearYouState.asyncValue
        state.nearYouGenerationRequest = TripGenerationRequest(
            tripKey: trip.tripKey ?? TripKey.mint(),
            input: trip.generationInput
                ?? TripGenerationInput(details: trip.details, answers: [])
        )

        router.goToItineraryResult(state, resetStack: false)
    }

    /// A trip in "Shared" is already a durable local copy
    /// (`ReceivedSharedTripStorage`) — opens instantly, no network.
    func navigateToSharedTripDetails(_ trip: Trip) {
        var properties: [String: AnalyticsValue] = [
            "source": .string("saved_trips"),
            "outcome": .string("success")
        ]
        if let destination = AnalyticsSanitizer.destination(trip.destination) {
            properties["destination"] = .string(destination)
        }
        AnalyticsTracker.shared.log(.init(.sharedTripOpened, properties: properties))
        let suggestions: AsyncValue<Trip.Suggestions> = trip.suggestions != nil ?
            .loaded(trip.suggestions!) : .initial

        var state = TripOutputStore.State(
            details: trip.details,
            selectedContentTab: .discover,
            favorites: trip.favorites,
            saved: false,
            mode: .sharedTrip,
            shareCode: trip.shareCode,
            itineraryResponse: .loaded(trip.itinerary),
            suggestionsResponse: suggestions,
            knowBeforeYouGoResponse: trip.knowBeforeYouGo.map { .loaded($0) } ?? .initial
        )
        // A received trip is the recipient's own local file, so these are the
        // recipient's decisions, restored. The *sender's* never arrive: the
        // share payload carries content only, and the recipient gets the cards
        // undecided the first time — deciding is the point.
        state.worthItResponse = trip.worthItItems.map(AsyncValue.loaded) ?? .initial
        state.whereToStayResponse = trip.whereToStay.map(AsyncValue.loaded) ?? .initial
        state.interestPrompts = trip.interestPrompts ?? []
        state.worthItDecisions = trip.worthItDecisions ?? [:]
        state.deepDives = trip.deepDives
        // Accommodation and Near You are a solo owner's personal layer. A
        // received share never carries either, even if a future payload grows
        // fields with similar names.
        state.accommodation = nil
        state.nearYouResponse = .initial

        router.goToItineraryResult(state, resetStack: false)
    }
}

#Preview {
    NavigationStack {
        SavedTripsScreen()
            .environmentObject(NavigationRouter())
    }
}
