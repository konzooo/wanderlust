//
//  AnyCodable.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 3/30/25.
//

import Foundation

struct AnyCodable: Codable {
    let value: Any

    /// Initialize with an arbitrary Swift value
    init(_ value: Any) {
        self.value = value
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            // Map [AnyCodable] back to [Any]
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            // Map [String: AnyCodable] back to [String: Any]
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable: Unsupported JSON structure."
            )
        }
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        switch value {
        case is NSNull:
            var container = encoder.singleValueContainer()
            try container.encodeNil()

        case let bool as Bool:
            var container = encoder.singleValueContainer()
            try container.encode(bool)

        case let int as Int:
            var container = encoder.singleValueContainer()
            try container.encode(int)

        case let double as Double:
            var container = encoder.singleValueContainer()
            try container.encode(double)

        case let string as String:
            var container = encoder.singleValueContainer()
            try container.encode(string)

        case let array as [Any]:
            var container = encoder.unkeyedContainer()
            for element in array {
                let codable = AnyCodable(element)
                try container.encode(codable)
            }

        case let dictionary as [String: Any]:
            // We need dynamic keys because we don't know them beforehand
            var container = encoder.container(keyedBy: DynamicCodingKeys.self)
            for (key, value) in dictionary {
                guard let codingKey = DynamicCodingKeys(stringValue: key) else { continue }
                let codableValue = AnyCodable(value)
                try container.encode(codableValue, forKey: codingKey)
            }

        default:
            // If you have more specialized cases, handle them here
            throw EncodingError.invalidValue(
                value,
                .init(codingPath: encoder.codingPath,
                      debugDescription: "AnyCodable: Unknown value type \(type(of: value)).")
            )
        }
    }

    // MARK: - Helpers

    /// Allows creating coding keys dynamically at runtime.
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }
}
