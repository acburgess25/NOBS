import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Control Center Widget

/// Appears in Control Center on iOS 18+. One tap → ask NOBS. No app required.
@available(iOS 18.0, *)
struct NOBSControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.nobsdash.nobs.control.ask") {
            ControlWidgetButton(action: AskNOBSControlAction()) {
                Label {
                    Text("Ask NOBS")
                } icon: {
                    Image("NOBSBrandMark")
                }
            }
        }
        .displayName("Ask NOBS")
        .description("Talk to your private AI from anywhere.")
    }
}

/// Tapping the Control Center button — Siri collects the question.
struct AskNOBSControlAction: AppIntent {
    static var title: LocalizedStringResource = "Ask NOBS"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Bundle

@main
struct NOBSControlBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 18.0, *) {
            NOBSControlWidget()
        }
    }
}
