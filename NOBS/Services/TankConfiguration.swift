import Foundation
@preconcurrency import KeychainAccess

enum TankConfiguration {
    private static let addressKey = "nobs.tank.address"
    private static let tokenAccount = "tank-device-token"
    private static let appleUserAccount = "tank-apple-user-id"
    private static let keychainService = "com.acburgess25.NOBS"
    private static var keychain: Keychain {
        Keychain(service: keychainService)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    static var hasSavedAddress: Bool {
        guard let saved = UserDefaults.standard.string(forKey: addressKey) else { return false }
        return normalizedURL(from: saved) != nil
    }

    static var savedAddress: String {
        if let saved = UserDefaults.standard.string(forKey: addressKey), !saved.isEmpty {
            return saved
        }
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8000"
        #else
        return ""
        #endif
    }

    static var savedToken: String { currentToken ?? "" }

    static var currentURL: URL? { normalizedURL(from: savedAddress) }
    static var currentToken: String? { try? keychain.get(tokenAccount) }
    static var savedAppleUserID: String? { try? keychain.get(appleUserAccount) }

    static func normalizedURL(from value: String) -> URL? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: clean),
              ["http", "https"].contains(url.scheme?.lowercased()),
              url.host != nil else { return nil }
        return url
    }

    static func saveAddress(_ address: String) {
        UserDefaults.standard.set(address, forKey: addressKey)
    }

    static func save(address: String, token: String) throws {
        saveAddress(address)
        try keychain.set(token, key: tokenAccount)
    }

    static func saveAppleUserID(_ userID: String) {
        try? keychain.set(userID, key: appleUserAccount)
    }
}
