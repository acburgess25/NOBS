import SwiftUI

// Keep in sync with design/tokens.json, website/src/nobs-tokens.css,
// and the NOBS Design System tokens (tokens/colors.css).
extension Color {
    /// Deep forest ink for primary text (#172818)
    static let nobsInk = Color(red: 23 / 255, green: 40 / 255, blue: 24 / 255)
    /// Interactive accent — original sage (#5D7D4A)
    static let nobsAccent = Color(red: 93 / 255, green: 125 / 255, blue: 74 / 255)
    /// Forest anchor for emphasis (#31562F)
    static let nobsForest = Color(red: 49 / 255, green: 86 / 255, blue: 47 / 255)
    /// Decorative sage (#5D7D4A)
    static let nobsGreen = Color(red: 93 / 255, green: 125 / 255, blue: 74 / 255)
    /// Warm canvas (#F8F6EF)
    static let nobsCanvas = Color(red: 248 / 255, green: 246 / 255, blue: 239 / 255)
    /// Secondary text (#657064)
    static let nobsMuted = Color(red: 101 / 255, green: 112 / 255, blue: 100 / 255)
    /// Card / bubble surfaces (#E8EDE2)
    static let nobsSagePale = Color(red: 232 / 255, green: 237 / 255, blue: 226 / 255)
    /// Subtle section wash (#F0F3EB)
    static let nobsSageMist = Color(red: 240 / 255, green: 243 / 255, blue: 235 / 255)
    /// Caution / warning ink — schedule conflicts, medium risk (#A8672E). Maps to `--nobs-warning-ink`.
    static let nobsWarning = Color(red: 168 / 255, green: 103 / 255, blue: 46 / 255)
    /// Caution callout wash — "notifications off" and similar (#D68A45 at 12%). Maps to `--nobs-warning-bg`.
    static let nobsWarningWash = Color(red: 214 / 255, green: 138 / 255, blue: 69 / 255).opacity(0.12)
    /// Pending-approval count badges only (#D64541) — maps to `--nobs-destructive`.
    static let nobsDestructive = Color(red: 214 / 255, green: 69 / 255, blue: 65 / 255)
    /// Live "online" status dot — Tank connected (#5C8B48). Maps to `--nobs-online`.
    static let nobsOnline = Color(red: 92 / 255, green: 139 / 255, blue: 72 / 255)
    /// Composer / text-input fill — soft neutral tint. Maps to `--nobs-composer-fill`.
    static let nobsComposerFill = Color.black.opacity(0.05)
}
