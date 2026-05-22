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
        let handler = RemindersHandler(inMemory: true)
        let intent  = AssistantIntent.createReminder(
            title: "Test", dueDate: nil, notes: nil, context: .personal
        )
        XCTAssertTrue(handler.canHandle(intent))
    }

    func testHandlerAcceptsListReminders() {
        let handler = RemindersHandler(inMemory: true)
        XCTAssertTrue(handler.canHandle(.listReminders(context: .work)))
    }

    func testHandlerAcceptsCompleteReminder() {
        let handler = RemindersHandler(inMemory: true)
        XCTAssertTrue(handler.canHandle(.completeReminder(id: UUID().uuidString)))
    }

    func testHandlerRejectsUnrelatedIntent() {
        let handler = RemindersHandler(inMemory: true)
        XCTAssertFalse(handler.canHandle(.makeCall(phoneNumber: "555", contactName: nil)))
        XCTAssertFalse(handler.canHandle(.sendMessage(to: "alice", body: "hi")))
    }

    // MARK: - RemindersHandler (in-memory CRUD)

    func testListReturnsEmptyWhenEventKitUnavailable() async throws {
        let handler = RemindersHandler(inMemory: true)
        let items = try await handler.list(context: .personal)
        XCTAssertTrue(items.isEmpty)
    }

    func testInMemoryCRUD() async throws {
        let handler = RemindersHandler(inMemory: true)
        
        // 1. Create a personal reminder
        let item1 = ReminderItem(title: "Buy groceries", dataContext: .personal)
        try await handler.create(item1)
        
        // 2. Create a work reminder
        let item2 = ReminderItem(title: "Finish report", dataContext: .work)
        try await handler.create(item2)
        
        // 3. List personal reminders
        var personal = try await handler.list(context: .personal)
        XCTAssertEqual(personal.count, 1)
        XCTAssertEqual(personal.first?.title, "Buy groceries")
        
        // 4. List work reminders
        var work = try await handler.list(context: .work)
        XCTAssertEqual(work.count, 1)
        XCTAssertEqual(work.first?.title, "Finish report")
        
        // 5. Complete work reminder
        try await handler.complete(id: item2.id)
        
        // 6. Work reminders should now be empty
        work = try await handler.list(context: .work)
        XCTAssertTrue(work.isEmpty)
        
        // 7. Personal reminders should still have 1
        personal = try await handler.list(context: .personal)
        XCTAssertEqual(personal.count, 1)
    }
    
    func testCompleteNonExistentThrows() async throws {
        let handler = RemindersHandler(inMemory: true)
        do {
            try await handler.complete(id: "does-not-exist")
            XCTFail("Expected error, but complete succeeded")
        } catch ReminderError.notFound(let id) {
            XCTAssertEqual(id, "does-not-exist")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
