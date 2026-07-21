import Foundation

public enum OAKeyManager {
    public static func installIfNeeded() throws {
        guard !SecretVault.isInstalled() else { return }
        let plaintext = try OAInstallerDecrypter.decryptInstallerBlob()
        try SecretVault.wrapAndPersist(plaintext)
    }

    public static func fetchAPIKey() throws -> String {
        let d = try SecretVault.loadAndUnwrap()
        return String(decoding: d, as: UTF8.self)
    }
}
