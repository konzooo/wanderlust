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

    private let suggestions = ["Lisbon", "Tokyo", "Norway road trip", "North Vietnam"]
    private let logoHeight: CGFloat
    private let subtitleFontSize: Float

    init(
        logoHeight: CGFloat = 56,
        subtitleFontSize: Float = 13
    ) {
        self.logoHeight = logoHeight
        self.subtitleFontSize = subtitleFontSize
    }

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
                .font(.kanitLightItalic(subtitleFontSize))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Spacer(minLength: 22)

            VStack(alignment: .leading, spacing: 16) {
                Text("Where are you\ngoing next?")
                    .font(.kanitLight(30))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(-3)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
            .frame(height: logoHeight)
#if DEBUG
            .onTapGesture(count: 3) {
                router.goToDebugMenu(on: .home)
            }
#endif
    }

    private var askField: some View {
        HStack(spacing: 14) {
            PrototypeMapPin()
                .frame(width: 18, height: 20)
                .foregroundStyle(Color.appTint)

            ZStack(alignment: .leading) {
                if store.state.destinationQuery.isEmpty {
                    Text("Barcelona, a road trip,\nanywhere…")
                        .font(.kanit(17))
                        .foregroundStyle(Color.secondary.opacity(0.72))
                        .allowsHitTesting(false)
                }

                TextField("", text: $store.state.destinationQuery, axis: .vertical)
                    .font(.kanit(17))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.go)
                    .lineLimit(1...2)
                    .focused($askFieldFocused)
                    .onSubmit(planTrip)
                    .accessibilityLabel("Trip destination")
            }

            Button(action: planTrip) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.appTint)
                    .frame(width: 34, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(store.state.trimmedDestination.isEmpty)
            .opacity(store.state.trimmedDestination.isEmpty ? 0.78 : 1)
            .accessibilityLabel("Plan this trip")
        }
        .padding(.leading, 20)
        .padding(.trailing, 14)
        .frame(minHeight: 88)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: Color.appTint.opacity(0.08), radius: 20, y: 10)
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
            HomeSeeAllTripsCard()
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

/// Matches the lightweight, Lucide-style pin used in the Home prototype.
private struct PrototypeMapPin: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 24
        let scaleY = rect.height / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scaleX, y: y * scaleY)
        }

        var path = Path()
        path.move(to: point(12, 22))
        path.addCurve(
            to: point(4, 10),
            control1: point(10.2, 20.2),
            control2: point(4, 14.8)
        )
        path.addCurve(
            to: point(12, 2),
            control1: point(4, 5.6),
            control2: point(7.6, 2)
        )
        path.addCurve(
            to: point(20, 10),
            control1: point(16.4, 2),
            control2: point(20, 5.6)
        )
        path.addCurve(
            to: point(12, 22),
            control1: point(20, 14.8),
            control2: point(13.8, 20.2)
        )
        path.addEllipse(in: CGRect(
            x: 9 * scaleX,
            y: 7 * scaleY,
            width: 6 * scaleX,
            height: 6 * scaleY
        ))
        return path.strokedPath(
            StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )
    }
}

private struct HomeSeeAllTripsCard: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.96),
                    Color(hex: "#EEF0FF").opacity(0.96),
                    Color(hex: "#FFF7EA").opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.appTint.opacity(0.10))
                .frame(width: 150, height: 150)
                .blur(radius: 2)
                .offset(x: 265, y: -70)

            Circle()
                .stroke(Color.appTint.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                .frame(width: 130, height: 130)
                .offset(x: 300, y: 76)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("TRIP LIBRARY", systemImage: "rectangle.stack.fill")
                        .font(.kanit(11).weight(.semibold))
                        .tracking(1.3)
                        .foregroundStyle(Color.appTint)

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appTint)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.78), in: Circle())
                        .overlay { Circle().stroke(Color.appTint.opacity(0.10)) }
                }

                Spacer(minLength: 4)

                Text("See all your trips")
                    .font(.kanitMedium(27))
                    .foregroundStyle(.primary)

                Text("Every plan, group adventure and shared journey — together.")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: 310, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardLarge, style: .continuous)
                .stroke(.white.opacity(0.82), lineWidth: 1)
        }
        .shadow(color: Color.appTint.opacity(0.10), radius: 18, y: 8)
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
