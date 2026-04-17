import XCTest
@testable import NOBSCore

final class ModelClientTests: XCTestCase {

    // MARK: - PromptBuilder

    func testPromptContainsUserName() {
        let prompt = PromptBuilder.systemPrompt(for: .general, userName: "Alice")
        XCTAssertTrue(prompt.contains("Alice"))
    }

    func testPromptContainsContext() {
        let prompt = PromptBuilder.systemPrompt(for: .calls)
        XCTAssertTrue(prompt.contains("phone_calls"))
    }

    func testPromptContainsAdditionalContext() {
        let extra = "User prefers short replies."
        let prompt = PromptBuilder.systemPrompt(for: .general, additionalContext: extra)
        XCTAssertTrue(prompt.contains(extra))
    }

    // MARK: - IntentParser

    func testExtractJSONSuccess() throws {
        let text = #"Some preamble {"intent": "makeCall", "params": {}} more text"#
        let json = try IntentParser.extractJSON(from: text)
        XCTAssertEqual(json["intent"] as? String, "makeCall")
    }

    func testExtractJSONNoJSONThrows() {
        XCTAssertThrowsError(try IntentParser.extractJSON(from: "No braces here"))
    }

    func testExtractJSONNestedParams() throws {
        let text = #"{"intent": "controlDevice", "params": {"deviceName": "lamp"}}"#
        let json = try IntentParser.extractJSON(from: text)
        let params = json["params"] as? [String: Any]
        XCTAssertEqual(params?["deviceName"] as? String, "lamp")
    }

    // MARK: - ChatMessage

    func testChatMessageRoundTrip() throws {
        let msg = ChatMessage(role: .user, content: "Hello!")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.role, .user)
        XCTAssertEqual(decoded.content, "Hello!")
    }

    func testSystemRoleRoundTrip() throws {
        let msg = ChatMessage(role: .system, content: "You are NOBS.")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.role, .system)
    }

    // MARK: - ModelConfiguration

    func testDefaultModelName() {
        let config = ModelConfiguration(localEndpoint: URL(string: "http://localhost:11434")!)
        XCTAssertEqual(config.modelName, "llama3")
        XCTAssertEqual(config.maxTokens, 2048)
        XCTAssertEqual(config.temperature, 0.7, accuracy: 0.001)
    }

    func testLocalhostConvenience() {
        let config = ModelConfiguration.localhost
        XCTAssertEqual(config.localEndpoint.host, "127.0.0.1")
        XCTAssertEqual(config.localEndpoint.port, 11434)
    }

    func testCustomConfiguration() {
        let url = URL(string: "http://192.168.1.10:11434")!
        let config = ModelConfiguration(localEndpoint: url, modelName: "mistral", maxTokens: 1024)
        XCTAssertEqual(config.modelName, "mistral")
        XCTAssertEqual(config.maxTokens, 1024)
        XCTAssertEqual(config.localEndpoint.host, "192.168.1.10")
    }

    func testTemperatureIsClamped() {
        let url = URL(string: "http://localhost:11434")!
        let tooHigh = ModelConfiguration(localEndpoint: url, temperature: 2.5)
        XCTAssertEqual(tooHigh.temperature, 1.0, accuracy: 0.001, "Temperature > 1.0 should be clamped to 1.0")

        let tooLow = ModelConfiguration(localEndpoint: url, temperature: -0.5)
        XCTAssertEqual(tooLow.temperature, 0.0, accuracy: 0.001, "Temperature < 0.0 should be clamped to 0.0")

        let valid = ModelConfiguration(localEndpoint: url, temperature: 0.5)
        XCTAssertEqual(valid.temperature, 0.5, accuracy: 0.001, "Valid temperature should be unchanged")
    }

    func testMaxTokensIsAtLeastOne() {
        let url = URL(string: "http://localhost:11434")!
        let config = ModelConfiguration(localEndpoint: url, maxTokens: 0)
        XCTAssertEqual(config.maxTokens, 1, "maxTokens <= 0 should be clamped to 1")

        let negative = ModelConfiguration(localEndpoint: url, maxTokens: -100)
        XCTAssertEqual(negative.maxTokens, 1)
    }

    // MARK: - AssistantIntent

    func testDataContextAllCases() {
        XCTAssertEqual(DataContext.allCases.count, 2)
        XCTAssertTrue(DataContext.allCases.contains(.personal))
        XCTAssertTrue(DataContext.allCases.contains(.work))
    }

    func testHomeActionRawValues() {
        XCTAssertEqual(HomeAction.turnOn.rawValue, "turnOn")
        XCTAssertEqual(HomeAction.lock.rawValue, "lock")
    }
}
