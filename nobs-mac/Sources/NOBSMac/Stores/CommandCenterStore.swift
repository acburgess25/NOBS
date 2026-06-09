import Foundation
import Observation

@Observable
final class CommandCenterStore {
    var selectedSection: NOBSSection? = .dashboard
    var searchText = ""
    var memoryNotes: [MemoryNote] = []
    var selectedNote: MemoryNote?
    var localPrompt = ""
    var chatTranscript: [String] = [
        "Tank AI is ready for you two, with private memory, shared plans, and fast offline fallback."
    ]
    var isWorking = false
    var runtimeMode: RuntimeMode = .auto
    var isOnlineRouteAvailable = false
    var morningDocumentApproved = false
    var lastRunOutput = ""
    var hardwareProfile: HardwareProfile = .unknown

    private let memoryService = MemoryFileService()
    private let workspaceService = WorkspaceService()
    private let hardwareProfiler = HardwareProfiler()

    var signals: [SystemSignal] {
        [
            SystemSignal(title: "Memory", value: "\(memoryNotes.count) files", symbolName: "icloud.and.arrow.down", tint: .sage),
            SystemSignal(title: "Hardware", value: hardwareProfile.recommendation.route.rawValue, symbolName: hardwareProfile.recommendation.route.symbolName, tint: hardwareProfile.recommendation.route.tint),
            SystemSignal(title: "Runtime", value: activeRoute.title, symbolName: activeRoute.symbolName, tint: activeRoute.tint),
            SystemSignal(title: "Workspace", value: "NOBS", symbolName: "folder", tint: .amber),
            SystemSignal(title: "Mode", value: runtimeMode.title, symbolName: "lock.shield", tint: .graphite)
        ]
    }

    var activeRoute: ConnectivityRoute {
        switch runtimeMode {
        case .auto:
            isOnlineRouteAvailable ? .online : .offline
        case .online:
            .online
        case .offline:
            .offline
        }
    }

    var runtimeStatusText: String {
        switch runtimeMode {
        case .auto:
            isOnlineRouteAvailable ? "Auto: online route ready" : "Auto: offline route ready"
        case .online:
            isOnlineRouteAvailable ? "Online route ready" : "Online selected, fallback armed"
        case .offline:
            "Offline route locked"
        }
    }

    var filteredNotes: [MemoryNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return memoryNotes }

        return memoryNotes.filter { note in
            note.title.localizedCaseInsensitiveContains(query)
                || note.relativePath.localizedCaseInsensitiveContains(query)
                || note.body.localizedCaseInsensitiveContains(query)
        }
    }

    @MainActor
    func refresh() async {
        memoryNotes = memoryService.loadNotes()
        selectedNote = selectedNote ?? memoryNotes.first
        hardwareProfile = await hardwareProfiler.currentProfile()
        isOnlineRouteAvailable = await workspaceService.isOnlineRouteAvailable()
    }

    @MainActor
    func refreshRuntimeStatus() async {
        isOnlineRouteAvailable = await workspaceService.isOnlineRouteAvailable()
    }

    @MainActor
    func distillMemory() async {
        isWorking = true
        defer { isWorking = false }
        lastRunOutput = await workspaceService.runDistillation()
        await refresh()
    }

    @MainActor
    func sendPrompt() async {
        let prompt = localPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        localPrompt = ""
        chatTranscript.append("You: \(prompt)")
        isWorking = true
        defer { isWorking = false }

        if runtimeMode != .offline {
            isOnlineRouteAvailable = await workspaceService.isOnlineRouteAvailable()
        }

        if activeRoute == .online {
            do {
                let response = try await workspaceService.askOnlineModel(prompt)
                chatTranscript.append(response.isEmpty ? "NOBS online: No response returned." : "NOBS online: \(response)")
                return
            } catch {
                isOnlineRouteAvailable = false
                chatTranscript.append("NOBS: Online route missed, switching offline.")
            }
        }

        let response = await workspaceService.askLocalModel(prompt)
        chatTranscript.append(response.isEmpty ? "NOBS offline: No response returned." : "NOBS offline: \(response)")
    }

    @MainActor
    func approveMorningDocument() async {
        isWorking = true
        defer { isWorking = false }
        lastRunOutput = await workspaceService.approveMorningDocument()
        morningDocumentApproved = true
    }

    func openAIRoot() {
        workspaceService.open(workspaceService.aiRoot)
    }

    func openNOBSApp() {
        workspaceService.open(workspaceService.nobsAppRoot)
    }

    func openVault() {
        workspaceService.open(workspaceService.vaultRoot)
    }
}
