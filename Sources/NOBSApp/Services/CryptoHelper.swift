import Foundation
import CryptoKit
import NOBSSecurity

enum CryptoHelper {
    private static let keychain = KeychainStore(service: "com.nobs.crypto")
    private static let keyTag = "data_encryption_key"
    private static var cachedKey: SymmetricKey?

    private static func getKey() throws -> SymmetricKey {
        if let key = cachedKey { return key }
        if let keyData = try? keychain.load(forKey: keyTag),
           let data = Data(base64Encoded: keyData) {
            let key = SymmetricKey(data: data)
            cachedKey = key
            return key
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }.base64EncodedString()
        try keychain.save(keyData, forKey: keyTag)
        cachedKey = key
        return key
    }

    static func encrypt(_ text: String) throws -> String {
        let data = Data(text.utf8)
        let key = try getKey()
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw CryptoError.encryptionFailed }
        return combined.base64EncodedString()
    }

    static func decrypt(_ base64: String) throws -> String {
        guard let combined = Data(base64Encoded: base64) else { throw CryptoError.invalidData }
        let key = try getKey()
        let sealed = try AES.GCM.SealedBox(combined: combined)
        let data = try AES.GCM.open(sealed, using: key)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

enum CryptoError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidData
}