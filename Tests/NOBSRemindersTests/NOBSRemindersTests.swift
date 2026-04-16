import XCTest
@testable import NOBSReminders
import NOBSCore

final class NOBSRemindersTests: XCTestCase {

    // MARK: - ReminderItem

    func testReminderItemDefaults() {
        let item = ReminderItem(title: "Buy milk")
        XCTAssertFalse(item.id.isEmpty)
        XCTAssertEqual(item.title, "Buy milk")
        XCTAssertNil(item.dueDate)
        XCTAssertFalse(item.isCompleted)
        XCTAssertEqual(item.dataContext, .personal)
    }

    func testReminderItemWorkContext() {
        let item = ReminderItem(title: "File taxes", dataContext: .work)
        XCTAssertEqual(item.dataContext, .work)
    }

    func testReminderItemWithDueDate() {
        let due  = Date().addingTimeInterval(86400)
        let item = ReminderItem(title: "Doctor appointment", dueDate: due)
        XCTAssertNotNil(item.dueDate)
        XCTAssertEqual(item.dueDate!.timeIntervalSince1970, due.timeIntervalSince1970, accuracy: 1)
    }

    // MARK: - RemindersHandler (intent routing)

    func testHandlerAcceptsCreateReminder() {
        let handler = RemindersHandler()
        let intent  = AssistantIntent.createReminder(
            title: "Test", dueDate: nil, notes: nil, context: .personal
        )
        XCTAssertTrue(handler.canHandle(intent))
    }

    func testHandlerAcceptsListReminders() {
        let handler = RemindersHandler()
        XCTAssertTrue(handler.canHandle(.listReminders(context: .work)))
    }

    func testHandlerAcceptsCompleteReminder() {
        let handler = RemindersHandler()
        XCTAssertTrue(handler.canHandle(.completeReminder(id: UUID().uuidString)))
    }

    func testHandlerRejectsUnrelatedIntent() {
        let handler = RemindersHandler()
        XCTAssertFalse(handler.canHandle(.makeCall(phoneNumber: "555", contactName: nil)))
        XCTAssertFalse(handler.canHandle(.sendMessage(to: "alice", body: "hi")))
    }

    // MARK: - RemindersHandler (list on Linux / no EventKit)

    func testListReturnsEmptyWhenEventKitUnavailable() async throws {
        let handler = RemindersHandler()
        // On Linux / CI there is no EventKit so list returns []
        let items = try await handler.list(context: .personal)
        XCTAssertTrue(items.isEmpty)
    }
}
