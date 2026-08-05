import CoreArchitecture
import DesignSystem
import SwiftUI
import UIKit

struct GroupDashboardScreen: View {
    @ObservedObject var store: GroupDashboardStore
    @State private var newMemberName = ""
    @State private var didCopyLink = false
    @State private var isEditingRoster = false
    @State private var isAddingMember = false
    @State private var pendingGenerateWarning = false

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
        .onAppear {
            AnalyticsTracker.shared.log(.screenViewed(.groupDashboard))
        }
    }

    // MARK: - Loaded content

    private func content(_ group: GroupDTO) -> some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 8)
                .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    shareLinkCard(group)
                    statusCard(group)

                    // Group name as a title, visually separated above the box.
                    HStack(alignment: .firstTextBaseline) {
                        Text(group.name)
                            .font(.kanit(24))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(group.completedCount)/\(group.memberCount) completed")
                            .font(.kanit(13))
                            .foregroundColor(Color.appTint)
                    }
                    .padding(.top, 4)

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
        .alert("Generate without everyone?", isPresented: $pendingGenerateWarning) {
            Button("Generate anyway", role: .destructive) { store.send(.generate) }
            Button("Go back", role: .cancel) {}
        } message: {
            Text(incompleteWarningMessage(group))
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Group Trip").font(DS.Typography.displayRegular)
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
                        AnalyticsTracker.shared.log(
                            .init(.groupInviteShared, properties: [
                                "method": .string("copy_link"),
                                "roster_count": .integer(group.memberCount)
                            ])
                        )
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
                body: "Your trip appears here once everyone has submitted."
            )
        case .generating:
            generatingBanner
        case .ready:
            // A ready trip can still be missing a best-effort component: the
            // itinerary is required, everything else ships when it works and
            // says so when it doesn't, rather than failing the whole trip.
            let suggestions = group.state(of: .suggestions)
            VStack(spacing: 12) {
                Button { router.goToGroupOutput(group) } label: {
                    infoBanner(
                        icon: "checkmark.circle.fill",
                        tint: .green,
                        title: "Your group trip is ready",
                        body: suggestions.isReady
                            ? "Tap to view your itinerary and suggestions."
                            : "Tap to view your itinerary.",
                        chevron: true
                    )
                }
                .buttonStyle(.plain)

                if suggestions.isGenerating {
                    infoBanner(
                        icon: "sparkles",
                        tint: .orange,
                        title: "Still writing your suggestions",
                        body: "Your itinerary is ready to read in the meantime."
                    )
                } else if group.canRetry {
                    infoBanner(
                        icon: "exclamationmark.triangle.fill",
                        tint: .orange,
                        title: "Suggestions didn't come through",
                        body: group.viewerIsAdmin
                            ? "Your itinerary is fine. You can try the rest again."
                            : "Your itinerary is fine. Ask the organizer to try the rest again."
                    )
                    if group.viewerIsAdmin {
                        Button { store.send(.retry) } label: { Text("Try again") }
                            .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                    }
                }
            }
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

    private var generatingBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "map.fill").foregroundStyle(Color.appTint).font(.system(size: 18, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Creating your group trip").font(.kanitMedium(15)).foregroundColor(.black)
                    AnimatedDots()
                }
                Text("Blending everyone's preferences into one plan. This should only take a minute.")
                    .font(.kanit(13)).foregroundColor(Color(.systemGray))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.appTint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous))
    }

    private func rosterCard(_ group: GroupDTO) -> some View {
        DS.GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 10) {
                    ForEach(group.members) { member in
                        memberRow(member, group: group)
                    }
                }

                if group.viewerIsAdmin && group.status == .collecting {
                    cardDivider
                    rosterFooter(group)
                }
            }
        }
    }

    private func memberRow(_ member: MemberDTO, group: GroupDTO) -> some View {
        HStack(spacing: 8) {
            // Reserve the leading slot for every row in edit mode so names stay
            // aligned (classic iOS list-edit behavior).
            if isEditingRoster {
                if isRemovable(member) {
                    Button { store.send(.removeMember(member.memberId)) } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 20))
                    }
                } else {
                    Color.clear.frame(width: 20, height: 20)
                }
            }
            Image(systemName: "person.circle.fill").foregroundStyle(Color(.systemGray3))
            Text(member.name).font(.kanit(16)).foregroundColor(.black)
            if member.isYou {
                Text("you").font(.kanit(11)).foregroundColor(Color.appTint)
            }
            Spacer()
            statusPill(member.status)
        }
        .animation(.easeInOut(duration: 0.2), value: isEditingRoster)
    }

    private func rosterFooter(_ group: GroupDTO) -> some View {
        HStack(spacing: 8) {
            if isAddingMember {
                SelectAllTextField("Name", text: $newMemberName, onCommit: addMember)
                    .frame(height: 20)
                    .padding(.vertical, 9).padding(.horizontal, 12)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))
                Button(action: addMember) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 26)).foregroundStyle(Color.appTint)
                }
                .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Button {
                    withAnimation { isAddingMember = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add another member")
                    }
                    .font(.kanit(15))
                    .foregroundColor(Color.appTint)
                }

                Spacer()

                if hasRemovableMembers(group) {
                    Button {
                        withAnimation { isEditingRoster.toggle() }
                    } label: {
                        Text(isEditingRoster ? "Done" : "Edit")
                            .font(.kanit(15))
                            .foregroundColor(isEditingRoster ? Color.appTint : Color(.systemGray))
                    }
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

    private func addMember() {
        store.send(.addMember(newMemberName))
        newMemberName = ""
        withAnimation { isAddingMember = false }
    }

    @ViewBuilder
    private func adminGenerateButton(_ group: GroupDTO) -> some View {
        if group.status == .collecting && group.completedCount >= 1 {
            Button {
                if group.canAutoGenerate {
                    store.send(.generate)
                } else {
                    pendingGenerateWarning = true
                }
            } label: {
                Text(group.canAutoGenerate
                     ? "Generate group trip"
                     : "Generate with \(group.completedCount) of \(group.memberCount) members")
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
        }
    }

    // MARK: - Helpers

    private func isRemovable(_ member: MemberDTO) -> Bool {
        !member.isAdmin && member.status != .completed
    }

    private func hasRemovableMembers(_ group: GroupDTO) -> Bool {
        group.members.contains(where: isRemovable)
    }

    private func incompleteWarningMessage(_ group: GroupDTO) -> String {
        let pending = group.members.filter { $0.status == .pending }.map(\.name)
        let names: String
        switch pending.count {
        case 0: names = "Some members"
        case 1: names = pending[0]
        case 2: names = "\(pending[0]) and \(pending[1])"
        default: names = "\(pending.prefix(2).joined(separator: ", ")) and \(pending.count - 2) more"
        }
        return "\(names) haven't finished yet. We'll generate the trip from the \(group.completedCount) member\(group.completedCount == 1 ? "" : "s") who did, and this closes the group."
    }

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
        Button { router.pop() } label: {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.semibold)).foregroundStyle(.primary)
                .frame(width: 44, height: 44, alignment: .leading).contentShape(Rectangle())
        }
        .accessibilityLabel("Back")
    }

    private func shareLink(for code: String) -> String {
        "https://wanderlust.get-catalyst.app/join/\(code)"
    }
}

/// Three dots that fade in sequence — a subtle "working…" indicator.
private struct AnimatedDots: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.appTint)
                    .frame(width: 5, height: 5)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}
