import Foundation
import WidgetKit

struct BriefingSnapshotWriter {
    func write(from briefing: DailyBriefing?, kind: BriefingKind, redactDetailsOnLockScreen: Bool = true) {
        let snapshotFile = kind == .evening
            ? AppGroupStore.eveningBriefingSnapshotFile
            : AppGroupStore.briefingSnapshotFile
        let briefingFile = kind == .evening
            ? AppGroupStore.latestEveningBriefingFile
            : AppGroupStore.latestBriefingFile

        guard let briefing else {
            try? FileManager.default.removeItem(at: AppGroupStore.fileURL(snapshotFile))
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.briefingWidgetKind)
            return
        }
        let snapshot = BriefingSnapshot(briefing: briefing, redactDetailsOnLockScreen: redactDetailsOnLockScreen)
        try? AppGroupStore.writeJSON(snapshot, to: snapshotFile)
        try? AppGroupStore.writeJSON(briefing, to: briefingFile)
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.briefingWidgetKind)
    }
}
