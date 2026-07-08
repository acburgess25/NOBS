import XCTest
@testable import NOBS

final class OfflineMessageQueueTests: XCTestCase {
    private let queue = OfflineMessageQueue()
    private let queueURL = AppGroupStore.fileURL(AppGroupStore.offlineChatQueueFile)
    private let fixedDate = Date(timeIntervalSince1970: 1_752_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        try queue.clear()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: queueURL)
        try super.tearDownWithError()
    }

    func testLoadReturnsEmptyWhenQueueFileMissing() {
        XCTAssertTrue(queue.load().isEmpty)
    }

    func testEnqueueAppendsMessageInOrder() throws {
        let first = QueuedChatMessage(text: "First offline message", queuedAt: fixedDate)
        let second = QueuedChatMessage(text: "Second offline message", queuedAt: fixedDate)

        try queue.enqueue(first)
        try queue.enqueue(second)

        let loaded = queue.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, first.id)
        XCTAssertEqual(loaded[0].text, first.text)
        XCTAssertEqual(loaded[1].id, second.id)
        XCTAssertEqual(loaded[1].text, second.text)
    }

    func testDequeueRemovesMessageByID() throws {
        let first = QueuedChatMessage(text: "First", queuedAt: fixedDate)
        let second = QueuedChatMessage(text: "Second", queuedAt: fixedDate)
        try queue.enqueue(first)
        try queue.enqueue(second)

        try queue.remove(id: first.id)

        let loaded = queue.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, second.id)
        XCTAssertEqual(loaded[0].text, second.text)
    }

    func testPersistenceRoundTripSurvivesNewQueueInstance() throws {
        let message = QueuedChatMessage(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            text: "Held for Tank",
            queuedAt: fixedDate
        )
        try queue.enqueue(message)

        let reloaded = OfflineMessageQueue().load()

        XCTAssertEqual(reloaded, [message])
    }
}
