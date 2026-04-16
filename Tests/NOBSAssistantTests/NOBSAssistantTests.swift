import XCTest
@testable import NOBSAssistant
import NOBSCore
import NOBSDatabase

// MARK: - Mock IntentHandler

/// A simple stub that records which intents it handled.
final class MockIntentHandler: IntentHandler, @unchecked Sendable {
    var handledIntents: [AssistantIntent] = []
    var shouldThrow = false
    var supportedPattern: String   // "makeCall", "sendMessage", etc.
    var response: String

    init(pattern: String, response: String = "Done.") {
        self.supportedPattern = pattern
        self.response = response
    }

    func canHandle(_ intent: AssistantIntent) -> Bool {
        switch intent {
        case .makeCall:     return supportedPattern == "makeCall"
        case .sendMessage:  return supportedPattern == "sendMessage"
        case .listReminders: return supportedPattern == "listReminders"
        default:            return false
        }
    }

    func handle(_ intent: AssistantIntent) async throws -> String {
        if shouldThrow { throw NSError(domain: "Mock", code: 0) }
        handledIntents.append(intent)
        return response
    }
}

// MARK: - AssistantResponse

final class NOBSAssistantTests: XCTestCase {

    func testAssistantResponseDefaults() {
        let r = AssistantResponse(text: "Hello!")
        XCTAssertEqual(r.text, "Hello!")
        XCTAssertNil(r.intent)
        XCTAssertTrue(r.actionSucceeded)
    }

    func testAssistantResponseWithIntent() {
        let intent = AssistantIntent.makeCall(phoneNumber: "+1555", contactName: "Mom")
        let r = AssistantResponse(text: "Calling Mom", intent: intent, actionSucceeded: true)
        XCTAssertNotNil(r.intent)
    }

    // MARK: - IntentHandler protocol via mock

    func testMockHandlerCanHandleMakeCall() {
        let handler = MockIntentHandler(pattern: "makeCall")
        let intent  = AssistantIntent.makeCall(phoneNumber: "555", contactName: nil)
        XCTAssertTrue(handler.canHandle(intent))
    }

    func testMockHandlerCannotHandleOtherIntents() {
        let handler = MockIntentHandler(pattern: "makeCall")
        XCTAssertFalse(handler.canHandle(.sendMessage(to: "x", body: "y")))
    }

    func testMockHandlerRecordsHandledIntent() async throws {
        let handler = MockIntentHandler(pattern: "makeCall", response: "Calling!")
        let intent  = AssistantIntent.makeCall(phoneNumber: "555", contactName: nil)
        let result  = try await handler.handle(intent)
        XCTAssertEqual(result, "Calling!")
        XCTAssertEqual(handler.handledIntents.count, 1)
    }

    func testMockHandlerThrowsWhenConfigured() async {
        let handler = MockIntentHandler(pattern: "makeCall")
        handler.shouldThrow = true
        do {
            _ = try await handler.handle(.makeCall(phoneNumber: "555", contactName: nil))
            XCTFail("Expected throw")
        } catch {
            // expected
        }
    }

    // MARK: - DataContext

    func testDataContextRawValues() {
        XCTAssertEqual(DataContext.personal.rawValue, "personal")
        XCTAssertEqual(DataContext.work.rawValue,     "work")
    }

    // MARK: - HomeAction

    func testHomeActionRoundTrip() throws {
        let encoded = try JSONEncoder().encode(HomeAction.turnOn)
        let decoded = try JSONDecoder().decode(HomeAction.self, from: encoded)
        XCTAssertEqual(decoded, .turnOn)
    }
}
