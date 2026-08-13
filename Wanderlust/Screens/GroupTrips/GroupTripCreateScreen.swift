import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

struct GroupTripCreateScreen: View {
    @StateObject var store: GroupTripCreateStore
    @State private var didInitializeProfileSelection = false

    @EnvironmentObject var router: NavigationRouter

    @MainActor
    init(store: GroupTripCreateStore? = nil) {
        _store = StateObject(wrappedValue: store ?? GroupTripCreateStore())
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                segmentedControl
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                switch store.state.segment {
                case .create:
                    ScrollView {
                        formCard
                            .padding(.horizontal, 20)

                        if let errorMessage = store.state.errorMessage {
                            Text(errorMessage)
                                .font(DS.Typography.subtitle)
                                .foregroundColor(.red)
                                .padding(.top, 12)
                                .padding(.horizontal, 20)
                        }
                    }

                    ctaButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                case .join:
                    joinContent
                        .padding(.horizontal, 20)

                    Spacer()

                    joinButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
            }
        }
        .cleanTopInsets()
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileSelectionButton(selection: $store.state.selectedProfileID)
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileSelectionButton(selection: $store.state.selectedProfileID)
                }
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded { _ in hideKeyboard() }
        )
        .onChange(of: store.state.createdGroup) { _, createdGroup in
            guard let createdGroup else { return }
            router.goToGroupMembers(
                GroupTripMembersStore.State(
                    groupId: createdGroup.groupId,
                    code: createdGroup.code,
                    groupName: store.state.groupName,
                    destination: store.state.destination,
                    adminToken: createdGroup.adminToken,
                    selectedProfileID: store.state.selectedProfileID,
                    createdAt: createdGroup.createdAt,
                    startMonth: Month(wireValue: createdGroup.startMonth) ?? store.state.month,
                    durationDays: createdGroup.durationDays
                )
            )
        }
        .onAppear {
            AnalyticsTracker.shared.log(.screenViewed(.groupCreate))
            guard !didInitializeProfileSelection else { return }
            didInitializeProfileSelection = true
            store.state.selectedProfileID = TravellerProfileLibrary.shared.defaultSelectionID
        }
    }
}

// MARK: - Sections

extension GroupTripCreateScreen {
    var header: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.appTint)
                Text("Group Trip")
                    .font(DS.Typography.displayRegular)
            }
            Text("Different personalities — One Trip!")
                .font(DS.Typography.subtitle)
                .foregroundColor(Color(.systemGray))
        }
    }

    var segmentedControl: some View {
        Picker("Mode", selection: $store.state.segment) {
            ForEach(GroupTripCreateStore.Segment.allCases, id: \.self) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    var joinContent: some View {
        DS.GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Join via Invite ID", icon: "number")
                Text("Ask your group to share the invite link or ID.")
                    .font(.kanit(13))
                    .foregroundColor(Color(.systemGray))
                SelectAllTextField("e.g. 23696", text: $store.state.joinCode, keyboardType: .numberPad)
                    .frame(height: 24)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))
            }
        }
    }

    var joinButton: some View {
        Button(action: {
            hideKeyboard()
            router.goToGroupJoin(code: store.state.normalizedJoinCode)
        }) {
            HStack(spacing: 6) {
                Text("Join Trip")
                Image(systemName: "arrow.right")
            }
        }
        .disabled(!store.state.readyToJoin)
        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
    }

    var formCard: some View {
        DS.GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Where to?", icon: "mappin.circle.fill")
                    destinationTextField
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

                cardDivider

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Group name", icon: "person.3.fill")
                    groupNameTextField
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

extension GroupTripCreateScreen {
    var groupNameTextField: some View {
        textField("e.g. Barcelona Squad", text: $store.state.groupName)
    }

    var destinationTextField: some View {
        textField("e.g. Barcelona", text: $store.state.destination)
    }

    private func textField(_ placeholder: String, text: Binding<String>) -> some View {
        SelectAllTextField(placeholder, text: text)
            .frame(height: 24)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))
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

    var ctaButton: some View {
        Button(action: {
            hideKeyboard()
            store.send(.createGroup)
        }) {
            if store.state.isCreating {
                ProgressView().tint(.white)
            } else {
                HStack(spacing: 6) {
                    Text("Create Group Trip")
                    Image(systemName: "arrow.right")
                }
            }
        }
        .disabled(!store.state.readyToCreate || store.state.isCreating)
        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
    }
}

#Preview {
    NavigationStack {
        GroupTripCreateScreen()
    }.environmentObject(NavigationRouter())
}
