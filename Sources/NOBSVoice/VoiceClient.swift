/// NOBSVoice — Google Voice API Integration
///
/// Provides OAuth 2.0 token management and REST calls to place / receive calls
/// and send SMS via the Google Voice API. Events are bridged back into the
/// NOBS intent pipeline via `VoiceIntentHandler`.
///
/// Setup:
///   1. Create a Google Cloud project and enable the Google Voice API.
///   2. Create OAuth 2.0 credentials (Desktop / iOS app type).
///   3. Pass credentials to `VoiceClient`; store clientID/clientSecret
///      in the iOS Keychain — never in source files.
///   4. Call `VoiceClient.authorizationURL(redirectURI:)` to start OAuth flow.
///   5. After the redirect, call `VoiceClient.exchange(code:redirectURI:)`.

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import NOBSCore
import NOBSCallKit

// MARK: - VoiceCredentials

/// OAuth2 credentials for the Google Voice API.
/// Store `clientID` and `clientSecret` in the iOS Keychain.
public struct VoiceCredentials: Sendable {
    public let clientID: String
    public let clientSecret: String
    public var accessToken: String?
    public var refreshToken: String?
    public var tokenExpiry: Date?

    public init(clientID: String, clientSecret: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
    }

    /// True when a non-expired access token is present.
    public var isTokenValid: Bool {
        guard let token = accessToken, !token.isEmpty,
              let expiry = tokenExpiry else { return false }
        return expiry > Date()
    }
}

// MARK: - VoiceError

public enum VoiceError: Error, LocalizedError, Sendable {
    case notAuthorized
    case tokenRefreshFailed(String)
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError(String)
    case callFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:               return "Google Voice is not authorized. Complete the OAuth flow first."
        case .tokenRefreshFailed(let r):   return "Token refresh failed: \(r)"
        case .networkError(let e):         return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let code):   return "Google API returned HTTP \(code)"
        case .decodingError(let msg):      return "Failed to decode Google Voice response: \(msg)"
        case .callFailed(let reason):      return "Google Voice call failed: \(reason)"
        }
    }
}

// MARK: - VoiceClient

/// Async client for Google Voice API operations.
public actor VoiceClient {
    private static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    private static let voiceAPIBase  = URL(string: "https://voice.googleapis.com/v1")!
    private static let requiredScope = "https://www.googleapis.com/auth/voice"

    private var credentials: VoiceCredentials
    private let session: URLSession

    public init(credentials: VoiceCredentials) {
        self.credentials = credentials
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Authorization

    /// Returns the OAuth2 authorization URL the user must open to grant access.
    public func authorizationURL(redirectURI: String) -> URL? {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id",     value: credentials.clientID),
            URLQueryItem(name: "redirect_uri",  value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope",         value: Self.requiredScope),
            URLQueryItem(name: "access_type",   value: "offline"),
        ]
        return components?.url
    }

    /// Exchange an authorization code for access + refresh tokens.
    public func exchange(code: String, redirectURI: String) async throws {
        let body: [String: String] = [
            "code":          code,
            "client_id":     credentials.clientID,
            "client_secret": credentials.clientSecret,
            "redirect_uri":  redirectURI,
            "grant_type":    "authorization_code",
        ]
        try await performTokenRequest(body: body)
    }

    /// Refresh an expired access token using the stored refresh token.
    public func refreshAccessToken() async throws {
        guard let refresh = credentials.refreshToken, !refresh.isEmpty else {
            throw VoiceError.notAuthorized
        }
        let body: [String: String] = [
            "refresh_token": refresh,
            "client_id":     credentials.clientID,
            "client_secret": credentials.clientSecret,
            "grant_type":    "refresh_token",
        ]
        try await performTokenRequest(body: body)
    }

    // MARK: - Calls & SMS

    /// Initiate an outbound call via Google Voice.
    /// - Parameters:
    ///   - callerID:    Your Google Voice number (E.164 format, e.g. `+14155552671`).
    ///   - destination: The number to call (E.164 format).
    public func placeCall(from callerID: String, to destination: String) async throws {
        try await ensureValidToken()
        let url = Self.voiceAPIBase.appendingPathComponent("calls")
        var request = authorisedRequest(url: url, method: "POST")
        let body = ["callerIdNumber": callerID, "number": destination]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await perform(request)
        guard (200...299).contains(response.statusCode) else {
            throw VoiceError.invalidResponse(response.statusCode)
        }
    }

    /// Send an SMS via Google Voice.
    public func sendSMS(from callerID: String, to destination: String, message: String) async throws {
        try await ensureValidToken()
        let url = Self.voiceAPIBase.appendingPathComponent("sms/send")
        var request = authorisedRequest(url: url, method: "POST")
        let body: [String: Any] = [
            "callerIdNumber": callerID,
            "number":         destination,
            "message":        message,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await perform(request)
        guard (200...299).contains(response.statusCode) else {
            throw VoiceError.invalidResponse(response.statusCode)
        }
    }

    // MARK: - Private helpers

    private func ensureValidToken() async throws {
        if !credentials.isTokenValid {
            try await refreshAccessToken()
        }
    }

    private func authorisedRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // The bearer token is injected at runtime from Keychain — never hardcoded.
        if let token = credentials.accessToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func performTokenRequest(body: [String: String]) async throws {
        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await perform(request)
        guard (200...299).contains(response.statusCode) else {
            throw VoiceError.tokenRefreshFailed("HTTP \(response.statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VoiceError.decodingError("Token response was not valid JSON")
        }
        credentials.accessToken  = json["access_token"]  as? String
        credentials.refreshToken = json["refresh_token"] as? String ?? credentials.refreshToken
        if let expiresIn = json["expires_in"] as? TimeInterval {
            credentials.tokenExpiry = Date().addingTimeInterval(expiresIn)
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw VoiceError.networkError(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw VoiceError.invalidResponse(0)
        }
        return (data, http)
    }
}

// MARK: - VoiceIntentHandler

/// Bridges the NOBS intent pipeline to Google Voice for outbound calls.
public actor VoiceIntentHandler: IntentHandler {
    private let voiceClient: VoiceClient
    private let callerID: String

    public init(voiceClient: VoiceClient, callerID: String) {
        self.voiceClient = voiceClient
        self.callerID = callerID
    }

    public nonisolated func canHandle(_ intent: AssistantIntent) -> Bool {
        if case .makeCall = intent { return true }
        return false
    }

    public func handle(_ intent: AssistantIntent) async throws -> String {
        guard case .makeCall(let number, let name) = intent else {
            throw VoiceError.callFailed("Unsupported intent")
        }
        try await voiceClient.placeCall(from: callerID, to: number)
        return "Calling \(name ?? number) via Google Voice…"
    }
}
