import XCTest
@testable import NOBSDatabase
import NOBSCore

final class NOBSDatabaseTests: XCTestCase {

    var database: NOBSDatabase!

    override func setUpWithError() throws {
        database = NOBSDatabase.shared
        try database.setup(inMemory: true)
    }

    // MARK: - Setup

    func testSetupDoesNotThrow() throws {
        // If we get here without throwing, setup succeeded.
        XCTAssertNotNil(database)
    }

    // MARK: - MemoryRepository

    func testSaveAndFetchMemory() throws {
        let repo = MemoryRepository(context: .personal, database: database)
        let saved = try repo.save(content: "My favourite coffee is espresso.", tags: ["food"])
        XCTAssertFalse(saved.id.uuidString.isEmpty)

        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.content, "My favourite coffee is espresso.")
    }

    func testSearchMemory() throws {
        let repo = MemoryRepository(context: .personal, database: database)
        try repo.save(content: "Alice lives in Seattle")
        try repo.save(content: "Bob lives in Portland")

        let results = try repo.search(query: "Seattle")
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first!.content.contains("Alice"))
    }

    func testSearchIsCaseInsensitive() throws {
        let repo = MemoryRepository(context: .personal, database: database)
        try repo.save(content: "NOBS is a great assistant")

        let results = try repo.search(query: "nobs")
        XCTAssertEqual(results.count, 1)
    }

    func testSeparateReposAreSeparate() throws {
        let personal = MemoryRepository(context: .personal, database: database)
        let work     = MemoryRepository(context: .work,     database: database)

        try personal.save(content: "Personal note")
        try work.save(content: "Work note")

        let personalAll = try personal.fetchAll()
        let workAll     = try work.fetchAll()

        // Each repo maintains its own store — counts should be 1 each.
        XCTAssertEqual(personalAll.count, 1)
        XCTAssertEqual(workAll.count,     1)
        XCTAssertEqual(personalAll.first?.content, "Personal note")
        XCTAssertEqual(workAll.first?.content,     "Work note")
    }

    // MARK: - TaskRepository

    func testCreateAndFetchTask() throws {
        let repo = TaskRepository(context: .work, database: database)
        let task = try repo.create(title: "Send quarterly report")
        XCTAssertEqual(task.title, "Send quarterly report")
        XCTAssertFalse(task.isCompleted)

        let pending = try repo.fetchPending()
        XCTAssertEqual(pending.count, 1)
    }

    func testCompleteTask() throws {
        let repo = TaskRepository(context: .work, database: database)
        let task = try repo.create(title: "Review PR")
        try repo.complete(id: task.id)

        let pending = try repo.fetchPending()
        XCTAssertEqual(pending.count, 0)
    }

    func testCompletingNonExistentTaskIsNoop() throws {
        let repo = TaskRepository(context: .personal, database: database)
        XCTAssertNoThrow(try repo.complete(id: UUID()))
    }

    func testTaskWithDueDate() throws {
        let due  = Date().addingTimeInterval(3600)
        let repo = TaskRepository(context: .personal, database: database)
        let task = try repo.create(title: "Doctor appointment", dueDate: due)
        XCTAssertNotNil(task.dueDate)
        XCTAssertEqual(task.dueDate!.timeIntervalSince1970, due.timeIntervalSince1970, accuracy: 1)
    }
}
