import Foundation
import XCTest
@testable import NOBS

final class TankContractFixtureTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            let file = directory.appendingPathComponent("contracts/v1/fixtures/\(name).json")
            if FileManager.default.fileExists(atPath: file.path) {
                return try Data(contentsOf: file)
            }
            directory.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }

    private func roundTrip<T: Codable>(_ type: T.Type, fixture name: String) throws -> T {
        let data = try fixture(name)
        let value = try JSONDecoder().decode(type, from: data)
        let encoded = try JSONEncoder().encode(value)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? NSDictionary)
        XCTAssertEqual(result, original, "Wire fields changed in \(name)")
        return value
    }

    func testBriefingRequestFixture() throws {
        let request = try roundTrip(TankBriefingRequest.self, fixture: "briefing_request")
        XCTAssertEqual(request.date, "2026-07-04")
        XCTAssertEqual(request.calendar.first?.end, "11:00")
        XCTAssertNil(request.calendar.last?.end)
        XCTAssertNil(request.reminders.last?.due)
    }

    func testBriefingResponseFixture() throws {
        let briefing = try roundTrip(DailyBriefing.self, fixture: "briefing_response")
        XCTAssertEqual(briefing.route, .tank)
        XCTAssertEqual(briefing.recommendedPlan.count, 2)
        XCTAssertEqual(briefing.privacyReceipt.processed, "Tank on your private network")
        XCTAssertNil(briefing.clarifyingConflict)
    }

    func testSyncFixtures() throws {
        let calendar = try roundTrip(TankSyncCalendarRequest.self, fixture: "sync_calendar_request")
        XCTAssertEqual(calendar.events.first?.start, "2026-07-04T10:00:00Z")
        XCTAssertNil(calendar.events.last?.end)

        let reminders = try roundTrip(
            TankSyncRemindersRequest.self,
            fixture: "sync_reminders_request"
        )
        XCTAssertEqual(reminders.reminders.first?.due, "2026-07-04T14:00:00Z")
        XCTAssertNil(reminders.reminders.last?.due)
    }

    func testPrivacyReceiptFixture() throws {
        let receipt = try roundTrip(PrivacyReceipt.self, fixture: "privacy_receipt")
        XCTAssertTrue(receipt.shared.isEmpty)
        XCTAssertTrue(receipt.changed.isEmpty)
    }
}
