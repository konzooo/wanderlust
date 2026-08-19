import Foundation

/// Stable, versioned dimensions that make up a Traveller DNA profile.
public enum TravellerDNADimension: String, CaseIterable, Codable, Hashable, Sendable {
    case adviceDetail = "advice_detail"
    case physicalEnergy = "physical_energy"
    case experienceBreadth = "experience_breadth"
    case dayRhythm = "day_rhythm"
    case structure = "structure"

    public var leftLabel: String {
        switch self {
        case .adviceDetail: "Give me the essentials"
        case .physicalEnergy: "Keep it easy"
        case .experienceBreadth: "A few things, properly"
        case .dayRhythm: "Early start"
        case .structure: "A clear plan"
        }
    }

    public var rightLabel: String {
        switch self {
        case .adviceDetail: "Give me the story and context"
        case .physicalEnergy: "I enjoy an active day"
        case .experienceBreadth: "Lots of different experiences"
        case .dayRhythm: "Slow start, later finish"
        case .structure: "Room to improvise"
        }
    }
}

/// A deliberate 1–5 answer for one persistent DNA dimension.
public struct ProfileScaleAnswer: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let dimension: TravellerDNADimension
    public let value: Int

    public var id: TravellerDNADimension { dimension }

    public init(dimension: TravellerDNADimension, value: Int) {
        self.dimension = dimension
        self.value = max(1, min(5, value))
    }
}

/// The immutable, privacy-minimized profile payload attached to one trip.
///
/// It intentionally excludes the local profile UUID and display name.
public struct TravellerProfileSnapshot: Codable, Equatable, Hashable, Sendable {
    public static let currentVersion = 1

    public let questionnaireVersion: Int
    public let scaleAnswers: [ProfileScaleAnswer]
    public let usuallySkip: [String]
    public let mustHaves: [String]
    public let additionalNotes: String?
    public let age: Int?
    /// ISO 3166-1 alpha-2 region code, e.g. `DE`. Stored as a code so the
    /// display name can follow the device language.
    public let nationality: String?

    public init(
        questionnaireVersion: Int = Self.currentVersion,
        scaleAnswers: [ProfileScaleAnswer],
        usuallySkip: [String] = [],
        mustHaves: [String] = [],
        additionalNotes: String? = nil,
        age: Int? = nil,
        nationality: String? = nil
    ) {
        self.questionnaireVersion = questionnaireVersion
        self.scaleAnswers = scaleAnswers
        self.usuallySkip = usuallySkip
        self.mustHaves = mustHaves
        self.additionalNotes = additionalNotes
        self.age = age.map { max(1, min(120, $0)) }
        self.nationality = nationality
    }

    public func score(for dimension: TravellerDNADimension) -> Int? {
        scaleAnswers.first(where: { $0.dimension == dimension })?.value
    }

    public var hasEveryScaleAnswer: Bool {
        Set(scaleAnswers.map(\.dimension)) == Set(TravellerDNADimension.allCases)
    }

    /// Stable text representation used as a data section in solo LLM input.
    public var promptSummary: String {
        var lines = TravellerDNADimension.allCases.map { dimension in
            let value = score(for: dimension) ?? 3
            return "\n- \(dimension.rawValue): \(value)/5 (\(dimension.leftLabel) ↔ \(dimension.rightLabel))"
        }
        if let age {
            lines.append("\n- Age: \(age)")
        }
        if let nationalityName {
            lines.append("\n- Nationality: \(nationalityName)")
        }
        if !usuallySkip.isEmpty {
            lines.append("\n- Usually prefers to skip: \(usuallySkip.map(cleanPromptValue).joined(separator: "; "))")
        }
        if !mustHaves.isEmpty {
            lines.append("\n- Things that usually make travel feel right: \(mustHaves.map(cleanPromptValue).joined(separator: "; "))")
        }
        if let additionalNotes, !additionalNotes.isEmpty {
            lines.append("\n- Additional traveller context: \(cleanPromptValue(additionalNotes))")
        }
        return lines.joined()
    }

    private func cleanPromptValue(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}

/// One locally persisted Traveller DNA persona.
public struct TravellerProfile: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var questionnaireVersion: Int
    public var scaleAnswers: [ProfileScaleAnswer]
    public var usuallySkip: [String]
    public var mustHaves: [String]
    public var additionalNotes: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        questionnaireVersion: Int = TravellerProfileSnapshot.currentVersion,
        scaleAnswers: [ProfileScaleAnswer],
        usuallySkip: [String] = [],
        mustHaves: [String] = [],
        additionalNotes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.questionnaireVersion = questionnaireVersion
        self.scaleAnswers = scaleAnswers
        self.usuallySkip = usuallySkip
        self.mustHaves = mustHaves
        self.additionalNotes = additionalNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var snapshot: TravellerProfileSnapshot {
        TravellerProfileSnapshot(
            questionnaireVersion: questionnaireVersion,
            scaleAnswers: scaleAnswers,
            usuallySkip: usuallySkip,
            mustHaves: mustHaves,
            additionalNotes: additionalNotes
        )
    }

    public func score(for dimension: TravellerDNADimension) -> Int? {
        snapshot.score(for: dimension)
    }

    /// A deliberately lightweight local label. It is decorative, not diagnostic.
    public var archetype: String {
        let candidates: [(TravellerDNADimension, Int)] = [
            (.structure, score(for: .structure) ?? 3),
            (.experienceBreadth, score(for: .experienceBreadth) ?? 3),
            (.physicalEnergy, score(for: .physicalEnergy) ?? 3)
        ]
        guard let strongest = candidates.max(by: {
            abs($0.1 - 3) < abs($1.1 - 3)
        }), abs(strongest.1 - 3) > 0 else {
            return "The Balanced Voyager"
        }

        return switch (strongest.0, strongest.1 < 3) {
        case (.structure, true): "The Intentional Explorer"
        case (.structure, false): "The Free-Flow Explorer"
        case (.experienceBreadth, true): "The Deep Diver"
        case (.experienceBreadth, false): "The Experience Collector"
        case (.physicalEnergy, true): "The Gentle Wanderer"
        case (.physicalEnergy, false): "The Momentum Seeker"
        default: "The Balanced Voyager"
        }
    }
}
