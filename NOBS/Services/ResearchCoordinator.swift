import Foundation

@MainActor
final class ResearchCoordinator {
    unowned let model: AppModel
    private let tank: TankClient

    init(model: AppModel, tank: TankClient) {
        self.model = model
        self.tank = tank
    }

    func loadResearchJobs() async {
        guard TankConfiguration.currentToken != nil else {
            model.researchFetchState = .unavailable
            return
        }
        model.isLoadingResearch = true
        model.researchFetchState = .loading
        defer { model.isLoadingResearch = false }
        do {
            model.researchJobs = try await tank.researchJobs()
            model.researchFetchState = model.tankAvailable ? .loaded : .unavailable
        } catch {
            model.researchFetchState = fetchState(for: error, resource: "research jobs")
            if case .failed = model.researchFetchState {
                model.researchJobs = []
            }
        }
    }

    func startResearch(topic: String, context: String = "personal") async {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard TankConfiguration.currentToken != nil else {
            model.lastError = "Connect Tank in Privacy before requesting research."
            return
        }
        model.isSubmittingResearch = true
        defer { model.isSubmittingResearch = false }
        do {
            let job = try await tank.createResearch(topic: trimmed, context: context)
            if let index = model.researchJobs.firstIndex(where: { $0.id == job.id }) {
                model.researchJobs[index] = job
            } else {
                model.researchJobs.insert(job, at: 0)
            }
            model.logActivity("Prepared research brief: \(trimmed)")
        } catch let error as TankAPIError {
            if case .httpStatus(403, _) = error {
                model.lastError = "Research briefs require an active NOBScloud subscription."
            } else {
                model.lastError = "Tank could not prepare that research brief right now."
            }
        } catch {
            model.lastError = "Tank could not prepare that research brief right now."
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
