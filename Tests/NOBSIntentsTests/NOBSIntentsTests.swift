import XCTest
@testable import NOBSIntents
import NOBSCore
import NOBSAssistant

// MARK: - Mock IntentAssistant for testing

final class MockIntentAssistant: Sendable {
    let responseText: String

    init(responseText: String = "Mock response") {
        self.responseText = responseText
    }

    func process(_ input: String) async -> AssistantResponse {
        AssistantResponse(text: responseText)
    }
}

// MARK: - AskNOBSIntent Tests

final class AskNOBSIntentTests: XCTestCase {

    func testIntentHasCorrectTitle() {
        XCTAssertEqual(AskNOBSIntent.title.stringValue, "Ask NOBS")
    }

    func testIntentIsDiscoverable() {
        XCTAssertTrue(AskNOBSIntent.isDiscoverable)
    }

    func testIntentDoesNotOpenApp() {
        XCTAssertFalse(AskNOBSIntent.openAppWhenRun)
    }

    func testIntentInitWithQuestion() {
        let intent = AskNOBSIntent(question: "What is the weather?")
        XCTAssertEqual(intent.question, "What is the weather?")
    }

    func testIntentInitNoArguments() {
        let intent = AskNOBSIntent()
        XCTAssertEqual(intent.question, "")
    }
}

// MARK: - ControlHomeIntent Tests

final class ControlHomeIntentTests: XCTestCase {

    func testControlHomeIntentHasCorrectTitle() {
        XCTAssertEqual(ControlHomeIntent.title.stringValue, "Control Home")
    }

    func testControlHomeIntentIsNotDiscoverable() {
        XCTAssertFalse(ControlHomeIntent.isDiscoverable)
    }

    func testControlHomeIntentDoesNotOpenApp() {
        XCTAssertFalse(ControlHomeIntent.openAppWhenRun)
    }

    func testControlHomeIntentInitWithCommand() {
        let intent = ControlHomeIntent(command: "Turn on the lights")
        XCTAssertEqual(intent.command, "Turn on the lights")
    }

    func testControlHomeIntentInitNoArguments() {
        let intent = ControlHomeIntent()
        XCTAssertEqual(intent.command, "")
    }
}

// MARK: - RunSceneIntent Tests

final class RunSceneIntentTests: XCTestCase {

    func testRunSceneIntentHasCorrectTitle() {
        XCTAssertEqual(RunSceneIntent.title.stringValue, "Run Scene")
    }

    func testRunSceneIntentDoesNotOpenApp() {
        XCTAssertFalse(RunSceneIntent.openAppWhenRun)
    }

    func testRunSceneIntentInitWithSceneName() {
        let intent = RunSceneIntent(sceneName: "Movie Night")
        XCTAssertEqual(intent.sceneName, "Movie Night")
    }

    func testRunSceneIntentInitNoArguments() {
        let intent = RunSceneIntent()
        XCTAssertEqual(intent.sceneName, "")
    }
}

// MARK: - CreateReminderIntent Tests

final class CreateReminderIntentTests: XCTestCase {

    func testCreateReminderIntentHasCorrectTitle() {
        XCTAssertEqual(CreateReminderIntent.title.stringValue, "Create Reminder")
    }

    func testCreateReminderIntentDoesNotOpenApp() {
        XCTAssertFalse(CreateReminderIntent.openAppWhenRun)
    }

    func testCreateReminderIntentInitWithTitle() {
        let intent = CreateReminderIntent(title: "Buy milk")
        XCTAssertEqual(intent.title, "Buy milk")
    }

    func testCreateReminderIntentInitNoArguments() {
        let intent = CreateReminderIntent()
        XCTAssertEqual(intent.title, "")
    }
}

// MARK: - RememberThisIntent Tests

final class RememberThisIntentTests: XCTestCase {

    func testRememberThisIntentHasCorrectTitle() {
        XCTAssertEqual(RememberThisIntent.title.stringValue, "Remember This")
    }

    func testRememberThisIntentDoesNotOpenApp() {
        XCTAssertFalse(RememberThisIntent.openAppWhenRun)
    }

    func testRememberThisIntentInitWithText() {
        let intent = RememberThisIntent(text: "User likes espresso")
        XCTAssertEqual(intent.text, "User likes espresso")
    }

    func testRememberThisIntentInitNoArguments() {
        let intent = RememberThisIntent()
        XCTAssertEqual(intent.text, "")
    }
}

// MARK: - IntentAssistant Tests

final class IntentAssistantTests: XCTestCase {

    func testIntentAssistantMakeReturnsValidInstance() {
        let assistant = IntentAssistant.make()
        // Just verify it doesn't crash and returns something
        XCTAssertNotNil(assistant)
    }
}

// MARK: - NOBSShortcutsProvider Tests

final class NOBSShortcutsProviderTests: XCTestCase {

    func testShortcutsProviderProvides() {
        let provider = NOBSShortcutsProvider()
        let intents = provider.providedIntents

        // Should provide multiple intent types
        XCTAssertGreaterThan(intents.count, 0, "NOBSShortcutsProvider should provide at least one intent")
    }
}

// MARK: - NOBSIntentSnippet Tests

final class NOBSIntentSnippetTests: XCTestCase {

    func testIntentSnippetCanInitialize() {
        let snippet = NOBSIntentSnippet(intent: AskNOBSIntent(question: "test"))
        XCTAssertNotNil(snippet)
    }
}
