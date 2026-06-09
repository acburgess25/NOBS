/// NOBSSecurity — EncryptionService
///
/// Per-blob AES-GCM-256 encryption with HKDF-derived keys from a master key.
/// This is the cryptographic foundation of the NOBS E2EE promise.
///
/// Threat model:
///   - The server (Appwrite/tank) MUST NOT be able to decrypt blobs.
///   - Adversary with full server access sees only ciphertext + opaque IDs.
///   - Each blob has its own key, derived from the master + a per-blob salt
///     via HKDF-SHA256. The master never touches a blob.
///
/// Wire format for an encrypted blob:
///   [ 1 byte version | 16 bytes salt | 12 bytes nonce | ciphertext+tag ]
///
/// Why HKDF-per-blob instead of one global key:
///   - Compromise of one blob's salt+ciphertext doesn't extend to others.
///   - Future-proof for envelope encryption (e.g., per-user device keys).

import CryptoKit
import Foundation

public enum EncryptionError: Error, LocalizedError {
    case badEnvelope(String)
    case unsupportedVersion(UInt8)

    public var errorDescription: String? {
        switch self {
        case .badEnvelope(let m): return "Encryption envelope error: \(m)"
        case .unsupportedVersion(let v): return "Unsupported envelope version: \(v)"
        }
    }
}

public struct EncryptionService: Sendable {
    public static let version: UInt8 = 1
    public static let saltLength = 16
    public static let nonceLength = 12

    /// 256-bit master key, derived once on first launch + synced via iCloud Keychain.
    public let masterKey: SymmetricKey

    public init(masterKey: SymmetricKey) {
        self.masterKey = masterKey
    }

    /// Generate a brand-new 256-bit master key. Persist via SyncedKeychain.
    public static func generateMasterKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    /// Encrypt arbitrary data. Returns the on-wire envelope (version|salt|nonce|cipher+tag).
    public func encrypt(_ plaintext: Data) throws -> Data {
        var salt = Data(count: Self.saltLength)
        let saltStatus = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, Self.saltLength, $0.baseAddress!)
        }
        guard saltStatus == errSecSuccess else {
            throw EncryptionError.badEnvelope("random failed: \(saltStatus)")
        }
        let perBlobKey = Self.deriveKey(master: masterKey, salt: salt)
        let sealed = try AES.GCM.seal(plaintext, using: perBlobKey)
        guard let combined = sealed.combined else {
            throw EncryptionError.badEnvelope("seal returned no combined data")
        }
        // combined = nonce(12) || ciphertext || tag(16). We re-emit our envelope.
        var envelope = Data()
        envelope.append(Self.version)
        envelope.append(salt)
        envelope.append(combined)  // nonce + ciphertext + tag
        return envelope
    }

    /// Decrypt an on-wire envelope back to plaintext.
    public func decrypt(_ envelope: Data) throws -> Data {
        guard envelope.count > 1 + Self.saltLength + Self.nonceLength + 16 else {
            throw EncryptionError.badEnvelope("envelope too short (\(envelope.count)B)")
        }
        let version = envelope[envelope.startIndex]
        guard version == Self.version else {
            throw EncryptionError.unsupportedVersion(version)
        }
        let saltStart = envelope.index(envelope.startIndex, offsetBy: 1)
        let saltEnd = envelope.index(saltStart, offsetBy: Self.saltLength)
        let salt = envelope.subdata(in: saltStart..<saltEnd)
        let combined = envelope.subdata(in: saltEnd..<envelope.endIndex)
        let perBlobKey = Self.deriveKey(master: masterKey, salt: salt)
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: perBlobKey)
    }

    /// HKDF-SHA256(master, salt, info="nobs:blob:v1") → 256-bit per-blob key.
    private static func deriveKey(master: SymmetricKey, salt: Data) -> SymmetricKey {
        let info = Data("nobs:blob:v1".utf8)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: master,
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }
}

// MARK: - Convenience for round-tripping the master key as Data

public extension SymmetricKey {
    var rawData: Data {
        withUnsafeBytes { Data($0) }
    }

    init?(rawData: Data) {
        guard rawData.count == 32 else { return nil }
        self = SymmetricKey(data: rawData)
    }
}
