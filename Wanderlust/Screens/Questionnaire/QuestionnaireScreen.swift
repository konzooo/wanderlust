import Combine
import CoreArchitecture
import CoreModels
import DesignSystem
import Foundation
import SwiftUI

struct QuestionnaireScreen: View {

    @ObservedObject var store: QuestionnaireStore
    @EnvironmentObject var router: NavigationRouter
    @AppStorage(OnboardingPreferenceKey.questionnaireCardsDismissed) private var hasDismissedSoloCardsOnboarding = false
    @State private var isCardsOnboardingPresented = false

    private let swipeSubject = PassthroughSubject<SwipeDirection, Never>()
    private let undoSubject  = PassthroughSubject<Void,          Never>()
    private let onGroupCompletion: ((MemberPreferences) -> Void)?
    private let profileSelection: Binding<UUID?>

    init(
        mode: QuestionnaireStore.Mode = .solo,
        profileSelection: Binding<UUID?>? = nil,
        onGroupCompletion: ((MemberPreferences) -> Void)? = nil
    ) {
        self.store = QuestionnaireStore(mode: mode)
        self.onGroupCompletion = onGroupCompletion
        self.profileSelection = profileSelection ?? Binding(
            get: { TripOrganizer.shared.selectedProfileID },
            set: { TripOrganizer.shared.selectedProfileID = $0 }
        )
    }

    /// The tap/swipe tutorial overlay is solo-only: the group flow's own
    /// "What's your style?" onboarding (shown once, before this screen) already
    /// explains tap/swipe, so showing this overlay too would stack two
    /// onboardings on the same first card.
    private var hasDismissedCardsOnboarding: Bool {
        get {
            if case .group = store.mode { return true }
            return hasDismissedSoloCardsOnboarding
        }
        nonmutating set {
            guard case .solo = store.mode else { return }
            hasDismissedSoloCardsOnboarding = newValue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            titleSubtitle
                .padding(.bottom, 24)

            progressBar
                .padding(.horizontal, .Spacing.xlarge)
                .padding(.bottom, 6)

            cardsStack
                .padding(.top, .Spacing.medium)

            Spacer()

            bothButton
                .padding(.top, .Spacing.medium)
                .padding(.bottom, .Spacing.large)
        }
        .gradientBackground()
        .cleanTopInsets()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .navigationBarLeading) {
                    questionnaireBackButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileSelectionButton(selection: profileSelection)
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    questionnaireBackButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileSelectionButton(selection: profileSelection)
                }
            }
        }
        .onAppear {
            store.send(.start)
            AnalyticsTracker.shared.log(
                .screenViewed(
                    store.mode.analyticsName == "group"
                        ? .groupQuestionnaire
                        : .questionnaire
                )
            )
        }
        .sheet(isPresented: $store.state.presentDailyLimitSheet) {
            UsageThresholdOverlayView(
                metricKey : .dailyItineraries,
                threshold : MetricKey.dailyItineraries.threshold,
                onGoBack  : {
                    store.send(.restart)
                    router.popToRoot()
                }
            )
            .presentationDetents([.fraction(0.50), .large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(true)
        }
    }

    // MARK: Sub-views ---------------------------------------------------------
    var titleSubtitle: some View {
        VStack(spacing: 5) {
            Text("What's your style?")
                .font(DS.Typography.displayRegular)
            Text("Tap or swipe right/left to choose")
                .font(DS.Typography.subtitle)
                .foregroundColor(Color(.systemGray))
        }
    }

    var progressBar: some View {
        HStack {
            if store.state.cardsCompleted > 0 {
                undoButton
            } else {
                Spacer().frame(width: 1, height: 12)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray5))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.appTint)
                        .frame(width : geo.size.width * store.state.currentProgress,
                               height: 4)
                }
            }
            .frame(height: 4)
            .frame(maxWidth: .infinity)
        }
    }

    var undoButton: some View {
        Button {
            store.send(.undo)
            undoSubject.send(())
        } label: {
            Image(systemName: "arrowtriangle.left.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.appTint)
        }
    }

    var cardsStack: some View {
        CardStackWrapper(
            data        : store.state.cards,
            direction   : SwipeDirection.direction,
            onSwipe     : { card, dir in
                store.send(.cardSwipped(card, dir))
            },
            onEmptyStack: {
                store.send(.finished)
                let snapshot = TravellerProfileLibrary.shared
                    .profile(id: profileSelection.wrappedValue)?
                    .snapshot
                if let event = store.completionEvent(profile: snapshot) {
                    AnalyticsTracker.shared.log(event)
                }
                switch store.mode {
                case .solo:
                    generateItinerary()
                case .group:
                    if let preferences = store.groupPreferences(profile: snapshot) {
                        onGroupCompletion?(preferences)
                    }
                }
            },
            manualSwipe : swipeSubject.eraseToAnyPublisher(),
            manualUndo  : undoSubject.eraseToAnyPublisher(),
            isInteractionEnabled: hasDismissedCardsOnboarding
        ) { card, _, isTop in
            CardContentView(
                imageName : card.image,
                rightText : card.leftText,
                leftText  : card.rightText
            )
            .overlay {
                if isTop && isCardsOnboardingPresented {
                    QuestionnaireCardOnboardingOverlay {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isCardsOnboardingPresented = false
                            hasDismissedCardsOnboarding = true
                        }
                    }
                    .transition(
                        .scale(scale: 0.96)
                            .combined(with: .opacity)
                    )
                }
            }
            .padding()
        }
        .environment(
            \.cardStackConfiguration,
            CardStackConfiguration(maxVisibleCards: hasDismissedCardsOnboarding ? 5 : 1)
        )
        .animation(.easeInOut, value: store.state.cardsCompleted)
        .animation(.easeOut(duration: 0.3), value: hasDismissedCardsOnboarding)
        .task(id: hasDismissedCardsOnboarding) {
            guard !hasDismissedCardsOnboarding else {
                isCardsOnboardingPresented = false
                return
            }

            do {
                try await Task.sleep(nanoseconds: 450_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                isCardsOnboardingPresented = true
            }
        }
    }

    var bothButton: some View {
        Button {
            swipeSubject.send(.top)
        } label: {
            Text("I want both")
                .font(.kanitMedium(19))
                .underline()
        }
        .foregroundColor(.appTint)
    }

    private var questionnaireBackButton: some View {
        Button {
            router.pop()
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Back")
    }

    // MARK: Navigation helper
    private func generateItinerary() {
        let profile = TravellerProfileLibrary.shared
            .profile(id: profileSelection.wrappedValue)?
            .snapshot
        // `tripKey` is minted once, here, and travels with the trip from now on:
        // it is what scopes the backend's per-trip generation caps, so it must
        // not be re-minted on every screen open.
        let state = TripOutputStore.State(
            generationRequest: TripGenerationRequest(
                input: TripOrganizer.shared.generationInput(profile: profile)
            ),
            details    : TripOrganizer.shared.tripDetails,
            mode: .newTrip
        )
        router.goToItineraryResult(state, resetStack: true)
    }
}

enum OnboardingPreferenceKey {
    static let questionnaireCardsDismissed = "onboarding.questionnaireCards.dismissed"
    static let newTripOutputPermanentlyDismissed = "onboarding.newTripOutput.permanentlyDismissed"
}

private struct QuestionnaireCardOnboardingOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall)
                .fill(Color.black.opacity(0.56))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall)
                        .stroke(Color(.systemGray2), lineWidth: 2.5)
                }

            VStack(spacing: 16) {
                ZStack {
                    GeometryReader { geometry in
                        Path { path in
                            let centerX = geometry.size.width / 2
                            path.move(to: CGPoint(x: centerX, y: 22))
                            path.addLine(to: CGPoint(x: centerX, y: geometry.size.height - 4))
                        }
                        .stroke(
                            Color.white.opacity(0.9),
                            style: StrokeStyle(
                                lineWidth: 2,
                                lineCap: .round,
                                dash: [6, 8]
                            )
                        )
                        .accessibilityHidden(true)
                    }

                    HStack(spacing: 0) {
                        swipeDirection(icon: "arrow.left", text: "tap or swipe left")
                        swipeDirection(icon: "arrow.right", text: "tap or swipe right")
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 54)
                }

                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityHint("Dismisses the card instructions")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choose your style by tapping or swiping left or right")
    }

    private func swipeDirection(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .bold))
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .italic()
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    QuestionnaireScreen()
        .environmentObject(NavigationRouter())
}
