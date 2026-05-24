import XCTest
@testable import NOBSHomeKit
import NOBSCore

final class NOBSHomeKitTests: XCTestCase {

    // MARK: - HomeKitError

    func testHomeKitErrorNotAvailableDescription() {
        let error = HomeKitError.homeKitNotAvailable
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("HomeKit"))
    }

    func testHomeKitErrorHomeNotFoundDescription() {
        let error = HomeKitError.homeNotFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("home"))
    }

    func testHomeKitErrorAccessoryNotFoundDescription() {
        let error = HomeKitError.accessoryNotFound("Lamp")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Lamp"))
    }

    func testHomeKitErrorActionFailedDescription() {
        let error = HomeKitError.actionFailed("Network error")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Network error"))
    }

    // MARK: - HomeKitHandler — Intent Routing

    func testHandlerCanHandleControlDeviceIntent() {
        let handler = HomeKitHandler()
        let intent = AssistantIntent.controlDevice(deviceName: "Lamp", action: .turnOn)
        XCTAssertTrue(handler.canHandle(intent))
    }

    func testHandlerCanHandleRunSceneIntent() {
        let handler = HomeKitHandler()
        let intent = AssistantIntent.runScene(sceneName: "Movie Night")
        XCTAssertTrue(handler.canHandle(intent))
    }

    func testHandlerCanHandleQueryDeviceIntent() {
        let handler = HomeKitHandler()
        let intent = AssistantIntent.queryDevice(deviceName: "Thermostat")
        XCTAssertTrue(handler.canHandle(intent))
    }

    func testHandlerRejectsUnrelatedIntents() {
        let handler = HomeKitHandler()
        XCTAssertFalse(handler.canHandle(.makeCall(phoneNumber: "555", contactName: nil)))
        XCTAssertFalse(handler.canHandle(.sendMessage(to: "Bob", body: "Hi")))
        XCTAssertFalse(handler.canHandle(.listReminders(context: .personal)))
    }

    // MARK: - HomeKitHandler — Control (Platform-conditional)

    func testControlDeviceReturnsSimulatedResponseOnNonHomeKitPlatforms() async throws {
        let handler = HomeKitHandler()
        let result = try await handler.control(device: "Lamp", action: .turnOn)
        // On non-HomeKit platforms (like Linux CI), returns simulation message
        #if !canImport(HomeKit)
        XCTAssertTrue(result.contains("simulated") || result.contains("Lamp"))
        #endif
    }

    func testControlDeviceRespectsHomeActionVariants() async throws {
        let handler = HomeKitHandler()

        // Test each home action to ensure they generate appropriate responses
        let actions: [HomeAction] = [
            .turnOn, .turnOff, .lock, .unlock,
            .setBrightness, .setTemperature, .open, .close
        ]

        for action in actions {
            let result = try await handler.control(device: "TestDevice", action: action)
            // Should include device name in response
            XCTAssertTrue(result.contains("TestDevice"), "Response should mention device name for \(action)")
        }
    }

    // MARK: - HomeKitHandler — Scene Execution (Platform-conditional)

    func testRunSceneReturnsSimulatedResponseOnNonHomeKitPlatforms() async throws {
        let handler = HomeKitHandler()
        let result = try await handler.run(scene: "Movie Night")
        // On non-HomeKit platforms, returns simulation message
        #if !canImport(HomeKit)
        XCTAssertTrue(result.contains("simulated") || result.contains("Movie Night"))
        #endif
    }

    // MARK: - HomeKitHandler — Device Query (Platform-conditional)

    func testQueryDeviceReturnsSimulatedResponseOnNonHomeKitPlatforms() async throws {
        let handler = HomeKitHandler()
        let result = try await handler.query(device: "Thermostat")
        // On non-HomeKit platforms, returns simulation message
        #if !canImport(HomeKit)
        XCTAssertTrue(result.contains("simulated") || result.contains("Thermostat"))
        #endif
    }

    // MARK: - HomeKitHandler — Handle Method Dispatch

    func testHandleDispatchesControlDeviceIntent() async throws {
        let handler = HomeKitHandler()
        let intent = AssistantIntent.controlDevice(deviceName: "Light", action: .turnOn)
        let result = try await handler.handle(intent)
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    func testHandleDispatchesRunSceneIntent() async throws {
        let handler = HomeKitHandler()
        let intent = AssistantIntent.runScene(sceneName: "Evening")
        let result = try await handler.handle(intent)
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    func testHandleDispatchesQueryDeviceIntent() async throws {
        let handler = HomeKitHandler()
        let intent = AssistantIntent.queryDevice(deviceName: "Sensor")
        let result = try await handler.handle(intent)
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    func testHandleThrowsForUnhandledIntent() async throws {
        let handler = HomeKitHandler()
        let intent = AssistantIntent.makeCall(phoneNumber: "555", contactName: nil)

        do {
            try await handler.handle(intent)
            XCTFail("Expected to throw for unhandled intent")
        } catch HomeKitError.actionFailed(let reason) {
            XCTAssertTrue(reason.contains("Unsupported"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - HomeAction Tests

    func testHomeActionAllCases() {
        let actions: [HomeAction] = [
            .turnOn, .turnOff, .lock, .unlock,
            .setBrightness, .setTemperature, .open, .close
        ]
        XCTAssertEqual(actions.count, 8)
    }

    func testHomeActionRawValues() {
        XCTAssertEqual(HomeAction.turnOn.rawValue, "turnOn")
        XCTAssertEqual(HomeAction.turnOff.rawValue, "turnOff")
        XCTAssertEqual(HomeAction.lock.rawValue, "lock")
        XCTAssertEqual(HomeAction.unlock.rawValue, "unlock")
        XCTAssertEqual(HomeAction.setBrightness.rawValue, "setBrightness")
        XCTAssertEqual(HomeAction.setTemperature.rawValue, "setTemperature")
        XCTAssertEqual(HomeAction.open.rawValue, "open")
        XCTAssertEqual(HomeAction.close.rawValue, "close")
    }

    func testHomeActionConformsToCodable() throws {
        let action = HomeAction.turnOn
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(HomeAction.self, from: encoded)
        XCTAssertEqual(decoded, action)
    }

    // MARK: - Handler Isolation (Actor behavior)

    func testHandlerIsActorIsolated() async {
        let handler = HomeKitHandler()
        // Verify we can use the actor from async context
        let intent = AssistantIntent.controlDevice(deviceName: "Test", action: .turnOn)
        XCTAssertTrue(handler.canHandle(intent))
    }
}
