import SwiftUI
import NOBSDatabase
import NOBSCore

struct AuthView: View {
    @ObservedObject var auth: APIClient
    @State private var username = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @AppStorage("demo_seeded") private var demoSeeded = false

    var body: some View {
        ZStack {
            Color.nobsBg
                .ignoresSafeArea()
            
            VStack(spacing: Spacing.xl) {
                Spacer()
                
                VStack(spacing: Spacing.md) {
                    NobsLogo(size: 96)
                        .nobsShadow(strong: true)
                    
                    Text("NOBS")
                        .font(NOBSFont.largeTitle())
                        .foregroundStyle(Color.nobsPrimary)
                    
                    Text("No-BS Personal Assistant")
                        .font(NOBSFont.body())
                        .foregroundStyle(Color.nobsSecondary)
                }
                .padding(.bottom, Spacing.lg)

                VStack(spacing: Spacing.md) {
                    NOBSTextField(
                        placeholder: "Username",
                        text: $username,
                        icon: "person"
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    
                    NOBSTextField(
                        placeholder: "Password",
                        text: $password,
                        icon: "lock",
                        isSecure: true
                    )
                }
                .padding(.horizontal, Spacing.md)

                if let errorMessage {
                    Text(errorMessage)
                        .font(NOBSFont.footnote())
                        .foregroundStyle(Color.nobsRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                }

                VStack(spacing: Spacing.md) {
                    NOBSButton(
                        label: isRegistering ? "Create Account" : "Log In",
                        style: .primary,
                        size: .large,
                        fullWidth: true,
                        isLoading: isLoading,
                        disabled: username.isEmpty || password.isEmpty,
                        action: submit
                    )
                    
                    NOBSButton(
                        label: isRegistering ? "Already have an account? Log in" : "New here? Create an account",
                        style: .ghost,
                        size: .medium,
                        fullWidth: true,
                        action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isRegistering.toggle()
                                errorMessage = nil
                            }
                        }
                    )
                }
                .padding(.horizontal, Spacing.md)

                Text("Demo: alex / password123")
                    .font(NOBSFont.caption())
                    .foregroundStyle(Color.nobsTertiary)

                Spacer()
            }
        }
    }

    private func submit() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                if isRegistering {
                    try await auth.register(username: username, password: password)
                }
                try await auth.login(username: username, password: password)
                if !demoSeeded {
                    seedDemoData()
                    demoSeeded = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
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
                try? repo.save(content: encrypted, tags: tags)
            }
        }

        for (context, title, dueDate) in demoTasks {
            let repo = context == .personal ? personalTasks : workTasks
            try? repo.create(title: title, dueDate: dueDate)
        }
    }
}
