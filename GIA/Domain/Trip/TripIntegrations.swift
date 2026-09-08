import Foundation

enum TripReminderKind: String, Codable, CaseIterable, Sendable {
    case countdown
    case voting
    case scheduleChange
    case hotelCheckIn
    case flightCheckIn
    case departure
    case weatherWarning
}

struct TripNotificationSettings:
    Codable,
    Hashable,
    Sendable
{
    var isEnabled: Bool
    var enabledKinds: Set<TripReminderKind>
    var ownerTravelerID: UUID?
    var updatedAt: Date

    init(
        isEnabled: Bool = false,
        enabledKinds: Set<TripReminderKind> =
            Set(TripReminderKind.allCases),
        ownerTravelerID: UUID? = nil,
        updatedAt: Date = Date()
    ) {
        self.isEnabled = isEnabled
        self.enabledKinds = enabledKinds
        self.ownerTravelerID = ownerTravelerID
        self.updatedAt = updatedAt
    }
}

struct CalendarExportRecord:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    var id: UUID { itineraryItemID }
    var itineraryItemID: UUID
    var eventIdentifier: String
    var exportedStart: Date
    var exportedEnd: Date
    var timeZoneIdentifier: String
    var exportedAt: Date
}

struct TripIntegrations: Codable, Hashable, Sendable {
    var notificationSettings: TripNotificationSettings
    var calendarExports: [CalendarExportRecord]

    init(
        notificationSettings: TripNotificationSettings =
            TripNotificationSettings(),
        calendarExports: [CalendarExportRecord] = []
    ) {
        self.notificationSettings = notificationSettings
        self.calendarExports = calendarExports
    }
}
