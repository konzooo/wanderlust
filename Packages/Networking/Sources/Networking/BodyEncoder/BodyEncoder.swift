//
//  BodyEncoder.swift
//  Networking
//
//  Created by Rodrigo Mato Castellano on 6/1/25.
//

import Foundation

/// Converts an `Encodable` value into `(Data, contentTypeHeaderValue)`.
public protocol BodyEncoder {
    func encode<T: Encodable>(_ value: T) throws -> (data: Data, contentType: String)
}
