import SwiftUI

struct DashboardView: View {
    @Environment(CommandCenterStore.self) private var store
    @State private var heroExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(
                    title: "Command Center",
                    subtitle: "Private family AI for Apple devices, local hubs, Tank beta, and shared memory."
                )

                heroPanel

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                    ForEach(store.signals) { signal in
                        NOBSMetric(signal: signal)
                    }
                }

                hardwareSummary

                HStack(alignment: .top, spacing: 16) {
                    quickActions
                    recentMemory
                }
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var heroPanel: some View {
        GlassPanel(padding: 0, radius: 28) {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    NOBSBrandLockup()

                    Text("Private family AI, built into the Mac")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineLimit(2)

                    Text("Manage Tank AI, local agents, Apple-family roles, iCloud memory, Tank beta access, and permission-first automations from one native desktop surface.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button {
                            store.selectedSection = .tankAI
                        } label: {
                            Label("Tank AI", systemImage: "person.2.wave.2")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            store.selectedSection = .chat
                        } label: {
                            Label("Chat", systemImage: "bubble.left.and.bubble.right")
                        }
                    }
                }

                Spacer()

                SignalNetworkView()
                .frame(width: 190, height: 160)
            }
            .padding(26)
            .onAppear {
                withAnimation(.smooth(duration: 1.4).repeatForever(autoreverses: true)) {
                    heroExpanded = true
                }
            }
        }
    }

    private var quickActions: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Quick Actions")
                    .font(.headline)

                Button("Open AI Root", systemImage: "folder") {
                    store.openAIRoot()
                }
                Button("Open NOBS App", systemImage: "shippingbox") {
                    store.openNOBSApp()
                }
                Button("Open Vault", systemImage: "archivebox") {
                    store.openVault()
                }
                Button("Tank AI", systemImage: "person.2.wave.2") {
                    store.selectedSection = .tankAI
                }
                Button("Family Setup", systemImage: "person.3.sequence") {
                    store.selectedSection = .family
                }
                Button("Tank Beta", systemImage: "checkmark.seal") {
                    store.selectedSection = .tank
                }
                Button("Refresh Memory", systemImage: "arrow.clockwise") {
                    Task { await store.refresh() }
                }
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 280)
    }

    private var hardwareSummary: some View {
        let recommendation = store.hardwareProfile.recommendation

        return GlassPanel {
            HStack(spacing: 16) {
                Image(systemName: recommendation.route.symbolName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(recommendation.route.tint.color)
                    .frame(width: 48, height: 48)
                    .background(recommendation.route.tint.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Hardware route")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(recommendation.title)
                        .font(.headline)
                    Text(recommendation.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    store.selectedSection = .agents
                } label: {
                    Label("Review", systemImage: "slider.horizontal.3")
                }
            }
        }
    }

    private var recentMemory: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recent Memory")
                    .font(.headline)

                if store.memoryNotes.isEmpty {
                    Label("No iCloud memory files loaded yet", systemImage: "icloud.slash")
                        .foregroundStyle(.secondary)
                }

                ForEach(store.memoryNotes.prefix(4)) { note in
                    Button {
                        store.selectedNote = note
                        store.selectedSection = .memory
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(note.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(note.relativePath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
