import EventKit
import Foundation
import Observation

struct PlannedCalendarEvent: Hashable, Identifiable, Sendable {
    var id: UUID { itineraryItemID }
    var itineraryItemID: UUID
    var title: String
    var start: Date
    var end: Date
    var timeZoneIdentifier: String
    var location: String?
    var notes: String
    var marker: String
}

enum TripCalendarEventPlanner {
    static func events(for trip: Trip) -> [PlannedCalendarEvent] {
        trip.itinerary.days
            .flatMap(\.items)
            .filter {
                $0.status != .cancelled
                    && $0.start < $0.end
            }
            .sorted { $0.start < $1.start }
            .map { item in
                let marker =
                    "GIA-ID:\(trip.id.uuidString):\(item.id.uuidString)"
                return PlannedCalendarEvent(
                    itineraryItemID: item.id,
                    title: item.title,
                    start: item.start,
                    end: item.end,
                    timeZoneIdentifier:
                        item.timeZoneIdentifier,
                    location: item.location?.name,
                    notes:
                        "Planned with GIA. Status: "
                        + item.status.rawValue.capitalized
                        + ". Verify booking details in the provider app."
                        + "\n\(marker)",
                    marker: marker
                )
            }
    }
}

enum TripCalendarAuthorizationState: String, Sendable {
    case unknown
    case notDetermined
    case authorized
    case denied
}

enum TripCalendarError: Error {
    case permissionDenied
    case calendarUnavailable
    case exportFailed
}

@MainActor
@Observable
final class TripCalendarCoordinator {
    private(set) var authorizationState:
        TripCalendarAuthorizationState = .unknown
    private(set) var lastExportCount = 0
    private(set) var lastErrorMessage: String?

    @ObservationIgnored
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func refreshAuthorizationState() {
        authorizationState = Self.state(
            from: EKEventStore.authorizationStatus(
                for: .event
            )
        )
    }

    func export(_ trip: Trip) async throws
        -> [CalendarExportRecord]
    {
        refreshAuthorizationState()
        if authorizationState == .notDetermined {
            do {
                let granted =
                    try await eventStore
                        .requestFullAccessToEvents()
                refreshAuthorizationState()
                guard granted else {
                    throw TripCalendarError.permissionDenied
                }
            } catch let error as TripCalendarError {
                throw error
            } catch {
                throw TripCalendarError.permissionDenied
            }
        }
        guard authorizationState == .authorized else {
            lastErrorMessage = "Calendar access is not enabled."
            throw TripCalendarError.permissionDenied
        }
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            lastErrorMessage =
                "No writable calendar is available."
            throw TripCalendarError.calendarUnavailable
        }

        let drafts = TripCalendarEventPlanner.events(for: trip)
        guard !drafts.isEmpty else {
            lastExportCount = 0
            lastErrorMessage = nil
            return []
        }
        let earliest = drafts.map(\.start).min()!
        let latest = drafts.map(\.end).max()!
        let predicate = eventStore.predicateForEvents(
            withStart: earliest.addingTimeInterval(-86_400),
            end: latest.addingTimeInterval(86_400),
            calendars: nil
        )
        let existingEvents = eventStore.events(matching: predicate)
        let storedRecords = Dictionary(
            uniqueKeysWithValues:
                (trip.integrations?.calendarExports ?? []).map {
                    ($0.itineraryItemID, $0)
                }
        )
        var records: [CalendarExportRecord] = []

        do {
            for draft in drafts {
                let storedIdentifier =
                    storedRecords[draft.itineraryItemID]?
                        .eventIdentifier
                let event =
                    storedIdentifier.flatMap {
                        eventStore.event(withIdentifier: $0)
                    }
                    ?? existingEvents.first {
                        $0.notes?.contains(draft.marker) == true
                    }
                    ?? EKEvent(eventStore: eventStore)

                event.calendar = calendar
                event.title = draft.title
                event.startDate = draft.start
                event.endDate = draft.end
                event.timeZone =
                    TimeZone(identifier: draft.timeZoneIdentifier)
                event.location = draft.location
                event.notes = draft.notes
                event.availability = .busy
                try eventStore.save(
                    event,
                    span: .thisEvent,
                    commit: false
                )
                guard let identifier = event.eventIdentifier else {
                    throw TripCalendarError.exportFailed
                }
                records.append(
                    CalendarExportRecord(
                        itineraryItemID: draft.itineraryItemID,
                        eventIdentifier: identifier,
                        exportedStart: draft.start,
                        exportedEnd: draft.end,
                        timeZoneIdentifier:
                            draft.timeZoneIdentifier,
                        exportedAt: Date()
                    )
                )
            }
            try eventStore.commit()
            lastExportCount = records.count
            lastErrorMessage = nil
            return records
        } catch let error as TripCalendarError {
            lastErrorMessage = "Calendar export could not finish."
            throw error
        } catch {
            lastErrorMessage = "Calendar export could not finish."
            throw TripCalendarError.exportFailed
        }
    }

    private static func state(
        from status: EKAuthorizationStatus
    ) -> TripCalendarAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .fullAccess, .writeOnly, .authorized:
            .authorized
        case .denied, .restricted:
            .denied
        @unknown default:
            .unknown
        }
    }
}
