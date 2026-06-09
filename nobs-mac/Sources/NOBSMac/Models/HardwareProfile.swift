import Foundation

struct HardwareProfile: Hashable {
    let modelIdentifier: String
    let chipName: String
    let memoryGB: Int
    let cpuCores: Int
    let gpuDescription: String

    var localScore: Int {
        var score = 0

        if chipName.localizedCaseInsensitiveContains("M4") {
            score += 38
        } else if chipName.localizedCaseInsensitiveContains("M3") {
            score += 34
        } else if chipName.localizedCaseInsensitiveContains("M2") {
            score += 28
        } else if chipName.localizedCaseInsensitiveContains("M1") {
            score += 22
        } else if chipName.localizedCaseInsensitiveContains("Apple") {
            score += 16
        }

        score += min(memoryGB, 64)
        score += min(cpuCores * 3, 36)

        return min(score, 100)
    }

    var recommendation: RuntimeRecommendation {
        switch localScore {
        case 82...:
            RuntimeRecommendation(
                route: .local,
                title: "Use this Mac as the family hub",
                summary: "This hardware is strong enough for local agents, memory distillation, Apple workflows, and most family automation without a subscription.",
                nextStep: "Set this Mac as the default home hub, then use Tank only for beta testers or long remote jobs."
            )
        case 58..<82:
            RuntimeRecommendation(
                route: .hybrid,
                title: "Use local first, Tank for heavier jobs",
                summary: "This machine can handle everyday NOBS work, but bigger coding, call analysis, and multi-person workloads may benefit from Tank or a paid hosted tier.",
                nextStep: "Keep local workflows enabled and ask before moving expensive jobs to Tank or subscription compute."
            )
        default:
            RuntimeRecommendation(
                route: .hosted,
                title: "Recommend Tank or subscription compute",
                summary: "This hardware is better as a controller than the main agent runtime. Local features still work, but heavy jobs should move to Tank, a family server, or a subscription.",
                nextStep: "Offer setup on a stronger Mac, Linux box, Tank beta, or the hosted agent tier."
            )
        }
    }

    static let unknown = HardwareProfile(
        modelIdentifier: "Unknown Mac",
        chipName: "Unknown",
        memoryGB: 0,
        cpuCores: 0,
        gpuDescription: "Unknown"
    )
}

struct RuntimeRecommendation: Hashable {
    let route: RuntimeRoute
    let title: String
    let summary: String
    let nextStep: String
}

enum RuntimeRoute: String, Hashable {
    case local = "Local"
    case hybrid = "Hybrid"
    case hosted = "Hosted"

    var tint: NOBSTint {
        switch self {
        case .local: .sage
        case .hybrid: .amber
        case .hosted: .blue
        }
    }

    var symbolName: String {
        switch self {
        case .local: "macbook.and.iphone"
        case .hybrid: "arrow.triangle.branch"
        case .hosted: "server.rack"
        }
    }
}
