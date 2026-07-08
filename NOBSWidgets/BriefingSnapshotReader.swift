import Foundation

enum BriefingSnapshotReader {
    static let defaultEveningHour = 17

    static func load(eveningHour: Int = defaultEveningHour) -> BriefingSnapshot? {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= eveningHour,
           let evening: BriefingSnapshot = try? AppGroupStore.readJSON(
               BriefingSnapshot.self,
               from: AppGroupStore.eveningBriefingSnapshotFile
           ) {
            return evening
        }
        if hour >= eveningHour,
           let morning: BriefingSnapshot = try? AppGroupStore.readJSON(
               BriefingSnapshot.self,
               from: AppGroupStore.briefingSnapshotFile
           ),
           let preview = morning.tomorrowPreview ?? morning.priorities.first {
            return BriefingSnapshot(
                date: morning.date,
                kind: BriefingKind.evening.rawValue,
                topline: "Tomorrow preview",
                priorityCount: morning.priorityCount,
                priorities: [preview],
                topPriority: preview,
                hasConflict: morning.hasConflict,
                conflictSummary: morning.conflictSummary,
                tomorrowPreview: preview,
                unfinishedCount: nil,
                route: morning.route,
                generatedAt: morning.generatedAt,
                redactDetailsOnLockScreen: morning.redactDetailsOnLockScreen
            )
        }
        return try? AppGroupStore.readJSON(BriefingSnapshot.self, from: AppGroupStore.briefingSnapshotFile)
    }
}
