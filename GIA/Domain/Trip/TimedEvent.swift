import Foundation

enum TimedEventStatus: String, Codable, CaseIterable, Sendable {
    case upcoming
    case postponed
    case cancelled
    case unknown
}

enum ActivitySchedulingTrait: String, Codable, CaseIterable, Sendable {
    case fixedTime
    case flexibleTime
    case reservationAvailable
    case ticketRequired
    case walkIn
    case weatherDependent
    case indoor
    case outdoor
}

struct TimedEvent: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var providerEventIdentifier: String
    var title: String
    var summary: String?
    var venueName: String?
    var location: TravelLocation
    var start: Date?
    var end: Date?
    var rawDateText: String
    var timeZoneIdentifier: String
    var timeZoneIsResolved: Bool
    var status: TimedEventStatus
    var schedulingTraits: Set<ActivitySchedulingTrait>
    var venueRating: Double?
    var venueRatingScale: Double?
    var venueReviewCount: Int?
    var imageURL: URL?
    var sourceURL: URL?
    var ticketURLs: [URL]
    var provenance: DataProvenance

    init(
        id: UUID = UUID(),
        providerEventIdentifier: String,
        title: String,
        summary: String? = nil,
        venueName: String? = nil,
        location: TravelLocation,
        start: Date? = nil,
        end: Date? = nil,
        rawDateText: String,
        timeZoneIdentifier: String,
        timeZoneIsResolved: Bool,
        status: TimedEventStatus = .unknown,
        schedulingTraits: Set<ActivitySchedulingTrait> = [],
        venueRating: Double? = nil,
        venueRatingScale: Double? = nil,
        venueReviewCount: Int? = nil,
        imageURL: URL? = nil,
        sourceURL: URL? = nil,
        ticketURLs: [URL] = [],
        provenance: DataProvenance
    ) {
        self.id = id
        self.providerEventIdentifier = providerEventIdentifier
        self.title = title
        self.summary = summary
        self.venueName = venueName
        self.location = location
        self.start = start
        self.end = end
        self.rawDateText = rawDateText
        self.timeZoneIdentifier = timeZoneIdentifier
        self.timeZoneIsResolved = timeZoneIsResolved
        self.status = status
        self.schedulingTraits = schedulingTraits
        self.venueRating = venueRating
        self.venueRatingScale = venueRatingScale
        self.venueReviewCount = venueReviewCount
        self.imageURL = imageURL
        self.sourceURL = sourceURL
        self.ticketURLs = ticketURLs
        self.provenance = provenance
    }

    var hasResolvedSchedule: Bool {
        start != nil && timeZoneIsResolved
    }
}
