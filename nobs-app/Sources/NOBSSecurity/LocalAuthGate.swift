/// NOBSSecurity — LocalAuthGate
///
/// A lightweight gate that requires the user to authenticate with Face ID,
/// Touch ID, or their device passcode before a sensitive operation is allowed
/// to proceed.
///
/// Typical usage:
/// ```swift
/// let gate = LocalAuthGate()
/// try await gate.requireAuthentication()
/// // … perform sensitive operation …
/// ```
///
/// The gate caches a successful authentication for `sessionDuration` seconds
/// (default 5 minutes) so the user is not prompted repeatedly within a
/// single working session.  Call `invalidate()` to force re-authentication
/// (e.g. when the app is backgrounded).
///
/// On platforms where `LocalAuthentication` is unavailable (Linux / CI) the
/// gate compiles to a stub that always succeeds.

import Foundation

// MARK: - LocalAuthError

public enum LocalAuthError: Error, LocalizedError, Sendable {
    case authenticationFailed(String)
    case biometryNotAvailable
    case biometryNotEnrolled
    case cancelled
    case notSupported

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed(let reason): return "Authentication failed: \(reason)"
        case .biometryNotAvailable:             return "Biometric authentication is not available on this device"
        case .biometryNotEnrolled:              return "No biometrics are enrolled. Please set up Face ID or Touch ID."
        case .cancelled:                        return "Authentication was cancelled"
        case .notSupported:                     return "LocalAuthentication is not supported on this platform"
        }
    }
}

// MARK: - AuthPolicy

/// The authentication policy the gate will enforce.
public enum AuthPolicy: Sendable {
    /// Prefer biometrics (Face ID / Touch ID); fall back to the device passcode.
    /// This is the recommended policy for most use-cases.
    case biometricOrPasscode

    /// Require biometrics only — no passcode fallback.
    /// Use when you want to ensure the user is physically present.
    case biometricOnly
}

#if canImport(LocalAuthentication)
import LocalAuthentication

// MARK: - LocalAuthGate (full implementation)

/// Requires Face ID / Touch ID / passcode authentication before sensitive
/// operations are allowed to proceed.  Successful authentications are cached
/// for `sessionDuration` seconds.
public actor LocalAuthGate {
    private let policy:          AuthPolicy
    private let reason:          String
    private let sessionDuration: TimeInterval
    private var lastAuthDate:    Date?

    /// - Parameters:
    ///   - policy:          The authentication policy to apply.
    ///   - reason:          The string shown in the system authentication dialog.
    ///   - sessionDuration: How long (in seconds) a successful authentication
    ///                      remains valid before the user must re-authenticate.
    ///                      Defaults to 300 s (5 minutes).
    public init(
        policy:          AuthPolicy  = .biometricOrPasscode,
        reason:          String      = "Authenticate to use NOBS",
        sessionDuration: TimeInterval = 300
    ) {
        self.policy          = policy
        self.reason          = reason
        self.sessionDuration = sessionDuration
    }

    // MARK: - Public API

    /// Returns `true` when the user has authenticated recently (within
    /// `sessionDuration`).
    public var isAuthenticated: Bool {
        guard let date = lastAuthDate else { return false }
        return Date().timeIntervalSince(date) < sessionDuration
    }

    /// Require the user to authenticate.  Returns immediately if a valid
    /// cached authentication exists; otherwise presents the system dialog.
    ///
    /// - Throws: `LocalAuthError` if authentication fails or is cancelled.
    public func requireAuthentication() async throws {
        guard !isAuthenticated else { return }
        try await authenticate()
    }

    /// Force immediate re-authentication regardless of the cached state.
    public func forceAuthentication() async throws {
        lastAuthDate = nil
        try await authenticate()
    }

    /// Invalidate the cached authentication (e.g. call when the app enters
    /// the background so the next foreground use requires a fresh prompt).
    public func invalidate() {
        lastAuthDate = nil
    }

    // MARK: - Private helpers

    private func authenticate() async throws {
        let context = LAContext()
        let laPolicy = laPolicyValue(for: policy)

        var authError: NSError?
        guard context.canEvaluatePolicy(laPolicy, error: &authError) else {
            throw mapLAError(authError)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(laPolicy, localizedReason: self.reason) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: self.mapLAError(error as NSError?))
                }
            }
        }

        lastAuthDate = Date()
    }

    private func laPolicyValue(for policy: AuthPolicy) -> LAPolicy {
        switch policy {
        case .biometricOrPasscode: return .deviceOwnerAuthentication
        case .biometricOnly:       return .deviceOwnerAuthenticationWithBiometrics
        }
    }

    private nonisolated func mapLAError(_ error: NSError?) -> LocalAuthError {
        guard let error else { return .authenticationFailed("Unknown error") }
        switch error.code {
        case LAError.authenticationFailed.rawValue:  return .authenticationFailed(error.localizedDescription)
        case LAError.biometryNotAvailable.rawValue:  return .biometryNotAvailable
        case LAError.biometryNotEnrolled.rawValue:   return .biometryNotEnrolled
        case LAError.userCancel.rawValue,
             LAError.appCancel.rawValue,
             LAError.systemCancel.rawValue:          return .cancelled
        default:                                     return .authenticationFailed(error.localizedDescription)
        }
    }
}

#else
// MARK: - LocalAuthGate (stub for Linux / CI)

/// No-op stub for platforms where LocalAuthentication is unavailable.
/// `requireAuthentication()` always succeeds immediately.
public actor LocalAuthGate {
    public let policy:          AuthPolicy
    public let reason:          String
    public let sessionDuration: TimeInterval

    public init(
        policy:          AuthPolicy   = .biometricOrPasscode,
        reason:          String       = "Authenticate to use NOBS",
        sessionDuration: TimeInterval = 300
    ) {
        self.policy          = policy
        self.reason          = reason
        self.sessionDuration = sessionDuration
    }

    public var isAuthenticated: Bool { true }

    public func requireAuthentication() async throws {}
    public func forceAuthentication()   async throws {}
    public func invalidate() {}
}
#endif
