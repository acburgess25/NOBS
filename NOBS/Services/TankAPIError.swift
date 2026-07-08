import Foundation

enum TankAPIError: Error, LocalizedError, Sendable {
    case notConfigured
    case network(URLError)
    case httpStatus(Int, bodySnippet: String)
    case decoding(Error)

    var errorDescription: String? { userFacingMessage }

    var userFacingMessage: String {
        switch self {
        case .notConfigured:
            return "Tank address or device token is not configured."
        case .network(let urlError):
            return Self.message(for: urlError)
        case .httpStatus(let code, let snippet):
            switch code {
            case 401:
                return "Tank rejected the device token (401). Re-pair in Privacy or scan the Tank QR code."
            case 403:
                return "Tank denied access (403)."
            case 404:
                return "Tank endpoint was not found (404)."
            default:
                if snippet.isEmpty {
                    return "Tank returned HTTP \(code)."
                }
                return "Tank returned HTTP \(code): \(snippet)"
            }
        case .decoding:
            return "Tank returned data NOBS could not read."
        }
    }

    var isConnectivityFailure: Bool {
        switch self {
        case .notConfigured:
            return false
        case .network(let urlError):
            return Self.isConnectivity(urlError)
        case .httpStatus(let code, _):
            return code >= 500
        case .decoding:
            return false
        }
    }

    var isAuthenticationFailure: Bool {
        if case .httpStatus(401, _) = self { return true }
        if case .network(let urlError) = self, urlError.code == .userAuthenticationRequired {
            return true
        }
        return false
    }

    static func bodySnippet(from data: Data, limit: Int = 160) -> String {
        guard !data.isEmpty else { return "" }
        let text = String(data: data.prefix(limit), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return String(text.prefix(limit))
    }

    static func map(_ error: Error) -> TankAPIError {
        if let apiError = error as? TankAPIError { return apiError }
        if let urlError = error as? URLError { return .network(urlError) }
        return .network(URLError(.unknown))
    }

    private static func message(for error: URLError) -> String {
        switch error.code {
        case .timedOut:
            return "Connection to Tank timed out."
        case .cannotFindHost, .dnsLookupFailed:
            return "Could not resolve the Tank address (DNS). Try your Tank IP in Privacy."
        case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
            return "Tank is unreachable on this network."
        case .userAuthenticationRequired:
            return "Tank needs a valid device token."
        default:
            return error.localizedDescription
        }
    }

    private static func isConnectivity(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost,
             .networkConnectionLost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}
