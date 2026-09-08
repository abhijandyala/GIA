import Foundation

enum TravelClass: String, Codable, CaseIterable, Sendable {
    case economy
    case premiumEconomy
    case business
    case first
}

enum StopPreference: String, Codable, CaseIterable, Sendable {
    case nonstopOnly
    case atMostOne
    case any
}

struct FlightPreferences: Codable, Hashable, Sendable {
    var travelClass: TravelClass
    var stopPreference: StopPreference
    var preferredAirlines: Set<String>
    var excludedAirlines: Set<String>
    var checkedBagRequired: Bool
    var refundablePreferred: Bool
    var departureTimeWindow: TimeWindow?

    init(
        travelClass: TravelClass = .economy,
        stopPreference: StopPreference = .any,
        preferredAirlines: Set<String> = [],
        excludedAirlines: Set<String> = [],
        checkedBagRequired: Bool = false,
        refundablePreferred: Bool = false,
        departureTimeWindow: TimeWindow? = nil
    ) {
        self.travelClass = travelClass
        self.stopPreference = stopPreference
        self.preferredAirlines = preferredAirlines
        self.excludedAirlines = excludedAirlines
        self.checkedBagRequired = checkedBagRequired
        self.refundablePreferred = refundablePreferred
        self.departureTimeWindow = departureTimeWindow
    }
}

struct TimeWindow: Codable, Hashable, Sendable {
    var startMinute: Int
    var endMinute: Int

    init(startMinute: Int, endMinute: Int) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }
}

enum LodgingType: String, Codable, CaseIterable, Sendable {
    case hotel
    case hostel
    case resort
    case vacationRental
    case apartment
}

enum HotelAmenity: String, Codable, CaseIterable, Sendable {
    case accessibleRoom
    case airportShuttle
    case breakfast
    case fitnessCenter
    case kitchen
    case laundry
    case parking
    case pool
    case spa
    case wifi
}

struct HotelPreferences: Codable, Hashable, Sendable {
    var allowedTypes: Set<LodgingType>
    var minimumStarRating: Int?
    var minimumGuestRating: Double?
    var requiredAmenities: Set<HotelAmenity>
    var maximumNightlyRate: Money?
    var refundablePreferred: Bool
    var maximumMinutesFromActivities: Int?

    init(
        allowedTypes: Set<LodgingType> = [.hotel],
        minimumStarRating: Int? = nil,
        minimumGuestRating: Double? = nil,
        requiredAmenities: Set<HotelAmenity> = [],
        maximumNightlyRate: Money? = nil,
        refundablePreferred: Bool = false,
        maximumMinutesFromActivities: Int? = nil
    ) {
        self.allowedTypes = allowedTypes
        self.minimumStarRating = minimumStarRating
        self.minimumGuestRating = minimumGuestRating
        self.requiredAmenities = requiredAmenities
        self.maximumNightlyRate = maximumNightlyRate
        self.refundablePreferred = refundablePreferred
        self.maximumMinutesFromActivities =
            maximumMinutesFromActivities
    }
}

struct TripRequest: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var rawTranscript: String?
    var origin: TravelLocation?
    var destinations: [TravelLocation]
    var dateRange: TripDateRange?
    var durationDays: Int?
    var travelerCount: Int?
    var totalBudget: Money?
    var interests: Set<TripInterest>
    var dietaryRequirements: Set<DietaryRequirement>
    var accessibilityRequirements: Set<AccessibilityRequirement>
    var preferredPace: TravelPace
    var flightPreferences: FlightPreferences
    var hotelPreferences: HotelPreferences
    var notes: String?
    var requestedAt: Date

    init(
        id: UUID = UUID(),
        rawTranscript: String? = nil,
        origin: TravelLocation? = nil,
        destinations: [TravelLocation] = [],
        dateRange: TripDateRange? = nil,
        durationDays: Int? = nil,
        travelerCount: Int? = nil,
        totalBudget: Money? = nil,
        interests: Set<TripInterest> = [],
        dietaryRequirements: Set<DietaryRequirement> = [],
        accessibilityRequirements: Set<AccessibilityRequirement> = [],
        preferredPace: TravelPace = .balanced,
        flightPreferences: FlightPreferences = FlightPreferences(),
        hotelPreferences: HotelPreferences = HotelPreferences(),
        notes: String? = nil,
        requestedAt: Date = Date()
    ) {
        self.id = id
        self.rawTranscript = rawTranscript
        self.origin = origin
        self.destinations = destinations
        self.dateRange = dateRange
        self.durationDays = durationDays
        self.travelerCount = travelerCount
        self.totalBudget = totalBudget
        self.interests = interests
        self.dietaryRequirements = dietaryRequirements
        self.accessibilityRequirements = accessibilityRequirements
        self.preferredPace = preferredPace
        self.flightPreferences = flightPreferences
        self.hotelPreferences = hotelPreferences
        self.notes = notes
        self.requestedAt = requestedAt
    }
}
