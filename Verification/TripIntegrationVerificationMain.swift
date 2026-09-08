import Foundation

@main
enum TripIntegrationVerificationMain {
    @MainActor
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var trip = JudgeDemoTripFactory.makeTrip(
            retrievedAt: now
        )
        let ownerID = trip.organizerTravelerID
        trip.integrations = TripIntegrations(
            notificationSettings: TripNotificationSettings(
                isEnabled: true,
                ownerTravelerID: ownerID,
                updatedAt: now
            )
        )

        let zone = TimeZone(identifier: "Asia/Tokyo")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let checkIn = calendar.date(
            bySettingHour: 15,
            minute: 0,
            second: 0,
            of: trip.request.dateRange!.start
        )!
        let hotelItem = ItineraryItem(
            title: "Hotel check-in",
            kind: .hotelCheckIn,
            status: .selected,
            flexibility: .fixed,
            start: checkIn,
            end: checkIn.addingTimeInterval(1_800),
            timeZoneIdentifier: zone.identifier,
            location: trip.catalog.hotelOffers[0].location,
            reference: .hotelOffer(
                trip.catalog.hotelOffers[0].id
            )
        )
        trip.itinerary.days[0].items.append(hotelItem)

        let scheduleMessage = TripMessage(
            authorKind: .system,
            body: "A schedule item changed.",
            context: .itineraryItem(hotelItem.id),
            systemEvent: .itineraryChanged,
            createdAt: now.addingTimeInterval(30)
        )
        var communication =
            trip.communication ?? TripCommunication()
        communication.messages.append(scheduleMessage)
        trip.communication = communication

        let alert = WeatherAlert(
            headline: "Strong wind advisory",
            reportingAgency: "Fixture agency",
            severity: .severe,
            effectiveAt: now.addingTimeInterval(600),
            expiresAt: now.addingTimeInterval(7_200)
        )
        trip.catalog.weatherSnapshots[0].alerts = [alert]

        let reminders = TripReminderPlanner.reminders(
            for: trip,
            now: now
        )
        let kinds = Set(reminders.map(\.kind))
        precondition(kinds.contains(.countdown))
        precondition(kinds.contains(.voting))
        precondition(kinds.contains(.scheduleChange))
        precondition(kinds.contains(.hotelCheckIn))
        precondition(kinds.contains(.flightCheckIn))
        precondition(kinds.contains(.departure))
        precondition(kinds.contains(.weatherWarning))
        precondition(
            Set(reminders.map(\.id)).count == reminders.count
        )
        precondition(
            reminders == TripReminderPlanner.reminders(
                for: trip,
                now: now
            )
        )
        precondition(
            reminders.first {
                $0.kind == .hotelCheckIn
            }?.timeZoneIdentifier == "Asia/Tokyo"
        )
        precondition(
            reminders.first {
                $0.kind == .departure
            }?.timeZoneIdentifier == "America/New_York"
        )
        for reminder in reminders {
            precondition(!reminder.title.contains("Avery"))
            precondition(!reminder.body.contains("Avery"))
            precondition(!reminder.body.contains("@demo.gia"))
            precondition(!reminder.body.contains("vegetarian"))
        }

        let calendarEvents =
            TripCalendarEventPlanner.events(for: trip)
        precondition(
            calendarEvents.count
                == trip.itinerary.days.flatMap(\.items).count
        )
        precondition(
            Set(calendarEvents.map(\.marker)).count
                == calendarEvents.count
        )
        precondition(
            calendarEvents.first {
                $0.itineraryItemID == hotelItem.id
            }?.timeZoneIdentifier == "Asia/Tokyo"
        )
        precondition(
            calendarEvents.allSatisfy {
                $0.notes.contains("GIA-ID:")
                    && !$0.notes.contains("@demo.gia")
            }
        )

        let session = TripPlanningSession()
        try session.beginListening(source: .debug)
        try session.beginTranscribing()
        try session.beginValidation(request: trip.request)
        try session.beginSearch()
        try session.beginComparison()
        try session.beginItineraryBuild()
        try session.beginPresentation()
        try session.complete(with: trip)
        try session.updateNotificationSettings(isEnabled: true)
        precondition(
            session.currentTrip?.integrations?
                .notificationSettings.ownerTravelerID == ownerID
        )

        let firstRecord = CalendarExportRecord(
            itineraryItemID: hotelItem.id,
            eventIdentifier: "event-1",
            exportedStart: hotelItem.start,
            exportedEnd: hotelItem.end,
            timeZoneIdentifier: hotelItem.timeZoneIdentifier,
            exportedAt: now
        )
        let updatedRecord = CalendarExportRecord(
            itineraryItemID: hotelItem.id,
            eventIdentifier: "event-2",
            exportedStart: hotelItem.start,
            exportedEnd: hotelItem.end,
            timeZoneIdentifier: hotelItem.timeZoneIdentifier,
            exportedAt: now.addingTimeInterval(60)
        )
        try session.recordCalendarExports([firstRecord])
        try session.recordCalendarExports([updatedRecord])
        precondition(
            session.currentTrip?.integrations?
                .calendarExports.count == 1
        )
        precondition(
            session.currentTrip?.integrations?
                .calendarExports.first?.eventIdentifier == "event-2"
        )
        do {
            try session.recordCalendarExports([
                CalendarExportRecord(
                    itineraryItemID: UUID(),
                    eventIdentifier: "invalid",
                    exportedStart: now,
                    exportedEnd: now.addingTimeInterval(60),
                    timeZoneIdentifier: "UTC",
                    exportedAt: now
                )
            ])
            fatalError("Unknown itinerary export was accepted.")
        } catch let error as TripIntegrationError {
            if case .invalidCalendarRecord = error {
                // Expected.
            } else {
                fatalError("Unexpected calendar record error.")
            }
        }

        let encoded = try JSONEncoder().encode(trip)
        var legacyObject = try JSONSerialization.jsonObject(
            with: encoded
        ) as! [String: Any]
        legacyObject.removeValue(forKey: "integrations")
        let legacyTrip = try JSONDecoder().decode(
            Trip.self,
            from: JSONSerialization.data(
                withJSONObject: legacyObject
            )
        )
        precondition(legacyTrip.integrations == nil)

        print("Trip reminders and calendar planning passed.")
    }
}
