//
//  HomeView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 1/6/25.
//

import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

struct BasicInfoScreen: View {
    @ObservedObject var store: BasicInfoStore = BasicInfoStore()
    @FocusState private var destinationFocused: Bool
    @State private var isDrawerOpen = false
    @State private var didInitializeProfileSelection = false
    @ObservedObject private var tripOrganizer = TripOrganizer.shared

    @EnvironmentObject var router: NavigationRouter

    @MainActor
    init(store: BasicInfoStore? = nil) {
        self.store = store ?? BasicInfoStore()
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.bottom, 22)

                formCard
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)

                ctaButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .cleanTopInsets()
        .onAppear {
            AnalyticsTracker.shared.log(.screenViewed(.basicInfo))
        }
        .sheet(isPresented: $store.state.presentSpecifySheet) {
            specifyFormView
        }
        .animation(.easeInOut, value: store.state.presentSpecifySheet)
        .drawerToolbar(isOpen: $isDrawerOpen, selected: .newTrip, router: router)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileSelectionButton(selection: $tripOrganizer.selectedProfileID)
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded { _ in destinationFocused = false }
        )
        .onAppear {
            guard !didInitializeProfileSelection else { return }
            didInitializeProfileSelection = true
            tripOrganizer.selectedProfileID = TravellerProfileLibrary.shared.defaultSelectionID
        }
    }
}

// MARK: - Sections

extension BasicInfoScreen {
    var header: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.appTint)
                Text("Next Trip")
                    .font(DS.Typography.displayRegular)
            }
            Text("Your unique path starts here")
                .font(DS.Typography.subtitle)
                .foregroundColor(Color(.systemGray))
        }
    }

    var formCard: some View {
        DS.GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Where to?", icon: "mappin.circle.fill")
                    destinationTextfield
                }

                cardDivider

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        sectionLabel("Travel companions?", icon: "person.2.fill")
                        Spacer()
                        specifyButton
                    }
                    groupPicker
                }

                cardDivider

                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel("Trip duration?", icon: "clock.fill")
                    daysSlider
                    Text(store.state.durationText)
                        .font(.kanitMedium(16))
                        .foregroundColor(Color.appTint)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                cardDivider

                VStack(alignment: .leading, spacing: 2) {
                    sectionLabel("Start of your trip?", icon: "calendar")
                    monthsCarousel
                }
            }
        }
    }

    var cardDivider: some View {
        Divider().overlay(Color.white.opacity(0.5))
    }

    func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appTint)
            Text(text)
                .font(DS.Typography.fieldLabel)
        }
    }
}

// MARK: - Controls

extension BasicInfoScreen {
    var destinationTextfield: some View {
        HStack(spacing: 8) {
            Image("map-pin")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(.systemGray3))
                .frame(width: 20, height: 20)

            TextField("e.g. Barcelona", text: $store.state.destination)
                .font(.kanit(17).weight(.medium))
                .foregroundColor(.black)
                .focused($destinationFocused)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))
    }

    var specifyButton: some View {
        Button(action: {
            store.state.presentSpecifySheet.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.kanitBold(9))
                Text(store.state.specifyGroupText)
                    .font(.kanit(11))
            }
            .foregroundColor(store.state.groupSpecified ? Color.appTint.opacity(0.6) : Color.appTint)
        }
    }

    var specifyFormView: some View {
        SpecifyGroupView(
            averageAgeText: store.state.groupSpecification.stringAvgAge,
            genderSelection: store.state.groupSpecification.gender,
            customDescription: store.state.groupSpecification.customizations
        ) { result in
            store.send(.saveGroupSpecification(
                result.averageAge,
                result.gender,
                result.customDescription
            ))
            destinationFocused = false
        }
        .presentationDetents([.fraction(0.60), .large])  // sheet size behaviour
        .presentationDragIndicator(.visible)             // the little bar at top
    }

    var monthsCarousel: some View {
        ZStack {
            Picker("Month", selection: $store.state.month) {
                ForEach(Month.all, id: \.self) {
                    Text($0.simplified.capitalized)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(maxHeight: 92)
        }
        .frame(maxWidth: .infinity)
    }

    var daysSlider: some View {
        Slider(value: $store.state.duration, in: 1...14, step: 1)
            .tint(Color.appTint)
    }

    var groupPicker: some View {
        Picker(
            "Who are you travelling with?",
            selection: $store.state.groupSpecification.groupType
        ) {
            ForEach(Trip.Details.GroupType.all, id: \.self) { type in
                Text(type.rawValue.capitalized).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .tint(Color.appTint)
        .frame(height: 40)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    // Ensure tap priority over parent gestures for iOS 17+ compatibility
                }
        )
    }

    var ctaButton: some View {
        Button(action: {
            store.send(.continue)
            router.goToQuestionnaire()
            AnalyticsTracker.shared.log(
                .init(
                    .tripDetailsSubmitted,
                    properties: TripOrganizer.shared.basicInfoEventProperties
                )
            )
        }) {
            HStack(spacing: 6) {
                Text("Let's go")
                Image(systemName: "arrow.right")
            }
        }
        .disabled(!store.state.readyToContinue)
        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
    }
}

/// Layered, blurred gradient blobs standing in for the previous flat
/// two-stop linear gradient — same yellow/blue/purple family, more depth.
/// The dashed curve is a signature touch: a literal "path" tracing across
/// the background, echoing the "Your unique path starts here" subtitle.
struct AuroraBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gradientTop, Color.white, Color.gradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.appTint.opacity(0.32))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: -140, y: -280)

            Circle()
                .fill(Color.lightPurple.opacity(0.28))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 160, y: -180)

            Circle()
                .fill(Color(red: 1.0, green: 0.85, blue: 0.55).opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 140, y: 360)

            FlightPathShape()
                .stroke(
                    Color.white.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 9])
                )
        }
        .ignoresSafeArea()
    }
}

private struct FlightPathShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX - 30, y: rect.height * 0.32))
        path.addCurve(
            to: CGPoint(x: rect.maxX + 30, y: rect.height * 0.7),
            control1: CGPoint(x: rect.width * 0.32, y: rect.height * 0.06),
            control2: CGPoint(x: rect.width * 0.68, y: rect.height * 0.5)
        )
        return path
    }
}

#Preview {
    NavigationStack {
        BasicInfoScreen()
    }.environmentObject(NavigationRouter())
}
