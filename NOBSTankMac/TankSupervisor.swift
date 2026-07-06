import Foundation
import Observation

enum ServiceStatus: Equatable {
    case unknown
    case running
    case stopped
    case unauthorized

    var symbolName: String {
        switch self {
        case .unknown: "shippingbox"
        case .running: "shippingbox.fill"
        case .stopped: "exclamationmark.triangle"
        case .unauthorized: "lock.trianglebadge.exclamationmark"
        }
    }

    var label: String {
        switch self {
        case .unknown: "Checking…"
        case .running: "Running"
        case .stopped: "Stopped"
        case .unauthorized: "Token rejected"
        }
    }
}

/// Supervises the local Tank stack: the NOBS API LaunchAgent and Ollama.
/// The Mac acts as a mobile Tank; this object owns status, pairing, and control.
@MainActor
@Observable
final class TankSupervisor {
    static let launchAgentLabel = "com.nobs.tank"
    static let tankRootDefaultsKey = "nobs.tank.rootPath"
    static let serverPort = 8000

    var serverStatus: ServiceStatus = .unknown
    var ollamaRunning = false
    var lanAddress: String?

    private(set) var deviceToken: String?
    private var pollTask: Task<Void, Never>?
    private let client = TankClient()

    var tankRoot: URL {
        if let saved = UserDefaults.standard.string(forKey: Self.tankRootDefaultsKey) {
            return URL(filePath: saved)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Documents/NOBS")
    }

    var serverURL: URL { URL(string: "http://127.0.0.1:\(Self.serverPort)")! }

    /// Pairing payload the iPhone scans; same scheme the iOS app already handles.
    var pairingURL: String? {
        guard let ip = lanAddress, let token = deviceToken else { return nil }
        return "nobs://pair?url=http://\(ip):\(Self.serverPort)&token=\(token)"
    }

    init() {
        reloadToken()
        startPolling()
    }

    func reloadToken() {
        let envFile = tankRoot.appending(path: ".env")
        guard let contents = try? String(contentsOf: envFile, encoding: .utf8) else {
            deviceToken = nil
            return
        }
        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("NOBS_DEVICE_TOKEN=") else { continue }
            let value = trimmed.dropFirst("NOBS_DEVICE_TOKEN=".count)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            deviceToken = value.isEmpty ? nil : value
        }
    }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func refresh() async {
        lanAddress = Self.primaryIPv4Address()

        let healthy = await client.isHealthy(baseURL: serverURL)
        guard healthy else {
            serverStatus = .stopped
            ollamaRunning = await client.isOllamaRunning()
            return
        }
        if let token = deviceToken {
            serverStatus = await client.isReady(baseURL: serverURL, token: token) ? .running : .unauthorized
        } else {
            serverStatus = .unauthorized
        }
        ollamaRunning = await client.isOllamaRunning()
    }

    /// Restart the LaunchAgent that runs the Tank API. Visible, revocable control —
    /// the same launchctl commands the user could type themselves.
    func restartServer() {
        runLaunchctl(["kickstart", "-k", "gui/\(getuid())/\(Self.launchAgentLabel)"])
        Task {
            try? await Task.sleep(for: .seconds(3))
            await refresh()
        }
    }

    private func runLaunchctl(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/launchctl")
        process.arguments = arguments
        try? process.run()
    }

    /// First non-loopback IPv4 address (en0 preferred), for the pairing QR.
    nonisolated static func primaryIPv4Address() -> String? {
        var addresses: [(interface: String, address: String)] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0,
                  let sa = ptr.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET)
            else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let name = String(cString: ptr.pointee.ifa_name)
            addresses.append((name, String(cString: host)))
        }
        return (addresses.first { $0.interface == "en0" } ?? addresses.first)?.address
    }
}
