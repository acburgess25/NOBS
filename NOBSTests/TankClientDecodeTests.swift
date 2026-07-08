import XCTest
@testable import NOBS

final class TankClientDecodeTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testDailyBriefingDecodesTankJSON() throws {
        let json = """
        {
          "date": "2026-07-08",
          "topline": "A focused day with one meeting.",
          "priorities": ["Business · Design sync (10:00)"],
          "conflicts_or_risks": ["Tight transition after standup."],
          "recommended_plan": ["Prep before 09:30."],
          "one_useful_question": null,
          "suggested_next_actions": ["Review notes."],
            "generated_at": "2026-07-08T12:00:00Z",
          "kind": "morning",
          "route": "Tank",
          "privacy_receipt": {
            "used": ["1 calendar items", "1 reminder items"],
            "processed": "Tank on your private network",
            "shared": [],
            "changed": []
          }
        }
        """.data(using: .utf8)!

        let briefing = try decoder.decode(DailyBriefing.self, from: json)

        XCTAssertEqual(briefing.date, "2026-07-08")
        XCTAssertEqual(briefing.kind, .morning)
        XCTAssertEqual(briefing.topline, "A focused day with one meeting.")
        XCTAssertEqual(briefing.route, .tank)
        XCTAssertEqual(briefing.privacyReceipt.processed, "Tank on your private network")
        XCTAssertNil(briefing.oneUsefulQuestion)
    }

    func testTankScheduleDecodesSnakeCaseKeys() throws {
        let json = """
        [
          {
            "id": "sched-1",
            "time_of_day": "07:30",
            "status": "active",
            "created_at": "2026-07-08T10:00:00Z"
          }
        ]
        """.data(using: .utf8)!

        let schedules = try decoder.decode([TankSchedule].self, from: json)

        XCTAssertEqual(schedules.count, 1)
        XCTAssertEqual(schedules[0].timeOfDay, "07:30")
        XCTAssertEqual(schedules[0].status, "active")
    }

    func testTankChatResponseDecodesPrivacyReceipt() throws {
        let json = """
        {
          "message": "Let’s make it realistic.",
          "route": "Tank",
          "privacy_receipt": {
            "used": ["text entered in this conversation"],
            "processed": "Tank on your private network",
            "shared": [],
            "changed": []
          }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(TankChatResponse.self, from: json)

        XCTAssertEqual(response.message, "Let’s make it realistic.")
        XCTAssertEqual(response.route, .tank)
        XCTAssertEqual(response.receipt.used, ["text entered in this conversation"])
    }

    func testProcessingRouteDecodesAllCases() throws {
        XCTAssertEqual(try decodeRoute("\"Local\""), .local)
        XCTAssertEqual(try decodeRoute("\"Tank\""), .tank)
        XCTAssertEqual(try decodeRoute("\"NOBScloud\""), .cloud)
    }

    func testPendingApprovalDecodesExecutionContext() throws {
        let json = """
        {
          "id": "approval-1",
          "run_id": "run-1",
          "tool_name": "write_workspace_note",
          "arguments": {
            "context": "personal",
            "title": "Weekly priorities",
            "content": "Protect Friday afternoon."
          },
          "risk": "change",
          "reason": "Save a note",
          "status": "pending",
          "created_at": "2026-07-08T12:00:00Z",
          "decided_at": null,
          "triggered_by": "scheduler",
          "run_objective": "Autonomously propose a routine",
          "run_context": "personal",
          "audit_events": [
            {
              "event_type": "tool_executed",
              "detail": { "tool": "list_home_devices" },
              "created_at": "2026-07-08T11:59:00Z"
            }
          ]
        }
        """.data(using: .utf8)!

        let approval = try decoder.decode(PendingApproval.self, from: json)

        XCTAssertEqual(approval.triggeredBy, "scheduler")
        XCTAssertEqual(approval.runObjective, "Autonomously propose a routine")
        XCTAssertEqual(approval.auditEvents?.count, 1)
        XCTAssertEqual(approval.auditEvents?.first?.eventType, "tool_executed")
    }

    func testMalformedJSONThrowsDecodingError() {
        let json = "{".data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(DailyBriefing.self, from: json)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testMissingRequiredFieldThrowsDecodingError() throws {
        let json = """
        {
          "date": "2026-07-08",
          "topline": "Incomplete payload"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(DailyBriefing.self, from: json)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    private func decodeRoute(_ fragment: String) throws -> ProcessingRoute {
        let json = fragment.data(using: .utf8)!
        return try decoder.decode(ProcessingRoute.self, from: json)
    }
}
