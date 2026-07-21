//
//  JSONBodyEncoder.swift
//  Networking
//
//  Created by Rodrigo Mato Castellano on 6/1/25.
//

import Foundation

public struct JSONBodyEncoder: BodyEncoder {

    private let encoder: JSONEncoder
    public init(encoder: JSONEncoder = .init()) { self.encoder = encoder }

    public func encode<T>(_ value: T) throws -> (data: Data, contentType: String) where T : Encodable {
        try (encoder.encode(value), "application/json")
    }
}
