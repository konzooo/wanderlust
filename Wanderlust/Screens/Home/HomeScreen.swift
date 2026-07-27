//
//  HomeView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 1/6/25.
//

import CoreArchitecture
import DesignSystem
import enum Networking.FeedbackResult
import SwiftUI

struct HomeScreen: View {
    @StateObject var store: HomeStore = HomeStore()
    @StateObject var feedbackStore: FeedbackStore = FeedbackStore()
    @EnvironmentObject var router: NavigationRouter

    @State private var isDrawerOpen = false

    // Plane
    @State private var showPlane = false
    @State private var planeOffsetY: CGFloat = -200
    @State private var rotatePlane = false

    var body: some View {
        NavigationStack(path: $router.path) {
            VStack(spacing: 0) {
//                betabadge
//                    .padding(.horizontal, 20)
//
                logoView
                    .padding(.top, -10)
                    .padding(.bottom, 15)

                subtitleText

                Spacer()

                centerImage

                ctaButton
                    .padding(.top, .Padding.md3)

                Spacer()
            }
            .gradientBackground()
            .cleanTopInsets()
            .presentationDragIndicator(.visible)
            .withNavigationDestinations(feedbackStore: feedbackStore)
            .drawerToolbar(
                isOpen: $isDrawerOpen,
                selected: .home,
                router: router
//                trailingButton: AnyView(betabadge)
            )

            .onChange(of: feedbackStore.submissionResult) { _, newValue in
                if let newValue {
                    store.send(.processFeedbackResult(newValue))
                }
            }

            .onAppear {
                AnalyticsTracker.shared.log(.screenViewed(.home))
            }

            .toast(
                style: toastStyle(feedbackResult: store.state.feedbackResult),
                title: "Thanks for the feedback" ,
                subtitle: "It means a lot to us 🫶🏻",
                isPresented: $store.state.presentFeedbackToast,
                position: .top
            )
        }
        // Overlay the plane on top of the Stack
        .overlay(alignment: .top) {
            flyingPlane
        }
    }

    func toastStyle(feedbackResult: FeedbackResult?) -> DS.Toast.Style {
        if feedbackResult != nil {
            return .success
        }
        return .error
    }
}

extension HomeScreen {
    var betabadge: some View {
        HStack {
            Spacer()
            Text("BETA VERSION")
                .font(.kanitItalic(12))
                .foregroundColor(Color(red: 0.75, green: 0.45, blue: 0.50))
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color(red: 0.92, green: 0.85, blue: 0.87)) // Light pink color
                )
                .opacity(0.7)
                .onTapGesture(count: 2) {
                    showPlane = true
                }
        }
    }
    
    var logoView: some View {
        Image("app-logo")
            .resizable()
            .scaledToFit()
            .frame(height: 80)
#if DEBUG
            .onTapGesture(count: 3) {
                router.goToDebugMenu()
            }
#endif
    }

    var subtitleText: some View {
        Text("Get inspired for your next Travel")
            .font(Font.kanitLightItalic(16))
    }

    var centerImage: some View {
        Image("welcome-card")
            .resizable()
            .cornerRadius(CGFloat.Radius.image)
            .padding(.horizontal, 40)
            .frame(height: 360)
    }

    var ctaButton: some View {
        Button("Get Started") {
            //            store.send(.ctaTapped)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            router.goToBasicInfo()
        }
        .buttonStyle(PrimaryButtonStyle(fullWidth: false))

    }

    var feedbackCard: some View {
        DS.InformativeCard(
            title: "Your Feedback",
            subtitle: "We want to build this app together with you. Give us your feedback and suggestions.",
            icon: Image(systemName: "lightbulb.fill")
        ) {
//            store.send(.feedbackCardTapped)
            router.goToFeedback()
        }
    }
    
    var flyingPlane: some View {
        GeometryReader { geo in
            if showPlane {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color.appTint)
                    .frame(maxWidth: .infinity)
                    .rotationEffect(.degrees(rotatePlane ? 360 : 0))
                    .offset(y: planeOffsetY)
                    .onAppear {
                        // rotate forever
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotatePlane = true
                        }
                        // drop to just past bottom of the GeometryReader
                        withAnimation(.linear(duration: 4)) {
                            planeOffsetY = geo.size.height + 300
                        }
                        // cleanup
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showPlane = false
                            rotatePlane = false
                            planeOffsetY = -200
                        }
                    }
            }
        }
        .ignoresSafeArea()
    }
}

private extension View {
    func withNavigationDestinations(feedbackStore: FeedbackStore) -> some View {
        navigationDestination(for: Destination.self) { destination in
            switch destination {
            case .basicInfo:
                BasicInfoScreen()
            case .questionnaire:
                QuestionnaireScreen()
            case .groupCreate:
                GroupTripCreateScreen()
            case let .groupMembers(state):
                GroupTripMembersScreen(store: GroupTripMembersStore(initialState: state))
            case let .groupSwipe(groupId):
                GroupSwipeScreen(groupId: groupId)
            case let .groupDashboard(groupId):
                GroupDashboardScreen(groupId: groupId)
            case let .groupOutput(state):
                TripOutputScreen(initialState: state)
            case let .groupJoin(code):
                GroupJoinScreen(code: code)
            case let .sharedTrip(code):
                SharedTripScreen(code: code)
            case let .itineraryResult(state):
                TripOutputScreen(initialState: state)
            case .feedback:
                FeedbackScreen(store: feedbackStore)
            case .savedTrips:
                SavedTripsScreen()
            case .debugMenu:
                DebugMenuScreen()
            default: EmptyView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeScreen()
            .environmentObject(NavigationRouter())
    }
}
