import TipKit
import SwiftUI

// MARK: - Tip Definitions

struct MemoriesTip: Tip {
    var title: Text { Text("Save Anything") }
    var message: Text? { Text("Tap + to store a memory — facts, notes, or anything you want NOBS to remember. It stays encrypted on your device.") }
    var image: Image? { Image("NOBSBrandMark") }
}

struct TasksTip: Tip {
    var title: Text { Text("Stay on Top of Things") }
    var message: Text? { Text("Add tasks with optional due dates. NOBS sends a reminder when they're coming up.") }
    var image: Image? { Image(systemName: "checklist") }
}

struct VoiceTip: Tip {
    var title: Text { Text("Use Your Voice") }
    var message: Text? { Text("Ask NOBS anything in plain English — \"Remind me to call mom at 5pm\" or \"Save that idea I just had.\"") }
    var image: Image? { Image(systemName: "mic.fill") }
}

struct InsightsTip: Tip {
    var title: Text { Text("Track Your Productivity") }
    var message: Text? { Text("See how many tasks and memories you've logged over time — tap Insights to view your activity charts.") }
    var image: Image? { Image(systemName: "chart.bar.fill") }
}
