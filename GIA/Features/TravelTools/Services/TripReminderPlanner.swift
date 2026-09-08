import Foundation

struct PlannedTripNotification:
    Hashable,
    Identifiable,
    Sendable
{
    var id: String
    var kind: TripReminderKind
    var fireDate: Date
    var timeZoneIdentifier: String
    var title: String
    var body: String
    var relatedIdentifier: UUID?
}

enum TripReminderPlanner {
    static func reminders(
        for trip: Trip,
        now: Date = Date()
    ) -> [PlannedTripNotification] {
        let settings =
            trip.integrations?.notificationSettings
            ?? TripNotificationSettings()
        guard settings.isEnabled else { return [] }

        var reminders: [PlannedTripNotification] = []
        let tripPrefix = "gia.trip.\(trip.id.uuidString.lowercased())"
        let destinationZone =
            trip.request.dateRange?.timeZoneIdentifier
            ?? trip.request.destinations.first?.timeZoneIdentifier
            ?? TimeZone.current.identifier

        if
            settings.enabledKinds.contains(.countdown),
            let range = trip.request.dateRange,
            let fireDate = countdownDate(
                for: range.start,
                timeZoneIdentifier: range.timeZoneIdentifier
            ),
            fireDate > now
        {
            reminders.append(
                PlannedTripNotification(
                    id: "\(tripPrefix).countdown.seven-days",
                    kind: .countdown,
                    fireDate: fireDate,
                    timeZoneIdentifier: range.timeZoneIdentifier,
                    title: "Trip countdown",
                    body:
                        "Your trip begins in one week. "
                        + "Open GIA to review the shared plan."
                )
            )
        }

        if
            let selectedFlight = trip.catalog.flightOffers.first(
                where: {
                    trip.selections.flightOfferIDs.contains($0.id)
                }
            ),
            let firstSegment =
                selectedFlight.outboundSegments.first
        {
            if settings.enabledKinds.contains(.flightCheckIn) {
                appendIfFuture(
                    PlannedTripNotification(
                        id:
                            "\(tripPrefix).flight-check-in."
                            + selectedFlight.id.uuidString.lowercased(),
                        kind: .flightCheckIn,
                        fireDate:
                            firstSegment.departure
                            .addingTimeInterval(-86_400),
                        timeZoneIdentifier:
                            firstSegment
                                .departureTimeZoneIdentifier,
                        title: "Flight check-in reminder",
                        body:
                            "Check-in may be available. Open GIA and "
                            + "continue with the airline provider.",
                        relatedIdentifier: selectedFlight.id
                    ),
                    now: now,
                    to: &reminders
                )
            }
            if settings.enabledKinds.contains(.departure) {
                appendIfFuture(
                    PlannedTripNotification(
                        id:
                            "\(tripPrefix).departure."
                            + selectedFlight.id.uuidString.lowercased(),
                        kind: .departure,
                        fireDate:
                            firstSegment.departure
                            .addingTimeInterval(-10_800),
                        timeZoneIdentifier:
                            firstSegment
                                .departureTimeZoneIdentifier,
                        title: "Departure approaching",
                        body:
                            "Review departure time, travel documents, "
                            + "and airport arrival buffer in GIA.",
                        relatedIdentifier: selectedFlight.id
                    ),
                    now: now,
                    to: &reminders
                )
            }
        }

        if settings.enabledKinds.contains(.hotelCheckIn) {
            for item in trip.itinerary.days
                .flatMap(\.items)
                .filter({
                    $0.kind == .hotelCheckIn
                        && $0.status != .cancelled
                })
            {
                appendIfFuture(
                    PlannedTripNotification(
                        id:
                            "\(tripPrefix).hotel-check-in."
                            + item.id.uuidString.lowercased(),
                        kind: .hotelCheckIn,
                        fireDate:
                            item.start.addingTimeInterval(-7_200),
                        timeZoneIdentifier:
                            item.timeZoneIdentifier,
                        title: "Stay check-in approaching",
                        body:
                            "Open GIA to review the selected stay and "
                            + "provider confirmation status.",
                        relatedIdentifier: item.id
                    ),
                    now: now,
                    to: &reminders
                )
            }
        }

        if settings.enabledKinds.contains(.voting) {
            for decision in trip.decisions
            where
                decision.state == .voting
                || decision.state == .tied
                || decision.state == .needsRevision
            {
                let proposedReminder =
                    decision.proposedAt.addingTimeInterval(86_400)
                reminders.append(
                    PlannedTripNotification(
                        id:
                            "\(tripPrefix).vote."
                            + decision.id.uuidString.lowercased(),
                        kind: .voting,
                        fireDate:
                            proposedReminder > now
                            ? proposedReminder
                            : now.addingTimeInterval(3_600),
                        timeZoneIdentifier: destinationZone,
                        title: "Group decision waiting",
                        body:
                            "A shared trip decision needs attention. "
                            + "Open GIA to review and vote.",
                        relatedIdentifier: decision.id
                    )
                )
            }
        }

        if settings.enabledKinds.contains(.scheduleChange) {
            for message in trip.communication?.messages ?? []
            where message.systemEvent == .itineraryChanged {
                appendIfFuture(
                    PlannedTripNotification(
                        id:
                            "\(tripPrefix).schedule-change."
                            + message.id.uuidString.lowercased(),
                        kind: .scheduleChange,
                        fireDate:
                            message.createdAt.addingTimeInterval(5),
                        timeZoneIdentifier: destinationZone,
                        title: "Shared itinerary updated",
                        body:
                            "A schedule item changed. "
                            + "Open GIA to review the latest plan.",
                        relatedIdentifier: message.id
                    ),
                    now: now,
                    to: &reminders
                )
            }
        }

        if settings.enabledKinds.contains(.weatherWarning) {
            for snapshot in trip.catalog.weatherSnapshots {
                for alert in snapshot.alerts
                where
                    alert.severity == .moderate
                    || alert.severity == .severe
                    || alert.severity == .extreme
                {
                    guard
                        alert.expiresAt == nil
                        || alert.expiresAt! > now
                    else {
                        continue
                    }
                    let proposedDate =
                        alert.effectiveAt ?? now.addingTimeInterval(5)
                    reminders.append(
                        PlannedTripNotification(
                            id:
                                "\(tripPrefix).weather."
                                + alert.id.uuidString.lowercased(),
                            kind: .weatherWarning,
                            fireDate:
                                proposedDate > now
                                ? proposedDate
                                : now.addingTimeInterval(5),
                            timeZoneIdentifier:
                                snapshot.timeZoneIdentifier,
                            title: "Travel weather warning",
                            body:
                                "A sourced weather alert may affect "
                                + "the plan. Open GIA for details.",
                            relatedIdentifier: alert.id
                        )
                    )
                }
            }
        }

        return Dictionary(
            reminders.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        ).values.sorted {
            if $0.fireDate != $1.fireDate {
                return $0.fireDate < $1.fireDate
            }
            return $0.id < $1.id
        }
    }

    private static func countdownDate(
        for tripStart: Date,
        timeZoneIdentifier: String
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: timeZoneIdentifier) ?? .current
        guard
            let sevenDaysBefore = calendar.date(
                byAdding: .day,
                value: -7,
                to: tripStart
            )
        else {
            return nil
        }
        return calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: sevenDaysBefore
        )
    }

    private static func appendIfFuture(
        _ reminder: PlannedTripNotification,
        now: Date,
        to reminders: inout [PlannedTripNotification]
    ) {
        guard reminder.fireDate > now else { return }
        reminders.append(reminder)
    }
}
