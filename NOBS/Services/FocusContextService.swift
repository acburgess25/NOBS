import Foundation
import Intents

enum FocusContextKind: String, Sendable {
    case standard
    case work
    case sleep
    case personal
}

struct FocusContextSnapshot: Sendable {
    var kind: FocusContextKind
    var isFocusActive: Bool
    var focusIdentifier: String
    var displayName: String
}

@MainActor
struct FocusContextService {
    static let systemFocusIdentifier = "system.focus"

    func currentSnapshot() -> FocusContextSnapshot {
        let isFocused = INFocusStatusCenter.default.focusStatus.isFocused ?? false
        if isFocused {
            return FocusContextSnapshot(
                kind: .work,
                isFocusActive: true,
                focusIdentifier: Self.systemFocusIdentifier,
                displayName: "Focus"
            )
        }
        return FocusContextSnapshot(
            kind: .standard,
            isFocusActive: false,
            focusIdentifier: "standard",
            displayName: "Standard"
        )
    }

    func matchingPolicy(in profile: UserProfile, snapshot: FocusContextSnapshot? = nil) -> FocusPolicy? {
        let snapshot = snapshot ?? currentSnapshot()
        return profile.focusPolicies.first { $0.focusIdentifier == snapshot.focusIdentifier }
    }

    func effectiveResponseStyle(profile: UserProfile, snapshot: FocusContextSnapshot? = nil) -> ResponseStyle {
        let snapshot = snapshot ?? currentSnapshot()
        if let policy = matchingPolicy(in: profile, snapshot: snapshot) {
            return policy.responseStyle
        }
        switch snapshot.kind {
        case .work, .sleep:
            return .concise
        case .personal:
            return .reflective
        case .standard:
            return .standard
        }
    }

    func preferredContext(profile: UserProfile, snapshot: FocusContextSnapshot? = nil) -> BriefingContextBucket? {
        let snapshot = snapshot ?? currentSnapshot()
        if let policy = matchingPolicy(in: profile, snapshot: snapshot) {
            return policy.preferredContext
        }
        switch snapshot.kind {
        case .work:
            return .business
        case .personal:
            return .personal
        case .sleep, .standard:
            return nil
        }
    }

    func allowsProactiveNotifications(profile: UserProfile, snapshot: FocusContextSnapshot? = nil) -> Bool {
        if profile.proactivityLevel == .quiet {
            return false
        }
        let snapshot = snapshot ?? currentSnapshot()
        if let policy = matchingPolicy(in: profile, snapshot: snapshot) {
            return policy.allowProactiveNotifications
        }
        switch snapshot.kind {
        case .sleep, .work:
            return false
        case .personal, .standard:
            return true
        }
    }

    func shouldUseTomorrowFraming(profile: UserProfile, snapshot: FocusContextSnapshot? = nil) -> Bool {
        let snapshot = snapshot ?? currentSnapshot()
        return snapshot.kind == .sleep
    }
}
