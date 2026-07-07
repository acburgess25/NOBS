import Foundation

enum BriefingSnapshotReader {
    static func load() -> BriefingSnapshot? {
        try? AppGroupStore.readJSON(BriefingSnapshot.self, from: AppGroupStore.briefingSnapshotFile)
    }
}
