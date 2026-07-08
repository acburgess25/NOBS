import Foundation

@MainActor
final class ApprovalsCoordinator {
    unowned let model: AppModel
    private let tank: TankClient

    init(model: AppModel, tank: TankClient) {
        self.model = model
        self.tank = tank
    }

    func loadApprovals() async {
        guard TankConfiguration.currentToken != nil else {
            model.approvalsFetchState = .unavailable
            return
        }
        model.isLoadingApprovals = true
        model.approvalsFetchState = .loading
        defer { model.isLoadingApprovals = false }
        do {
            model.approvals = try await tank.approvals()
            model.approvalsFetchState = model.tankAvailable ? .loaded : .unavailable
        } catch {
            model.approvalsFetchState = fetchState(for: error, resource: "approvals")
            if case .failed = model.approvalsFetchState {
                model.approvals = []
            }
        }
    }

    func decideApproval(_ approval: PendingApproval, decision: String) async {
        do {
            _ = try await tank.decideApproval(id: approval.id, decision: decision)
            model.logActivity("\(decision == "approve" ? "Approved" : "Denied") \(approval.toolName)")
            await loadApprovals()
        } catch {
            model.lastError = "Tank could not update that approval. It may already have been decided."
        }
    }

    func loadProposals() async {
        guard TankConfiguration.currentToken != nil else {
            model.proposalsFetchState = .unavailable
            return
        }
        model.isLoadingProposals = true
        model.proposalsFetchState = .loading
        defer { model.isLoadingProposals = false }
        do {
            model.proposals = try await tank.proposals()
            model.proposalsFetchState = model.tankAvailable ? .loaded : .unavailable
        } catch {
            model.proposalsFetchState = fetchState(for: error, resource: "proposals")
            if case .failed = model.proposalsFetchState {
                model.proposals = []
            }
        }
    }

    func decideProposal(_ proposal: AgentProposal, decision: String) async {
        do {
            _ = try await tank.decideProposal(id: proposal.id, decision: decision)
            model.logActivity("\(decision == "approve" ? "Approved" : "Dismissed") idea: \(proposal.title)")
            await loadProposals()
        } catch {
            model.lastError = "Tank could not update that proposal. It may already have been decided."
        }
    }

    func loadSchedules() async {
        guard TankConfiguration.currentToken != nil else {
            model.schedulesFetchState = .unavailable
            return
        }
        model.isLoadingSchedules = true
        model.schedulesFetchState = .loading
        defer { model.isLoadingSchedules = false }
        do {
            model.schedules = try await tank.schedules()
            model.schedulesFetchState = model.tankAvailable ? .loaded : .unavailable
        } catch {
            model.schedulesFetchState = fetchState(for: error, resource: "schedules")
            if case .failed = model.schedulesFetchState {
                model.schedules = []
            }
        }
    }

    func updateSchedule(_ schedule: TankSchedule, status: String) async {
        do {
            _ = try await tank.updateSchedule(id: schedule.id, status: status)
            model.logActivity("Set schedule \(schedule.timeOfDay) to \(status)")
            await loadSchedules()
        } catch {
            model.lastError = "Tank could not update that schedule right now."
        }
    }

    private func fetchState(for error: Error, resource: String) -> TankFetchState {
        if TankSyncService.shouldMarkUnavailable(for: error) {
            model.tankAvailable = false
            return .unavailable
        }
        return .failed("Could not load \(resource) from Tank.")
    }
}
