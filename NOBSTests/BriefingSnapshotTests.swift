import XCTest
@testable import NOBS

final class BriefingSnapshotTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    override func setUp() {
        super.setUp()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func testBriefingSnapshotFromDailyBriefing() {
        let briefing = sampleBriefing(
            conflictsOrRisks: ["Back-to-back meetings at 10:00 and 10:05."]
        )

        let snapshot = BriefingSnapshot(briefing: briefing)

        XCTAssertEqual(snapshot.date, briefing.date)
        XCTAssertEqual(snapshot.topline, briefing.topline)
        XCTAssertEqual(snapshot.priorityCount, briefing.priorities.count)
        XCTAssertEqual(snapshot.priorities, Array(briefing.priorities.prefix(2)))
        XCTAssertEqual(snapshot.topPriority, briefing.priorities.first)
        XCTAssertTrue(snapshot.hasConflict)
        XCTAssertEqual(snapshot.conflictSummary, briefing.conflictsOrRisks.first)
        XCTAssertEqual(snapshot.route, ProcessingRoute.tank.rawValue)
    }

    func testConflictDetectionIgnoresNoMajorRisksMessage() {
        let briefing = sampleBriefing(
            conflictsOrRisks: ["No major schedule risks detected right now."]
        )

        let snapshot = BriefingSnapshot(briefing: briefing)

        XCTAssertFalse(snapshot.hasConflict)
        XCTAssertNil(snapshot.conflictSummary)
    }

    func testRedactDetailsOnLockScreen() {
        let snapshot = BriefingSnapshot(
            date: "2026-07-08",
            topline: "Busy day",
            priorityCount: 2,
            priorities: ["Meeting"],
            topPriority: "Meeting",
            hasConflict: true,
            conflictSummary: "Overlap at 10:00",
            route: "Tank",
            generatedAt: .now,
            redactDetailsOnLockScreen: true
        )

        XCTAssertTrue(snapshot.shouldRedactDetails(forLockScreen: true))
        XCTAssertFalse(snapshot.shouldRedactDetails(forLockScreen: false))
        XCTAssertEqual(snapshot.conflictLabel(redacted: true), "Schedule conflict")
        XCTAssertEqual(snapshot.conflictLabel(redacted: false), "Overlap at 10:00")
    }

    func testBriefingSnapshotRoundTripCodable() throws {
        let original = BriefingSnapshot(
            date: "2026-07-08",
            topline: "Manageable day",
            priorityCount: 3,
            priorities: ["Team sync", "Call plumber"],
            topPriority: "Team sync",
            hasConflict: false,
            conflictSummary: nil,
            route: "Local",
            generatedAt: Date(timeIntervalSince1970: 1_752_000_000),
            redactDetailsOnLockScreen: false
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(BriefingSnapshot.self, from: data)

        XCTAssertEqual(decoded.date, original.date)
        XCTAssertEqual(decoded.topline, original.topline)
        XCTAssertEqual(decoded.priorityCount, original.priorityCount)
        XCTAssertEqual(decoded.route, original.route)
        XCTAssertEqual(decoded.redactDetailsOnLockScreen, original.redactDetailsOnLockScreen)
    }

    func testBriefingSnapshotWriterClearsFilesWhenBriefingNil() throws {
        let writer = BriefingSnapshotWriter()
        let briefing = sampleBriefing(conflictsOrRisks: [])

        writer.write(from: briefing, kind: .morning)
        XCTAssertNotNil(try AppGroupStore.readJSON(BriefingSnapshot.self, from: AppGroupStore.briefingSnapshotFile))

        writer.write(from: nil, kind: .morning)
        XCTAssertFalse(FileManager.default.fileExists(atPath: AppGroupStore.fileURL(AppGroupStore.briefingSnapshotFile).path))
    }

    func testEveningBriefingSnapshotIncludesTomorrowPreview() {
        let briefing = DailyBriefing(
            date: "2026-07-08",
            kind: .evening,
            topline: "Solid progress today.",
            priorities: ["Business · Design sync (10:00)"],
            conflictsOrRisks: ["Personal · Call plumber — still open"],
            recommendedPlan: ["First up tomorrow: Standup at 09:00."],
            oneUsefulQuestion: nil,
            suggestedNextActions: ["Wind down without guilt."],
            generatedAt: "2026-07-08T20:00:00Z",
            route: .local,
            privacyReceipt: PrivacyReceipt(
                used: ["2 calendar items"],
                processed: "Local on this iPhone",
                shared: [],
                changed: []
            )
        )

        let snapshot = BriefingSnapshot(briefing: briefing)

        XCTAssertEqual(snapshot.kind, BriefingKind.evening.rawValue)
        XCTAssertEqual(snapshot.briefingKind, .evening)
        XCTAssertNotNil(snapshot.tomorrowPreview)
        XCTAssertTrue(snapshot.hasConflict)
        XCTAssertEqual(snapshot.conflictLabel(redacted: true), "Carry-over items")
    }

    private func sampleBriefing(conflictsOrRisks: [String]) -> DailyBriefing {
        DailyBriefing(
            date: "2026-07-08",
            topline: "A focused day.",
            priorities: ["Business · Design sync (10:00)", "Personal · Call plumber"],
            conflictsOrRisks: conflictsOrRisks,
            recommendedPlan: ["Prep before 09:30."],
            oneUsefulQuestion: nil,
            suggestedNextActions: ["Review notes."],
            generatedAt: "2026-07-08T12:00:00Z",
            route: .tank,
            privacyReceipt: PrivacyReceipt(
                used: ["1 calendar items"],
                processed: "Tank on your private network",
                shared: [],
                changed: []
            )
        )
    }
}
