import XCTest
@testable import NOBSiMessage
import NOBSCore
import NOBSDatabase

final class NOBSiMessageTests: XCTestCase {

    // MARK: - composeURL

    func testComposeURLUsesQuestionMarkNotAmpersand() {
        let url = iMessageHandler.composeURL(to: "+14155551234", body: "Hello")
        XCTAssertNotNil(url)
        // The first separator after the recipient must be `?`, not `&`
        XCTAssertTrue(url!.absoluteString.contains("?body="), "Expected ?body= but got: \(url!.absoluteString)")
        XCTAssertFalse(url!.absoluteString.contains("&body="))
    }

    func testComposeURLSchemeIsSMS() {
        let url = iMessageHandler.composeURL(to: "+14155551234", body: "Hi")
        XCTAssertEqual(url?.scheme, "sms")
    }

    func testComposeURLEncodesSpacesInBody() {
        let url = iMessageHandler.composeURL(to: "+14155551234", body: "Hello World")
        XCTAssertNotNil(url)
        XCTAssertFalse(url!.absoluteString.contains(" "), "URL must not contain unencoded spaces")
    }

    func testComposeURLReturnsNilForEmptyRecipient() {
        let url = iMessageHandler.composeURL(to: "", body: "Hi")
        XCTAssertNil(url)
    }

    func testComposeURLIncludesRecipient() {
        let url = iMessageHandler.composeURL(to: "+14155551234", body: "Hey")
        XCTAssertTrue(url!.absoluteString.contains("14155551234"))
    }

    // MARK: - iMessageHandler intent routing

    func testHandlerAcceptsSendMessage() {
        let db = NOBSDatabase.shared
        try? db.setup(storageMode: .localOnly, inMemory: true)
        let handler = iMessageHandler(dataContext: .personal, database: db)
        XCTAssertTrue(handler.canHandle(.sendMessage(to: "Alice", body: "Hey")))
    }

    func testHandlerAcceptsReadMessages() {
        let db = NOBSDatabase.shared
        try? db.setup(storageMode: .localOnly, inMemory: true)
        let handler = iMessageHandler(dataContext: .personal, database: db)
        XCTAssertTrue(handler.canHandle(.readMessages(from: "Alice")))
    }

    func testHandlerRejectsUnrelatedIntent() {
        let db = NOBSDatabase.shared
        try? db.setup(storageMode: .localOnly, inMemory: true)
        let handler = iMessageHandler(dataContext: .personal, database: db)
        XCTAssertFalse(handler.canHandle(.makeCall(phoneNumber: "555", contactName: nil)))
        XCTAssertFalse(handler.canHandle(.listReminders(context: .personal)))
    }

    // MARK: - MessageRecord

    func testMessageRecordDefaults() {
        let record = MessageRecord(sender: "Bob", body: "Hello")
        XCTAssertFalse(record.id.uuidString.isEmpty)
        XCTAssertEqual(record.sender, "Bob")
        XCTAssertEqual(record.body, "Hello")
        XCTAssertFalse(record.isOutbound)
        XCTAssertEqual(record.dataContext, .personal)
    }

    func testOutboundMessageRecord() {
        let record = MessageRecord(sender: "Alice", body: "Hi!", isOutbound: true)
        XCTAssertTrue(record.isOutbound)
    }
}
