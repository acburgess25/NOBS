import SwiftUI
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
                NavigationLink(destination: MemoriesView()) {
                    SidebarRow(icon: "brain.head.profile", label: "Memories", color: .nobsAccent)
                }
                NavigationLink(destination: TasksView()) {
                    SidebarRow(icon: "checklist", label: "Tasks", color: .nobsGreen)
                }
                Section("Tools") {
                    NavigationLink(destination: RemindersView()) {
                        SidebarRow(icon: "bell.fill", label: "Reminders", color: .nobsAccent)
                    }
                    NavigationLink(destination: PhoneView()) {
                        SidebarRow(icon: "phone.fill", label: "Phone", color: .nobsGreen)
                    }
                    NavigationLink(destination: IntegrationsView()) {
                        SidebarRow(icon: "square.grid.2x2.fill", label: "Integrations", color: .nobsSecondary)
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
            VStack(spacing: Spacing.lg) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Color.nobsAccent)
                Text("Your personal AI")
                    .font(NOBSFont.title(20))
                    .foregroundStyle(Color.nobsPrimary)
                Text("Select a section to get started")
                    .font(NOBSFont.body())
                    .foregroundStyle(Color.nobsSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.nobsBg)
        }
    }

    // MARK: - iPhone Tab View
    private var phoneView: some View {
        TabView {
            MemoriesView()
                .tabItem { Label("Memories", systemImage: "brain.head.profile") }

            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }

            NOBSMoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }

            SettingsView(auth: auth)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
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
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    MoreSection(title: "Notifications") {
                        MoreRow(icon: "bell.fill", label: "Reminders", color: .nobsAccent, destination: AnyView(RemindersView()))
                    }
                    MoreSection(title: "Communication") {
                        MoreRow(icon: "phone.fill", label: "Phone", color: .nobsGreen, destination: AnyView(PhoneView()))
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.nobsSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.nobsSecondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("iMessage")
                                    .font(NOBSFont.body())
                                    .foregroundStyle(Color.nobsPrimary)
                                Text("Set up BlueBubbles in Settings → iMessage Contact")
                                    .font(NOBSFont.caption())
                                    .foregroundStyle(Color.nobsSecondary)
                            }
                            Spacer()
                        }
                        .padding(Spacing.md)
                    }
                    MoreSection(title: "Connections") {
                        MoreRow(icon: "square.grid.2x2.fill", label: "Integrations", color: .nobsSecondary, destination: AnyView(IntegrationsView()))
                    }
                    MoreSection(title: "Siri & Shortcuts") {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.nobsAccent)
                                .frame(width: 30, height: 30)
                                .background(Color.nobsAccent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text("Ask Siri to save memories, add tasks, or check your list")
                                .font(NOBSFont.caption())
                                .foregroundStyle(Color.nobsSecondary)
                            Spacer()
                        }
                        .padding(Spacing.md)
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.nobsBg)
            .navigationTitle("More")
        }
    }
}

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
