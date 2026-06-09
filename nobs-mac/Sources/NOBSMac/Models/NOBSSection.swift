import SwiftUI

enum NOBSSection: String, CaseIterable, Identifiable {
    case dashboard
    case tankAI
    case chat
    case memory
    case agents
    case family
    case skills
    case apple
    case tank
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Command Center"
        case .tankAI: "Tank AI"
        case .chat: "Chat"
        case .memory: "Memory"
        case .agents: "Agents"
        case .family: "Family"
        case .skills: "Skills"
        case .apple: "Apple"
        case .tank: "Tank"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: "macwindow.and.cursorarrow"
        case .tankAI: "person.2.wave.2"
        case .chat: "bubble.left.and.bubble.right"
        case .memory: "square.stack.3d.up"
        case .agents: "cpu"
        case .family: "person.3"
        case .skills: "wrench.and.screwdriver"
        case .apple: "apple.logo"
        case .tank: "server.rack"
        case .settings: "gearshape"
        }
    }
}
