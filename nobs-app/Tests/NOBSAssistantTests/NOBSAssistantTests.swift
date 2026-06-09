import XCTest
@testable import NOBSAssistant
import NOBSCore
import NOBSDatabase

// MARK: - MockLLMBackend

final class MockLLMBackend: LLMBackend, @unchecked Sendable {
    var chatResponse: String = ""
    var errorToThrow: Error? = nil
    var structuredResult: StructuredIntentResult? = nil

    func chat(messages: [ChatMessage]) async throws -> String {
        if let error = errorToThrow { throw error }
        return chatResponse
    }

    func generateStructured(messages: [ChatMessage]) async throws -> StructuredIntentResult? {
        return structuredResult
    }
}

// MARK: - Mock IntentHandler

/// A simple stub that records which intents it handled.
final class MockIntentHandler: IntentHandler, @unchecked Sendable {
    var handledIntents: [AssistantIntent] = []
    var shouldThrow: Bool
    var supportedPattern: String   // "makeCall", "sendMessage", etc.
    var response: String

    init(pattern: String, response: String = "Done.", shouldThrow: Bool = false) {
        self.supportedPattern = pattern
        self.response = response
        self.shouldThrow = shouldThrow
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

    // MARK: - IntentMapper

    func testMapperMakeCall() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "makeCall",
                                params: ["phoneNumber": "+1555", "contactName": "Alice"])
        if case .makeCall(let number, let name) = intent {
            XCTAssertEqual(number, "+1555")
            XCTAssertEqual(name, "Alice")
        } else { XCTFail("Expected .makeCall") }
    }

    func testMapperMakeCallNoContactName() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "makeCall", params: ["phoneNumber": "+1555"])
        if case .makeCall(_, let name) = intent {
            XCTAssertNil(name)
        } else { XCTFail("Expected .makeCall") }
    }

    func testMapperScreenCall() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "screenCall", params: ["phoneNumber": "+19005550001"])
        if case .screenCall(let number) = intent {
            XCTAssertEqual(number, "+19005550001")
        } else { XCTFail("Expected .screenCall") }
    }

    func testMapperEndCall() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "endCall", params: [:])
        if case .endCall = intent { /* pass */ } else { XCTFail("Expected .endCall") }
    }

    func testMapperSendMessage() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "sendMessage", params: ["to": "Bob", "body": "Hi!"])
        if case .sendMessage(let to, let body) = intent {
            XCTAssertEqual(to, "Bob")
            XCTAssertEqual(body, "Hi!")
        } else { XCTFail("Expected .sendMessage") }
    }

    func testMapperReadMessages() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "readMessages", params: ["sender": "Alice"])
        if case .readMessages(let sender) = intent {
            XCTAssertEqual(sender, "Alice")
        } else { XCTFail("Expected .readMessages") }
    }

    func testMapperReadMessagesNilSender() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "readMessages", params: [:])
        if case .readMessages(let sender) = intent {
            XCTAssertNil(sender)
        } else { XCTFail("Expected .readMessages") }
    }

    func testMapperControlDevice() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "controlDevice",
                                params: ["deviceName": "Lamp", "action": "turnOff"])
        if case .controlDevice(let name, let action) = intent {
            XCTAssertEqual(name, "Lamp")
            XCTAssertEqual(action, .turnOff)
        } else { XCTFail("Expected .controlDevice") }
    }

    func testMapperControlDeviceDefaultsToTurnOn() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "controlDevice",
                                params: ["deviceName": "Fan", "action": "INVALID"])
        if case .controlDevice(_, let action) = intent {
            XCTAssertEqual(action, .turnOn)
        } else { XCTFail("Expected .controlDevice") }
    }

    func testMapperRunScene() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "runScene", params: ["sceneName": "Movie Night"])
        if case .runScene(let name) = intent {
            XCTAssertEqual(name, "Movie Night")
        } else { XCTFail("Expected .runScene") }
    }

    func testMapperQueryDevice() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "queryDevice", params: ["deviceName": "Thermostat"])
        if case .queryDevice(let name) = intent {
            XCTAssertEqual(name, "Thermostat")
        } else { XCTFail("Expected .queryDevice") }
    }

    func testMapperCreateReminder() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "createReminder",
                                params: ["title": "Buy milk", "context": "work"])
        if case .createReminder(let title, _, _, let ctx) = intent {
            XCTAssertEqual(title, "Buy milk")
            XCTAssertEqual(ctx, .work)
        } else { XCTFail("Expected .createReminder") }
    }

    func testMapperCreateReminderWithISODueDate() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "createReminder",
                                params: ["title": "Meeting", "dueDate": "2024-06-01T09:00:00Z"])
        if case .createReminder(_, let due, _, _) = intent {
            XCTAssertNotNil(due)
        } else { XCTFail("Expected .createReminder") }
    }

    func testMapperListReminders() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "listReminders", params: ["context": "work"])
        if case .listReminders(let ctx) = intent {
            XCTAssertEqual(ctx, .work)
        } else { XCTFail("Expected .listReminders") }
    }

    func testMapperListRemindersDefaultContext() {
        let mapper = IntentMapper(defaultContext: .work)
        let intent = mapper.map(name: "listReminders", params: [:])
        if case .listReminders(let ctx) = intent {
            XCTAssertEqual(ctx, .work)
        } else { XCTFail("Expected .listReminders") }
    }

    func testMapperCompleteReminder() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "completeReminder", params: ["id": "abc-123"])
        if case .completeReminder(let id) = intent {
            XCTAssertEqual(id, "abc-123")
        } else { XCTFail("Expected .completeReminder") }
    }

    func testMapperBrowseWeb() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "browseWeb", params: ["query": "Swift concurrency"])
        if case .browseWeb(let query) = intent {
            XCTAssertEqual(query, "Swift concurrency")
        } else { XCTFail("Expected .browseWeb") }
    }

    func testMapperStoreMemory() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "storeMemory",
                                params: ["content": "User likes espresso", "context": "personal"])
        if case .storeMemory(let content, let ctx) = intent {
            XCTAssertEqual(content, "User likes espresso")
            XCTAssertEqual(ctx, .personal)
        } else { XCTFail("Expected .storeMemory") }
    }

    func testMapperRecallMemory() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "recallMemory",
                                params: ["query": "coffee", "context": "work"])
        if case .recallMemory(let query, let ctx) = intent {
            XCTAssertEqual(query, "coffee")
            XCTAssertEqual(ctx, .work)
        } else { XCTFail("Expected .recallMemory") }
    }

    func testMapperUnknownFallsThrough() {
        let mapper = IntentMapper(defaultContext: .personal)
        let intent = mapper.map(name: "doSomethingRandom", params: [:])
        if case .unknown(let raw) = intent {
            XCTAssertEqual(raw, "doSomethingRandom")
        } else { XCTFail("Expected .unknown") }
    }

    // MARK: - NOBSAssistant

    func testProcessWithValidInput() async throws {
        let mock = MockLLMBackend()
        mock.chatResponse = "OK"
        let assistant = NOBSAssistant(backend: mock)
        let response = await assistant.process("Hello")
        XCTAssertEqual(response.text, "OK")
        XCTAssertTrue(response.actionSucceeded)
    }

    func testProcessWithError() async throws {
        let mock = MockLLMBackend()
        mock.errorToThrow = NSError(domain: "TestError", code: 1, userInfo: nil)
        let assistant = NOBSAssistant(backend: mock)
        let response = await assistant.process("Call Mom")
        XCTAssertTrue(response.text.hasPrefix("I had trouble reaching the local model"))
        XCTAssertFalse(response.actionSucceeded)
    }

    func testProcessWithEmptyInput() async throws {
        let mock = MockLLMBackend()
        let assistant = NOBSAssistant(backend: mock)
        let response = await assistant.process("")
        XCTAssertEqual(response.text, "Please enter a valid message.")
        XCTAssertFalse(response.actionSucceeded)
    }

    func testProcessReturnsRawTextWhenNoJSON() async throws {
        let mock = MockLLMBackend()
        mock.chatResponse = "I'm not sure what you mean."
        let assistant = NOBSAssistant(backend: mock)
        let response = await assistant.process("blah blah blah")
        XCTAssertEqual(response.text, "I'm not sure what you mean.")
        XCTAssertTrue(response.actionSucceeded)
    }

    func testProcessWithSuccessfulIntentHandling() async throws {
        let mock = MockLLMBackend()
        mock.structuredResult = StructuredIntentResult(
            intent: "makeCall",
            reply: "Calling Mom",
            params: ["phoneNumber": "555", "contactName": "Mom"]
        )
        let handler = MockIntentHandler(pattern: "makeCall", response: "Dialing...")
        let assistant = NOBSAssistant(backend: mock, handlers: [handler])
        let response = await assistant.process("Call Mom")
        XCTAssertTrue(response.actionSucceeded)
        XCTAssertEqual(handler.handledIntents.count, 1)
    }

    func testProcessWithErrorInIntentHandling() async throws {
        let mock = MockLLMBackend()
        mock.structuredResult = StructuredIntentResult(
            intent: "makeCall",
            reply: "Calling Mom",
            params: ["phoneNumber": "555", "contactName": "Mom"]
        )
        let handler = MockIntentHandler(pattern: "makeCall", shouldThrow: true)
        let assistant = NOBSAssistant(backend: mock, handlers: [handler])
        let response = await assistant.process("Call Mom")
        XCTAssertFalse(response.actionSucceeded)
    }

    func testProcessRoutesUnknownIntentWithNoHandlers() async throws {
        let mock = MockLLMBackend()
        mock.structuredResult = StructuredIntentResult(intent: "doSomethingRandom", reply: "Sure!", params: [:])
        let assistant = NOBSAssistant(backend: mock)
        let response = await assistant.process("Do something random")
        XCTAssertTrue(response.actionSucceeded)
        XCTAssertFalse(response.text.isEmpty)
    }
}
