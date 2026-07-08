import Foundation

@MainActor
final class MemoryCoordinator {
    unowned let model: AppModel
    private let tank: TankClient

    init(model: AppModel, tank: TankClient) {
        self.model = model
        self.tank = tank
    }

    func loadMemories() async {
        guard TankConfiguration.currentToken != nil else {
            model.memoriesFetchState = .unavailable
            return
        }
        model.isLoadingMemories = true
        model.memoriesFetchState = .loading
        defer { model.isLoadingMemories = false }
        do {
            model.memories = try await tank.memories()
            model.memoriesFetchState = model.tankAvailable ? .loaded : .unavailable
        } catch {
            model.memoriesFetchState = fetchState(for: error, resource: "memories")
            if case .failed = model.memoriesFetchState {
                model.memories = []
            }
        }
    }

    func deleteMemory(_ memory: TankMemory) async {
        do {
            try await tank.deleteMemory(id: memory.id)
            model.memories.removeAll { $0.id == memory.id }
            model.logActivity("Deleted a memory")
        } catch {
            model.lastError = "Tank could not delete that memory right now."
        }
    }

    func updateMemory(_ memory: TankMemory, content: String, category: String) async {
        do {
            let updated = try await tank.updateMemory(
                id: memory.id,
                content: content,
                category: category
            )
            if let index = model.memories.firstIndex(where: { $0.id == memory.id }) {
                model.memories[index] = updated
            }
            model.logActivity("Corrected a memory")
        } catch {
            model.lastError = "Tank could not update that memory right now."
        }
    }

    private func fetchState(for error: Error, resource: String) -> TankFetchState {
        if shouldMarkTankUnavailable(for: error) {
            model.tankAvailable = false
            return .unavailable
        }
        return .failed("Could not load \(resource) from Tank.")
    }

    private func shouldMarkTankUnavailable(for error: Error) -> Bool {
        if let apiError = error as? TankAPIError {
            return apiError.isConnectivityFailure
        }
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        let code = URLError.Code(rawValue: nsError.code)
        switch code {
        case .notConnectedToInternet, .cannotConnectToHost, .networkConnectionLost, .timedOut,
             .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}
