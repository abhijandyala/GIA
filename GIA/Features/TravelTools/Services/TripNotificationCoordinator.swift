import Foundation
import Observation
import UserNotifications

enum TripNotificationAuthorizationState: String, Sendable {
    case unknown
    case notDetermined
    case authorized
    case denied
}

@MainActor
@Observable
final class TripNotificationCoordinator {
    private(set) var authorizationState:
        TripNotificationAuthorizationState = .unknown
    private(set) var scheduledCount = 0
    private(set) var lastErrorMessage: String?

    @ObservationIgnored
    private let center: UNUserNotificationCenter

    init(
        center: UNUserNotificationCenter = .current()
    ) {
        self.center = center
    }

    func refreshAuthorizationState() async {
        let settings = await center.notificationSettings()
        authorizationState = Self.state(
            from: settings.authorizationStatus
        )
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await refreshAuthorizationState()
            lastErrorMessage = granted
                ? nil
                : "Notifications were not enabled."
            return granted
        } catch {
            authorizationState = .denied
            lastErrorMessage =
                "Notification permission could not be requested."
            return false
        }
    }

    func refresh(
        for trip: Trip,
        now: Date = Date()
    ) async {
        await refreshAuthorizationState()
        guard authorizationState == .authorized else {
            scheduledCount = 0
            return
        }
        guard
            trip.integrations?.notificationSettings.isEnabled
                == true
        else {
            await cancel(for: trip.id)
            return
        }

        let reminders = TripReminderPlanner.reminders(
            for: trip,
            now: now
        )
        let prefix =
            "gia.trip.\(trip.id.uuidString.lowercased())."
        let pending = await center.pendingNotificationRequests()
        let existingIDs = pending.map(\.identifier).filter {
            $0.hasPrefix(prefix)
        }
        center.removePendingNotificationRequests(
            withIdentifiers: existingIDs
        )
        let deliveredIDs = Set(
            await center.deliveredNotifications()
                .map(\.request.identifier)
        )

        var added = 0
        for reminder in reminders
        where !deliveredIDs.contains(reminder.id) {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = [
                "tripID": trip.id.uuidString,
                "kind": reminder.kind.rawValue
            ]
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Self.dateComponents(for: reminder),
                repeats: false
            )
            do {
                try await center.add(
                    UNNotificationRequest(
                        identifier: reminder.id,
                        content: content,
                        trigger: trigger
                    )
                )
                added += 1
            } catch {
                lastErrorMessage =
                    "One or more reminders could not be scheduled."
            }
        }
        scheduledCount = added
        if added == reminders.count {
            lastErrorMessage = nil
        }
    }

    func cancel(for tripID: UUID) async {
        let prefix =
            "gia.trip.\(tripID.uuidString.lowercased())."
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter {
            $0.hasPrefix(prefix)
        }
        center.removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
        scheduledCount = 0
    }

    private static func dateComponents(
        for reminder: PlannedTripNotification
    ) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: reminder.timeZoneIdentifier)
            ?? .current
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminder.fireDate
        )
        components.timeZone = calendar.timeZone
        return components
    }

    private static func state(
        from status: UNAuthorizationStatus
    ) -> TripNotificationAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized, .provisional, .ephemeral:
            .authorized
        @unknown default:
            .unknown
        }
    }
}
