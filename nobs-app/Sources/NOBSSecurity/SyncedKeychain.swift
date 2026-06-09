/// NOBSSecurity — SyncedKeychain
///
/// iCloud-synced Keychain wrapper for the E2EE master key. Separate from the
/// existing device-only `KeychainStore` because the master key MUST roam
/// across the user's Apple devices (otherwise a new device can't decrypt
/// existing blobs).
///
/// Protection class:
///   `kSecAttrAccessibleAfterFirstUnlock` (NOT ...ThisDeviceOnly)
///   + `kSecAttrSynchronizable: true`
///
/// This means: any signed-in Apple device of the user gets the same key via
/// iCloud Keychain sync. Lose all devices? Use Apple's iCloud Keychain
/// recovery flow. We don't ever see the key.

import Foundation
import Security

public enum SyncedKeychainError: Error, LocalizedError {
    case osStatus(OSStatus)
    case notFound
    case badData

    public var errorDescription: String? {
        switch self {
        case .osStatus(let s): return "Keychain OSStatus \(s)"
        case .notFound: return "Item not found in synced Keychain"
        case .badData: return "Unexpected data shape in synced Keychain"
        }
    }
}

public struct SyncedKeychain: Sendable {
    public let service: String   // e.g. "com.nobsdash.nobs"
    public let account: String   // e.g. "master_key_v1"

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    public static let masterKey = SyncedKeychain(
        service: "com.nobsdash.nobs",
        account: "master_key_v1"
    )

    public func read() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: kCFBooleanTrue!,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { throw SyncedKeychainError.notFound }
        guard status == errSecSuccess else { throw SyncedKeychainError.osStatus(status) }
        guard let data = result as? Data else { throw SyncedKeychainError.badData }
        return data
    }

    public func write(_ data: Data) throws {
        // SecItemUpdate first; if not found, add.
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
        ]
        let update: [String: Any] = [
            kSecValueData as String: data,
        ]
        var status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw SyncedKeychainError.osStatus(status) }
    }

    public func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw SyncedKeychainError.osStatus(status)
        }
    }

    /// Convenience: read existing or create-and-store a fresh 256-bit master key.
    public func readOrCreateMasterKey() throws -> Data {
        if let existing = try? read() {
            return existing
        }
        var key = Data(count: 32)
        let status = key.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        guard status == errSecSuccess else { throw SyncedKeychainError.osStatus(status) }
        try write(key)
        return key
    }
}
