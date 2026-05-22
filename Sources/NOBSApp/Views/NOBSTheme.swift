/// NOBSTheme — Design System
///
/// Warm & Human aesthetic — implemented from the Claude Design handoff.
/// Bear + Day One + Craft inspiration. SF Rounded, amber + sage, 4pt grid.

import SwiftUI

// MARK: - Color Palette

extension Color {
    // Backgrounds
    static let nobsBg          = Color("NBBackground")   // #FAF8F5 / #1C1917
    static let nobsCard        = Color("NBCard")          // #FFFFFF / #28231F
    static let nobsSurface     = Color("NBSurface")       // #F2EEE7 / #221E1A

    // Accent
    static let nobsAccent      = Color("NBAccent")        // #D97706 amber
    static let nobsAccentDeep  = Color("NBAccentDeep")    // #B35914
    static let nobsAccentSoft  = Color("NBAccentSoft")    // amber 10-14% tint bg
    static let nobsGreen       = Color("NBGreen")         // #65A36E sage
    static let nobsGreenSoft   = Color("NBGreenSoft")     // sage 12-18% tint bg
    static let nobsRed         = Color("NBRed")           // #C75D5D rose danger
    static let nobsBlue        = Color("NBBlue")          // #5680A8 info

    // Text
    static let nobsPrimary     = Color("NBPrimary")       // #1C1917 / #F5F1EA
    static let nobsSecondary   = Color("NBSecondary")     // #57534E / #A8A29E
    static let nobsTertiary    = Color("NBTertiary")      // #A8A29E / #78716C

    // Structural
    static let nobsBorder      = Color("NBBorder")
    static let nobsDivider     = Color("NBDivider")
}

// MARK: - Typography (Apple HIG scale, SF Rounded)

struct NOBSFont {
    /// 34pt bold — screen titles (Memories, Tasks…)
    static func largeTitle(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    /// 28pt bold
    static func title1(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    /// 22pt bold
    static func title2(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    /// 20pt semibold
    static func title3(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    /// 17pt semibold — section titles, important labels
    static func headline(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    /// 17pt regular — body copy
    static func body(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    /// 16pt regular
    static func callout(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    /// 15pt medium — metadata, toggles
    static func subhead(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    /// 13pt medium — timestamps, secondary info
    static func footnote(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    /// 12pt medium — badges, pill labels
    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    /// 11pt heavy uppercase — section overlines (EARLIER THIS WEEK)
    static func overline(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    // Legacy aliases
    static func display(_ size: CGFloat = 34) -> Font { largeTitle(size) }
    static func title(_ size: CGFloat = 22) -> Font { title2(size) }
}

// MARK: - Spacing  (4pt grid)

enum Spacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum Radius {
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 18
    static let xxl: CGFloat = 22
    static let xxxl: CGFloat = 28
    static let full: CGFloat = 9999
}

// MARK: - Shadows

extension View {
    func nobsShadow(strong: Bool = false) -> some View {
        self.shadow(
            color: Color.black.opacity(strong ? 0.08 : 0.05),
            radius: strong ? 16 : 8,
            x: 0, y: strong ? 4 : 2
        )
        .shadow(
            color: Color.black.opacity(strong ? 0.04 : 0.03),
            radius: 2, x: 0, y: 1
        )
    }
}

// MARK: - NOBSCard

/// Warm surface card — rounded, softly shadowed, no harsh separators
struct NOBSCard<Content: View>: View {
    var padding: CGFloat = Spacing.md
    var radius: CGFloat = Radius.xxl
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Color.nobsCard)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .nobsShadow()
    }
}

// MARK: - NOBSTag (pill label)

struct NOBSTag: View {
    let text: String
    var color: Color = .nobsAccent
    var size: CGFloat = 12

    var body: some View {
        Text(text)
            .font(NOBSFont.caption(size))
            .fontWeight(.bold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - NOBSButton

struct NOBSButton: View {
    let label: String
    var icon: String? = nil
    var style: ButtonStyle = .primary
    var size: ButtonSize = .large
    var fullWidth: Bool = true
    var isLoading: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    enum ButtonStyle { case primary, secondary, ghost }
    enum ButtonSize   { case small, medium, large
        var height: CGFloat   { switch self { case .small: 36; case .medium: 48; case .large: 56 } }
        var hPad: CGFloat     { switch self { case .small: 16; case .medium: 22; case .large: 28 } }
        var fontSize: CGFloat { switch self { case .small: 15; case .medium: 16; case .large: 17 } }
    }

    var body: some View {
        Button(action: {
            if !isLoading && !disabled {
                action()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(style == .primary ? .white : .nobsAccent)
                } else {
                    if let icon { Image(systemName: icon) }
                    Text(label)
                        .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, fullWidth ? 0 : size.hPad)
            .background(background.opacity(disabled ? 0.5 : 1.0))
            .foregroundStyle(foreground.opacity(disabled ? 0.6 : 1.0))
            .clipShape(Capsule())
            .shadow(
                color: (style == .primary && !disabled) ? Color.nobsAccent.opacity(0.35) : .clear,
                radius: 10, x: 0, y: 3
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled || isLoading)
    }

    private var background: Color {
        switch style {
        case .primary:   .nobsAccent
        case .secondary: Color.primary.opacity(0.05)
        case .ghost:     .clear
        }
    }

    private var foreground: Color {
        switch style {
        case .primary:   .white
        case .secondary: .nobsPrimary
        case .ghost:     .nobsAccent
        }
    }
}

// MARK: - CheckButton (task checkbox)

struct CheckButton: View {
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(done ? Color.clear : Color.nobsTertiary.opacity(0.5), lineWidth: 2)
                    .fill(done ? Color.nobsGreen : Color.clear)
                    .frame(width: 24, height: 24)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: done)
    }
}

// MARK: - NOBSTextField

struct NOBSTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(Color.nobsTertiary)
                    .font(.system(size: 16))
            }
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(NOBSFont.body())
                    .textContentType(.password)
            } else {
                TextField(placeholder, text: $text)
                    .font(NOBSFont.body())
            }
        }
        .padding(Spacing.md)
        .background(Color.nobsCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .nobsShadow()
    }
}

// MARK: - NobsLogo

/// NOBS app icon mark — amber-deep rounded square with bold "N" and wavy underline
struct NobsLogo: View {
    var size: CGFloat = 64

    var body: some View {
        Canvas { ctx, _ in
            let sf = size / 320
            let cornerRadius = size * 0.21
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let rrect = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            // 1. Amber-deep background
            ctx.fill(
                rrect.path(in: rect),
                with: .color(Color(hex: "#B35914"))
            )

            // 2. Inner highlight ring — 2pt cream stroke at 18% opacity
            ctx.stroke(
                rrect.path(in: rect),
                with: .color(Color.white.opacity(0.18)),
                style: StrokeStyle(lineWidth: 2)
            )

            // 3. Bold "N" centered at 40% height
            let nText = Text("N")
                 .font(.system(size: size * 0.74, weight: .black, design: .default))
                 .foregroundStyle(Color.white)
             ctx.draw(nText, at: CGPoint(x: size / 2, y: size * 0.40))

            // 4. Wavy underline (scaled from 320-viewbox)
            let y    = 262 * sf
            let x1   = 77  * sf
            let x2   = 243 * sf
            let span = x2 - x1
            var wave = Path()
            wave.move(to: CGPoint(x: x1, y: y))
            wave.addCurve(
                to: CGPoint(x: x2, y: y),
                control1: CGPoint(x: x1 + span * 0.33, y: y - 7 * sf),
                control2: CGPoint(x: x1 + span * 0.67, y: y + 7 * sf)
            )
            ctx.stroke(
                wave,
                with: .color(Color.white.opacity(0.95)),
                style: StrokeStyle(lineWidth: size * 0.026, lineCap: .round)
            )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.21, style: .continuous))
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Section Header modifier

struct SectionOverline: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(NOBSFont.overline())
            .foregroundStyle(Color.nobsTertiary)
            .textCase(.uppercase)
            .tracking(1.2)
    }
}

extension View {
    func sectionOverline() -> some View {
        modifier(SectionOverline())
    }
}
