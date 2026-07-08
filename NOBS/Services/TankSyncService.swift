@preconcurrency import EventKit
import Foundation

@MainActor
final class TankSyncService {
    unowned let model: AppModel
    private let tank: TankClient
    private let discovery: TankDiscoveryService
    private let calendar: CalendarService
    private var refreshTask: Task<Void, Never>?

    init(
        model: AppModel,
        tank: TankClient,
        discovery: TankDiscoveryService = TankDiscoveryService(),
        calendar: CalendarService = CalendarService()
    ) {
        self.model = model
        self.tank = tank
        self.discovery = discovery
        self.calendar = calendar
    }

    deinit {
        refreshTask?.cancel()
    }

    static func shouldMarkUnavailable(for error: Error) -> Bool {
        if let apiError = error as? TankAPIError {
            return apiError.isConnectivityFailure
        }
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return false
        }
        let code = URLError.Code(rawValue: nsError.code)
        switch code {
        case .notConnectedToInternet, .cannotConnectToHost, .networkConnectionLost, .timedOut,
             .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    func updateTankSyncStatus() {
        if model.isReconnecting {
            model.tankSyncStatus = .connecting
            return
        }
        if model.tankAvailable {
            model.tankSyncStatus = .connected
            return
        }
        if model.pendingOfflineMessageCount > 0 {
            model.tankSyncStatus = .localFallback(pendingMessages: model.pendingOfflineMessageCount)
            return
        }
        if let tankLastConnectionError = model.tankLastConnectionError, !tankLastConnectionError.isEmpty {
            model.tankSyncStatus = .offline(reason: tankLastConnectionError)
            return
        }
        model.tankSyncStatus = .localFallback(pendingMessages: 0)
    }

    /// Returns true when Tank became reachable after being offline.
    @discardableResult
    func refreshTankStatus() async -> Bool {
        let wasAvailable = model.tankAvailable
        model.tankAvailable = await tank.checkHealth()
        model.tankLastConnectionError = await tank.lastConnectionError?.userFacingMessage
        updateTankSyncStatus()
        return model.tankAvailable && !wasAvailable
    }

    func reconnectToTank() async {
        model.isReconnecting = true
        model.tankSyncStatus = .connecting
        defer {
            model.isReconnecting = false
            updateTankSyncStatus()
        }

        await refreshTankStatus()
        if model.tankAvailable {
            model.tankConnectStatus = "Connected to Tank"
            model.logActivity("Reconnected to Tank")
            return
        }

        model.discoveredTanks = await discovery.discover(timeout: 5)
        if let discovered = model.discoveredTanks.first {
            model.tankAddress = discovered.url.absoluteString
            TankConfiguration.saveAddress(discovered.url.absoluteString)
            await refreshTankStatus()
            if model.tankAvailable {
                model.tankConnectStatus = "Discovered \(discovered.name) on your network"
                model.logActivity("Discovered Tank at \(discovered.url.absoluteString)")
                return
            }
        }

        let reason = await tank.lastConnectionError?.userFacingMessage
            ?? "Tank was not found on your network. Check the address or try again at home."
        model.tankSyncStatus = .offline(reason: reason)
        model.tankConnectStatus = reason
        model.lastError = reason
    }

    func browseForTanks() async {
        guard !model.tankAvailable else { return }
        model.discoveredTanks = await discovery.discover(timeout: 4)
    }

    func signInWithApple(userIdentifier: String, identityToken: String?) async {
        model.isSigningIn = true
        model.tankConnectStatus = "Connecting to Tank…"
        defer { model.isSigningIn = false }

        TankConfiguration.saveAppleUserID(userIdentifier)

        guard prepareTankAddressForAuth() else { return }

        let reachable = await tank.checkReachability()
        if !reachable {
            let reason = await tank.lastConnectionError?.userFacingMessage
                ?? "Could not reach Tank. If tank.local does not resolve, enter your Tank IP in Privacy (for example http://192.168.1.100:8000)."
            model.tankConnectStatus = "Tank is not reachable at \(model.tankAddress)."
            model.lastError = reason
            return
        }

        do {
            let response = try await tank.authWithApple(
                userIdentifier: userIdentifier,
                identityToken: identityToken
            )
            try TankConfiguration.save(address: model.tankAddress, token: response.deviceToken)
            model.tankToken = response.deviceToken
            model.tankAddress = TankConfiguration.savedAddress
            await refreshTankStatus()
            model.tankConnectStatus = model.tankAvailable
                ? "Connected to Tank"
                : "Token saved. Tank unavailable on this network."
            model.logActivity("Signed in with Apple and connected to Tank")
        } catch {
            model.tankConnectStatus = "Could not connect: \(error.localizedDescription)"
            if Self.shouldMarkUnavailable(for: error) {
                model.lastError = "Tank is unreachable. Make sure you're on your home network and Tank is running."
            } else {
                model.lastError = "Tank didn't recognise this Apple ID. Make sure you've run the setup once at home."
            }
        }
    }

    func saveTankConnection() async {
        guard let url = TankConfiguration.normalizedURL(from: model.tankAddress) else {
            model.lastError = "Enter a valid Tank address beginning with http:// or https://."
            return
        }
        let cleanToken = model.tankToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            model.lastError = "Enter the device token created during Tank setup."
            return
        }

        do {
            try TankConfiguration.save(address: url.absoluteString, token: cleanToken)
            model.tankAddress = url.absoluteString
            model.tankToken = cleanToken
            await refreshTankStatus()
            model.logActivity(model.tankAvailable ? "Tank connection verified" : "Tank connection saved; server unavailable")
            if !model.tankAvailable {
                let reason = await tank.lastConnectionError?.userFacingMessage
                    ?? "Connection saved, but Tank did not answer. NOBS will keep working locally."
                model.lastError = reason
            }
        } catch {
            model.lastError = "The Tank token could not be saved securely."
        }
    }

    func requestCalendarAccess() async {
        model.isLoadingCalendar = true
        defer { model.isLoadingCalendar = false }
        do {
            let granted = try await calendar.requestAccess()
            model.calendarStatus = EKEventStore.authorizationStatus(for: .event)
            if granted {
                model.logActivity("Calendar access approved")
                await loadToday()
                model.reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
                await syncCalendarToTank()
            } else {
                model.lastError = "Calendar access was not granted. NOBS still works as private chat."
            }
        } catch {
            model.lastError = "Calendar access could not be requested: \(error.localizedDescription)"
        }
    }

    func requestReminderAccess() async {
        model.isLoadingReminders = true
        defer { model.isLoadingReminders = false }
        do {
            let granted = try await calendar.requestReminderAccess()
            model.reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
            if granted {
                model.logActivity("Reminders access approved")
                await loadReminders()
                await syncRemindersToTank()
            } else {
                model.lastError = "Reminders access was not granted. Briefings will use calendar events only."
            }
        } catch {
            model.lastError = "Reminders access could not be requested: \(error.localizedDescription)"
        }
    }

    func loadToday() async {
        model.isLoadingCalendar = true
        defer { model.isLoadingCalendar = false }
        model.events = calendar.todayEvents()
        model.logActivity("Loaded \(model.events.count) calendar events locally")
    }

    func loadReminders() async {
        model.isLoadingReminders = true
        defer { model.isLoadingReminders = false }
        model.reminders = await calendar.todayReminders()
        model.logActivity("Loaded \(model.reminders.count) reminder items locally")
    }

    func loadTomorrow() async {
        model.tomorrowEvents = calendar.tomorrowEvents()
        model.tomorrowReminders = await calendar.tomorrowReminders()
        model.logActivity(
            "Loaded tomorrow context: \(model.tomorrowEvents.count) events, \(model.tomorrowReminders.count) reminders"
        )
    }

    func syncCalendarToTank() async {
        guard model.tankAvailable, !model.isSyncingCalendar else { return }
        guard await ensureCalendarAccessForSync() else { return }
        model.isSyncingCalendar = true
        defer { model.isSyncingCalendar = false }

        do {
            let syncedEvents = calendar.syncEvents(daysAhead: 7)
            let formatter = ISO8601DateFormatter()
            let payload = syncedEvents.map {
                TankBriefingCalendarItem(
                    title: $0.title,
                    start: formatter.string(from: $0.start),
                    end: formatter.string(from: $0.end),
                    location: $0.location,
                    context: $0.context.rawValue
                )
            }
            try await tank.syncCalendar(events: payload)
            let receipt = PrivacyReceipt(
                used: ["\(payload.count) calendar event\(payload.count == 1 ? "" : "s") from EventKit"],
                processed: "Tank on your private network",
                shared: [],
                changed: ["Synced Tank calendar cache"]
            )
            model.syncActivity.insert(
                SyncActivityEntry(
                    title: "Calendar sync completed",
                    detail: "Uploaded \(payload.count) events from this iPhone",
                    route: .tank,
                    receipt: receipt
                ),
                at: 0
            )
            model.logActivity("Synced \(payload.count) calendar events to Tank")
        } catch {
            handleSyncFailure(kind: "calendar", error: error)
        }
    }

    func syncRemindersToTank() async {
        guard model.tankAvailable, !model.isSyncingReminders else { return }
        guard await ensureReminderAccessForSync() else { return }
        model.isSyncingReminders = true
        defer { model.isSyncingReminders = false }

        do {
            let syncedReminders = await calendar.openReminders(limit: 200)
            let isoFormatter = ISO8601DateFormatter()
            let payload = syncedReminders.map {
                TankBriefingReminderItem(
                    title: $0.title,
                    due: $0.due.map { isoFormatter.string(from: $0) },
                    context: $0.context.rawValue
                )
            }
            try await tank.syncReminders(reminders: payload)
            let receipt = PrivacyReceipt(
                used: ["\(payload.count) reminder\(payload.count == 1 ? "" : "s") from EventKit"],
                processed: "Tank on your private network",
                shared: [],
                changed: ["Synced Tank reminders cache"]
            )
            model.syncActivity.insert(
                SyncActivityEntry(
                    title: "Reminders sync completed",
                    detail: "Uploaded \(payload.count) reminders from this iPhone",
                    route: .tank,
                    receipt: receipt
                ),
                at: 0
            )
            model.logActivity("Synced \(payload.count) reminders to Tank")
        } catch {
            handleSyncFailure(kind: "reminders", error: error)
        }
    }

    func startAutoRefresh(onTankAvailable: @escaping () async -> Void) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                await self.refreshTankStatus()
                if self.model.tankAvailable {
                    await onTankAvailable()
                }
            }
        }
    }

    @discardableResult
    private func prepareTankAddressForAuth() -> Bool {
        guard let url = TankConfiguration.normalizedURL(from: model.tankAddress) else {
            model.tankConnectStatus = "Enter a valid Tank address in Privacy settings first."
            model.lastError = "Sign in needs a Tank address. Open Privacy and enter your Tank URL."
            return false
        }
        TankConfiguration.saveAddress(url.absoluteString)
        model.tankAddress = url.absoluteString
        return true
    }

    private func handleSyncFailure(kind: String, error: Error) {
        let offline = Self.shouldMarkUnavailable(for: error)
        if offline {
            model.tankAvailable = false
            model.lastError = "Tank is offline, so \(kind) sync stayed local."
        } else {
            model.lastError = "Tank could not sync \(kind). Your data stayed on this iPhone."
        }
        let receipt = PrivacyReceipt(
            used: ["\(kind) remained on this iPhone"],
            processed: "Local on this iPhone",
            shared: [],
            changed: []
        )
        model.syncActivity.insert(
            SyncActivityEntry(
                title: offline ? "\(kind.capitalized) sync stayed local" : "\(kind.capitalized) sync failed",
                detail: offline
                    ? "Tank was unavailable, so no \(kind) left this iPhone"
                    : "Tank returned an error; no \(kind) left this iPhone",
                route: .local,
                receipt: receipt
            ),
            at: 0
        )
    }

    private func ensureCalendarAccessForSync() async -> Bool {
        switch model.calendarStatus {
        case .fullAccess:
            return true
        case .notDetermined:
            await requestCalendarAccess()
            return model.hasCalendarAccess
        default:
            model.lastError = "Calendar access is required to sync events to Tank."
            return false
        }
    }

    private func ensureReminderAccessForSync() async -> Bool {
        switch model.reminderStatus {
        case .fullAccess:
            return true
        case .notDetermined:
            await requestReminderAccess()
            return model.hasReminderReadAccess
        default:
            model.lastError = "Reminders access is required to sync reminders to Tank."
            return false
        }
    }
}
