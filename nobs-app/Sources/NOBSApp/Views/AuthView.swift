import SwiftUI
import AuthenticationServices
import NOBSDatabase
import NOBSCore

struct AuthView: View {
    @ObservedObject var auth: APIClient
    @State private var errorMessage: String?
    @AppStorage("demo_seeded") private var demoSeeded = false

    // Background
    @State private var animateBg = false

    // Logo take-off state
    @State private var logoYOffset: CGFloat = 180
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var logoBlurRadius: CGFloat = 0

    // Supporting content fade
    @State private var contentVisible = false

    private let bgColors: [Color] = [
        Color(hex: "#060403"), Color(hex: "#130A03"), Color(hex: "#060403"),
        Color(hex: "#2E1305"), Color(hex: "#5C280C"), Color(hex: "#1E0D04"),
        Color(hex: "#060403"), Color(hex: "#0E0703"), Color(hex: "#060403"),
    ]

    var body: some View {
        ZStack {
            // Animated dark-amber mesh gradient
            MeshGradient(
                width: 3, height: 3,
                points: animateBg
                    ? [[0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                       [0.0, 0.5], [0.65, 0.38], [1.0, 0.5],
                       [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]]
                    : [[0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                       [0.0, 0.5], [0.35, 0.62], [1.0, 0.5],
                       [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]],
                colors: bgColors
            )
            .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true), value: animateBg)
            .ignoresSafeArea()

            // Drifting amber glow orb
            Circle()
                .fill(Color(hex: "#D97706").opacity(0.10))
                .frame(width: 380)
                .blur(radius: 90)
                .offset(x: animateBg ? 55 : -55, y: animateBg ? -65 : -15)
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: animateBg)
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Logo + title
                VStack(spacing: Spacing.md) {
                    NobsLogo(size: 96)
                        .shadow(color: Color(hex: "#D97706").opacity(0.55), radius: 36, x: 0, y: 10)
                        .scaleEffect(logoScale)
                        .offset(y: logoYOffset)
                        .opacity(logoOpacity)
                        .blur(radius: logoBlurRadius)

                    Text("NOBS")
                        .font(NOBSFont.largeTitle())
                        .foregroundStyle(.white)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 10)
                        .animation(.easeOut(duration: 0.4), value: contentVisible)

                    Text("No-BS Personal Assistant")
                        .font(NOBSFont.body())
                        .foregroundStyle(.white.opacity(0.55))
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 8)
                        .animation(.easeOut(duration: 0.4).delay(0.05), value: contentVisible)
                }
                .padding(.bottom, Spacing.lg)

                // Glass sign-in card
                VStack(spacing: Spacing.md) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(NOBSFont.footnote())
                            .foregroundStyle(Color.nobsRed)
                            .multilineTextAlignment(.center)
                    }

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(Spacing.lg)
                .glassEffect(in: RoundedRectangle(cornerRadius: Radius.xxxl, style: .continuous))
                .padding(.horizontal, Spacing.md)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 16)
                .animation(.easeOut(duration: 0.5).delay(0.08), value: contentVisible)

                Text("Your data stays on device.\nApple never shares your password with NOBS.")
                    .font(NOBSFont.caption())
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.15), value: contentVisible)

                Spacer()
            }
        }
        .onAppear {
            animateBg = true

            // Logo springs in from below with a bouncy landing
            withAnimation(.spring(response: 0.75, dampingFraction: 0.46).delay(0.2)) {
                logoYOffset = 0
                logoScale = 1.0
                logoOpacity = 1.0
            }

            // Content fades in after the logo lands
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                contentVisible = true
            }
        }
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unexpected credential type."
                return
            }

            // Logo takes off! — fast easeIn to shoot upward
            withAnimation(.easeIn(duration: 0.3)) {
                logoYOffset = -720
                logoScale = 2.8
                logoOpacity = 0
                logoBlurRadius = 40
                contentVisible = false
            }

            let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            // Authenticate after the animation has had a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                auth.loginWithApple(userIdentifier: credential.user, displayName: displayName)
                if !demoSeeded {
                    seedDemoData()
                    demoSeeded = true
                }
            }

        case .failure(let error):
            let asError = error as? ASAuthorizationError
            if asError?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func seedDemoData() {
        let personalMemories = MemoryRepository(context: .personal)
        let workMemories = MemoryRepository(context: .work)
        let personalTasks = TaskRepository(context: .personal)
        let workTasks = TaskRepository(context: .work)

        let demoMemories = [
            (context: DataContext.personal, content: "My first memory with NOBS — this app remembers everything for me!", tags: ["encrypted", "personal"]),
            (context: DataContext.personal, content: "I showed NOBS to my team and they loved the kitchen metaphor. The privacy-first approach really resonates.", tags: ["encrypted", "personal"]),
            (context: DataContext.personal, content: "Notes from today's meeting: decide on pricing model for the agency. Options are flat monthly vs per-post.", tags: ["encrypted", "personal"]),
            (context: DataContext.work, content: "Q3 goals: launch the content agency, onboard 5 pilot clients, hit $2k MRR by September.", tags: ["encrypted", "work"]),
            (context: DataContext.work, content: "Content calendar template is done. Next: build the client approval flow with Stripe integration.", tags: ["encrypted", "work"]),
        ]

        let demoTasks = [
            (context: DataContext.personal, title: "Review NOBS app onboarding flow", dueDate: Date().addingTimeInterval(86400)),
            (context: DataContext.personal, title: "Update project.yml with widget target", dueDate: Date().addingTimeInterval(172800)),
            (context: DataContext.work, title: "Deploy API proxy with auth endpoints", dueDate: Date().addingTimeInterval(3600)),
            (context: DataContext.work, title: "Pull qwen2:1.5b on the tank server", dueDate: Date().addingTimeInterval(86400)),
            (context: DataContext.work, title: "Set up Stripe payment links for agency plans", dueDate: Date().addingTimeInterval(259200)),
        ]

        for (context, content, tags) in demoMemories {
            if let encrypted = try? CryptoHelper.encrypt(content) {
                let repo = context == .personal ? personalMemories : workMemories
                _ = try? repo.save(content: encrypted, tags: tags)
            }
        }

        for (context, title, dueDate) in demoTasks {
            let repo = context == .personal ? personalTasks : workTasks
            _ = try? repo.create(title: title, dueDate: dueDate)
        }
    }
}
