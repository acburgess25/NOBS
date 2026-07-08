import Foundation
import WidgetKit

struct BriefingSnapshotWriter {
    func write(
        from briefing: DailyBriefing?,
        profile: UserProfile,
        eventCount: Int = 0,
        eveningHeadline: String? = nil,
        redactDetailsOnLockScreen: Bool = true
    ) {
        guard let briefing else {
            try? FileManager.default.removeItem(at: AppGroupStore.fileURL(AppGroupStore.briefingSnapshotFile))
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.briefingWidgetKind)
            return
        }
        let snapshot = BriefingSnapshot(
            briefing: briefing,
            profile: profile,
            eventCount: eventCount,
            eveningHeadline: eveningHeadline,
            redactDetailsOnLockScreen: redactDetailsOnLockScreen
        )
        try? AppGroupStore.writeJSON(snapshot, to: AppGroupStore.briefingSnapshotFile)
        try? AppGroupStore.writeJSON(briefing, to: AppGroupStore.latestBriefingFile)
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.briefingWidgetKind)
    }
}
