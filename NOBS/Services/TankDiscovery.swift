import Foundation
import Network

/// Finds a private Tank without exposing LAN addresses or device tokens in the UI.
actor TankDiscovery {
    enum DiscoveryError: LocalizedError {
        case notFound
        case unavailable(String)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "NOBS couldn't find your Tank nearby."
            case .unavailable(let message):
                return message
            }
        }
    }

    func findFirstTank(timeout: TimeInterval = 6) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let browser = NWBrowser(for: .bonjour(type: "_nobs._tcp", domain: nil), using: .tcp)
            let completion = DiscoveryCompletion(continuation: continuation, browser: browser)

            browser.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    completion.finish(.failure(.unavailable(error.localizedDescription)))
                }
            }
            browser.browseResultsChangedHandler = { results, _ in
                guard let result = results.first else { return }
                completion.resolve(result.endpoint)
            }
            browser.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                completion.finish(.failure(.notFound))
            }
        }
    }
}

private final class DiscoveryCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var didFinish = false
    private let continuation: CheckedContinuation<URL, Error>
    private let browser: NWBrowser

    init(continuation: CheckedContinuation<URL, Error>, browser: NWBrowser) {
        self.continuation = continuation
        self.browser = browser
    }

    func resolve(_ endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                guard case let .hostPort(host, port)? = connection.currentPath?.remoteEndpoint,
                      let url = URL(string: "http://\(host.debugDescription):\(port.rawValue)")
                else {
                    self.finish(.failure(TankDiscovery.DiscoveryError.notFound))
                    return
                }
                connection.cancel()
                self.finish(.success(url))
            case .failed(let error):
                self.finish(.failure(.unavailable(error.localizedDescription)))
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    func finish(_ result: Result<URL, TankDiscovery.DiscoveryError>) {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return }
        didFinish = true
        browser.cancel()
        continuation.resume(with: result)
    }
}
