import Foundation

enum DeepLinkDestination: Equatable {
    case today
    case chat(prompt: String?)
    case privacy
    case conflict
    case approvals(id: String?, action: String?)
    case tankPairing(url: URL)
}

enum DeepLinkRouter {
    static func isTankPairingURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let hasTankQuery = components.queryItems?.contains(where: { $0.name == "url" || $0.name == "token" || $0.name == "device" }) == true
        return hasTankQuery
    }

    static func destination(for url: URL) -> DeepLinkDestination? {
        if isTankPairingURL(url) {
            return .tankPairing(url: url)
        }
        guard url.scheme?.lowercased() == "nobs" else { return nil }

        let host = (url.host ?? "").lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let segment = host.isEmpty ? path : host
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let prompt = components?.queryItems?.first(where: { $0.name == "prompt" })?.value

        switch segment {
        case "today":
            return .today
        case "chat":
            return .chat(prompt: prompt)
        case "privacy":
            return .privacy
        case "conflict":
            return .conflict
        case "approvals":
            let id = components?.queryItems?.first(where: { $0.name == "id" })?.value
            let action = components?.queryItems?.first(where: { $0.name == "action" })?.value
            return .approvals(id: id, action: action)
        default:
            return nil
        }
    }
}
