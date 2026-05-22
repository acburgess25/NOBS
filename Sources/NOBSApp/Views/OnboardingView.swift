import SwiftUI
import NOBSDatabase

struct OnboardingView: View {
    @Binding var isComplete: Bool

    @State private var step = 0
    @State private var displayName = ""
    @State private var interests = ""
    @State private var routines = ""

    private let totalSteps = 5
    private var personalMemories: MemoryRepository {
        MemoryRepository(context: NOBSDatabase.shared.isPersonalModeEnabled ? .personal : .work)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                welcomePage.tag(0)
                transparencyPage.tag(1)
                privacyPage.tag(2)
                interviewPage.tag(3)
                donePage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack {
                if step > 0 {
                    Button("Back") {
                        withAnimation { step -= 1 }
                    }
                }
                Spacer()
                Text("\(step + 1) of \(totalSteps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(step == totalSteps - 1 ? "Get Started" : "Next") {
                    if step == totalSteps - 1 {
                        finish()
                    } else {
                        withAnimation { step += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(step == 3 && displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            Text("Welcome to NOBS")
                .font(.largeTitle.bold())
            Text("Think of it as having a trusted companion by your side.\nSomeone who knows you, remembers what matters,\nand always has your back. Private. Secure. Yours.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private var transparencyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 20)
                Label("How NOBS Keeps You Safe", systemImage: "lock.shield.fill")
                    .font(.title2.bold())
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 16) {
                    row(icon: "faceid",
                        title: "Only You Get In",
                        detail: "NOBS recognizes your face. Every time you come back, it checks it's really you. Nobody else can walk in — not even the person who built this.")
                    row(icon: "lock.fill",
                        title: "Everything is Locked",
                        detail: "All your personal information is stored in a locked vault. The only key is on your device, in your hands — nowhere else.")
                    row(icon: "rectangle.stack.fill",
                        title: "Stored Separately",
                        detail: "Your name, your notes, your memories — each one is sealed individually. Even if someone got to your device, they would see nothing but locked boxes.")
                    row(icon: "antenna.radiowaves.left.and.right.slash",
                        title: "Stays on Your Device",
                        detail: "Your information lives on your phone, not on someone else's server. The person who built NOBS cannot read your data. Nobody can.")
                    row(icon: "icloud.slash.fill",
                        title: "No Cloud by Default",
                        detail: "NOBS works completely on its own. If you ever want to sync across your devices, you choose to turn it on. It's off until you decide.")
                    row(icon: "shippingbox.fill",
                        title: "Encrypted in Transit",
                        detail: "When NOBS reaches out to your private server, everything is locked and sealed before it leaves your hands. Only your device can read what comes back.")
                }

                Spacer()
            }
            .padding()
        }
    }

    private var privacyPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("What NOBS Will Never Do")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    Text("Share your information with anyone else")
                }
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    Text("Sell your data or hand it to a third party")
                }
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    Text("Access your private notes — only you hold the key")
                }
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("You are always in control. Always.")
                }
            }
            .font(.body)

            Spacer()
        }
        .padding()
    }

    private var interviewPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 20)
                Label("Let's Get to Know You", systemImage: "person.fill.questionmark")
                    .font(.title2.bold())

                Text("Tell NOBS a little about yourself so it can be genuinely helpful from day one. Everything you share stays sealed on your device — nobody else reads it.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("What should NOBS call you?").font(.headline)
                    TextField("Your name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("What topics or things matter most to you?").font(.headline)
                    TextEditor(text: $interests)
                        .frame(minHeight: 80)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.tertiary))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Any daily habits or routines NOBS should know about?").font(.headline)
                    TextEditor(text: $routines)
                        .frame(minHeight: 80)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.tertiary))
                }

                Text("You can always update this later in Settings → My Profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private var donePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            Text("You're All Set!")
                .font(.largeTitle.bold())
            Text("Your profile is saved privately on your device. NOBS knows your name and is ready to help — whenever you need it.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private func finish() {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            try? personalMemories.save(content: name, tags: ["profile", "display_name", "personal"])
        }
        if !interests.isEmpty {
            try? personalMemories.save(content: interests, tags: ["profile", "bio", "personal"])
        }
        if !routines.isEmpty {
            try? personalMemories.save(content: routines, tags: ["profile", "routines", "personal"])
        }
        isComplete = true
    }
}

private func row(icon: String, title: String, detail: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
        Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(.blue)
            .frame(width: 30)
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
    }
}
