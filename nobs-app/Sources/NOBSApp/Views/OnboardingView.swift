import SwiftUI
import NOBSDatabase

struct OnboardingView: View {
    @Binding var isComplete: Bool

    @State private var step = 0
    @State private var displayName = ""
    @State private var interests = ""
    @State private var routines = ""
    @State private var appleApps = ""
    @State private var familyHardware = ""
    @State private var biggestApplePain = ""
    @AppStorage("onboarding_start_step") private var onboardingStartStep = 0
    @Namespace private var navNamespace

    private let totalSteps = 5
    private var personalMemories: MemoryRepository {
        MemoryRepository(context: NOBSDatabase.shared.isPersonalModeEnabled ? .personal : .work)
    }

    var body: some View {
        ZStack {
            Color.nobsBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content — .tag() is required for selection binding to work
                TabView(selection: $step) {
                    welcomePage.tag(0)
                    transparencyPage.tag(1)
                    privacyPage.tag(2)
                    interviewPage.tag(3)
                    donePage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Glass navigation bar
                GlassEffectContainer(spacing: 20) {
                    HStack(spacing: 20) {
                        if step > 0 {
                            Button("Back") {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { step -= 1 }
                            }
                            .font(NOBSFont.body())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .glassEffect(.regular.interactive())
                            .glassEffectID("back", in: navNamespace)
                            .glassEffectTransition(.materialize)
                            .accessibilityLabel("Go back to the previous page")
                        }

                        Spacer()

                        // Animated pill step indicator
                        HStack(spacing: 6) {
                            ForEach(0..<totalSteps, id: \.self) { i in
                                Capsule()
                                    .fill(i == step ? Color.nobsAccent : Color.secondary.opacity(0.3))
                                    .frame(width: i == step ? 22 : 6, height: 6)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: step)
                            }
                        }

                        Spacer()

                        Button(step == totalSteps - 1 ? "Get Started" : "Next") {
                            if step == totalSteps - 1 {
                                finish()
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { step += 1 }
                            }
                        }
                        .disabled(step == 3 && displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .font(NOBSFont.headline())
                        .foregroundStyle(Color.nobsAccent)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .glassEffect(.regular.tint(Color.nobsAccent).interactive())
                        .glassEffectID("next", in: navNamespace)
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
        }
        .onAppear {
            if onboardingStartStep > 0 {
                step = min(onboardingStartStep, totalSteps - 1)
                onboardingStartStep = 0
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            NobsLogo(size: 96)
                .nobsShadow(strong: true)
            VStack(spacing: Spacing.sm) {
                Text("Welcome to NOBS")
                    .font(NOBSFont.largeTitle())
                    .foregroundStyle(Color.nobsPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Welcome to NOBS.")
                Text("A trusted companion that knows you,\nremembers what matters, and always\nhas your back. Private. Secure. Yours.")
                    .font(NOBSFont.body())
                    .foregroundStyle(Color.nobsSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(Spacing.xl)
    }

    private var transparencyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.nobsAccent)
                    Text("How NOBS Keeps You Safe")
                        .font(NOBSFont.title2())
                        .foregroundStyle(Color.nobsPrimary)
                }
                .padding(.top, Spacing.md)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    securityRow(icon: "faceid", title: "Only You Get In",
                        detail: "NOBS recognizes your face. Every time you come back, it checks it's really you.")
                    securityRow(icon: "lock.fill", title: "Everything is Locked",
                        detail: "All your personal information is stored in a locked vault. The only key is on your device.")
                    securityRow(icon: "rectangle.stack.fill", title: "Stored Separately",
                        detail: "Each memory and note is sealed individually — nobody sees your private data.")
                    securityRow(icon: "antenna.radiowaves.left.and.right.slash", title: "Stays on Your Device",
                        detail: "Your information lives on your phone, not on a server. Nobody can read your data.")
                    securityRow(icon: "icloud.slash.fill", title: "No Cloud by Default",
                        detail: "NOBS works completely offline. Enable iCloud sync only if you choose to.")
                    securityRow(icon: "shippingbox.fill", title: "Encrypted in Transit",
                        detail: "When NOBS reaches your private server, everything is sealed end-to-end.")
                }
            }
            .padding(Spacing.lg)
        }
    }

    private var privacyPage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(Color.nobsAccent)
            Text("What NOBS Will Never Do")
                .font(NOBSFont.title2())
                .foregroundStyle(Color.nobsPrimary)

            NOBSCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    privacyRow(icon: "xmark.circle.fill", color: .nobsRed, text: "Share your information with anyone")
                    privacyRow(icon: "xmark.circle.fill", color: .nobsRed, text: "Sell your data or hand it to a third party")
                    privacyRow(icon: "xmark.circle.fill", color: .nobsRed, text: "Access your private notes — only you hold the key")
                    privacyRow(icon: "checkmark.circle.fill", color: .nobsGreen, text: "You are always in control. Always.")
                }
            }
            .padding(.horizontal, Spacing.md)

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
    }

    private var interviewPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.nobsAccent)
                    Text("30-Minute Apple Interview")
                        .font(NOBSFont.title2())
                        .foregroundStyle(Color.nobsPrimary)
                }
                .padding(.top, Spacing.md)

                Text("This is the first pass. NOBS uses it to recommend how your iPhone, Mac, iCloud, Reminders, Calendar, Notes, calls, family devices, and Tank should work together. Everything stays sealed on your device.")
                    .font(NOBSFont.body())
                    .foregroundStyle(Color.nobsSecondary)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("What should NOBS call you?")
                        .font(NOBSFont.headline())
                        .foregroundStyle(Color.nobsPrimary)
                    NOBSTextField(placeholder: "Your name", text: $displayName, icon: "person")
                        .accessibilityLabel("Enter your display name")
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("What Apple apps do you already live in?")
                        .font(NOBSFont.headline())
                        .foregroundStyle(Color.nobsPrimary)
                    TextEditor(text: $appleApps)
                        .font(NOBSFont.body())
                        .frame(minHeight: 80)
                        .padding(Spacing.sm)
                        .background(Color.nobsCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .nobsShadow()
                        .accessibilityLabel("Enter the Apple apps you use most")
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("What should NOBS help with every week?")
                        .font(NOBSFont.headline())
                        .foregroundStyle(Color.nobsPrimary)
                    TextEditor(text: $interests)
                        .font(NOBSFont.body())
                        .frame(minHeight: 80)
                        .padding(Spacing.sm)
                        .background(Color.nobsCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .nobsShadow()
                        .accessibilityLabel("Enter what NOBS should help with")
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("What devices can your family use?")
                        .font(NOBSFont.headline())
                        .foregroundStyle(Color.nobsPrimary)
                    TextEditor(text: $familyHardware)
                        .font(NOBSFont.body())
                        .frame(minHeight: 80)
                        .padding(Spacing.sm)
                        .background(Color.nobsCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .nobsShadow()
                        .accessibilityLabel("Enter family hardware")
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Where does Apple feel messy right now?")
                        .font(NOBSFont.headline())
                        .foregroundStyle(Color.nobsPrimary)
                    TextEditor(text: $biggestApplePain)
                        .font(NOBSFont.body())
                        .frame(minHeight: 80)
                        .padding(Spacing.sm)
                        .background(Color.nobsCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .nobsShadow()
                        .accessibilityLabel("Enter your biggest Apple workflow problem")
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Any daily habits or routines NOBS should protect?")
                        .font(NOBSFont.headline())
                        .foregroundStyle(Color.nobsPrimary)
                    TextEditor(text: $routines)
                        .font(NOBSFont.body())
                        .frame(minHeight: 80)
                        .padding(Spacing.sm)
                        .background(Color.nobsCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .nobsShadow()
                        .accessibilityLabel("Enter your daily routines")
                }

                Text("The full interview can become a voice-led session later. For this build, these answers seed the private recommendation plan.")
                    .font(NOBSFont.caption())
                    .foregroundStyle(Color.nobsTertiary)
            }
            .padding(Spacing.lg)
        }
    }

    private var donePage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80, weight: .semibold))
                .foregroundStyle(Color.nobsGreen)
            VStack(spacing: Spacing.sm) {
                Text("You're All Set!")
                    .font(NOBSFont.largeTitle())
                    .foregroundStyle(Color.nobsPrimary)
                Text("Your profile is saved privately on your device.\nNOBS is ready to help — whenever you need it.")
                    .font(NOBSFont.body())
                    .foregroundStyle(Color.nobsSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(Spacing.xl)
    }

    // MARK: - Helpers

    private func securityRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.nobsAccent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NOBSFont.headline())
                    .foregroundStyle(Color.nobsPrimary)
                Text(detail)
                    .font(NOBSFont.callout())
                    .foregroundStyle(Color.nobsSecondary)
            }
        }
    }

    private func privacyRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(NOBSFont.body())
                .foregroundStyle(Color.nobsPrimary)
        }
    }

    private func finish() {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            _ = try? personalMemories.save(content: name, tags: ["profile", "display_name", "personal"])
        }
        if !interests.isEmpty {
            _ = try? personalMemories.save(content: interests, tags: ["profile", "bio", "personal"])
        }
        if !appleApps.isEmpty {
            _ = try? personalMemories.save(content: appleApps, tags: ["profile", "apple_apps", "interview"])
        }
        if !familyHardware.isEmpty {
            _ = try? personalMemories.save(content: familyHardware, tags: ["profile", "family_hardware", "interview"])
        }
        if !biggestApplePain.isEmpty {
            _ = try? personalMemories.save(content: biggestApplePain, tags: ["profile", "apple_pain", "interview"])
        }
        if !routines.isEmpty {
            _ = try? personalMemories.save(content: routines, tags: ["profile", "routines", "personal"])
        }
        isComplete = true
    }
}
