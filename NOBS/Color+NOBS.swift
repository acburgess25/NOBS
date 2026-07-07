import SwiftUI

// Keep in sync with design/tokens.json and website/src/nobs-tokens.css
extension Color {
    /// Soft charcoal-green for primary text (#2A3328)
    static let nobsInk = Color(red: 42 / 255, green: 51 / 255, blue: 40 / 255)
    /// Interactive accent — muted sage (#6E8B62)
    static let nobsAccent = Color(red: 110 / 255, green: 139 / 255, blue: 98 / 255)
    /// Forest anchor for emphasis (#4A5D45)
    static let nobsForest = Color(red: 74 / 255, green: 93 / 255, blue: 69 / 255)
    /// Decorative sage (#9CAF88)
    static let nobsGreen = Color(red: 156 / 255, green: 175 / 255, blue: 136 / 255)
    /// Warm canvas (#F5F3ED)
    static let nobsCanvas = Color(red: 245 / 255, green: 243 / 255, blue: 237 / 255)
    /// Secondary text (#707A72)
    static let nobsMuted = Color(red: 112 / 255, green: 122 / 255, blue: 114 / 255)
    /// Card / bubble surfaces (#EAEEE6)
    static let nobsSagePale = Color(red: 234 / 255, green: 238 / 255, blue: 230 / 255)
    /// Subtle section wash (#F2F4F0)
    static let nobsSageMist = Color(red: 242 / 255, green: 244 / 255, blue: 240 / 255)
    /// Schedule conflict / caution (#C17A3A)
    static let nobsWarning = Color(red: 193 / 255, green: 122 / 255, blue: 58 / 255)
}
