//
//  DebugMenuScreen.swift
//  Wanderlust
//
//  Internal-only screen for QA toggles and design-in-progress previews.
//  Reached via a triple-tap on the Home screen logo (DEBUG builds only).
//

import CoreArchitecture
import DesignSystem
import SwiftUI

struct DebugMenuScreen: View {
    @AppStorage(DebugSettings.useMockTripDataKey) private var useMockTripData = false
    @State private var didResetOnboarding = false
    @State private var costs: AsyncValue<[GenerationCostRow]> = .initial
    @State private var showsCostInfo = false

    var body: some View {
        List {
            Section("Data") {
                Toggle(isOn: $useMockTripData) {
                    Label("Mock trip data (no API)", systemImage: "ladybug.fill")
                }
                .tint(Color.appTint)
            }

            Section {
                if let pooled = NearYouStats.pooledSurvivalRate {
                    LabeledContent("Survival rate") {
                        Text(percent(pooled))
                            .foregroundStyle(pooled < 0.5 ? Color.red : Color.primary)
                    }
                } else {
                    Text("No Near You runs recorded yet")
                        .font(.kanit(13))
                        .foregroundColor(Color(.systemGray))
                }

                ForEach(NearYouStats.recent().prefix(5)) { run in
                    LabeledContent {
                        Text(percent(run.survivalRate))
                            .font(.kanit(13))
                            .foregroundColor(Color(.systemGray))
                    } label: {
                        Text("\(run.proposed) proposed → \(run.resolved) found → \(run.survived) shown")
                            .font(.kanit(13))
                    }
                }
            } header: {
                Text("Near You verification")
            } footer: {
                Text("Share of model-proposed places that MapKit could find and route to within the walking radius. A low found count means the names or hints are vague; a healthy found count with few shown means the model knows the city but not this street.")
            }

            Section {
                switch costs {
                case .initial, .loading:
                    HStack { ProgressView(); Text("Loading").font(.kanit(13)) }
                case .error:
                    Text("Couldn't load spend").font(.kanit(13)).foregroundColor(.red)
                case let .loaded(rows) where rows.isEmpty:
                    Text("No model calls recorded yet")
                        .font(.kanit(13))
                        .foregroundColor(Color(.systemGray))
                case let .loaded(rows):
                    ForEach(rows.prefix(5)) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(row.component).font(.kanit(15).weight(.medium))
                                Spacer()
                                Text(row.costUSD.map(money) ?? "—")
                                    .font(.kanit(15))
                            }
                            Text("\(row.model ?? "unknown model") · \(seconds(row.durationMs)) · \(row.inputTokens) in / \(row.outputTokens) out")
                                .font(.kanit(12))
                                .foregroundColor(Color(.systemGray))
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                HStack {
                    Text("Recent model calls")
                    Spacer()
                    Button {
                        showsCostInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.appTint)
                    .accessibilityLabel("How cost is estimated")
                }
            }

            Section {
                Button(action: resetOnboarding) {
                    Label(
                        didResetOnboarding ? "Onboarding reset" : "Reset onboarding",
                        systemImage: didResetOnboarding ? "checkmark.circle.fill" : "arrow.counterclockwise"
                    )
                }
                .disabled(didResetOnboarding)
            } footer: {
                Text("Clears the welcome, group, joiner, questionnaire, trip output and Traveller DNA flags. The welcome flow is gated on cold launch, so quit and relaunch to see it.")
            }

            Section {
                ForEach(DesignPlayground.variants) { variant in
                    NavigationLink(destination: variant.destination) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(variant.title)
                                .font(.kanit(15).weight(.medium))
                            Text(variant.subtitle)
                                .font(.kanit(12))
                                .foregroundColor(Color(.systemGray))
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Design Playground")
            } footer: {
                Text("In-progress redesigns. Add or remove entries in DesignPlayground.swift.")
            }
        }
        .navigationTitle("Debug Menu")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsCostInfo) { costInfo }
        .task {
            guard case .initial = costs else { return }
            costs = .loading
            do {
                costs = .loaded(try await GroupTripService.shared.recentCosts())
            } catch {
                costs = .error(error)
            }
        }
    }

    /// Everything that makes the figure beside each call an estimate rather
    /// than a bill. It lives behind an icon because it is the kind of thing you
    /// need once, when the number first surprises you.
    private var costInfo: some View {
        NavigationStack {
            List {
                Section {
                    Text("Every model call records how many tokens it used. The cost beside each one is those tokens multiplied by a price list kept in costs.ts — not a figure returned by OpenAI.")
                } header: {
                    Text("What the number is")
                }

                Section {
                    infoRow("Input", "Tokens sent — the prompt and the traveller's answers. Tokens OpenAI had already cached from a previous call are billed at a lower rate and counted separately.")
                    infoRow("Output", "Tokens written back. On models that think before answering, that thinking is billed as output, so it is already inside this figure rather than missing from it.")
                    infoRow("Web search", "Charged per search action. Zero for every component since Near You stopped searching.")
                    infoRow("Retries", "A call that needed a corrective second attempt sums both attempts into one row, so a retry shows as one expensive call rather than disappearing.")
                } header: {
                    Text("What is counted")
                }

                Section {
                    infoRow("Prices drift", "The price list is maintained by hand and nothing warns you when OpenAI changes it. This is the weakest part: it fails silently and confidently.")
                    infoRow("Failures still cost", "A call that failed or was cut off at its token ceiling was still billed for what it produced. Those look like ordinary expensive rows.")
                    infoRow("It is a sample", "The last 20 calls on whichever backend this build talks to — the dev one in a Debug build. It will never match an OpenAI invoice.")
                    infoRow("A dash", "Means the model has no price listed, shown as unknown rather than as zero.")
                } header: {
                    Text("Why it is an estimate")
                } footer: {
                    Text("Good for asking which component costs or takes the most. Not accounting.")
                }
            }
            .navigationTitle("How cost is estimated")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsCostInfo = false }
                }
            }
        }
    }

    private func infoRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.kanit(15).weight(.medium))
            Text(detail)
                .font(.kanit(13))
                .foregroundColor(Color(.systemGray))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func seconds(_ ms: Int) -> String {
        String(format: "%.1fs", Double(ms) / 1_000)
    }

    private func money(_ usd: Double) -> String {
        // Sub-cent calls are the normal case now, so two decimal places would
        // render almost every row as "$0.00".
        usd < 0.01 ? String(format: "%.4f USD", usd) : String(format: "%.2f USD", usd)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func resetOnboarding() {
        OnboardingPreferenceKey.all.forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        OnboardingSession.shared.reset()
        didResetOnboarding = true
    }
}

#Preview {
    NavigationStack {
        DebugMenuScreen()
    }
    .environmentObject(NavigationRouter())
}
