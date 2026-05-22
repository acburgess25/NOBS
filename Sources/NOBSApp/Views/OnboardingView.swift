import SwiftUI
import NOBSDatabase

struct OnboardingView: View {
    @Binding var isComplete: Bool

    @State private var step = 0
    @State private var displayName = ""
    @State private var interests = ""
    @State private var routines = ""

    private let totalSteps = 5
    private let personalMemories = MemoryRepository(context: .personal)

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
            Image(systemName: "fork.knife")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            Text("Welcome to NOBS")
                .font(.largeTitle.bold())
            Text("Think of it as your own personal kitchen.\nA chef you trust, cooking just for you.\nPrivate. Secure. Yours.")
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
                Label("How Your Kitchen Works", systemImage: "lock.shield.fill")
                    .font(.title2.bold())
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 16) {
                    row(icon: "faceid",
                        title: "Only You Have the Key",
                        detail: "Your kitchen has a lock that only your face can open. Every time you come back, you show your face. Without it, nobody gets in — not even the chef.")
                    row(icon: "lock.fill",
                        title: "Locked Containers",
                        detail: "Every ingredient you keep in your pantry is stored in a sealed, locked container. The only key lives on your keyring — in your pocket, not in the kitchen.")
                    row(icon: "rectangle.stack.fill",
                        title: "Each Item Wrapped Separately",
                        detail: "Your name, your tasks, your notes — each one is wrapped and sealed individually. Even if someone peeked in the pantry, they'd see nothing but sealed boxes.")
                    row(icon: "antenna.radiowaves.left.and.right.slash",
                        title: "Your Pantry is at Home",
                        detail: "All your ingredients stay in your own home pantry. The delivery kitchen never stores your recipes, your grocery list, or your leftovers. I (the chef who built this) can't see them either.")
                    row(icon: "icloud.slash.fill",
                        title: "No Shared Kitchen by Default",
                        detail: "Your kitchen works completely standalone. If you ever want a second pantry in the cloud (iCloud), you have to flip the switch yourself. It's off until you say so.")
                    row(icon: "shippingbox.fill",
                        title: "Secure Delivery",
                        detail: "When you send an order to the chef's kitchen, it travels in a sealed, armored truck with a trusted driver. Your order slip is locked in a box that only the chef can open.")
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
                    Text("Share your recipe box with any other kitchen")
                }
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    Text("Sell your ingredients or hand them to a stranger")
                }
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    Text("Open your locked containers — only you have the key")
                }
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("You are the head chef. Always.")
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
                Label("Set the Table", systemImage: "person.fill.questionmark")
                    .font(.title2.bold())

                Text("Tell the chef about yourself so every meal is made just for you. Everything stays sealed in your pantry — nobody else reads it.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("What name should the chef call you?").font(.headline)
                    TextField("Your name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("What kind of food (topics) do you like?").font(.headline)
                    TextEditor(text: $interests)
                        .frame(minHeight: 80)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.tertiary))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Any daily cooking routines the chef should know?").font(.headline)
                    TextEditor(text: $routines)
                        .frame(minHeight: 80)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.tertiary))
                }

                Text("You can always update your preferences later in Settings → My Profile.")
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
            Text("Your Kitchen is Ready!")
                .font(.largeTitle.bold())
            Text("Your recipe card is saved in your personal pantry — locked and sealed. The chef knows your name and is ready to cook.")
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
