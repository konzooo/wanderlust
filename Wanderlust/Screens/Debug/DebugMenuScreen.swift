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
                Text("Recent model calls")
            } footer: {
                Text("Rates are hand-maintained in costs.ts and drift as OpenAI's prices change, so read this for comparison between components rather than as a bill. A dash means the row predates model recording or names a model with no rate.")
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
