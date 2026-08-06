//
//  DesignPlayground.swift
//  Wanderlust
//
//  Registry of in-progress design explorations, listed in the Debug Menu
//  (triple-tap the Home logo in a DEBUG build). Add an entry whenever you
//  start a new variant; delete the entry (and its screen file) once you've
//  merged it into the real screen or ruled it out.
//

import CoreModels
import SwiftUI

/// A single design-exploration entry shown in the Debug Menu's Design Playground list.
struct DesignVariant: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let destination: AnyView

    init<Content: View>(
        id: String,
        title: String,
        subtitle: String,
        @ViewBuilder destination: () -> Content
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.destination = AnyView(destination())
    }
}

enum DesignPlayground {
#if DEBUG
    private static let questionnaireVariants: [DesignVariant] = [
        DesignVariant(
            id: "questionnaire-split-postcard",
            title: "Questionnaire 1 — Split Postcard",
            subtitle: "Very close: the current split-card idea with live content, responsive halves, five levels, haptics, and no baked-in copy."
        ) {
            SplitPostcardPrototype()
        },
        DesignVariant(
            id: "questionnaire-day-two-ways",
            title: "Questionnaire 2 — A Day, Two Ways",
            subtitle: "Close, evolved: compare two concrete mini-itineraries and scrub toward the day that feels right."
        ) {
            DayTwoWaysPrototype()
        },
        DesignVariant(
            id: "questionnaire-moments-deck",
            title: "Questionnaire 3 — Moments Deck",
            subtitle: "Cards reimagined: pass, save, or love 16 travel moments while the eight-axis profile is inferred quietly."
        ) {
            MomentsDeckPrototype()
        },
        DesignVariant(
            id: "questionnaire-forking-journey",
            title: "Questionnaire 4 — Forking Journey",
            subtitle: "Free spirit: guide a compass through eight forks and watch the route become your travel signature."
        ) {
            ForkingJourneyPrototype()
        },
        DesignVariant(
            id: "questionnaire-vibe-mixer",
            title: "Questionnaire 5 — Vibe Mixer",
            subtitle: "Free spirit: tune eight preference channels, two at a time, while a code-drawn travel poster reacts."
        ) {
            VibeMixerPrototype()
        }
    ]
    /// The output shell, wired to mock content so the tabs, the sticky pills,
    /// the favourites sheet and the Worth-it/Skip decisions can be looked at
    /// without generating a trip. `.savedTrip` with no `generationRequest`, so
    /// opening it costs nothing and calls nothing.
    private static let outputVariants: [DesignVariant] = [
        DesignVariant(
            id: "output-shell",
            title: "Trip Output — Discover / Know Before You Go shell",
            subtitle: "Tabs, sticky Discover pills, Worth-it/Skip decisions and the favourites sheet, on mock content."
        ) {
            TripOutputScreen(
                initialState: {
                    var state = TripOutputStore.State(
                        details: .mock,
                        saved: true,
                        mode: .savedTrip
                    )
                    state.itineraryResponse = .loaded(.mock)
                    state.suggestionsResponse = .loaded(.mock)
                    state.worthItResponse = .loaded(Trip.WorthItItem.mockSet)
                    state.whereToStayResponse = .loaded(Trip.StayArea.mockSet)
                    state.interestPrompts = [
                        "Natural wine bars", "Rooftop sunsets", "Modernista rooftops"
                    ]
                    return state
                }()
            )
        }
    ]
#else
    private static let questionnaireVariants: [DesignVariant] = []
    private static let outputVariants: [DesignVariant] = []
#endif

    /// Registry of in-progress design explorations. Add/remove entries here.
    static let variants: [DesignVariant] = outputVariants + questionnaireVariants
}
