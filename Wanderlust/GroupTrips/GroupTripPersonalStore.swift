import CoreModels
import Foundation

/// The group content is shared, but these choices belong to one traveller on
/// one device. They are deliberately absent from every Convex group DTO.
struct GroupTripPersonalLayer: Codable, Equatable {
    var favorites: Trip.Favorites = .init()
    var worthItDecisions: [UUID: WorthItDecision] = [:]
}

protocol GroupTripPersonalStoring {
    func load(groupId: String) -> GroupTripPersonalLayer
    func save(_ layer: GroupTripPersonalLayer, groupId: String)
    func clear(groupId: String)
}

/// A small per-group UserDefaults store. Generated content keeps server IDs,
/// so these local choices still point at the same items after save/reopen.
struct GroupTripPersonalStore: GroupTripPersonalStoring {
    private let defaults: UserDefaults
    private let keyPrefix: String

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "com.wanderlust.grouptrip.personal."
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    func load(groupId: String) -> GroupTripPersonalLayer {
        guard let data = defaults.data(forKey: key(for: groupId)),
              let layer = try? JSONDecoder().decode(GroupTripPersonalLayer.self, from: data) else {
            return .init()
        }
        return layer
    }

    func save(_ layer: GroupTripPersonalLayer, groupId: String) {
        guard let data = try? JSONEncoder().encode(layer) else { return }
        defaults.set(data, forKey: key(for: groupId))
    }

    func clear(groupId: String) {
        defaults.removeObject(forKey: key(for: groupId))
    }

    private func key(for groupId: String) -> String {
        keyPrefix + groupId
    }
}
