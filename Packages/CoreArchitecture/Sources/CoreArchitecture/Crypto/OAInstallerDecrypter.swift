//
//  OAInstallerDecrypter.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato on 27/8/25.
//


import Foundation
import CryptoKit

enum OADecryptError: Error { case bundle, format, crypto }

struct OAInstallerDecrypter {
    static func decryptInstallerBlob() throws -> Data {
        guard
            let url = Bundle.main.url(forResource: "oa", withExtension: "enc"),
            let blob = try? Data(contentsOf: url)
        else { throw OADecryptError.bundle }

        // Format: "OA1"(3) + salt(16) + combined
        guard blob.count > 19, blob.prefix(3) == Data("OA1".utf8) else { throw OADecryptError.format }
        let salt = blob[3..<19]
        let combined = blob[19...]

        // Obfuscated passphrase — implement your own reveal()
        let passphrase = InstallerSecret.reveal()

        let inputKey = SymmetricKey(data: Data(passphrase.utf8))
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: salt,
            info: Data("oaenc".utf8),
            outputByteCount: 32
        )
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key) // plaintext "sk-..."
    }
}
