/// NOBSSecurity — KeychainStore
///
/// A type-safe wrapper around Apple's Security framework (`SecItem` APIs) for
/// storing, loading, and deleting sensitive string values (tokens, keys, secrets)
/// in the iOS / macOS Keychain.
///
/// Each item is stored as a generic-password Keychain entry scoped to a
/// `service` identifier (reverse-DNS, e.g. `"com.yourcompany.nobs"`).
///
/// Protection class:
///   `.afterFirstUnlockThisDeviceOnly` — accessible after the first device
///   unlock, non-migratable (never leaves this device via backup or iCloud
///   Keychain sync). This is the right class for OAuth tokens and similar
///   short-lived secrets.
///
/// On Linux / CI (where Security.framework is unavailable) the store falls
/// back to a thread-safe in-memory dictionary so the rest of the package
/// still compiles and tests run.

import Foundation

// MARK: - KeychainError

public enum KeychainError: Error, LocalizedError, Sendable {
    case saveFailed(Int32)
    case loadFailed(Int32)
    case deleteFailed(Int32)
    case unexpectedData

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let s):   return "Keychain save failed (OSStatus \(s))"
        case .loadFailed(let s):   return "Keychain load failed (OSStatus \(s))"
        case .deleteFailed(let s): return "Keychain delete failed (OSStatus \(s))"
        case .unexpectedData:      return "Keychain returned data in an unexpected format"
        }
    }
}

// MARK: - In-memory backing (shared by inMemory mode and Linux stub)

private final class KeychainMemory: @unchecked Sendable {
    var dict: [String: String] = [:]
    let lock = NSLock()
}

// MARK: - KeychainStore

#if canImport(Security)
import Security

/// Stores and retrieves sensitive string values in the system Keychain.
///
/// Items are scoped to `service` so multiple NOBS features can share one
/// store without key collisions, e.g.:
/// ```swift
/// let store = KeychainStore(service: "com.yourcompany.nobs.voice")
/// try store.save("my-token", forKey: "accessToken")
/// let token = try store.load(forKey: "accessToken")
/// ```
public struct KeychainStore: Sendable {
    /// The Keychain service identifier that namespaces all keys in this store.
    public let service: String
    private let inMemory: Bool
    private let memory = KeychainMemory()

    public init(service: String = "com.nobs.keychain", inMemory: Bool = false) {
        self.service = service
        self.inMemory = inMemory
    }

    // MARK: - Write

    /// Persist `secret` under `key`.  Overwrites any existing value.
    public func save(_ secret: String, forKey key: String) throws {
        if inMemory {
            memory.lock.lock()
            defer { memory.lock.unlock() }
            memory.dict["\(service).\(key)"] = secret
            return
        }

        guard let data = secret.data(using: .utf8) else { throw KeychainError.unexpectedData }

        // Delete any pre-existing item first so we can do a clean add.
        try? delete(forKey: key)

        let query: [CFString: Any] = [
            kSecClass:              kSecClassGenericPassword,
            kSecAttrService:        service,
            kSecAttrAccount:        key,
            kSecValueData:          data,
            // Non-migratable: never leaves this device via Backup or iCloud Keychain.
            kSecAttrAccessible:     kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    // MARK: - Read

    /// Load the value stored under `key`, or `nil` if no item exists.
    public func load(forKey key: String) throws -> String? {
        if inMemory {
            memory.lock.lock()
            defer { memory.lock.unlock() }
            return memory.dict["\(service).\(key)"]
        }

        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedData
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.loadFailed(status)
        }
    }

    // MARK: - Delete

    /// Remove the item stored under `key`.  A no-op if the key does not exist.
    public func delete(forKey key: String) throws {
        if inMemory {
            memory.lock.lock()
            defer { memory.lock.unlock() }
            memory.dict.removeValue(forKey: "\(service).\(key)")
            return
        }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Remove **all** items stored under this service.  Use with caution.
    public func deleteAll() throws {
        if inMemory {
            memory.lock.lock()
            defer { memory.lock.unlock() }
            let prefix = "\(service)."
            memory.dict.keys
                .filter { $0.hasPrefix(prefix) }
                .forEach { memory.dict.removeValue(forKey: $0) }
            return
        }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

#else
// MARK: - KeychainStore (in-memory stub for Linux / CI)

import Foundation

/// In-memory stub used on platforms where Security.framework is unavailable.
/// Provides the same public API backed by a `NSLock`-protected dictionary.
public struct KeychainStore: Sendable {
    public let service: String
    private let inMemory: Bool
    private let memory = KeychainMemory()

    public init(service: String = "com.nobs.keychain", inMemory: Bool = false) {
        self.service = service
        self.inMemory = inMemory
    }

    private func namespaced(_ key: String) -> String { "\(service).\(key)" }

    public func save(_ secret: String, forKey key: String) throws {
        memory.lock.lock(); defer { memory.lock.unlock() }
        memory.dict[namespaced(key)] = secret
    }

    public func load(forKey key: String) throws -> String? {
        memory.lock.lock(); defer { memory.lock.unlock() }
        return memory.dict[namespaced(key)]
    }

    public func delete(forKey key: String) throws {
        memory.lock.lock(); defer { memory.lock.unlock() }
        memory.dict.removeValue(forKey: namespaced(key))
    }

    public func deleteAll() throws {
        memory.lock.lock(); defer { memory.lock.unlock() }
        let prefix = "\(service)."
        memory.dict.keys
            .filter { $0.hasPrefix(prefix) }
            .forEach { memory.dict.removeValue(forKey: $0) }
    }
}
#endif
