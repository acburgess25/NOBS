import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var page = 0
    private let accent = Color.nobsAccent

    private let pages: [(icon: String, title: String, body: String)] = [
        ("leaf",
         "Your technology.\nFinally working for you.",
         "NOBS helps turn a chaotic day into a realistic plan. Chat stays at the center."),
        ("hand.raised",
         "Private by default.\nClear when it isn't.",
         "Every answer shows whether it was processed on this iPhone, your Tank, or optional NOBScloud."),
    ]

    var body: some View {
        if page < pages.count {
            let p = pages[page]
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image(systemName: p.icon)
                    .font(.system(size: 42))
                    .foregroundStyle(accent)
                Text(p.title)
                    .font(.system(size: 42, weight: .regular, design: .serif))
                Text(p.body)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                Spacer()
                Button("Continue") { withAnimation { page += 1 } }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(28)
        } else {
            SignInView(mode: .onboarding) { onComplete() }
        }
    }
}
