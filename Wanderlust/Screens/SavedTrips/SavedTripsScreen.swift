import SwiftUI
import DesignSystem
import CoreModels
import Networking
import CoreArchitecture

struct SavedTripsScreen: View {
    @StateObject var store: SavedTripsStore = SavedTripsStore()

    @EnvironmentObject var router: NavigationRouter
    @State private var segment: Segment = .myTrips
    @State private var groupSummaries: [GroupTripSummary] = []
    @State private var sharedTrips: [Trip] = []
    @State private var didLogView = false

    // Shortened labels so all three fit the segmented control on small
    // devices and at larger Dynamic Type sizes ("My Group Trips" would
    // truncate). The feature itself is still called "My Group Trips"
    // everywhere else.
    private enum Segment: String, CaseIterable {
        case myTrips = "My Trips"
        case myGroupTrips = "Group Trips"
        case shared = "Shared with me"
    }

    @MainActor
    init(store: SavedTripsStore? = nil) {
        self._store = StateObject(wrappedValue: store ?? SavedTripsStore())
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $segment) {
                ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 14)
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
        .navigationTitle("My Trips")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                plusButton
            }
        }
        .onTabRootAppear(.trips, router: router) {
            AnalyticsTracker.shared.log(.screenViewed(.savedTrips))
            refreshTrips()
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
        .onReceive(NotificationCenter.default.publisher(for: .tripLibraryDidChange)) { _ in
            refreshTrips()
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
        DS.EmptyState(
            eyebrow: "Group trips",
            symbol: "person.3",
            title: "Many preferences. One trip.",
            message: "Everyone swipes on their own, and the trip is built from what the group actually agrees on.",
            actionTitle: "Create a group trip",
            action: { router.goToGroupCreate(resetStack: true) },
            secondaryTitle: "Join with a code",
            secondaryAction: { router.goToGroupCreate(segment: .join, resetStack: true) }
        )
        .padding(.top, 20)
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
                                TripCard(trip: trip) { url in
                                    persistImageURL(url, for: trip, received: false)
                                }
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
        DS.EmptyState(
            eyebrow: "My trips",
            symbol: "suitcase.rolling",
            title: "No trips yet",
            message: "Where are you going next? It's time to get some inspiration and local tips.",
            actionTitle: "Plan a trip",
            action: { router.goToBasicInfo(resetStack: true) }
        )
        .padding(.top, 20)
    }

    var plusButton: some View {
        Menu {
            Button {
                router.goToBasicInfo(resetStack: true)
            } label: {
                Label("Start a new trip", systemImage: "mappin.and.ellipse")
            }
            Button {
                router.goToGroupCreate(resetStack: true)
            } label: {
                Label("Create a group trip", systemImage: "person.3.fill")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.appTint)
        }
        .accessibilityLabel("Create trip")
    }

    private func refreshTrips() {
        store.send(.loadSavedTrips)
        groupSummaries = GroupTripCredentialsStore.summaries
        sharedTrips = (try? ReceivedSharedTripStorage.received().fetchAll()) ?? []
    }

    var sharedTripsList: some View {
        ScrollView {
            VStack(spacing: 18) {
                if sharedTrips.isEmpty {
                    sharedEmptyState
                } else {
                    ForEach(sharedTrips) { trip in
                        Button(action: { navigateToSharedTripDetails(trip) }) {
                            TripCard(trip: trip) { url in
                                persistImageURL(url, for: trip, received: true)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    /// The one empty state a traveller cannot fix from this screen — nobody has
    /// sent them anything yet. It offers the code path rather than nothing at
    /// all, so the segment is not a dead end.
    var sharedEmptyState: some View {
        DS.EmptyState(
            eyebrow: "Shared with me",
            symbol: "paperplane",
            title: "Ask friends to share their trip",
            message: "Their favourites land here, already marked.",
            secondaryTitle: "Join a group trip with a code",
            secondaryAction: { router.goToGroupCreate(segment: .join, resetStack: true) }
        )
        .padding(.top, 20)
    }

    // should be part of a Store Action
    func navigateToTripDetails(_ trip: Trip) {
        var properties: [String: AnalyticsValue] = ["trip_type": .string("personal")]
        if let destination = AnalyticsSanitizer.destination(trip.destination) {
            properties["destination"] = .string(destination)
        }
        AnalyticsTracker.shared.log(.init(.savedTripOpened, properties: properties))
        router.goToItineraryResult(
            TripOutputStateFactory.savedTrip(trip),
            resetStack: false
        )
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
        if let imageURL = trip.imageUrl.flatMap(URL.init(string:)) {
            state.imageUrlResponse = .loaded(imageURL)
        }

        router.goToItineraryResult(state, resetStack: false)
    }

    /// One-time migration for trips saved before their selected image URL was
    /// part of the model. Avoids even the cached async URL lookup on the next
    /// tab switch or app launch.
    private func persistImageURL(_ url: URL, for trip: Trip, received: Bool) {
        guard trip.imageUrl == nil else { return }
        Task.detached(priority: .utility) {
            do {
                let storage: TripStorage
                if received {
                    storage = try ReceivedSharedTripStorage.received()
                } else {
                    storage = try TripStorage()
                }
                var updated = trip
                updated.imageUrl = url.absoluteString
                let stored = try storage
                    .fetch(inGrouping: updated.groupingFolder)
                    .first { $0.duplicateIdentity == updated.duplicateIdentity }
                try storage.save(stored.map(updated.merged(over:)) ?? updated)
            } catch {
                // Best effort: both the URL-selection cache and image-byte
                // cache still prevent network work if this migration fails.
            }
        }
    }
}

#Preview {
    NavigationStack {
        SavedTripsScreen()
            .environmentObject(NavigationRouter())
    }
}
