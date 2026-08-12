import CoreArchitecture
import DesignSystem
import Networking
import SwiftUI

struct HomeScreen: View {
    @StateObject private var store = HomeStore()
    @StateObject private var tripsStore = HomeTripsStore()
    @EnvironmentObject private var router: NavigationRouter
    @FocusState private var askFieldFocused: Bool
    @State private var selectedContinueID: String?

    private let suggestions = ["Beach", "City break", "Mountains", "Food trip", "Surprise me"]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    aboveTheFold
                        .frame(minHeight: proxy.size.height, alignment: .top)
                        .frame(maxWidth: .infinity)

                    if !tripsStore.items.isEmpty {
                        continueSection(width: proxy.size.width)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background { AuroraBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .onTabRootAppear(.home, router: router) {
            AnalyticsTracker.shared.log(.screenViewed(.home))
            tripsStore.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tripLibraryDidChange)) { _ in
            tripsStore.load()
        }
        .simultaneousGesture(TapGesture().onEnded { askFieldFocused = false })
    }

    private var aboveTheFold: some View {
        VStack(spacing: 0) {
            logo
                .padding(.top, 12)

            Text("Get inspired for your next travel")
                .font(.kanitLightItalic(13))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Spacer(minLength: 22)

            VStack(spacing: 15) {
                Text("Where are you going next?")
                    .font(DS.Typography.displayRegular)
                    .multilineTextAlignment(.center)

                askField

                HomeFlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            store.state.destinationQuery = suggestion
                            planTrip()
                        }
                        .buttonStyle(HomeSuggestionButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 24)

            groupTripCard

            Button {
                router.goToGroupCreate(segment: .join, on: .home)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "number.circle.fill")
                        .foregroundStyle(Color.appTint)
                    Text("Join a group trip with a code")
                        .font(.kanit(15).weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 20)
    }

    private var logo: some View {
        Image("app-logo")
            .resizable()
            .scaledToFit()
            .frame(height: 56)
#if DEBUG
            .onTapGesture(count: 3) {
                router.goToDebugMenu(on: .home)
            }
#endif
    }

    private var askField: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.appTint)

            TextField("Ask Wanderlust…", text: $store.state.destinationQuery)
                .font(.kanit(16))
                .textInputAutocapitalization(.words)
                .submitLabel(.go)
                .focused($askFieldFocused)
                .onSubmit(planTrip)

            Button(action: planTrip) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.appTint, in: Circle())
            }
            .disabled(store.state.trimmedDestination.isEmpty)
            .opacity(store.state.trimmedDestination.isEmpty ? 0.38 : 1)
            .accessibilityLabel("Plan this trip")
        }
        .padding(.leading, 16)
        .padding(.trailing, 9)
        .frame(height: 56)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }

    private var groupTripCard: some View {
        Button {
            router.goToGroupCreate(segment: .create, on: .home)
        } label: {
            HStack(spacing: 15) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.appTint)
                    .frame(width: 46, height: 46)
                    .background(Color.appTint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Travelling with friends?")
                        .font(.kanit(17).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Plan together and find your group’s sweet spot.")
                        .font(.kanit(12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appTint)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.56), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func continueSection(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTINUE")
                .font(.kanit(12).weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(tripsStore.items) { item in
                        Button {
                            open(item)
                        } label: {
                            continueCard(item)
                                .frame(width: width)
                        }
                        .buttonStyle(.plain)
                        .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .frame(height: 184)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $selectedContinueID)

            HStack(spacing: 6) {
                ForEach(tripsStore.items) { item in
                    Circle()
                        .fill(item.id == currentContinueID ? Color.appTint : Color.black.opacity(0.16))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 26)
        }
        .onAppear {
            if selectedContinueID == nil {
                selectedContinueID = tripsStore.items.first?.id
            }
        }
        .onChange(of: tripsStore.items) { _, items in
            if !items.contains(where: { $0.id == selectedContinueID }) {
                selectedContinueID = items.first?.id
            }
        }
    }

    private var currentContinueID: String? {
        selectedContinueID ?? tripsStore.items.first?.id
    }

    @ViewBuilder
    private func continueCard(_ item: HomeTripItem) -> some View {
        switch item {
        case let .personal(trip):
            TripCard(trip: trip)
        case let .group(summary):
            HomeGroupTripCard(summary: summary)
        case .seeAll:
            ZStack {
                LinearGradient(
                    colors: [Color.appTint.opacity(0.82), Color.appTint.opacity(0.52)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 9) {
                    Image(systemName: "suitcase.rolling.fill")
                        .font(.system(size: 28))
                    Text("See all trips")
                        .font(DS.Typography.displayLight)
                }
                .foregroundStyle(.white)
            }
        }
    }

    private func open(_ item: HomeTripItem) {
        switch item {
        case let .personal(trip):
            router.goToItineraryResult(
                TripOutputStateFactory.savedTrip(trip),
                on: .home
            )
        case let .group(summary):
            router.goToGroupDashboard(summary.groupId, on: .home)
        case .seeAll:
            router.goToTabRoot(.trips)
        }
    }

    private func planTrip() {
        let destination = store.state.trimmedDestination
        guard !destination.isEmpty else { return }
        askFieldFocused = false
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        AnalyticsTracker.shared.log(.tripPlanningStarted(entryPoint: "home_ask"))
        router.goToBasicInfo(.init(destination: destination), on: .home)
    }
}

private struct HomeGroupTripCard: View {
    let summary: GroupTripSummary
    @State private var imageURL: AsyncValue<URL> = .initial
    private let imageService = UnsplashService()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CacheDestinationImage(cacheKey: summary.destination, imageUrlState: imageURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.64), .clear],
                        startPoint: .bottom,
                        endPoint: .center
                    )
                }

            VStack(alignment: .leading, spacing: 7) {
                Label("Group trip", systemImage: "person.3.fill")
                    .font(.kanit(12).weight(.medium))
                Text(summary.name)
                    .font(DS.Typography.displayBold)
                Text(summary.destination)
                    .font(.kanit(14))
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .task {
            guard case .initial = imageURL else { return }
            imageURL = .loading
            do {
                imageURL = .loaded(try await imageService.fetchImageURL(for: summary.destination))
            } catch {
                imageURL = .error(error)
            }
        }
    }
}

private struct HomeSuggestionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kanit(13).weight(.medium))
            .foregroundStyle(Color.primary.opacity(0.78))
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(.white.opacity(configuration.isPressed ? 0.84 : 0.58), in: Capsule())
            .overlay { Capsule().stroke(Color.black.opacity(0.055), lineWidth: 1) }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct HomeFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let result = arrange(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? 335
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), points)
    }
}

#Preview {
    NavigationStack {
        HomeScreen()
            .environmentObject(NavigationRouter())
    }
}
