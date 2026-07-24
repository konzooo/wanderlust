import CoreArchitecture
import DesignSystem
import SwiftUI
import UIKit

struct GroupTripMembersScreen: View {
    @ObservedObject var store: GroupTripMembersStore
    @State private var didCopyLink = false

    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.bottom, 22)

                ScrollView {
                    VStack(spacing: 16) {
                        shareLinkCard
                        rosterCard

                        if let errorMessage = store.state.errorMessage {
                            Text(errorMessage)
                                .font(DS.Typography.subtitle)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Enabled once M3 wires the group swipe + submit path.
                startSwipingButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .cleanTopInsets()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded { _ in hideKeyboard() }
        )
    }
}

// MARK: - Sections

extension GroupTripMembersScreen {
    var header: some View {
        VStack(spacing: 4) {
            Text(store.state.groupName)
                .font(DS.Typography.displayRegular)
            Text("Add and invite group members")
                .font(DS.Typography.subtitle)
                .foregroundColor(Color(.systemGray))
        }
    }

    var shareLinkCard: some View {
        DS.GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Share link to invite", icon: "link")

                HStack(spacing: 8) {
                    Text(store.state.shareLink)
                        .font(.kanit(14))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = store.state.shareLink
                        withAnimation { didCopyLink = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            withAnimation { didCopyLink = false }
                        }
                    } label: {
                        Image(systemName: didCopyLink ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(Color.appTint)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))
            }
        }
    }

    var rosterCard: some View {
        DS.GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    sectionLabel(store.state.groupName, icon: "person.2.fill")
                    Spacer()
                    Text("\(store.state.members.count) member\(store.state.members.count == 1 ? "" : "s")")
                        .font(.kanit(12)).foregroundColor(Color.appTint)
                }

                if !store.state.hasAddedSelf {
                    Text("Add your name first, then invite the rest of your group.")
                        .font(.kanit(13)).foregroundColor(Color(.systemGray))
                }

                if !store.state.members.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.state.members) { member in
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(Color(.systemGray3))
                                Text(member.name)
                                    .font(.kanit(16))
                                    .foregroundColor(.black)
                                if member.isAdmin {
                                    Text("you").font(.kanit(11)).foregroundColor(Color.appTint)
                                }
                                Spacer()
                            }
                        }
                    }

                    cardDivider
                }

                addMemberField
            }
        }
    }

    var cardDivider: some View {
        Divider().overlay(Color.white.opacity(0.5))
    }

    var addMemberField: some View {
        HStack(spacing: 8) {
            SelectAllTextField(
                store.state.hasAddedSelf ? "Add member" : "Your name",
                text: $store.state.newMemberName,
                onCommit: { store.send(.addMember) }
            )
                .frame(height: 22)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))

            Button {
                store.send(.addMember)
            } label: {
                if store.state.isAddingMember {
                    ProgressView()
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.appTint)
                }
            }
            .disabled(store.state.newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.state.isAddingMember)
        }
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

    var startSwipingButton: some View {
        Button(action: {
            router.goToGroupSwipe(store.state.groupId)
        }) {
            HStack(spacing: 6) {
                Text("Start with your preferences")
                Image(systemName: "arrow.right")
            }
        }
        .disabled(!store.state.hasAddedSelf)
        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
    }

    var backButton: some View {
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
}

#Preview {
    NavigationStack {
        GroupTripMembersScreen(
            store: GroupTripMembersStore(
                initialState: .init(
                    groupId: "preview",
                    code: "12345",
                    groupName: "Barcelona Squad",
                    destination: "Barcelona",
                    adminToken: "preview-token"
                )
            )
        )
    }.environmentObject(NavigationRouter())
}
