import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var phase: Phase = .brand(0)
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
                withAnimation { phase = .signIn }
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
            Text(page.title)
                .font(.system(size: 42, weight: .regular, design: .serif))
            Text(page.body)
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
            Spacer()
            Button("Continue") {
                withAnimation {
                    if index + 1 < pages.count {
                        phase = .brand(index + 1)
                    } else {
                        phase = .chat
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(28)
    }
}
