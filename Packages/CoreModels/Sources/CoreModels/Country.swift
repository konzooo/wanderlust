import Foundation

/// One selectable country, identified by its ISO 3166-1 alpha-2 code.
///
/// The list comes from the system rather than a bundled table, so it stays
/// correct as the OS updates and the names follow the device language.
public struct Country: Identifiable, Hashable, Sendable {
    /// ISO 3166-1 alpha-2 code, e.g. `DE`.
    public let code: String
    /// Localized country name for display.
    public let name: String

    public var id: String { code }

    /// The regional-indicator flag emoji for the code.
    public var flag: String { Country.flag(for: code) }

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

extension Country {
    /// Every ISO country, sorted by localized name.
    ///
    /// Continents and numeric groupings ("001 – World") are filtered out by
    /// requiring a two-letter code that belongs to a continent.
    public static let all: [Country] = {
        Locale.Region.isoRegions
            .filter { region in
                region.identifier.count == 2 &&
                region.identifier.allSatisfy { $0.isASCII && $0.isUppercase } &&
                region.continent != nil
            }
            .compactMap { region in
                guard let name = displayName(for: region.identifier) else { return nil }
                return Country(code: region.identifier, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    public static func displayName(for code: String) -> String? {
        Locale.current.localizedString(forRegionCode: code)
    }

    /// The English name, for prompt text that should not shift with the
    /// device language.
    public static func englishName(for code: String) -> String? {
        Locale(identifier: "en_US_POSIX").localizedString(forRegionCode: code)
    }

    public static func flag(for code: String) -> String {
        let base: UInt32 = 127_397
        var scalars = String.UnicodeScalarView()
        for character in code.uppercased().unicodeScalars {
            guard let scalar = UnicodeScalar(base + character.value) else { return "" }
            scalars.append(scalar)
        }
        return String(scalars)
    }

    /// Matches on both the localized name and the code, so typing "DE" or
    /// "Ger" both land on Germany.
    public static func search(_ query: String) -> [Country] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let prefixed = all.filter {
            $0.name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil ||
            $0.code.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        let contained = all.filter { candidate in
            !prefixed.contains(candidate) &&
            candidate.name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        return prefixed + contained
    }
}
