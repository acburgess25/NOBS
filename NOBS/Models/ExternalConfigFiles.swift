import Foundation

/// Subset of `UserProfile` editable from `profile.json` in an external config folder.
struct ExternalProfileConfig: Codable, Sendable {
    var displayName: String?
    var preferredTone: TonePreference?
    var workingHoursStart: String?
    var workingHoursEnd: String?
    var mentalLoadSources: [String]?
    var morningRoutineNote: String?
    var eveningRoutineNote: String?
    var proactivityLevel: ProactivityLevel?
    var privacyComfort: PrivacyComfort?
    var immediateProblem: String?
    var focusPolicies: [FocusPolicy]?
    var accessibilityPreferences: AccessibilityPreferences?
    /// When true, marks onboarding complete without opening the onboarding flow.
    var completeOnboarding: Bool?

    func apply(to profile: inout UserProfile) {
        if let displayName { profile.displayName = displayName }
        if let preferredTone { profile.preferredTone = preferredTone }
        if let workingHoursStart { profile.workingHoursStart = workingHoursStart }
        if let workingHoursEnd { profile.workingHoursEnd = workingHoursEnd }
        if let mentalLoadSources { profile.mentalLoadSources = mentalLoadSources }
        if let morningRoutineNote { profile.morningRoutineNote = morningRoutineNote }
        if let eveningRoutineNote { profile.eveningRoutineNote = eveningRoutineNote }
        if let proactivityLevel { profile.proactivityLevel = proactivityLevel }
        if let privacyComfort { profile.privacyComfort = privacyComfort }
        if let immediateProblem { profile.immediateProblem = immediateProblem }
        if let focusPolicies { profile.focusPolicies = focusPolicies }
        if let accessibilityPreferences { profile.accessibilityPreferences = accessibilityPreferences }
        if completeOnboarding == true, profile.onboardingCompletedAt == nil {
            profile.onboardingCompletedAt = Date()
        }
    }
}

/// Tank URL only — device tokens stay in Keychain and must never appear in iCloud files.
struct ExternalTankConfig: Codable, Sendable {
    var address: String?
}

struct ExternalConfigApplyResult: Sendable {
    var appliedProfile: Bool
    var appliedTankAddress: Bool
    var messages: [String]

    var summary: String {
        if messages.isEmpty { return "No config files changed." }
        return messages.joined(separator: " ")
    }
}
