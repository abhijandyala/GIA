import SwiftUI

struct TripIntegrationSection: View {
    let trip: Trip

    @Environment(TripPlanningSession.self)
    private var tripPlanningSession
    @Environment(TripNotificationCoordinator.self)
    private var notificationCoordinator
    @Environment(TripCalendarCoordinator.self)
    private var calendarCoordinator
    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @State private var errorMessage: String?
    @State private var isWorking = false

    private var notificationSettings: TripNotificationSettings {
        trip.integrations?.notificationSettings
            ?? TripNotificationSettings()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TRIP ASSISTANCE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(
                            GIAColor.primaryText.opacity(0.42)
                        )

                    Text("Contextual alerts and calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(GIAColor.secondaryText)
                }

                Spacer()

                Text(countdownLabel)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(GIAColor.intelligenceAccent)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Trip assistance, \(countdownLabel) until departure"
            )

            integrationCardLayout

            Label(
                "Permissions are requested only when you enable a feature.",
                systemImage: "hand.raised"
            )
            .font(.caption2)
            .foregroundStyle(GIAColor.secondaryText)

            if
                notificationCoordinator.authorizationState == .denied
                || calendarCoordinator.authorizationState == .denied
            {
                HStack {
                    Text(
                        "Permission is off. Enable access in "
                        + "Settings to use this feature."
                    )
                    .font(.caption2)
                    .foregroundStyle(GIAColor.warningAccent)

                    Spacer()

                    Button("OPEN SETTINGS", action: openSettings)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(GIAColor.warningAccent)
                        .frame(minHeight: 44)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open G.I.A. settings")
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(GIAColor.warningAccent)
            }
        }
    }

    @ViewBuilder
    private var integrationCardLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 11) {
                notificationCard
                calendarCard
            }
        } else {
            HStack(spacing: 11) {
                notificationCard
                calendarCard
            }
        }
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: notificationSymbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(notificationColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("TRIP ALERTS")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(GIAColor.secondaryText)

                Text(notificationStatus)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)

                Text(
                    notificationSettings.isEnabled
                        ? "\(notificationCoordinator.scheduledCount) "
                            + "scheduled"
                        : "Countdown, votes, travel, weather"
                )
                .font(.caption2)
                .foregroundStyle(GIAColor.secondaryText)
                .lineLimit(2)
            }

            Spacer(minLength: 3)

            Button(action: toggleNotifications) {
                Text(
                    notificationSettings.isEnabled
                        ? "DISABLE"
                        : "ENABLE ALERTS"
                )
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(
                    notificationSettings.isEnabled
                        ? GIAColor.warningAccent
                        : GIAColor.intelligenceAccent
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            GIAColor.primaryText.opacity(0.05)
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 190)
        .planSurface(cornerRadius: 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trip alerts")
        .accessibilityValue(
            "\(notificationStatus), "
            + "\(notificationCoordinator.scheduledCount) scheduled"
        )
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(GIAColor.intelligenceAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text("CALENDAR")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(GIAColor.secondaryText)

                Text(calendarStatus)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)

                Text(
                    "Destination time zones · "
                    + "duplicate-safe updates"
                )
                .font(.caption2)
                .foregroundStyle(GIAColor.secondaryText)
                .lineLimit(2)
            }

            Spacer(minLength: 3)

            Button(action: exportCalendar) {
                Text("EXPORT PLAN")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(GIAColor.intelligenceAccent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background {
                        Capsule(style: .continuous)
                            .fill(
                                GIAColor.primaryText.opacity(0.05)
                            )
                    }
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 190)
        .planSurface(cornerRadius: 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calendar export")
        .accessibilityValue(calendarStatus)
    }

    private var countdownLabel: String {
        guard let start = trip.request.dateRange?.start else {
            return "DATES NEEDED"
        }
        let days = max(
            Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: start)
            ).day ?? 0,
            0
        )
        return days == 1 ? "1 DAY" : "\(days) DAYS"
    }

    private var notificationStatus: String {
        if notificationSettings.isEnabled {
            return "Enabled"
        }
        switch notificationCoordinator.authorizationState {
        case .denied:
            return "Permission denied"
        case .authorized:
            return "Ready"
        case .notDetermined, .unknown:
            return "Off"
        }
    }

    private var notificationSymbol: String {
        notificationSettings.isEnabled
            ? "bell.badge.fill"
            : "bell"
    }

    private var notificationColor: Color {
        notificationSettings.isEnabled
            ? GIAColor.confirmedAccent
            : GIAColor.intelligenceAccent
    }

    private var calendarStatus: String {
        let count =
            trip.integrations?.calendarExports.count ?? 0
        if count > 0 {
            return "\(count) items exported"
        }
        switch calendarCoordinator.authorizationState {
        case .denied:
            return "Permission denied"
        case .authorized:
            return "Ready to export"
        case .notDetermined, .unknown:
            return "Not exported"
        }
    }

    private func toggleNotifications() {
        isWorking = true
        Task {
            defer { isWorking = false }
            if notificationSettings.isEnabled {
                do {
                    try tripPlanningSession.updateNotificationSettings(
                        isEnabled: false
                    )
                    await notificationCoordinator.cancel(
                        for: trip.id
                    )
                    errorMessage = nil
                } catch {
                    errorMessage =
                        "Trip alerts could not be disabled."
                }
                return
            }

            let granted =
                await notificationCoordinator.requestAuthorization()
            guard granted else {
                errorMessage =
                    notificationCoordinator.lastErrorMessage
                    ?? "Notification permission was not granted."
                return
            }
            do {
                try tripPlanningSession.updateNotificationSettings(
                    isEnabled: true
                )
                if let updatedTrip =
                    tripPlanningSession.currentTrip
                {
                    await notificationCoordinator.refresh(
                        for: updatedTrip
                    )
                }
                errorMessage = nil
            } catch {
                errorMessage = "Trip alerts could not be enabled."
            }
        }
    }

    private func exportCalendar() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let records = try await calendarCoordinator.export(
                    trip
                )
                try tripPlanningSession.recordCalendarExports(
                    records
                )
                errorMessage = nil
            } catch {
                errorMessage =
                    calendarCoordinator.lastErrorMessage
                    ?? "Calendar export could not finish."
            }
        }
    }

    private func openSettings() {
        guard
            let url = URL(
                string: UIApplication.openSettingsURLString
            )
        else {
            return
        }
        openURL(url)
    }
}
