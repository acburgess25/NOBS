import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var phase: Phase = .brand(0)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let accent = Color.nobsAccent

    private let pages: [(icon: String, title: String, body: String)] = [
        ("leaf",
         "Your technology.\nFinally working for you.",
         "NOBS helps turn a chaotic day into a realistic plan. Chat stays at the center."),
        ("hand.raised",
         "Private by default.\nClear when it isn't.",
         "Every answer shows whether it was processed on this iPhone, your Tank, or optional NOBScloud."),
    ]

    enum Phase: Equatable {
        case brand(Int)
        case chat
        case signIn
    }

    var body: some View {
        switch phase {
        case .brand(let page):
            brandPage(pages[page], page: page)
        case .chat:
            OnboardingChatView {
                applyPhaseChange(.signIn)
            }
        case .signIn:
            SignInView(mode: .onboarding, onComplete: onComplete)
        }
    }

    private func brandPage(_ page: (icon: String, title: String, body: String), page index: Int) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 42))
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            Text(page.title)
                .font(.system(size: 42, weight: .regular, design: .serif))
                .accessibilityAddTraits(.isHeader)
            Text(page.body)
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
            Spacer()
            Button("Continue") {
                applyPhaseChange(index + 1 < pages.count ? .brand(index + 1) : .chat)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityHint(index + 1 < pages.count ? "Next introduction screen" : "Start conversational setup")
        }
        .padding(28)
        .nobsScreenBackground()
    }

    private func applyPhaseChange(_ next: Phase) {
        if reduceMotion {
            phase = next
        } else {
            withAnimation { phase = next }
        }
    }
}
