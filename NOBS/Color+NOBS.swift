import SwiftUI

// Keep in sync with design/tokens.json and website/src/nobs-tokens.css
extension Color {
    /// Primary ink (#172818)
    static let nobsInk = Color(red: 23 / 255, green: 40 / 255, blue: 24 / 255)
    /// Primary accent — sage dark (#31562f)
    static let nobsAccent = Color(red: 49 / 255, green: 86 / 255, blue: 47 / 255)
    /// Secondary sage (#5d7d4a)
    static let nobsGreen = Color(red: 93 / 255, green: 125 / 255, blue: 74 / 255)
    /// Canvas background — cream (#f8f6ef)
    static let nobsCanvas = Color(red: 248 / 255, green: 246 / 255, blue: 239 / 255)
    /// Muted body text (#657064)
    static let nobsMuted = Color(red: 101 / 255, green: 112 / 255, blue: 100 / 255)
    /// Pale sage surfaces (#e8ede2)
    static let nobsSagePale = Color(red: 232 / 255, green: 237 / 255, blue: 226 / 255)
}
