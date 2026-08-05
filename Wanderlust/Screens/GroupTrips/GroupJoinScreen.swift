import CoreArchitecture
import DesignSystem
import SwiftUI

/// The joiner's landing screen (deep link or invite ID). Shows the roster so
/// the joiner can claim a name the admin entered, or add themselves.
struct GroupJoinScreen: View {
    @ObservedObject var store: GroupJoinStore

    @EnvironmentObject var router: NavigationRouter

    init(code: String) {
        self.store = GroupJoinStore(code: code)
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            switch store.state.resolved {
            case .initial, .loading:
                ProgressView().tint(Color.appTint)
            case .error:
                invalidCodeState
            case let .loaded(dto):
                content(dto)
            }
        }
        .cleanTopInsets()
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .navigationBarLeading) { backButton } }
        .simultaneousGesture(TapGesture().onEnded { _ in hideKeyboard() })
        .onAppear {
            store.setAnalyticsSource(router.groupJoinAnalyticsSource)
            AnalyticsTracker.shared.log(.screenViewed(.groupJoin))
        }
        .onChange(of: store.state.joinedGroupId) { _, groupId in
            if let groupId { router.goToGroupSwipe(groupId, resetStack: true) }
        }
    }

    // MARK: - Content

    private func content(_ dto: JoinDTO) -> some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 8)
                .padding(.bottom, 18)

            if dto.status != .collecting {
                closedState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        rosterCard(dto)
                        if let errorMessage = store.state.errorMessage {
                            Text(errorMessage).font(DS.Typography.subtitle).foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                joinButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Join a group Trip").font(DS.Typography.displayRegular)
            Text("Different personalities — One Trip!")
                .font(DS.Typography.subtitle)
                .foregroundColor(Color(.systemGray))
        }
    }

    private func rosterCard(_ dto: JoinDTO) -> some View {
        DS.GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    label(dto.name, icon: "person.2.fill")
                    Spacer()
                    Text("\(dto.members.count) member\(dto.members.count == 1 ? "" : "s")")
                        .font(.kanit(12)).foregroundColor(Color.appTint)
                }
                Text("Select your name below")
                    .font(.kanit(13)).foregroundColor(Color(.systemGray))

                VStack(spacing: 10) {
                    ForEach(dto.members) { member in
                        memberRow(member)
                    }
                }

                addYourselfControl
            }
        }
    }

    private func memberRow(_ member: JoinMemberDTO) -> some View {
        let isSelected = store.state.selection == .existing(member.memberId)
        return Button {
            if !member.claimed { store.send(.selectExisting(member.memberId)) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill").foregroundStyle(Color(.systemGray3))
                Text(member.name)
                    .font(.kanit(16))
                    .foregroundColor(member.claimed ? Color(.systemGray2) : .black)
                Spacer()
                if member.claimed {
                    Text("taken").font(.kanit(11)).foregroundColor(Color(.systemGray2))
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.appTint)
                }
            }
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(isSelected ? Color.appTint.opacity(0.12) : Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(member.claimed)
    }

    @ViewBuilder
    private var addYourselfControl: some View {
        if store.state.selection == .new {
            HStack(spacing: 8) {
                SelectAllTextField("Enter your name", text: Binding(
                    get: { store.state.newName },
                    set: { store.send(.updateNewName($0)) }
                ), onCommit: { store.send(.join) })
                .frame(height: 22)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))
            }
        } else {
            Button {
                store.send(.startAddYourself)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Add yourself")
                }
                .font(.kanit(15))
                .foregroundColor(Color.appTint)
            }
        }
    }

    private var joinButton: some View {
        Button {
            store.send(.join)
        } label: {
            if store.state.isJoining {
                ProgressView().tint(.white)
            } else {
                HStack(spacing: 6) {
                    Text("Start with your preferences")
                    Image(systemName: "arrow.right")
                }
            }
        }
        .disabled(!store.state.canJoin || store.state.isJoining)
        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
    }

    private var closedState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.fill").font(.system(size: 40)).foregroundStyle(Color(.systemGray2))
            Text("This trip already started").font(DS.Typography.displayLight)
            Text("The organizer has already generated the group trip, so it can't be joined.")
                .font(DS.Typography.subtitle).foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var invalidCodeState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle").font(.system(size: 40)).foregroundStyle(Color(.systemGray2))
            Text("Invite not found").font(DS.Typography.displayLight)
            Text("Double-check the invite ID or link and try again.")
                .font(DS.Typography.subtitle).foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private func label(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.appTint)
            Text(text).font(DS.Typography.fieldLabel)
        }
    }

    private var backButton: some View {
        Button { router.popToRoot() } label: {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.semibold)).foregroundStyle(.primary)
                .frame(width: 44, height: 44, alignment: .leading).contentShape(Rectangle())
        }
        .accessibilityLabel("Back")
    }
}
