import Foundation

enum AppGroupStore {
    static let groupID = "group.com.nobsdash.nobs"

    static let userProfileFile = "user-profile.json"
    static let briefingSnapshotFile = "widget-snapshot.json"
    static let latestBriefingFile = "latest-briefing.json"
    static let clarifyingConflictFile = "clarifying-conflict.json"
    static let briefingWidgetKind = "NOBSBriefingWidget"

    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            return url
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let fallback = appSupport.appendingPathComponent("NOBSShared", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    static func fileURL(_ name: String) -> URL {
        containerURL.appendingPathComponent(name, isDirectory: false)
    }

    static func writeJSON<T: Encodable>(_ value: T, to filename: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: fileURL(filename), options: .atomic)
    }

    static func readJSON<T: Decodable>(_ type: T.Type, from filename: String) throws -> T? {
        let url = fileURL(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
