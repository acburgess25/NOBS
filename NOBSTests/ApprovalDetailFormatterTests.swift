import XCTest
@testable import NOBS

final class ApprovalDetailFormatterTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testHomeDeviceSummaryUsesFriendlyLabels() throws {
        let approval = try decodeApproval(
            toolName: "control_home_device",
            arguments: [
                "entity_id": "light.living_room",
                "service": "turn_on",
                "service_data": [:]
            ]
        )

        let lines = ApprovalDetailFormatter.summaryLines(
            toolName: approval.toolName,
            arguments: approval.arguments
        )

        XCTAssertEqual(lines.first(where: { $0.id == "device" })?.value, "Living Room")
        XCTAssertEqual(lines.first(where: { $0.id == "action" })?.value, "Turn on")
    }

    func testWorkspaceNoteSummaryIncludesTitleAndContext() throws {
        let approval = try decodeApproval(
            toolName: "write_workspace_note",
            arguments: [
                "context": "personal",
                "title": "Weekly priorities",
                "content": "Protect Friday afternoon for planning."
            ]
        )

        let lines = ApprovalDetailFormatter.summaryLines(
            toolName: approval.toolName,
            arguments: approval.arguments
        )

        XCTAssertEqual(lines.first(where: { $0.id == "title" })?.value, "Weekly priorities")
        XCTAssertEqual(lines.first(where: { $0.id == "context" })?.value, "Personal")
    }

    func testHomeDeviceReversalMapsTurnOnToTurnOff() throws {
        let approval = try decodeApproval(
            toolName: "control_home_device",
            arguments: [
                "entity_id": "light.kitchen",
                "service": "turn_on",
                "service_data": [:]
            ],
            runObjective: "Make the kitchen brighter"
        )

        let reversal = ApprovalDetailFormatter.reversal(for: approval)

        XCTAssertNotNil(reversal)
        XCTAssertTrue(reversal?.detail.contains("turn off Kitchen") == true)
        XCTAssertTrue(reversal?.chatPrompt.contains("turn_off") == true)
    }

    func testTriggeredByLabelDistinguishesScheduler() {
        XCTAssertEqual(ApprovalDetailFormatter.triggeredByLabel("scheduler"), "Scheduled on Tank")
        XCTAssertEqual(ApprovalDetailFormatter.triggeredByLabel("user"), "You asked in chat")
    }

    private func decodeApproval(
        toolName: String,
        arguments: [String: Any],
        runObjective: String = "Test objective"
    ) throws -> PendingApproval {
        let argumentsJSON = try String(
            data: JSONSerialization.data(withJSONObject: arguments),
            encoding: .utf8
        )!
        let json = """
        {
          "id": "a1",
          "run_id": "r1",
          "tool_name": "\(toolName)",
          "arguments": \(argumentsJSON),
          "risk": "change",
          "reason": "Test reason",
          "status": "pending",
          "created_at": "2026-07-08T12:00:00Z",
          "decided_at": null,
          "triggered_by": "user",
          "run_objective": "\(runObjective)",
          "run_context": "personal",
          "audit_events": []
        }
        """.data(using: .utf8)!

        return try decoder.decode(PendingApproval.self, from: json)
    }
}
