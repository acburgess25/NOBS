import Foundation

@MainActor
final class HomeCoordinator {
    unowned let model: AppModel
    private let tank: TankClient

    init(model: AppModel, tank: TankClient) {
        self.model = model
        self.tank = tank
    }

    func loadHomeDevices() async {
        guard TankConfiguration.currentToken != nil else {
            model.homeDevicesFetchState = .unavailable
            return
        }
        model.isLoadingHomeDevices = true
        model.homeDevicesFetchState = .loading
        defer { model.isLoadingHomeDevices = false }
        do {
            let response = try await tank.homeDevices()
            model.homeDevicesConfigured = response.configured
            model.homeDevicesMessage = response.message
            model.homeDevices = response.devices
            model.homeDevicesTruncated = response.truncated
            model.homeDevicesFetchState = model.tankAvailable ? .loaded : .unavailable
        } catch {
            model.homeDevicesFetchState = fetchState(for: error, resource: "home devices")
            if case .failed = model.homeDevicesFetchState {
                model.homeDevices = []
            }
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
