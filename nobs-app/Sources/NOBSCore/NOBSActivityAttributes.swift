#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// Shared Live Activity attributes — imported by both the app and widget targets via NOBSCore.
public struct NOBSActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// "thinking", "done", or "error"
        public var phase: String
        public var message: String

        public init(phase: String, message: String) {
            self.phase = phase
            self.message = message
        }
    }

    public let userName: String

    public init(userName: String) {
        self.userName = userName
    }
}
#endif
