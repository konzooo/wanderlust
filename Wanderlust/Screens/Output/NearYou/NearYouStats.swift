//
//  NearYouStats.swift
//  Wanderlust
//
//  Survival-rate telemetry for the propose-then-verify pipeline.
//

import CoreArchitecture
import Foundation

/// How many model proposals survived the map gate, over the last few runs.
///
/// This exists because the failure mode it watches for is silent. If the model
/// drifts towards naming places that are vague, renamed or simply invented, the
/// screen does not break — it just quietly gets thinner, and nothing in the
/// finished result says why. The ratio between proposed, resolved and survived
/// separates the two causes that need different fixes: a low *resolved* count
/// means the names or hints are bad, while a healthy resolved count with a low
/// *survived* count means the model knows the city but not this neighbourhood.
enum NearYouStats {
    struct Run: Codable, Equatable, Identifiable, Sendable {
        var id: Date { at }
        let at: Date
        let proposed: Int
        let resolved: Int
        let survived: Int

        /// Share of proposals that reached the traveller.
        var survivalRate: Double {
            proposed == 0 ? 0 : Double(survived) / Double(proposed)
        }
    }

    private static let storageKey = "debug.nearYou.runs"
    private static let maxRuns = 20

    @MainActor
    static func record(_ verification: NearYouVerification) {
        let run = Run(
            at: Date(),
            proposed: verification.proposed,
            resolved: verification.resolved,
            survived: verification.survived
        )

        var runs = recent()
        runs.insert(run, at: 0)
        runs = Array(runs.prefix(maxRuns))
        if let data = try? JSONEncoder().encode(runs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }

        AnalyticsTracker.shared.log(
            .init(.nearYouVerified, properties: [
                "proposed": .integer(run.proposed),
                "resolved": .integer(run.resolved),
                "survived": .integer(run.survived)
            ])
        )
    }

    static func recent() -> [Run] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let runs = try? JSONDecoder().decode([Run].self, from: data)
        else { return [] }
        return runs
    }

    /// Pooled across runs rather than averaged per run, so one three-proposal
    /// run in a village cannot swing the number as hard as a full city run.
    static var pooledSurvivalRate: Double? {
        let runs = recent()
        let proposed = runs.reduce(0) { $0 + $1.proposed }
        guard proposed > 0 else { return nil }
        return Double(runs.reduce(0) { $0 + $1.survived }) / Double(proposed)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
