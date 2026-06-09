import SwiftUI
import TipKit
import NOBSAssistant

struct ContentView: View {
    let auth: APIClient
    let assistant: NOBSAssistant
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        if hSize == .regular {
            splitView
        } else {
            phoneView
        }
    }

    // MARK: - iPad Split View

    private var splitView: some View {
        NavigationSplitView {
            List {
                NavigationLink(destination: NOBSChatView(assistant: assistant)) {
                    SidebarRow(icon: "bubble.left.and.bubble.right.fill", label: "Health Coach", color: .nobsAccent)
                }
                NavigationLink(destination: MemoriesView()) {
                    SidebarRow(icon: "heart.text.square.fill", label: "Health Logs", color: .nobsAccent)
                }
                NavigationLink(destination: TasksView()) {
                    SidebarRow(icon: "checklist", label: "Meds Schedule", color: .nobsGreen)
                }
                Section("Tools") {
                    NavigationLink(destination: RemindersView()) {
                        SidebarRow(icon: "bell.fill", label: "Wellness Reminders", color: .nobsAccent)
                    }
                    NavigationLink(destination: PhoneView()) {
                        SidebarRow(icon: "phone.fill", label: "Care Phone", color: .nobsGreen)
                    }
                    NavigationLink(destination: NOBSInsightsView()) {
                        SidebarRow(icon: "eye.fill", label: "Wellness & Screen Time", color: .nobsAccent)
                    }
                    NavigationLink(destination: IntegrationsView()) {
                        SidebarRow(icon: "square.grid.2x2.fill", label: "Apple Health & Sync", color: .nobsSecondary)
                    }
                }
                Section("Account") {
                    NavigationLink(destination: SettingsView(auth: auth)) {
                        SidebarRow(icon: "gearshape.fill", label: "Settings", color: .nobsSecondary)
                    }
                }
            }
            .navigationTitle("NOBS")
            .scrollContentBackground(.hidden)
            .background(Color.nobsBg)
        } detail: {
            NOBSChatView(assistant: assistant)
        }
    }

    // MARK: - iPhone Tab View

    private var phoneView: some View {
        TabView {
            NOBSHomeView()
                .tabItem { Label("Health", systemImage: "heart.fill") }

            NOBSChatView(assistant: assistant)
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right.fill") }

            MemoriesView()
                .tabItem { Label("Logs", systemImage: "heart.text.square.fill") }

            NOBSMoreView(auth: auth)
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        .tint(Color.nobsAccent)
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(label)
                .font(NOBSFont.body())
                .foregroundStyle(Color.nobsPrimary)
        }
    }
}

// MARK: - More View

struct NOBSMoreView: View {
    let auth: APIClient
    private let insightsTip = InsightsTip()
    private let voiceTip = VoiceTip()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    MoreSection(title: "Notifications") {
                        MoreRow(icon: "bell.fill", label: "Wellness Reminders", color: .nobsAccent, destination: AnyView(RemindersView()))
                    }
                    MoreSection(title: "Communication") {
                        MoreRow(icon: "phone.fill", label: "Care Phone", color: .nobsGreen, destination: AnyView(PhoneView()))
                        MoreRow(icon: "message.fill", label: "iMessage Sync", color: .nobsSecondary, destination: AnyView(IMessagesView()))
                    }
                    MoreSection(title: "Productivity & Health") {
                        MoreRow(icon: "checklist", label: "Meds Schedule", color: .nobsGreen, destination: AnyView(TasksView()))
                        MoreRow(icon: "eye.fill", label: "Wellness & Screen Time", color: .nobsAccent, destination: AnyView(NOBSInsightsView()))
                            .popoverTip(insightsTip)
                    }
                    MoreSection(title: "Connections") {
                        MoreRow(icon: "square.grid.2x2.fill", label: "Apple Health & Sync", color: .nobsSecondary, destination: AnyView(IntegrationsView()))
                    }
                    MoreSection(title: "Siri AI & Shortcuts") {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.nobsAccent)
                                .frame(width: 30, height: 30)
                                .background(Color.nobsAccent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text("Ask Siri AI to log medications, check screen time, or record symptoms")
                                .font(NOBSFont.caption())
                                .foregroundStyle(Color.nobsSecondary)
                            Spacer()
                        }
                        .padding(Spacing.md)
                        .popoverTip(voiceTip)
                    }
                    MoreSection(title: "Account") {
                        MoreRow(icon: "gearshape.fill", label: "Settings", color: .nobsSecondary, destination: AnyView(SettingsView(auth: auth)))
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.nobsBg)
            .navigationTitle("More")
        }
    }
}

// MARK: - More Section / Row

private struct MoreSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.uppercased())
                .font(NOBSFont.caption(11))
                .foregroundStyle(Color.nobsTertiary)
                .padding(.horizontal, Spacing.xs)
            NOBSCard(padding: 0) {
                VStack(spacing: 0) { content }
            }
        }
    }
}

private struct MoreRow: View {
    let icon: String
    let label: String
    let color: Color
    let destination: AnyView

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(label)
                    .font(NOBSFont.body())
                    .foregroundStyle(Color.nobsPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.nobsTertiary)
            }
            .padding(Spacing.md)
        }
        .buttonStyle(.plain)
    }
}
