import Foundation

struct UserProfileStore {
    func load() -> UserProfile {
        if let stored: UserProfile = try? AppGroupStore.readJSON(UserProfile.self, from: AppGroupStore.userProfileFile) {
            return stored
        }
        var profile = UserProfile()
        if UserDefaults.standard.bool(forKey: Self.legacyOnboardingKey) {
            profile.onboardingCompletedAt = Date()
            try? save(profile)
        }
        return profile
    }

    func save(_ profile: UserProfile) throws {
        try AppGroupStore.writeJSON(profile, to: AppGroupStore.userProfileFile)
        UserDefaults.standard.set(profile.isOnboardingComplete, forKey: Self.legacyOnboardingKey)
    }

    private static let legacyOnboardingKey = "nobs.onboarding.complete"
}
