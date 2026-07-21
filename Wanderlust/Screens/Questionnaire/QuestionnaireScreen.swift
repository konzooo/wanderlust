import Combine
import CoreArchitecture
import DesignSystem
import Foundation
import SwiftUI

struct QuestionnaireScreen: View {

    @ObservedObject var store = QuestionnaireStore()
    @EnvironmentObject var router: NavigationRouter

    private let swipeSubject = PassthroughSubject<SwipeDirection, Never>()
    private let undoSubject  = PassthroughSubject<Void,          Never>()

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
                .padding(.bottom, .Spacing.medium)
//                .padding(, .Spacing.large)
        }
        .gradientBackground()
        .cleanTopInsets()
        .onAppear {
            store.send(.start)
            AnalyticsTracker.shared.log(.screenViewed(.questionaire))
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
                .font(.kanit(34))
            Text("Tap or swipe right/left to choose")
                .font(.kanitLight(18))
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
                generateItinerary()
                AnalyticsTracker.shared.log(
                    .questionnaireFinished(
                        properties: TripOrganizer.shared.questionnaireEventProperties
                    )
                )
            },
            manualSwipe : swipeSubject.eraseToAnyPublisher(),
            manualUndo  : undoSubject.eraseToAnyPublisher()
        ) { card, _, _ in
            CardContentView(
                imageName : card.image,
                rightText : card.leftText,
                leftText  : card.rightText
            )
            .padding()
        }
        .animation(.easeInOut, value: store.state.cardsCompleted)
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

    // MARK: Navigation helper
    private func generateItinerary() {
        let state = TripOutputStore.State(
            tripSummary: TripOrganizer.shared.generateTripSummary(),
            details    : TripOrganizer.shared.tripDetails,
            mode: .newTrip
        )
        router.goToItineraryResult(state, resetStack: true)
    }
}

#Preview {
    QuestionnaireScreen()
        .environmentObject(NavigationRouter())
}
