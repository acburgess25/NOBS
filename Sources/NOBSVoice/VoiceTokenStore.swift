/// NOBSVoice — VoiceTokenStore
///
/// A Keychain-backed store specifically for the Google Voice OAuth2 tokens
/// used by `VoiceClient`.
///
/// Tokens are stored as individual generic-password items so they can be
/// updated independently (e.g. only the access token changes on a refresh).
/// The expiry date is serialised as an ISO 8601 string alongside the tokens.
///
/// `clientID` and `clientSecret` are **never** stored — they must be
/// supplied at runtime from your app's provisioning or secure configuration.
///
/// Usage:
/// ```swift
/// let tokenStore = VoiceTokenStore()
/// // Persist after OAuth exchange or refresh:
/// try tokenStore.save(from: credentials)
/// // Restore tokens on app launch:
/// var creds = VoiceCredentials(clientID: id, clientSecret: secret)
/// try tokenStore.load(into: &creds)
/// // Wipe on sign-out:
/// try tokenStore.clear()
/// ```

import Foundation
import NOBSSecurity

// MARK: - VoiceTokenStore

/// Persists and retrieves `VoiceCredentials` token fields in the system Keychain.
public struct VoiceTokenStore: Sendable {
    private enum Keys {
        static let accessToken  = "accessToken"
        static let refreshToken = "refreshToken"
        static let tokenExpiry  = "tokenExpiry"
    }

    private let keychain: KeychainStore

    /// - Parameter keychain: The backing Keychain store.  Defaults to a store
    ///   scoped to `"com.nobs.voice"`, which keeps Google Voice tokens isolated
    ///   from any other Keychain items the app may write.
    public init(keychain: KeychainStore = KeychainStore(service: "com.nobs.voice")) {
        self.keychain = keychain
    }

    // MARK: - Persist

    /// Write the token fields from `credentials` into the Keychain.
    /// Only non-nil fields are written; existing Keychain values are overwritten.
    public func save(from credentials: VoiceCredentials) throws {
        if let accessToken = credentials.accessToken {
            try keychain.save(accessToken, forKey: Keys.accessToken)
        }
        if let refreshToken = credentials.refreshToken {
            try keychain.save(refreshToken, forKey: Keys.refreshToken)
        }
        if let expiry = credentials.tokenExpiry {
            let isoString = ISO8601DateFormatter().string(from: expiry)
            try keychain.save(isoString, forKey: Keys.tokenExpiry)
        }
    }

    // MARK: - Restore

    /// Populate the mutable `credentials` with any tokens found in the Keychain.
    /// Fields that have no Keychain entry are left unchanged.
    public func load(into credentials: inout VoiceCredentials) throws {
        if let token = try keychain.load(forKey: Keys.accessToken) {
            credentials.accessToken = token
        }
        if let token = try keychain.load(forKey: Keys.refreshToken) {
            credentials.refreshToken = token
        }
        if let isoString = try keychain.load(forKey: Keys.tokenExpiry),
           let date = ISO8601DateFormatter().date(from: isoString) {
            credentials.tokenExpiry = date
        }
    }

    // MARK: - Delete

    /// Remove all stored tokens from the Keychain.
    /// Call this when the user signs out of Google Voice.
    public func clear() throws {
        try keychain.delete(forKey: Keys.accessToken)
        try keychain.delete(forKey: Keys.refreshToken)
        try keychain.delete(forKey: Keys.tokenExpiry)
    }
}
