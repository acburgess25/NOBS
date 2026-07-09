import Foundation

/// Reads `profile.json` and `tank.json` from a user-selected iCloud (or local) folder.
enum ExternalConfigSync {
    static let profileFileName = "profile.json"
    static let tankFileName = "tank.json"
    private static let bookmarkKey = "nobs.externalConfig.folderBookmark"
    private static let folderNameKey = "nobs.externalConfig.folderDisplayName"

    static var linkedFolderName: String? {
        UserDefaults.standard.string(forKey: folderNameKey)
    }

    static var hasLinkedFolder: Bool {
        resolvedFolderURL() != nil
    }

    static func saveFolderBookmark(_ url: URL) throws {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        let data = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: bookmarkKey)
        UserDefaults.standard.set(url.lastPathComponent, forKey: folderNameKey)
    }

    static func clearFolderBookmark() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: folderNameKey)
    }

    static func resolvedFolderURL() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        if stale, let refreshed = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
        }
        return url
    }

    static func sync(
        profile: UserProfile,
        tankAddress: String
    ) async -> (result: ExternalConfigApplyResult, profile: UserProfile, tankAddress: String) {
        guard let folderURL = resolvedFolderURL() else {
            return (
                ExternalConfigApplyResult(appliedProfile: false, appliedTankAddress: false, messages: []),
                profile,
                tankAddress
            )
        }

        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { folderURL.stopAccessingSecurityScopedResource() }
        }

        var messages: [String] = []
        var appliedProfile = false
        var appliedTank = false
        var updatedProfile = profile
        var updatedTankAddress = tankAddress

        let profileURL = folderURL.appendingPathComponent(profileFileName)
        if FileManager.default.fileExists(atPath: profileURL.path) {
            await ensureDownloaded(at: profileURL)
            if let config: ExternalProfileConfig = readJSON(ExternalProfileConfig.self, from: profileURL) {
                config.apply(to: &updatedProfile)
                appliedProfile = true
                messages.append("Updated profile from \(profileFileName).")
            } else {
                messages.append("Could not read \(profileFileName).")
            }
        }

        let tankURL = folderURL.appendingPathComponent(tankFileName)
        if FileManager.default.fileExists(atPath: tankURL.path) {
            await ensureDownloaded(at: tankURL)
            if let config: ExternalTankConfig = readJSON(ExternalTankConfig.self, from: tankURL),
               let address = config.address?.trimmingCharacters(in: .whitespacesAndNewlines),
               !address.isEmpty,
               let normalized = TankConfiguration.normalizedURL(from: address) {
                updatedTankAddress = normalized.absoluteString
                TankConfiguration.saveAddress(normalized.absoluteString)
                appliedTank = true
                messages.append("Updated Tank address from \(tankFileName).")
            } else if FileManager.default.fileExists(atPath: tankURL.path) {
                messages.append("Could not read a valid address from \(tankFileName).")
            }
        }

        let result = ExternalConfigApplyResult(
            appliedProfile: appliedProfile,
            appliedTankAddress: appliedTank,
            messages: messages
        )
        return (result, updatedProfile, updatedTankAddress)
    }

    private static func readJSON<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private static func ensureDownloaded(at url: URL) async {
        guard FileManager.default.isUbiquitousItem(at: url) else { return }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        for _ in 0..<20 {
            if let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
               values.ubiquitousItemDownloadingStatus == .current {
                return
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }
}
