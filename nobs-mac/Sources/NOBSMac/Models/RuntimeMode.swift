import Foundation

enum RuntimeMode: String, CaseIterable, Identifiable {
    case auto
    case online
    case offline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .online: "Online"
        case .offline: "Offline"
        }
    }
}

enum ConnectivityRoute {
    case online
    case offline

    var title: String {
        switch self {
        case .online: "Online"
        case .offline: "Offline"
        }
    }

    var symbolName: String {
        switch self {
        case .online: "network"
        case .offline: "wifi.slash"
        }
    }

    var tint: NOBSTint {
        switch self {
        case .online: .sage
        case .offline: .amber
        }
    }
}
