import Foundation
import Security
import CryptoKit
import NOBSSecurity
import NOBSDatabase

@MainActor
class APIClient: ObservableObject {
    @Published var isAuthenticated = false
    @Published var username = "" {
        didSet {
            NOBSDatabase.shared.activeUsername = username
        }
    }

    private let baseURL = URL(string: "https://nobsdash.com/api/v1")!
    private let keychain = KeychainStore(service: "com.nobsdash.nobs")
    private let tokenKey = "auth_token"
    private let usernameKey = "auth_username"

    private let session: URLSession
    private let pinnedHash: String? = "fgJeP9v7tHakiFA4c+oWl4JWKqS22GdlAjOf3urMi8Q="

    private var token: String? {
        didSet { isAuthenticated = token != nil }
    }

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        let delegate = PinningDelegate(pinnedHash: pinnedHash)
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        loadFromKeychain()
    }

    func login(username: String, password: String) async throws {
        let body = ["username": username, "password": password]
        let data = try await request(path: "/auth/login", method: "POST", body: body)
        let res = try JSONDecoder().decode(LoginResponse.self, from: data)
        self.token = res.token
        self.username = res.username
        saveToKeychain(token: res.token, username: res.username)
    }

    func register(username: String, password: String) async throws {
        let body = ["username": username, "password": password]
        let _ = try await request(path: "/auth/register", method: "POST", body: body)
    }

    func syncAgencySubscription(tier: AgencyTier) async throws {
        let body: [String: String] = ["tier": tier.rawValue.components(separatedBy: ".").last ?? tier.rawValue]
        _ = try await request(path: "/agency/subscription", method: "POST", body: body)
    }

    func logout() {
        token = nil
        username = ""
        deleteFromKeychain()
        wipeLocalData()
        Task { try? await request(path: "/auth/logout", method: "POST") }
    }

    private func wipeLocalData() {
        // Clear in-memory state on logout
        // Core Data protected files stay on-device with NSFileProtectionComplete
    }

    private func request(path: String, method: String, body: Any? = nil) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            req.setValue(token, forHTTPHeaderField: "x-nobs-token")
        }
        if let body = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if http.statusCode == 401 {
            logout()
            throw APIError.unauthorized
        }
        if http.statusCode >= 400 {
            let msg = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.detail ?? "unknown error"
            throw APIError.serverError(msg)
        }
        return data
    }

    private func saveToKeychain(token: String, username: String) {
        try? keychain.save(token, forKey: tokenKey)
        try? keychain.save(username, forKey: usernameKey)
    }

    private func loadFromKeychain() {
        if let t = try? keychain.load(forKey: tokenKey) {
            token = t
        }
        if let u = try? keychain.load(forKey: usernameKey) {
            username = u
        }
    }

    private func deleteFromKeychain() {
        try? keychain.delete(forKey: tokenKey)
        try? keychain.delete(forKey: usernameKey)
    }
}

private class PinningDelegate: NSObject, URLSessionDelegate {
    let pinnedHash: String?

    init(pinnedHash: String?) {
        self.pinnedHash = pinnedHash
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let hash = pinnedHash else {
            return (.performDefaultHandling, nil)
        }

        var error: CFError?
        let valid = SecTrustEvaluateWithError(trust, &error)
        guard valid else {
            return (.cancelAuthenticationChallenge, nil)
        }

        guard let certChain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let serverCert = certChain.first else {
            return (.cancelAuthenticationChallenge, nil)
        }

        guard let serverKey = SecCertificateCopyKey(serverCert),
              let serverKeyData = SecKeyCopyExternalRepresentation(serverKey, nil) as Data? else {
            return (.cancelAuthenticationChallenge, nil)
        }

        let b64 = Data(SHA256.hash(data: serverKeyData)).base64EncodedString()

        guard b64 == hash else {
            return (.cancelAuthenticationChallenge, nil)
        }

        return (.useCredential, URLCredential(trust: trust))
    }
}

struct LoginResponse: Codable {
    let token: String
    let username: String
}

struct ErrorResponse: Codable {
    let detail: String
}

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .unauthorized: return "Session expired. Please log in again."
        case .serverError(let msg): return msg
        }
    }
}
