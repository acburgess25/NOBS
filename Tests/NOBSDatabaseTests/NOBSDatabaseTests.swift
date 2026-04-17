import XCTest
@testable import NOBSDatabase
import NOBSCore

final class NOBSDatabaseTests: XCTestCase {

    var database: NOBSDatabase!

    override func setUpWithError() throws {
        database = NOBSDatabase.shared
        try database.setup(storageMode: .localOnly, inMemory: true)
    }

    // MARK: - Setup

    func testSetupDoesNotThrow() throws {
        XCTAssertNotNil(database)
    }

    func testDefaultStorageModeIsLocalOnly() throws {
        XCTAssertFalse(database.storageMode.syncsToCloud)
        XCTAssertEqual(database.storageMode.displayName, "On-Device Only")
    }

    // MARK: - StorageMode

    func testLocalOnlyDoesNotSyncToCloud() {
        let mode = StorageMode.localOnly
        XCTAssertFalse(mode.syncsToCloud)
    }

    func testICloudSyncsToCloud() {
        let mode = StorageMode.iCloud(containerID: "iCloud.com.example.nobs")
        XCTAssertTrue(mode.syncsToCloud)
    }

    func testLocalOnlyDisplayName() {
        XCTAssertEqual(StorageMode.localOnly.displayName, "On-Device Only")
    }

    func testICloudDisplayName() {
        let mode = StorageMode.iCloud(containerID: "iCloud.com.example.nobs")
        XCTAssertEqual(mode.displayName, "iCloud Sync")
    }

    func testStorageModeAfterSetupIsRecorded() throws {
        let db = NOBSDatabase.shared
        try db.setup(storageMode: .localOnly, inMemory: true)
        XCTAssertFalse(db.storageMode.syncsToCloud)
    }

    // MARK: - iCloudDisclosure

    func testUserFacingWarningMentionsICloud() {
        XCTAssertTrue(iCloudDisclosure.userFacingWarning.contains("iCloud"))
    }

    func testUserFacingWarningMentionsPrivacy() {
        let warning = iCloudDisclosure.userFacingWarning.lowercased()
        XCTAssertTrue(warning.contains("privacy") || warning.contains("server"))
    }

    func testUserFacingWarningIsOffByDefault() {
        XCTAssertTrue(iCloudDisclosure.userFacingWarning.contains("OFF by default"))
    }

    func testFullExplanationContainsApplePrivacyURL() {
        XCTAssertTrue(iCloudDisclosure.fullExplanation.contains("apple.com"))
    }

    func testFullExplanationMentionsBothContexts() {
        let text = iCloudDisclosure.fullExplanation
        XCTAssertTrue(text.contains("Work") || text.contains("Personal"))
    }

    func testStatusLineLocalOnly() {
        let line = iCloudDisclosure.statusLine(for: .localOnly)
        XCTAssertTrue(line.contains("never leaves"))
    }

    func testStatusLineICloud() {
        let id   = "iCloud.com.example.nobs"
        let line = iCloudDisclosure.statusLine(for: .iCloud(containerID: id))
        XCTAssertTrue(line.contains("iCloud"))
        XCTAssertTrue(line.contains(id))
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
        XCTAssertEqual(try personal.fetchAll().count, 1)
        XCTAssertEqual(try work.fetchAll().count,     1)
        XCTAssertEqual(try personal.fetchAll().first?.content, "Personal note")
        XCTAssertEqual(try work.fetchAll().first?.content,     "Work note")
    }

    // MARK: - TaskRepository

    func testCreateAndFetchTask() throws {
        let repo = TaskRepository(context: .work, database: database)
        let task = try repo.create(title: "Send quarterly report")
        XCTAssertEqual(task.title, "Send quarterly report")
        XCTAssertFalse(task.isCompleted)
        XCTAssertEqual(try repo.fetchPending().count, 1)
    }

    func testCompleteTask() throws {
        let repo = TaskRepository(context: .work, database: database)
        let task = try repo.create(title: "Review PR")
        try repo.complete(id: task.id)
        XCTAssertEqual(try repo.fetchPending().count, 0)
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

    // MARK: - DatabaseError

    func testDatabaseErrorDescription() {
        let error = DatabaseError.notSetUp
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("setup()"))
    }
}
