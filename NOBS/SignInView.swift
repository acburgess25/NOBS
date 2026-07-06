import AuthenticationServices
import SwiftUI

// MARK: - Sign In View (shown in onboarding step 3 and Privacy tab)

struct SignInView: View {
    let mode: Mode
    @ObservedObject var model: AppModel
    let onComplete: () -> Void

    enum Mode {
        case onboarding  // Full-screen step in onboarding
        case settings    // Compact card in Privacy tab
    }

    private let accent = Color(red: 0.31, green: 0.43, blue: 0.20)

    var body: some View {
        switch mode {
        case .onboarding: onboardingLayout
        case .settings: settingsLayout
        }
    }

    // MARK: Onboarding layout

    private var onboardingLayout: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Image(systemName: "server.rack")
                .font(.system(size: 42))
                .foregroundStyle(accent)
            Text("Connect to\nyour Tank.")
                .font(.system(size: 42, weight: .regular, design: .serif))
            Text("Sign in with Apple to automatically pair with your Tank on the home network. No password, no token to copy.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineSpacing(4)

            if let status = model.tankConnectStatus {
                Label(status, systemImage: statusIcon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(statusColor)
                    .padding(.vertical, 4)
            }

            Spacer()

            VStack(spacing: 14) {
                if model.isSigningIn {
                    ProgressView("Connecting to Tank…")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                } else if model.tankAvailable && model.tankToken != "" {
                    // Already connected — show success and skip button
                    Label("Connected to Tank", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(accent)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    Button("Continue") { onComplete() }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    signInButton
                    Button("Skip for now") { onComplete() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(28)
    }

    // MARK: Settings layout

    private var settingsLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Apple Sign-In", systemImage: "apple.logo")
                .font(.headline)

            if let uid = model.appleUserID {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                    Text("Signed in")
                        .font(.subheadline)
                    Spacer()
                    Text(String(uid.prefix(12)) + "…")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sign in to automatically connect this iPhone to your Tank.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if model.isSigningIn {
                    ProgressView("Connecting…")
                } else {
                    signInButton
                }
            }
        }
    }

    // MARK: Shared sign-in button

    private var signInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
                Task {
                    await model.signInWithApple(
                        userIdentifier: credential.user,
                        identityToken: credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
                    )
                    if model.tankAvailable { onComplete() }
                }
            case .failure(let error):
                model.lastError = "Sign in with Apple failed: \(error.localizedDescription)"
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .accessibilityLabel("Sign in with Apple to connect to Tank")
    }

    private var statusIcon: String {
        guard let status = model.tankConnectStatus else { return "info.circle" }
        if status.contains("Connected") { return "checkmark.circle.fill" }
        if status.contains("not registered") || status.contains("failed") { return "exclamationmark.triangle" }
        return "arrow.triangle.2.circlepath"
    }

    private var statusColor: Color {
        guard let status = model.tankConnectStatus else { return .secondary }
        if status.contains("Connected") { return accent }
        if status.contains("not registered") || status.contains("failed") { return .orange }
        return .secondary
    }
}
