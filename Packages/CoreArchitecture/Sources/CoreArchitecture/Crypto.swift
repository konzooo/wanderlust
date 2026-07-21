import CommonCrypto
import Foundation

public enum Crypto {
    /// Create a (non-unique) hash string based on the base URL and query parameters.
    /// A hash key created for the same UrlRequest should output the same value.
    /// - Parameter request: urlrequest to generate the key from
    /// - Returns: unique key
    public static func hashKey(
        fromRequest request: URLRequest,
        extraParams: [String] = [],
        obfuscate: Bool = false
    ) -> String? {
        guard let url = request.url else {
            // TODO: log?
            return nil
        }

        // Extract base URL
        guard let baseURL = url.scheme.flatMap({ $0 + "://" })?.appending(url.host ?? "") else {
            // TODO: log?
            return nil
        }

        // Extract query parameters (if any)
        var queryParameters = ""
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            // Sort query items to ensure a consistent order
            let sortedQueryItems = queryItems.sorted { $0.name < $1.name }
            queryParameters = sortedQueryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        }

        // Combine base URL and sorted query parameters
        var combinedString = baseURL + (queryParameters.isEmpty ? "" : "?" + queryParameters)

        // Append a extra parameters if any
        for param in extraParams {
            combinedString += param
        }

        // Create a unique hash of the combined string and obfuscate using SHA-256 if key needs to
        // be unique, or use the normal version.
        return obfuscate ? (combinedString.sha256() ?? combinedString) : combinedString
    }

    /// Create a unique hash key using the class name + class module prefix + sha-256 hash.
    /// Alternative simple version of the key using Strings in case the sha hash fails.
    /// - Returns: unique key String
    public static func hashKey(
        for objectType: AnyObject.Type,
        extraTypes: [Any.Type],
        extraParams: [String] = [],
        obfuscate: Bool = false
    ) -> String {
        // Using NSStringFromClass to get the full class name with module prefix
        var className = NSStringFromClass(objectType)

        // Simple Name hash in case the SHA-256 hash fails
        var simpleKey = String(describing: objectType)

        // Append extra types description if included
        for type in extraTypes {
            className += "+\(String(describing: type))"
            simpleKey += "+\(String(describing: type))"
        }

        // Append a extra parameters if necessary
        for param in extraParams {
            className += param
            simpleKey += param
        }

        // Hash the class name using SHA-256 (or use the simple version)
        return obfuscate ? (className.sha256() ?? simpleKey) : className
    }

    /// Simple consistent (non-unique) hash for a specific type
    /// - Parameter type: value type
    /// - Returns: string hash
    public static func hashKey(
        for types: [Any.Type],
        extraParams: [String] = [],
        obfuscate: Bool = false
    ) -> String {
        // Type Name for main key
        var key = ""

        // Add types to the key descruption
        for type in types {
            key += String(describing: type)
        }

        // Append a extra parameters if necessary
        for param in extraParams {
            key += param
        }

        // Hash the class name using SHA-256 if key needs to be unique, or use the simple version.
        return obfuscate ? (key.sha256() ?? key) : key
    }
}

// Reasonable character limit for Strings which will be hashed with SHA-256
private let hashableMaxLength: Int = 150

// Extension adding SHA-256 hashing to String
public extension String {
    func sha256() -> String? {
        guard let data = data(using: .utf8), count < hashableMaxLength else { return nil }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
