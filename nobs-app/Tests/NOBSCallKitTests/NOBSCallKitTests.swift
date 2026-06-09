import XCTest
@testable import NOBSCallKit
import NOBSCore

final class NOBSCallKitTests: XCTestCase {

    // MARK: - CallScreener

    func testKnownContactIsAllowed() {
        let screener = CallScreener(knownContactNumbers: ["14155551234"])
        let decision = screener.evaluate(phoneNumber: "+1 (415) 555-1234", callerName: nil)
        XCTAssertEqual(decision, .allow)
    }

    func testBlockedNumberIsRejected() {
        let screener = CallScreener(
            knownContactNumbers: [],
            blockedNumbers: ["18005550000"]
        )
        let decision = screener.evaluate(phoneNumber: "1-800-555-0000", callerName: nil)
        XCTAssertEqual(decision, .reject)
    }

    func testNamedButUnknownCallerIsSilenced() {
        let screener = CallScreener()
        let decision = screener.evaluate(phoneNumber: "19995550001", callerName: "Spam Likely")
        XCTAssertEqual(decision, .silence)
    }

    func testCompletelyUnknownCallerAsksForName() {
        let screener = CallScreener()
        let decision = screener.evaluate(phoneNumber: "19995550002", callerName: nil)
        XCTAssertEqual(decision, .askForName)
    }

    func testNormalisationStripsFormatting() {
        let screener = CallScreener(knownContactNumbers: ["14155551234"])
        // Number supplied with spaces, dashes, and parentheses
        let decision = screener.evaluate(phoneNumber: "+1 (415) 555-1234", callerName: nil)
        XCTAssertEqual(decision, .allow)
    }

    // MARK: - CallRecord

    func testCallRecordDefaults() {
        let record = CallRecord(
            phoneNumber: "+14155551234",
            direction: .outbound,
            outcome: .connected
        )
        XCTAssertFalse(record.id.uuidString.isEmpty)
        XCTAssertEqual(record.direction, .outbound)
        XCTAssertEqual(record.outcome, .connected)
        XCTAssertEqual(record.duration, 0)
    }

    // MARK: - CallManager (intent handler)

    func testCallManagerHandlesMakeCall() {
        let manager = CallManager()
        let intent = AssistantIntent.makeCall(phoneNumber: "+14155551234", contactName: "Mom")
        XCTAssertTrue(manager.canHandle(intent))
    }

    func testCallManagerHandlesScreenCall() {
        let manager = CallManager()
        XCTAssertTrue(manager.canHandle(.screenCall(phoneNumber: "18005550000")))
    }

    func testCallManagerHandlesEndCall() {
        let manager = CallManager()
        XCTAssertTrue(manager.canHandle(.endCall))
    }

    func testCallManagerDoesNotHandleReminders() {
        let manager = CallManager()
        let intent  = AssistantIntent.listReminders(context: .personal)
        XCTAssertFalse(manager.canHandle(intent))
    }

    func testInvalidPhoneNumberThrows() async {
        let manager = CallManager()
        do {
            try await manager.place(call: "abc-not-a-number")
            XCTFail("Expected CallError.invalidPhoneNumber")
        } catch CallError.invalidPhoneNumber {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCallHistoryStartsEmpty() {
        let manager = CallManager()
        // History is initially empty — checked via actor isolation
        let expectation = expectation(description: "history empty")
        Task {
            let history = await manager.callHistory
            XCTAssertTrue(history.isEmpty)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - Injected CallScreener

    func testCallManagerUsesInjectedScreenerForKnownContact() async {
        let screener = CallScreener(knownContactNumbers: ["14155551234"])
        let manager  = CallManager(screener: screener)
        let result   = try? await manager.handle(.screenCall(phoneNumber: "+1 (415) 555-1234"))
        // The injected screener knows this number — decision should be "allow"
        XCTAssertEqual(result, "Screen decision for +1 (415) 555-1234: allow")
    }

    func testCallManagerUsesInjectedScreenerForBlockedNumber() async {
        let screener = CallScreener(knownContactNumbers: [], blockedNumbers: ["18005550000"])
        let manager  = CallManager(screener: screener)
        let result   = try? await manager.handle(.screenCall(phoneNumber: "1-800-555-0000"))
        XCTAssertEqual(result, "Screen decision for 1-800-555-0000: reject")
    }

    func testCallManagerEmptyScreenerAsksForNameForUnknownCaller() async {
        let manager = CallManager()  // default: empty screener
        let result  = try? await manager.handle(.screenCall(phoneNumber: "+19995550099"))
        XCTAssertEqual(result, "Screen decision for +19995550099: askForName")
    }
}
