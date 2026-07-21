//
//  FormURLEncodedBodyEncoder.swift
//  Networking
//
//  Created by Rodrigo Mato Castellano on 6/1/25.
//

import Foundation

public struct FormURLEncodedBodyEncoder: BodyEncoder {
    
    private let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._* ")

    public init() {}
    public func encode<T>(_ value: T) throws -> (data: Data, contentType: String) where T : Encodable {
        // 1.  Re-encode the model to `[String:String]` using JSON, then flatten.
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
        guard let dict = json as? [String: Any] else {
            throw EncodingError.invalidValue(value, .init(codingPath: [],
                debugDescription: "Expected a flat object"))
        }

        // 2.  Percent-encode every key / value.
        let bodyString = dict.compactMap { (k, v) -> String? in
            guard let stringValue = String(describing: v).addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
            return "\(k)=\(stringValue.replacingOccurrences(of: " ", with: "+"))"
        }
        .joined(separator: "&")

        guard let data = bodyString.data(using: .utf8) else {
            throw EncodingError.invalidValue(value, .init(codingPath: [],
                debugDescription: "Unable to produce UTF-8 data"))
        }
        return (data, "application/x-www-form-urlencoded")
    }
}
