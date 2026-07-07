import SwiftUI

enum NOBSTheme {
    static let cardRadius: CGFloat = 16
    static let chipRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 12
}

// MARK: - View modifiers

private struct NOBSScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.nobsCanvas.ignoresSafeArea())
    }
}

private struct NOBSSectionCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(Color.nobsSagePale, in: RoundedRectangle(cornerRadius: NOBSTheme.cardRadius))
    }
}

private struct NOBSListScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.nobsCanvas.ignoresSafeArea())
    }
}

extension View {
    func nobsScreenBackground() -> some View {
        modifier(NOBSScreenBackgroundModifier())
    }

    func nobsSectionCard() -> some View {
        modifier(NOBSectionCardModifier())
    }

    func nobsListScreen() -> some View {
        modifier(NOBSListScreenModifier())
    }

    func nobsSerifTitle(_ size: CGFloat = 30) -> some View {
        font(.system(size: size, weight: .regular, design: .serif))
            .foregroundStyle(Color.nobsInk)
    }

    func nobsEyebrow() -> some View {
        font(.caption.weight(.bold))
            .foregroundStyle(Color.nobsForest)
            .textCase(.uppercase)
            .tracking(1.2)
    }
}

// MARK: - Reusable components

struct NOBSEmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(Color.nobsAccent)
                .accessibilityHidden(true)
            Text(title)
                .nobsSerifTitle(26)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.body)
                .foregroundStyle(Color.nobsMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 12)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .nobsScreenBackground()
    }
}

struct NOBSBetaBadge: View {
    var body: some View {
        Text("Beta")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.nobsForest)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.nobsSagePale, in: Capsule())
            .accessibilityLabel("Beta release")
    }
}
