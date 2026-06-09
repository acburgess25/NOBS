/// NOBSCore — AppwriteClient
///
/// Minimal REST client for Appwrite Cloud. No SDK dependency — just URLSession.
/// Handles only what the MVP needs: anonymous session + storage buckets.
///
/// Endpoints used:
///   POST /account/sessions/anonymous     — create anonymous session
///   POST /storage/buckets/<id>/files     — upload ciphertext (multipart)
///   GET  /storage/buckets/<id>/files     — list user's files
///   GET  /storage/buckets/<id>/files/<id>/view  — download ciphertext
///   DEL  /storage/buckets/<id>/files/<id>       — delete
///
/// Auth: cookie-based session after anonymous login (URLSession default
/// HTTPCookieStorage handles it). Optional API key for server-only calls.

import Foundation

public struct AppwriteConfig: Sendable {
    public let endpoint: URL
    public let projectId: String

    public init(endpoint: URL, projectId: String) {
        self.endpoint = endpoint
        self.projectId = projectId
    }

    /// Production config for the NOBS Apple product.
    public static let production = AppwriteConfig(
        endpoint: URL(string: "https://sfo.cloud.appwrite.io/v1")!,
        projectId: "6a1585e80002d494c9b2"
    )
}

public enum AppwriteError: Error, LocalizedError {
    case http(Int, String)
    case decode(String)
    case noSession

    public var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "Appwrite HTTP \(code): \(body)"
        case .decode(let msg): return "Appwrite decode: \(msg)"
        case .noSession: return "No active Appwrite session — call ensureSession() first."
        }
    }
}

public struct AppwriteFile: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let size: Int
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case name
        case size = "sizeOriginal"
        case createdAt = "$createdAt"
    }
}

public actor AppwriteClient {
    public let config: AppwriteConfig
    private let session: URLSession

    public init(config: AppwriteConfig = .production) {
        self.config = config
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieAcceptPolicy = .always
        cfg.httpShouldSetCookies = true
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Session

    public func ensureSession() async throws {
        // Cheap check: try to fetch account; if 401, create anonymous session.
        var req = makeRequest(path: "/account", method: "GET")
        do {
            _ = try await send(req)
            return
        } catch AppwriteError.http(let code, _) where code == 401 {
            req = makeRequest(path: "/account/sessions/anonymous", method: "POST")
            _ = try await send(req)
        }
    }

    // MARK: - Storage

    public func uploadFile(bucketId: String, fileId: String, name: String, data: Data) async throws -> AppwriteFile {
        let boundary = "----nobs-\(UUID().uuidString)"
        var req = makeRequest(path: "/storage/buckets/\(bucketId)/files", method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func part(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        part("fileId", fileId)
        // permissions: read/update/delete only by current user
        part("permissions[]", "read(\"users\")")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        let respData = try await send(req)
        return try decode(AppwriteFile.self, from: respData)
    }

    public func listFiles(bucketId: String, limit: Int = 100) async throws -> [AppwriteFile] {
        let req = makeRequest(path: "/storage/buckets/\(bucketId)/files?queries[]=limit(\(limit))", method: "GET")
        let respData = try await send(req)
        struct ListResponse: Decodable { let files: [AppwriteFile] }
        return try decode(ListResponse.self, from: respData).files
    }

    public func downloadFile(bucketId: String, fileId: String) async throws -> Data {
        let req = makeRequest(path: "/storage/buckets/\(bucketId)/files/\(fileId)/view", method: "GET")
        return try await send(req)
    }

    public func deleteFile(bucketId: String, fileId: String) async throws {
        let req = makeRequest(path: "/storage/buckets/\(bucketId)/files/\(fileId)", method: "DELETE")
        _ = try await send(req)
    }

    // MARK: - Internals

    private func makeRequest(path: String, method: String) -> URLRequest {
        var req = URLRequest(url: config.endpoint.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path))
        req.httpMethod = method
        req.setValue(config.projectId, forHTTPHeaderField: "X-Appwrite-Project")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("NOBS-iOS/1.0", forHTTPHeaderField: "User-Agent")
        return req
    }

    private func send(_ req: URLRequest) async throws -> Data {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AppwriteError.http(0, "non-http response")
        }
        if (200..<300).contains(http.statusCode) { return data }
        let body = String(data: data, encoding: .utf8) ?? ""
        throw AppwriteError.http(http.statusCode, body)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw AppwriteError.decode(String(describing: error)) }
    }
}
