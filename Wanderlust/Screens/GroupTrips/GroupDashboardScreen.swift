import CoreArchitecture
import DesignSystem
import SwiftUI
import UIKit

struct GroupDashboardScreen: View {
    @ObservedObject var store: GroupDashboardStore
    @State private var newMemberName = ""
    @State private var didCopyLink = false

    @EnvironmentObject var router: NavigationRouter

    init(groupId: String) {
        self.store = GroupDashboardStore(groupId: groupId)
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            switch store.state.group {
            case .initial, .loading:
                ProgressView().tint(Color.appTint)
            case let .error(error):
                errorState(error)
            case let .loaded(group):
                content(group)
            }
        }
        .cleanTopInsets()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { backButton }
        }
        .simultaneousGesture(TapGesture().onEnded { _ in hideKeyboard() })
    }

    // MARK: - Loaded content

    private func content(_ group: GroupDTO) -> some View {
        VStack(spacing: 0) {
            header(group)
                .padding(.top, 8)
                .padding(.bottom, 18)

            ScrollView {
                VStack(spacing: 16) {
                    shareLinkCard(group)
                    statusCard(group)
                    rosterCard(group)

                    if let actionError = store.state.actionError {
                        Text(actionError).font(DS.Typography.subtitle).foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            if group.viewerIsAdmin {
                adminGenerateButton(group)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
    }

    private func header(_ group: GroupDTO) -> some View {
        VStack(spacing: 4) {
            Text(group.name).font(DS.Typography.displayRegular)
            Text("Different personalities — One Trip!")
                .font(DS.Typography.subtitle)
                .foregroundColor(Color(.systemGray))
        }
    }

    private func shareLinkCard(_ group: GroupDTO) -> some View {
        DS.GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                label("Share link to invite", icon: "link")
                HStack(spacing: 8) {
                    Text(shareLink(for: group.code))
                        .font(.kanit(14)).foregroundColor(.black)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = shareLink(for: group.code)
                        withAnimation { didCopyLink = true }
                        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); withAnimation { didCopyLink = false } }
                    } label: {
                        Image(systemName: didCopyLink ? "checkmark" : "doc.on.doc").foregroundStyle(Color.appTint)
                    }
                }
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))

                Text("Invite ID: \(group.code)")
                    .font(.kanit(12)).foregroundColor(Color(.systemGray))
            }
        }
    }

    @ViewBuilder
    private func statusCard(_ group: GroupDTO) -> some View {
        switch group.status {
        case .collecting:
            infoBanner(
                icon: "clock.fill",
                tint: Color.appTint,
                title: "Waiting for members",
                // Push is deferred, so we point to My Group Trips rather than
                // promising a notification.
                body: "Your trip appears here — and under My Group Trips — once everyone has submitted their choices."
            )
        case .generating:
            infoBanner(icon: "sparkles", tint: Color.appTint, title: "Creating your group trip…", body: "Blending everyone's preferences into one plan. This takes a moment.")
        case .ready:
            Button { router.goToGroupOutput(group) } label: {
                infoBanner(icon: "checkmark.circle.fill", tint: .green, title: "Your group trip is ready", body: "Tap to view your itinerary and suggestions.", chevron: true)
            }
            .buttonStyle(.plain)
        case .error:
            VStack(spacing: 12) {
                infoBanner(icon: "exclamationmark.triangle.fill", tint: .orange, title: "Something went wrong", body: group.viewerIsAdmin ? "Generation failed. You can try again." : "Generation failed. Ask the organizer to retry.")
                if group.viewerIsAdmin {
                    Button { store.send(.retry) } label: { Text("Try again") }
                        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                }
            }
        }
    }

    private func rosterCard(_ group: GroupDTO) -> some View {
        DS.GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    label(group.name, icon: "person.2.fill")
                    Spacer()
                    Text("\(group.completedCount)/\(group.memberCount) completed")
                        .font(.kanit(12)).foregroundColor(Color.appTint)
                }

                VStack(spacing: 10) {
                    ForEach(group.members) { member in
                        memberRow(member, group: group)
                    }
                }

                if group.viewerIsAdmin && group.status == .collecting {
                    cardDivider
                    addMemberField
                }
            }
        }
    }

    private func memberRow(_ member: MemberDTO, group: GroupDTO) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.circle.fill").foregroundStyle(Color(.systemGray3))
            Text(member.name).font(.kanit(16)).foregroundColor(.black)
            if member.isYou {
                Text("you").font(.kanit(11)).foregroundColor(Color.appTint)
            }
            Spacer()
            statusPill(member.status)
            if group.viewerIsAdmin && group.status == .collecting && !member.isAdmin && member.status != .completed {
                Button { store.send(.removeMember(member.memberId)) } label: {
                    Image(systemName: "minus.circle").foregroundStyle(Color(.systemGray2))
                }
            }
        }
    }

    @ViewBuilder
    private func statusPill(_ status: MemberStatus) -> some View {
        switch status {
        case .completed:
            pill("Completed", color: .green)
        case .pending:
            pill("Pending", color: .orange)
        case .skipped:
            pill("Skipped", color: Color(.systemGray))
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.kanit(11))
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var addMemberField: some View {
        HStack(spacing: 8) {
            SelectAllTextField("Add another member", text: $newMemberName, onCommit: addMember)
                .frame(height: 20)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))
            Button(action: addMember) {
                Image(systemName: "plus.circle.fill").font(.system(size: 26)).foregroundStyle(Color.appTint)
            }
            .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func addMember() {
        store.send(.addMember(newMemberName))
        newMemberName = ""
    }

    @ViewBuilder
    private func adminGenerateButton(_ group: GroupDTO) -> some View {
        if group.status == .collecting && group.completedCount >= 1 {
            Button { store.send(.generate) } label: {
                Text(group.canAutoGenerate
                     ? "Generate group trip"
                     : "Generate with \(group.completedCount) of \(group.memberCount) members")
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
        }
    }

    // MARK: - Building blocks

    private func infoBanner(icon: String, tint: Color, title: String, body: String, chevron: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).font(.system(size: 18, weight: .semibold))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.kanitMedium(15)).foregroundColor(.black)
                Text(body).font(.kanit(13)).foregroundColor(Color(.systemGray))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if chevron { Image(systemName: "chevron.right").foregroundStyle(Color(.systemGray3)) }
        }
        .padding(14)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous))
    }

    private var cardDivider: some View { Divider().overlay(Color.white.opacity(0.5)) }

    private func label(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.appTint)
            Text(text).font(DS.Typography.fieldLabel)
        }
    }

    private func errorState(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash").font(.system(size: 32)).foregroundStyle(Color(.systemGray2))
            Text("Couldn't load this group.").font(DS.Typography.subtitle).foregroundColor(Color(.systemGray))
        }
        .padding()
    }

    private var backButton: some View {
        Button { router.popToRoot() } label: {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.semibold)).foregroundStyle(.primary)
                .frame(width: 44, height: 44, alignment: .leading).contentShape(Rectangle())
        }
        .accessibilityLabel("Back")
    }

    private func shareLink(for code: String) -> String {
        "https://get-catalyst.app/join/\(code)"
    }
}
