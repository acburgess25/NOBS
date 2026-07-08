import Foundation
import Network

struct DiscoveredTank: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let url: URL
}

@MainActor
final class TankDiscoveryService {
    static let serviceType = "_nobs._tcp"

    private var browser: NWBrowser?
    private var resolvers: [String: NetServiceResolver] = [:]
    private var collected: [String: DiscoveredTank] = [:]
    private var continuation: CheckedContinuation<[DiscoveredTank], Never>?
    private var browseTimeoutTask: Task<Void, Never>?

    func discover(timeout: TimeInterval = 5) async -> [DiscoveredTank] {
        stopBrowsing()
        collected = [:]
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            startBrowsing()
            browseTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                guard let self, !Task.isCancelled else { return }
                self.finishBrowsing()
            }
        }
    }

    func stopBrowsing() {
        browseTimeoutTask?.cancel()
        browseTimeoutTask = nil
        browser?.cancel()
        browser = nil
        resolvers.values.forEach { $0.cancel() }
        resolvers = [:]
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: sortedResults())
        }
    }

    private func startBrowsing() {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjour(type: Self.serviceType, domain: nil)
        let browser = NWBrowser(for: descriptor, using: parameters)
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                if case .failed = state {
                    self.finishBrowsing()
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handle(results: results)
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    private func handle(results: Set<NWBrowser.Result>) {
        for result in results {
            guard case let .service(name, type, domain, _) = result.endpoint else { continue }
            let key = "\(name).\(type).\(domain)"
            guard resolvers[key] == nil else { continue }
            let resolver = NetServiceResolver(name: name, type: type, domain: domain) { [weak self] tank in
                Task { @MainActor in
                    guard let self, let tank else { return }
                    self.collected[tank.id] = tank
                }
            }
            resolvers[key] = resolver
            resolver.resolve()
        }
    }

    private func finishBrowsing() {
        browseTimeoutTask?.cancel()
        browseTimeoutTask = nil
        browser?.cancel()
        browser = nil
        resolvers.values.forEach { $0.cancel() }
        resolvers = [:]
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: sortedResults())
    }

    private func sortedResults() -> [DiscoveredTank] {
        collected.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private final class NetServiceResolver: NSObject, NetServiceDelegate {
    private let netService: NetService
    private let onResolved: (DiscoveredTank?) -> Void
    private var finished = false

    init(name: String, type: String, domain: String, onResolved: @escaping (DiscoveredTank?) -> Void) {
        self.netService = NetService(domain: domain, type: type, name: name)
        self.onResolved = onResolved
        super.init()
        netService.delegate = self
    }

    func resolve() {
        netService.resolve(withTimeout: 5)
    }

    func cancel() {
        guard !finished else { return }
        finished = true
        netService.stop()
        netService.delegate = nil
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard !finished else { return }
        finished = true
        defer { netService.stop() }

        guard let host = sender.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !host.isEmpty else {
            onResolved(nil)
            return
        }
        let port = sender.port > 0 ? sender.port : 8000
        guard let url = URL(string: "http://\(host):\(port)") else {
            onResolved(nil)
            return
        }
        let tank = DiscoveredTank(id: "\(sender.name)-\(host)-\(port)", name: sender.name, url: url)
        onResolved(tank)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        guard !finished else { return }
        finished = true
        netService.stop()
        onResolved(nil)
    }
}
