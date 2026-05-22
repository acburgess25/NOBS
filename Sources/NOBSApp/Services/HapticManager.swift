/// HapticManager — Centralized Haptic Feedback
///
/// Singleton wrapper over UIKit haptic generators.
/// All app actions route through named methods so we can tune
/// feedback globally without hunting call sites.

import UIKit

// MARK: - HapticManager

final class HapticManager {

    // MARK: Shared

    static let shared = HapticManager()
    private init() {}

    // MARK: - Impact generators (pre-warmed lazily)

    private lazy var lightImpact   = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpact  = UIImpactFeedbackGenerator(style: .medium)
    private lazy var rigidImpact   = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var notification  = UINotificationFeedbackGenerator()
    private lazy var selection     = UISelectionFeedbackGenerator()

    // MARK: - Named actions

    /// Fired when a task is marked complete — success chime feel
    func taskCompleted() {
        notification.prepare()
        notification.notificationOccurred(.success)
    }

    /// Fired when a new task is created — medium punch
    func taskCreated() {
        mediumImpact.prepare()
        mediumImpact.impactOccurred()
    }

    /// Fired when a memory is saved — subtle confirmation
    func memoryAdded() {
        lightImpact.prepare()
        lightImpact.impactOccurred()
    }

    /// Generic button tap — crisp rigid tap
    func buttonTap() {
        rigidImpact.prepare()
        rigidImpact.impactOccurred()
    }

    /// Fired before destructive actions (delete, reset) — warning pattern
    func destructiveAction() {
        notification.prepare()
        notification.notificationOccurred(.warning)
    }

    /// Fired when picker / segment selection changes
    func selectionChanged() {
        selection.prepare()
        selection.selectionChanged()
    }
}
