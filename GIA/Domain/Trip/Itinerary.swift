import Foundation

enum ItineraryItemKind: String, Codable, CaseIterable, Sendable {
    case activity
    case arrival
    case departure
    case flight
    case freeTime
    case hotelCheckIn
    case hotelCheckOut
    case meal
    case meeting
    case transportation
}

enum ItineraryItemStatus: String, Codable, CaseIterable, Sendable {
    case proposed
    case selected
    case confirmed
    case completed
    case cancelled
}

enum ItineraryFlexibility: String, Codable, CaseIterable, Sendable {
    case fixed
    case flexible
    case lockedByUser
}

enum ItineraryReference: Codable, Hashable, Sendable {
    case flightOffer(UUID)
    case hotelOffer(UUID)
    case place(UUID)
    case timedEvent(UUID)
    case transportationLeg(UUID)
    case userCreated
}

struct ItineraryItem: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var subtitle: String?
    var kind: ItineraryItemKind
    var status: ItineraryItemStatus
    var flexibility: ItineraryFlexibility
    var start: Date
    var end: Date
    var timeZoneIdentifier: String
    var location: TravelLocation?
    var reference: ItineraryReference
    var estimatedCost: Money?
    var notes: String?
    var createdByTravelerID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        kind: ItineraryItemKind,
        status: ItineraryItemStatus = .proposed,
        flexibility: ItineraryFlexibility = .flexible,
        start: Date,
        end: Date,
        timeZoneIdentifier: String,
        location: TravelLocation? = nil,
        reference: ItineraryReference = .userCreated,
        estimatedCost: Money? = nil,
        notes: String? = nil,
        createdByTravelerID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.status = status
        self.flexibility = flexibility
        self.start = start
        self.end = end
        self.timeZoneIdentifier = timeZoneIdentifier
        self.location = location
        self.reference = reference
        self.estimatedCost = estimatedCost
        self.notes = notes
        self.createdByTravelerID = createdByTravelerID
    }

    var isChronological: Bool {
        start <= end
    }
}

struct ItineraryDay: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var date: Date
    var timeZoneIdentifier: String
    var items: [ItineraryItem]
    var weatherSnapshotID: UUID?

    init(
        id: UUID = UUID(),
        date: Date,
        timeZoneIdentifier: String,
        items: [ItineraryItem] = [],
        weatherSnapshotID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.timeZoneIdentifier = timeZoneIdentifier
        self.items = items
        self.weatherSnapshotID = weatherSnapshotID
    }

    var chronologicallySortedItems: [ItineraryItem] {
        items.sorted { left, right in
            if left.start == right.start {
                return left.end < right.end
            }
            return left.start < right.start
        }
    }
}

struct TripItinerary: Codable, Hashable, Sendable {
    var days: [ItineraryDay]
    var transportationLegs: [TransportationLeg]

    init(
        days: [ItineraryDay] = [],
        transportationLegs: [TransportationLeg] = []
    ) {
        self.days = days
        self.transportationLegs = transportationLegs
    }

    var chronologicallySortedDays: [ItineraryDay] {
        days.sorted { $0.date < $1.date }
    }
}
