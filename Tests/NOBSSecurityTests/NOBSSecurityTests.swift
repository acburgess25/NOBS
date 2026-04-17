import XCTest
@testable import NOBSSecurity

final class NOBSSecurityTests: XCTestCase {

    // MARK: - KeychainStore — basic round-trip

    func testSaveAndLoadValue() throws {
        let store = KeychainStore(service: "com.nobs.test.\(UUID().uuidString)")
        try store.save("secret-value", forKey: "myKey")
        let loaded = try store.load(forKey: "myKey")
        XCTAssertEqual(loaded, "secret-value")
        try store.deleteAll()
    }

    func testLoadMissingKeyReturnsNil() throws {
        let store = KeychainStore(service: "com.nobs.test.\(UUID().uuidString)")
        let loaded = try store.load(forKey: "does-not-exist")
        XCTAssertNil(loaded)
    }

    func testOverwriteExistingValue() throws {
        let store = KeychainStore(service: "com.nobs.test.\(UUID().uuidString)")
        try store.save("first", forKey: "token")
        try store.save("second", forKey: "token")
        let loaded = try store.load(forKey: "token")
        XCTAssertEqual(loaded, "second")
        try store.deleteAll()
    }

    func testDeleteKey() throws {
        let store = KeychainStore(service: "com.nobs.test.\(UUID().uuidString)")
        try store.save("to-delete", forKey: "temp")
        try store.delete(forKey: "temp")
        let loaded = try store.load(forKey: "temp")
        XCTAssertNil(loaded)
    }

    func testDeleteNonExistentKeyIsNoop() throws {
        let store = KeychainStore(service: "com.nobs.test.\(UUID().uuidString)")
        XCTAssertNoThrow(try store.delete(forKey: "ghost"))
    }

    func testDeleteAll() throws {
        let store = KeychainStore(service: "com.nobs.test.\(UUID().uuidString)")
        try store.save("a", forKey: "key1")
        try store.save("b", forKey: "key2")
        try store.deleteAll()
        XCTAssertNil(try store.load(forKey: "key1"))
        XCTAssertNil(try store.load(forKey: "key2"))
    }

    func testSeparateServicesDoNotCollide() throws {
        let storeA = KeychainStore(service: "com.nobs.test.A.\(UUID().uuidString)")
        let storeB = KeychainStore(service: "com.nobs.test.B.\(UUID().uuidString)")
        try storeA.save("value-A", forKey: "shared-key")
        try storeB.save("value-B", forKey: "shared-key")
        XCTAssertEqual(try storeA.load(forKey: "shared-key"), "value-A")
        XCTAssertEqual(try storeB.load(forKey: "shared-key"), "value-B")
        try storeA.deleteAll()
        try storeB.deleteAll()
    }

    // MARK: - LocalAuthGate

    func testLocalAuthGateInvalidateResetsState() async {
        // On the real LocalAuthentication platform, `invalidate()` clears cached
        // auth state so `isAuthenticated` must return false until re-authenticated.
        // On Linux the stub always succeeds and this assertion is not applicable.
        #if canImport(LocalAuthentication)
        let gate = LocalAuthGate()
        await gate.invalidate()
        let authenticated = await gate.isAuthenticated
        XCTAssertFalse(authenticated)
        #endif
    }

    func testLocalAuthGateIsAuthenticatedByDefaultOnStub() async {
        // On platforms without LocalAuthentication the stub always reports
        // isAuthenticated == true (no OS dialog is possible).
        #if !canImport(LocalAuthentication)
        let gate = LocalAuthGate()
        let authenticated = await gate.isAuthenticated
        XCTAssertTrue(authenticated)
        #endif
    }

    func testLocalAuthGateRequireAuthDoesNotThrowOnStub() async {
        #if !canImport(LocalAuthentication)
        let gate = LocalAuthGate()
        await XCTAssertNoThrowAsync(try await gate.requireAuthentication())
        #endif
    }
}

// MARK: - Async XCTest helper

func XCTAssertNoThrowAsync(
    _ expression: @autoclosure () async throws -> Void,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
    } catch {
        XCTFail("Expected no throw, got \(error). \(message)", file: file, line: line)
    }
}
