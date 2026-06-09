#if canImport(ActivityKit)
import ActivityKit
import NOBSCore
import Foundation

@MainActor
final class NOBSLiveActivityManager {
    static let shared = NOBSLiveActivityManager()
    private var current: Activity<NOBSActivityAttributes>?
    private init() {}

    func startThinking(userName: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, current == nil else { return }
        let attrs = NOBSActivityAttributes(userName: userName)
        let state = NOBSActivityAttributes.ContentState(phase: "thinking", message: "NOBS is thinking…")
        let content = ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(300))
        current = try? Activity.request(attributes: attrs, content: content)
    }

    func update(message: String) async {
        guard let current else { return }
        let state = NOBSActivityAttributes.ContentState(phase: "thinking", message: message)
        let content = ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(300))
        await current.update(content)
    }

    func end(reply: String) async {
        guard let current else { return }
        let state = NOBSActivityAttributes.ContentState(phase: "done", message: reply)
        let content = ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(30))
        await current.end(content, dismissalPolicy: .after(Date.now.addingTimeInterval(10)))
        self.current = nil
    }
}
#endif
