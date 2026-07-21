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

    @EnvironmentObject var router: NavigationRouter    
        
    var body: some View {
        contentScrollView
            .gradientBackground()
            .cleanTopInsets()
            .onAppear {
                AnalyticsTracker.shared.log(.screenViewed(.basicInfo))
            }
            .sheet(isPresented: $store.state.presentSpecifySheet) {
                specifyFormView
            }
            .animation(.easeInOut, value: store.state.presentSpecifySheet)
            .drawerToolbar(isOpen: $isDrawerOpen, selected: .newTrip, router: router)
    }
}

extension BasicInfoScreen {
    var contentScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                titleSubtitle
                    .padding(.bottom, 30)
                
                whiteCardForm
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            // Dismiss keyboard when tapping on the card background
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        destinationFocused = false
                    }
            )
        }
    }
    
    var titleSubtitle: some View {
        VStack(spacing: 0) {
            Text("Next Trip")
                .font(.kanit(34))
            Text("Your unique path starts here")
                .font(.kanitLight(18))
                .foregroundColor(Color(.systemGray))
        }
    }
    
    var whiteCardForm: some View {
        VStack(spacing: 0) {
            basicInfoForm
            
            bottomCTA
                .padding(.top, .Padding.md)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color(.systemGray4).opacity(0.3), radius: 12, x: 0, y: 4)
    }

    var basicInfoForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Destination
            Text("Where to?")
                .font(.kanitMedium(16))
                .padding(.bottom, 10)

            destinationTextfield
                .padding(.bottom, .Spacing.large)

            // Group type
            Text("Travel companions?")
                .font(.kanitMedium(16))
                .padding(.top, 8)
                .padding(.bottom, 10)
            groupPicker
            specifyButton
                .padding(.horizontal, .Padding.sm)
                .padding(.top, .Spacing.small)
                .padding(.bottom, .Spacing.small)

            // Duration
            Text("Trip duration?")
                .font(.kanitMedium(16))
                .padding(.top, 8)
                .padding(.bottom, 10)
            daysSlider
                .padding(.bottom, .Spacing.large)
                .padding(.horizontal, .Padding.sm3)

            // Month
            Text("Start of your trip?")
                .font(.kanitMedium(16))
                .padding(.top, 8)

            monthsCarousel

            Spacer()
        }
    }
    
    var destinationTextfield: some View {
        ZStack(alignment: .leading) {
            if store.state.destination.isEmpty {
                HStack(spacing: 8) {
                    Image("map-pin")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color(.systemGray3))
                        .frame(width: 26, height: 26)
                    
                    Text("e.g. Barcelona")
                        .foregroundColor(Color(.systemGray3))
                        .font(.kanit(16).weight(.light))
                        .italic()                }
            }
            TextField("", text: $store.state.destination)
                .font(.kanit(20).weight(.medium))
                .foregroundColor(.black)
                .focused($destinationFocused)
        }
        .padding(.vertical, .Padding.sm3)
        .padding(.horizontal, .Padding.sm2)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    var specifyButton: some View {
        HStack {
            Spacer()
            
            Button(action: {
                AnalyticsTracker.shared.log(.buttonTapped("specify_group", screen: .basicInfo))
                store.state.presentSpecifySheet.toggle()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "pencil")
                        .font(.kanitBold(10))

                    Text(store.state.specifyGroupText)
                        .font(.kanit(12))
                }
                .foregroundColor(store.state.groupSpecified ? Color.appTint.opacity(0.6) : Color.appTint)
            }
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
            .frame(maxHeight: 100)
        }
        .frame(maxWidth: .infinity)
    }

    var daysSlider: some View {
        VStack {
            Slider(value: $store.state.duration, in: 1...14, step: 1)
                .tint(Color.appTint)

            Text(store.state.durationText)
                .foregroundColor(.appTint)
                .font(.body.bold())
        }
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
        .frame(height: 44)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    // Ensure tap priority over parent gestures for iOS 17+ compatibility
                }
        )
    }

    var bottomCTA: some View {
        Button("Let's go →", action: {
            store.send(.continue)
            router.goToQuestionnaire()
            AnalyticsTracker.shared.log(
                .confirmBasicInfo(
                    properties: TripOrganizer.shared.basicInfoEventProperties
                )
            )
        })
        .disabled(!store.state.readyToContinue)
        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
    }
}

#Preview {
    NavigationStack {
        BasicInfoScreen()
    }.environmentObject(NavigationRouter())
}
