import Foundation

enum TonePreference: String, Codable, CaseIterable, Sendable {
    case neutral
    case warm
    case direct
    case witty

    var title: String { rawValue.capitalized }
}

enum ProactivityLevel: String, Codable, CaseIterable, Sendable {
    case quiet
    case balanced
    case proactive

    var title: String { rawValue.capitalized }
}

enum PrivacyComfort: String, Codable, CaseIterable, Sendable {
    case localFirst
    case tankPreferred
    case cloudOk

    var title: String {
        switch self {
        case .localFirst: "Local first"
        case .tankPreferred: "Tank preferred"
        case .cloudOk: "Cloud OK when needed"
        }
    }
}

enum ResponseStyle: String, Codable, CaseIterable, Sendable {
    case concise
    case standard
    case reflective

    var title: String { rawValue.capitalized }
}

struct FocusPolicy: Codable, Hashable, Sendable {
    var focusIdentifier: String
    var displayName: String
    var responseStyle: ResponseStyle
    var allowProactiveNotifications: Bool
    var preferredContext: BriefingContextBucket?
}

struct AccessibilityPreferences: Codable, Hashable, Sendable {
    var responseLength: ResponseLength = .standard
    var prefersVoiceFirst: Bool = false
    var speakingRate: Float = 0.5
}

struct UserProfile: Codable, Sendable {
    var schemaVersion: Int = 1
    var displayName: String?
    var preferredTone: TonePreference = .neutral
    var workingHoursStart: String?
    var workingHoursEnd: String?
    var mentalLoadSources: [String] = []
    var morningRoutineNote: String?
    var eveningRoutineNote: String?
    var proactivityLevel: ProactivityLevel = .balanced
    var privacyComfort: PrivacyComfort = .localFirst
    var onboardingCompletedAt: Date?
    var immediateProblem: String?
    var focusPolicies: [FocusPolicy] = []
    var accessibilityPreferences = AccessibilityPreferences()

    var isOnboardingComplete: Bool {
        onboardingCompletedAt != nil
    }

    var greetingName: String? {
        guard let displayName else { return nil }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
