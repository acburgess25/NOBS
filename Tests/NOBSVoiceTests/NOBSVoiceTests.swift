import XCTest
@testable import NOBSVoice
import NOBSCore
import NOBSSecurity

final class NOBSVoiceTests: XCTestCase {

    // MARK: - VoiceCredentials

    func testTokenValidWhenPresentAndNotExpired() {
        var creds = VoiceCredentials(clientID: "id", clientSecret: "secret")
        creds.accessToken  = "tok"
        creds.tokenExpiry  = Date().addingTimeInterval(3600)
        XCTAssertTrue(creds.isTokenValid)
    }

    func testTokenInvalidWhenExpired() {
        var creds = VoiceCredentials(clientID: "id", clientSecret: "secret")
        creds.accessToken = "tok"
        creds.tokenExpiry = Date().addingTimeInterval(-60)
        XCTAssertFalse(creds.isTokenValid)
    }

    func testTokenInvalidWhenMissing() {
        let creds = VoiceCredentials(clientID: "id", clientSecret: "secret")
        XCTAssertFalse(creds.isTokenValid)
    }

    func testTokenInvalidWhenEmpty() {
        var creds = VoiceCredentials(clientID: "id", clientSecret: "secret")
        creds.accessToken = ""
        creds.tokenExpiry = Date().addingTimeInterval(3600)
        XCTAssertFalse(creds.isTokenValid)
    }

    // MARK: - VoiceClient authorization URL

    func testAuthorizationURLContainsClientID() async {
        let creds  = VoiceCredentials(clientID: "my-client-id", clientSecret: "secret")
        let client = VoiceClient(credentials: creds, tokenStore: nil)
        let state  = "random-csrf-state-123"
        let url    = await client.authorizationURL(redirectURI: "com.nobs://oauth", state: state)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("my-client-id"))
    }

    func testAuthorizationURLContainsScope() async {
        let creds  = VoiceCredentials(clientID: "id", clientSecret: "secret")
        let client = VoiceClient(credentials: creds, tokenStore: nil)
        let url    = await client.authorizationURL(redirectURI: "com.nobs://oauth", state: "state-abc")
        XCTAssertTrue(url!.absoluteString.contains("voice"))
    }

    func testAuthorizationURLUsesOAuthEndpoint() async {
        let creds  = VoiceCredentials(clientID: "id", clientSecret: "secret")
        let client = VoiceClient(credentials: creds, tokenStore: nil)
        let url    = await client.authorizationURL(redirectURI: "com.nobs://oauth", state: "state-abc")
        XCTAssertTrue(url!.host == "accounts.google.com")
    }

    func testAuthorizationURLContainsState() async {
        let creds  = VoiceCredentials(clientID: "id", clientSecret: "secret")
        let client = VoiceClient(credentials: creds)
        let state  = "my-unique-csrf-token"
        let url    = await client.authorizationURL(redirectURI: "com.nobs://oauth", state: state)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains(state),
                      "Authorization URL must include the state parameter for CSRF protection")
    }

    // MARK: - Refresh without token throws

    func testRefreshWithoutRefreshTokenThrows() async {
        let creds  = VoiceCredentials(clientID: "id", clientSecret: "secret")
        let client = VoiceClient(credentials: creds, tokenStore: nil)
        do {
            try await client.refreshAccessToken()
            XCTFail("Expected VoiceError.notAuthorized")
        } catch VoiceError.notAuthorized {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - VoiceIntentHandler

    func testVoiceIntentHandlerHandlesMakeCall() {
        let creds   = VoiceCredentials(clientID: "id", clientSecret: "secret")
        let client  = VoiceClient(credentials: creds, tokenStore: nil)
        let handler = VoiceIntentHandler(voiceClient: client, callerID: "+14155551234")
        XCTAssertTrue(handler.canHandle(.makeCall(phoneNumber: "+19995550001", contactName: nil)))
    }

    func testVoiceIntentHandlerDoesNotHandleOtherIntents() {
        let creds   = VoiceCredentials(clientID: "id", clientSecret: "secret")
        let client  = VoiceClient(credentials: creds, tokenStore: nil)
        let handler = VoiceIntentHandler(voiceClient: client, callerID: "+14155551234")
        XCTAssertFalse(handler.canHandle(.sendMessage(to: "bob", body: "hi")))
        XCTAssertFalse(handler.canHandle(.listReminders(context: .personal)))
    }

    // MARK: - VoiceTokenStore

    func testVoiceTokenStoreRoundTrip() throws {
        let keychain = KeychainStore(service: "com.nobs.test.voice.\(UUID().uuidString)")
        let store = VoiceTokenStore(keychain: keychain)

        var creds = VoiceCredentials(clientID: "test-id", clientSecret: "test-secret")
        creds.accessToken  = "access-123"
        creds.refreshToken = "refresh-456"
        creds.tokenExpiry  = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(from: creds)

        var loaded = VoiceCredentials(clientID: "test-id", clientSecret: "test-secret")
        try store.load(into: &loaded)

        XCTAssertEqual(loaded.accessToken,  "access-123")
        XCTAssertEqual(loaded.refreshToken, "refresh-456")
        let loadedExpiry = loaded.tokenExpiry?.timeIntervalSince1970 ?? 0
        let savedExpiry  = creds.tokenExpiry?.timeIntervalSince1970  ?? 0
        XCTAssertEqual(loadedExpiry, savedExpiry, accuracy: 1.0)
        try store.clear()
    }

    func testVoiceTokenStoreClear() throws {
        let keychain = KeychainStore(service: "com.nobs.test.voice.\(UUID().uuidString)")
        let store = VoiceTokenStore(keychain: keychain)

        var creds = VoiceCredentials(clientID: "test-id", clientSecret: "test-secret")
        creds.accessToken  = "tok"
        creds.refreshToken = "ref"
        try store.save(from: creds)
        try store.clear()

        var empty = VoiceCredentials(clientID: "test-id", clientSecret: "test-secret")
        try store.load(into: &empty)
        XCTAssertNil(empty.accessToken)
        XCTAssertNil(empty.refreshToken)
        XCTAssertNil(empty.tokenExpiry)
    }

    func testVoiceTokenStoreDoesNotOverwriteClientSecret() throws {
        let keychain = KeychainStore(service: "com.nobs.test.voice.\(UUID().uuidString)")
        let store = VoiceTokenStore(keychain: keychain)

        var creds = VoiceCredentials(clientID: "test-id", clientSecret: "test-secret")
        creds.accessToken = "tok"
        try store.save(from: creds)

        var loaded = VoiceCredentials(clientID: "other-id", clientSecret: "other-secret")
        try store.load(into: &loaded)

        // clientID and clientSecret must NOT be modified by load
        XCTAssertEqual(loaded.clientID,     "other-id")
        XCTAssertEqual(loaded.clientSecret, "other-secret")
        try store.clear()
    }

    // MARK: - E.164 validation

    func testValidE164Numbers() {
        XCTAssertTrue(VoiceClient.isValidE164("+14155551234"))
        XCTAssertTrue(VoiceClient.isValidE164("+447911123456"))
        XCTAssertTrue(VoiceClient.isValidE164("+1234567"))    // 7-digit minimum
    }

    func testInvalidE164Numbers() {
        XCTAssertFalse(VoiceClient.isValidE164("14155551234"),   "Missing leading +")
        XCTAssertFalse(VoiceClient.isValidE164("+1 415 5551234"), "Spaces not allowed")
        XCTAssertFalse(VoiceClient.isValidE164("+1-415-555-1234"), "Dashes not allowed")
        XCTAssertFalse(VoiceClient.isValidE164("+123456"),       "Too short (< 7 digits)")
        XCTAssertFalse(VoiceClient.isValidE164(""),               "Empty string")
        XCTAssertFalse(VoiceClient.isValidE164("+"))              // Only + sign
    }
}
