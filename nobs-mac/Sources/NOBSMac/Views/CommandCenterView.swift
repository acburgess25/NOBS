import SwiftUI

struct CommandCenterView: View {
    @Environment(CommandCenterStore.self) private var store
    @Namespace private var selectionAnimation
    @AppStorage("hasSeenNOBSIntro") private var hasSeenIntro = false
    @State private var showingIntro = false

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            SidebarView(selectionAnimation: selectionAnimation)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            DetailSwitchView()
                .safeAreaInset(edge: .bottom) {
                    bottomStatusBar
                }
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search NOBS")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Runtime", selection: $store.runtimeMode) {
                    ForEach(RuntimeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
                .onChange(of: store.runtimeMode) { _, _ in
                    Task { await store.refreshRuntimeStatus() }
                }

                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    showingIntro = true
                } label: {
                    Label("Intro", systemImage: "play.rectangle")
                }

                Button {
                    Task { await store.distillMemory() }
                } label: {
                    Label("Distill Memory", systemImage: "wand.and.sparkles")
                }
                .disabled(store.isWorking)

                Menu {
                    Button("Open AI Root", systemImage: "folder") {
                        store.openAIRoot()
                    }
                    Button("Open NOBS App", systemImage: "shippingbox") {
                        store.openNOBSApp()
                    }
                    Button("Open Vault", systemImage: "archivebox") {
                        store.openVault()
                    }
                } label: {
                    Label("Open", systemImage: "rectangle.stack.badge.play")
                }
            }
        }
        .sheet(isPresented: $showingIntro) {
            NOBSIntroView(autoplay: !hasSeenIntro) {
                hasSeenIntro = true
            }
        }
        .task {
            if !hasSeenIntro {
                showingIntro = true
            }
        }
    }

    private var bottomStatusBar: some View {
        HStack(spacing: 10) {
            StatusPulse(tint: store.isWorking ? .nobsAmber : store.activeRoute.tint.color)
                .frame(width: 32, height: 32)
                .scaleEffect(0.74)

            Text(store.isWorking ? "Working" : store.runtimeStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Label(store.activeRoute.title, systemImage: store.activeRoute.symbolName)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(.bar)
    }
}

struct SidebarView: View {
    @Environment(CommandCenterStore.self) private var store
    let selectionAnimation: Namespace.ID

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedSection) {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    NOBSBrandLockup(compact: true)
                    Text("Local-first command center")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            .listRowSeparator(.hidden)

            Section("NOBS") {
                ForEach(NOBSSection.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.symbolName)
                            .symbolVariant(store.selectedSection == section ? .fill : .none)
                    }
                    .tag(section)
                }
            }
        }
        .navigationTitle("NOBS")
    }
}

struct DetailSwitchView: View {
    @Environment(CommandCenterStore.self) private var store

    var body: some View {
        switch store.selectedSection ?? .dashboard {
        case .dashboard:
            DashboardView()
        case .tankAI:
            TankAIView()
        case .chat:
            ChatView()
        case .memory:
            MemoryView()
        case .agents:
            AgentsView()
        case .family:
            FamilyView()
        case .skills:
            SkillsSecurityView()
        case .apple:
            AppleIntegrationView()
        case .tank:
            TankView()
        case .settings:
            SettingsView()
        }
    }
}
