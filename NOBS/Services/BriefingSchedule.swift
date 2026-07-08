import Foundation

enum BriefingSchedule {
    static let defaultEveningWrapUpHour = 17

    static func eveningWrapUpHour(profile: UserProfile) -> Int {
        guard let end = profile.workingHoursEnd else { return defaultEveningWrapUpHour }
        let parts = end.split(separator: ":")
        guard let hour = parts.first.flatMap({ Int($0) }) else { return defaultEveningWrapUpHour }
        return max(hour, defaultEveningWrapUpHour - 2)
    }

    static func isEveningDisplayHour(profile: UserProfile) -> Bool {
        Calendar.current.component(.hour, from: Date()) >= eveningWrapUpHour(profile: profile)
    }
}
