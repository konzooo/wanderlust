import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

struct ProfileTabScreen: View {
    @ObservedObject private var library = TravellerProfileLibrary.shared
    @EnvironmentObject private var router: NavigationRouter
    @Environment(\.navigationTab) private var navigationTab

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    travellerPassport

                    personalisationMessage
                        .padding(.top, 14)

                    settingsSection
                        .padding(.top, 28)

                    communitySection
                        .padding(.top, 25)

#if DEBUG
                    developerSection
                        .padding(.top, 25)
#endif
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onTabRootAppear(.profile, router: router) {
            AnalyticsTracker.shared.log(.screenViewed(.profiles))
        }
    }

    private var travellerPassport: some View {
        NavigationLink {
            ProfilesScreen(
                navigationTitle: "Traveller profiles",
                showsDoneButton: false,
                automaticallyPresentsOnboarding: false
            )
        } label: {
            TravelPassportCard(
                profile: library.mainProfile,
                profileCount: library.profiles.count
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Traveller DNA profiles")
    }

    private var personalisationMessage: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appTint)
                .frame(width: 32, height: 32)
                .background(Color.appTint.opacity(0.10), in: Circle())

            Text("The more Wanderlust learns about you, the more personal your travel advice becomes.")
                .font(.kanit(14))
                .foregroundStyle(Color.primary.opacity(0.74))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
    }

    private var settingsSection: some View {
        ProfileMenuSection(title: "Settings") {
            NavigationLink {
                NotificationsScreen()
            } label: {
                ProfileMenuRow(
                    symbol: "bell.badge",
                    title: "Notifications",
                    subtitle: "Choose when Wanderlust checks in",
                    accessory: .chevron
                )
            }
            .buttonStyle(.plain)

            ProfileMenuDivider()

            ProfileMenuRow(
                symbol: "person.crop.circle",
                title: "Account",
                subtitle: "Your account and personal details",
                accessory: .comingSoon
            )
            .accessibilityElement(children: .combine)
        }
    }

    private var communitySection: some View {
        ProfileMenuSection(title: "Community") {
            Button {
                router.goToFeedback(on: navigationTab)
            } label: {
                ProfileMenuRow(
                    symbol: "bubble.left.and.bubble.right",
                    title: "Give Feedback",
                    subtitle: "Help shape what Wanderlust becomes",
                    accessory: .chevron
                )
            }
            .buttonStyle(.plain)
        }
    }

#if DEBUG
    private var developerSection: some View {
        ProfileMenuSection(title: "Developer") {
            Button {
                router.goToDebugMenu(on: navigationTab)
            } label: {
                ProfileMenuRow(
                    symbol: "ladybug",
                    title: "Debug Menu",
                    subtitle: "Design playground and QA controls",
                    accessory: .chevron
                )
            }
            .buttonStyle(.plain)
        }
    }
#endif
}

private struct TravelPassportCard: View {
    let profile: TravellerProfile?
    let profileCount: Int

    private var displayName: String {
        profile?.name ?? "Your travel profile"
    }

    private var archetype: String {
        profile?.archetype ?? "Ready to become uniquely yours"
    }

    private var countLabel: String? {
        guard profileCount > 0 else { return nil }
        return profileCount == 1 ? "1 profile" : "\(profileCount) profiles"
    }

    private var answers: [ProfileScaleAnswer] {
        profile?.scaleAnswers ?? [
            ProfileScaleAnswer(dimension: .adviceDetail, value: 4),
            ProfileScaleAnswer(dimension: .physicalEnergy, value: 3),
            ProfileScaleAnswer(dimension: .experienceBreadth, value: 2),
            ProfileScaleAnswer(dimension: .dayRhythm, value: 4),
            ProfileScaleAnswer(dimension: .structure, value: 2)
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#20274E"), Color(hex: "#3D4BA8"), Color.appTint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            passportDecoration

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("TRAVEL PASSPORT", systemImage: "airplane")
                        .font(.kanit(10).weight(.semibold))
                        .tracking(1.45)
                        .foregroundStyle(.white.opacity(0.76))

                    Spacer()

                    Text(profile == nil ? "SET UP" : "MAIN")
                        .font(.kanit(9).weight(.semibold))
                        .tracking(0.9)
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.12), in: Capsule())
                        .overlay { Capsule().stroke(.white.opacity(0.12), lineWidth: 1) }
                }

                HStack(spacing: 16) {
                    TravellerDNABlob(
                        answers: answers,
                        compact: true,
                        animated: false,
                        expressionText: displayName
                    )
                    .frame(width: 78, height: 78)
                    .padding(10)
                    .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.82), lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.kanit(25).weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(archetype)
                            .font(.kanit(13))
                            .foregroundStyle(.white.opacity(0.73))
                            .lineLimit(1)

                        if let countLabel {
                            Label(countLabel, systemImage: "person.2.fill")
                                .font(.kanit(10).weight(.medium))
                                .foregroundStyle(.white.opacity(0.58))
                                .padding(.top, 2)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 20)

                Spacer(minLength: 18)

                Rectangle()
                    .fill(.white.opacity(0.14))
                    .frame(height: 1)

                HStack(spacing: 8) {
                    Text(profile == nil ? "Create Traveller DNA" : "Manage Traveller DNA")
                        .font(.kanit(13).weight(.medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.11), in: Circle())
                }
                .foregroundStyle(.white.opacity(0.90))
                .padding(.top, 10)
            }
            .padding(20)
        }
        .frame(height: 246)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        }
        .shadow(color: Color(hex: "#27336F").opacity(0.24), radius: 22, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var passportDecoration: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 210, height: 210)
                    .position(x: proxy.size.width - 26, y: 14)

                Circle()
                    .stroke(.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 142, height: 142)
                    .position(x: proxy.size.width - 26, y: 14)

                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 128, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.035))
                    .position(x: proxy.size.width - 52, y: proxy.size.height - 38)
            }
        }
        .allowsHitTesting(false)
    }
}

private enum ProfileMenuAccessory {
    case chevron
    case comingSoon
}

private struct ProfileMenuSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.kanit(11).weight(.semibold))
                .tracking(1.55)
                .foregroundStyle(Color.secondary.opacity(0.86))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(.white.opacity(0.70), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(.white.opacity(0.76), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.025), radius: 12, y: 6)
        }
    }
}

private struct ProfileMenuRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let accessory: ProfileMenuAccessory

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.appTint)
                .frame(width: 38, height: 38)
                .background(Color.appTint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.kanit(15).weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.kanit(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            switch accessory {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.78))
            case .comingSoon:
                Text("COMING SOON")
                    .font(.kanit(8).weight(.semibold))
                    .tracking(0.55)
                    .foregroundStyle(Color.appTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.appTint.opacity(0.09), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 67)
        .contentShape(Rectangle())
    }
}

private struct ProfileMenuDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 65)
            .opacity(0.46)
    }
}

private struct NotificationsScreen: View {
    @AppStorage("profile.notifications.enabled") private var notificationsEnabled = true
    @AppStorage("profile.notifications.inspiration") private var inspirationEnabled = true
    @AppStorage("profile.notifications.tripReminders") private var tripRemindersEnabled = true
    @AppStorage("profile.notifications.groupActivity") private var groupActivityEnabled = true

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    notificationSection

                    Text("You can change these preferences at any time.")
                        .font(.kanit(11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.appTint)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(
                    LinearGradient(
                        colors: [Color.appTint, Color(hex: "#8B6BF6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .shadow(color: Color.appTint.opacity(0.24), radius: 16, y: 8)

            Text("Stay in the loop")
                .font(.kanit(24).weight(.semibold))

            Text("Choose the moments when you’d like Wanderlust to check in.")
                .font(.kanit(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("NOTIFICATIONS")
                .font(.kanit(11).weight(.semibold))
                .tracking(1.55)
                .foregroundStyle(Color.secondary.opacity(0.86))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                NotificationToggleRow(
                    symbol: "bell.fill",
                    title: "Allow notifications",
                    subtitle: "Keep helpful updates switched on",
                    isOn: $notificationsEnabled,
                    isEmphasized: true
                )

                Group {
                    ProfileMenuDivider()

                    NotificationToggleRow(
                        symbol: "sparkles",
                        title: "Fresh inspiration",
                        subtitle: "Occasional ideas picked for you",
                        isOn: $inspirationEnabled
                    )

                    ProfileMenuDivider()

                    NotificationToggleRow(
                        symbol: "calendar.badge.clock",
                        title: "Trip reminders",
                        subtitle: "Helpful nudges before you go",
                        isOn: $tripRemindersEnabled
                    )

                    ProfileMenuDivider()

                    NotificationToggleRow(
                        symbol: "person.3.fill",
                        title: "Group trip activity",
                        subtitle: "Votes and updates from your group",
                        isOn: $groupActivityEnabled
                    )
                }
                .disabled(!notificationsEnabled)
                .opacity(notificationsEnabled ? 1 : 0.42)
            }
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(.white.opacity(0.76), lineWidth: 1)
            }
        }
    }
}

private struct NotificationToggleRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var isEmphasized = false

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isEmphasized ? .white : Color.appTint)
                .frame(width: 36, height: 36)
                .background(
                    isEmphasized ? Color.appTint : Color.appTint.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.kanit(15).weight(.medium))
                Text(subtitle)
                    .font(.kanit(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 70)
    }
}

#Preview {
    NavigationStack {
        ProfileTabScreen()
    }
    .environmentObject(NavigationRouter())
}
