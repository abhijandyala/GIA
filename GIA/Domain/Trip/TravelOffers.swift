import Foundation

enum OfferBadge: String, Codable, CaseIterable, Sendable {
    case giaRecommended
    case lowestPrice
    case fastest
    case fewestStops
    case flexible
    case lowerEmissions
}

enum PriceLevel: String, Codable, CaseIterable, Sendable {
    case low
    case typical
    case high
    case unknown
}

struct PriceInsight: Codable, Hashable, Sendable {
    var level: PriceLevel
    var typicalLow: Money?
    var typicalHigh: Money?
    var observedLowest: Money?
}

struct BaggageAllowance: Codable, Hashable, Sendable {
    var personalItems: Int?
    var carryOnBags: Int?
    var checkedBags: Int?
    var checkedBagFee: Money?
    var rawDescription: String?
}

struct FlightSegment: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var airlineCode: String
    var airlineName: String
    var flightNumber: String
    var origin: TravelLocation
    var destination: TravelLocation
    var departure: Date
    var arrival: Date
    var departureLocalTimeText: String?
    var arrivalLocalTimeText: String?
    var departureTimeZoneIdentifier: String
    var arrivalTimeZoneIdentifier: String
    var departureTimeZoneIsResolved: Bool
    var arrivalTimeZoneIsResolved: Bool
    var duration: TimeInterval
    var aircraftName: String?
    var travelClass: TravelClass

    init(
        id: UUID = UUID(),
        airlineCode: String,
        airlineName: String,
        flightNumber: String,
        origin: TravelLocation,
        destination: TravelLocation,
        departure: Date,
        arrival: Date,
        departureLocalTimeText: String? = nil,
        arrivalLocalTimeText: String? = nil,
        departureTimeZoneIdentifier: String,
        arrivalTimeZoneIdentifier: String,
        departureTimeZoneIsResolved: Bool = true,
        arrivalTimeZoneIsResolved: Bool = true,
        duration: TimeInterval,
        aircraftName: String? = nil,
        travelClass: TravelClass
    ) {
        self.id = id
        self.airlineCode = airlineCode.uppercased()
        self.airlineName = airlineName
        self.flightNumber = flightNumber
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.arrival = arrival
        self.departureLocalTimeText = departureLocalTimeText
        self.arrivalLocalTimeText = arrivalLocalTimeText
        self.departureTimeZoneIdentifier =
            departureTimeZoneIdentifier
        self.arrivalTimeZoneIdentifier =
            arrivalTimeZoneIdentifier
        self.departureTimeZoneIsResolved =
            departureTimeZoneIsResolved
        self.arrivalTimeZoneIsResolved =
            arrivalTimeZoneIsResolved
        self.duration = duration
        self.aircraftName = aircraftName
        self.travelClass = travelClass
    }
}

struct FlightOffer: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var providerOfferIdentifier: String
    var continuationToken: String?
    var outboundSegments: [FlightSegment]
    var returnSegments: [FlightSegment]
    var totalDuration: TimeInterval
    var totalPrice: Money
    var baggage: BaggageAllowance?
    var badges: Set<OfferBadge>
    var carbonEmissionsGrams: Int?
    var priceInsight: PriceInsight?
    var refundable: Bool?
    var bookingURL: URL?
    var provenance: DataProvenance

    init(
        id: UUID = UUID(),
        providerOfferIdentifier: String,
        continuationToken: String? = nil,
        outboundSegments: [FlightSegment],
        returnSegments: [FlightSegment] = [],
        totalDuration: TimeInterval,
        totalPrice: Money,
        baggage: BaggageAllowance? = nil,
        badges: Set<OfferBadge> = [],
        carbonEmissionsGrams: Int? = nil,
        priceInsight: PriceInsight? = nil,
        refundable: Bool? = nil,
        bookingURL: URL? = nil,
        provenance: DataProvenance
    ) {
        self.id = id
        self.providerOfferIdentifier = providerOfferIdentifier
        self.continuationToken = continuationToken
        self.outboundSegments = outboundSegments
        self.returnSegments = returnSegments
        self.totalDuration = totalDuration
        self.totalPrice = totalPrice
        self.baggage = baggage
        self.badges = badges
        self.carbonEmissionsGrams = carbonEmissionsGrams
        self.priceInsight = priceInsight
        self.refundable = refundable
        self.bookingURL = bookingURL
        self.provenance = provenance
    }
}

struct CancellationPolicy: Codable, Hashable, Sendable {
    var summary: String
    var refundableUntil: Date?
    var penalty: Money?
}

struct HotelOffer: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var providerOfferIdentifier: String
    var name: String
    var location: TravelLocation
    var lodgingType: LodgingType
    var starRating: Int?
    var guestRating: Double?
    var guestRatingScale: Double?
    var reviewCount: Int?
    var nightlyPrice: Money?
    var totalPrice: Money
    var taxesAndFeesIncluded: Bool?
    var roomDescription: String?
    var amenities: Set<HotelAmenity>
    var imageURLs: [URL]
    var checkInTime: String?
    var checkOutTime: String?
    var cancellationPolicy: CancellationPolicy?
    var badges: Set<OfferBadge>
    var bookingURL: URL?
    var provenance: DataProvenance

    init(
        id: UUID = UUID(),
        providerOfferIdentifier: String,
        name: String,
        location: TravelLocation,
        lodgingType: LodgingType,
        starRating: Int? = nil,
        guestRating: Double? = nil,
        guestRatingScale: Double? = nil,
        reviewCount: Int? = nil,
        nightlyPrice: Money? = nil,
        totalPrice: Money,
        taxesAndFeesIncluded: Bool? = nil,
        roomDescription: String? = nil,
        amenities: Set<HotelAmenity> = [],
        imageURLs: [URL] = [],
        checkInTime: String? = nil,
        checkOutTime: String? = nil,
        cancellationPolicy: CancellationPolicy? = nil,
        badges: Set<OfferBadge> = [],
        bookingURL: URL? = nil,
        provenance: DataProvenance
    ) {
        self.id = id
        self.providerOfferIdentifier = providerOfferIdentifier
        self.name = name
        self.location = location
        self.lodgingType = lodgingType
        self.starRating = starRating
        self.guestRating = guestRating
        self.guestRatingScale = guestRatingScale
        self.reviewCount = reviewCount
        self.nightlyPrice = nightlyPrice
        self.totalPrice = totalPrice
        self.taxesAndFeesIncluded = taxesAndFeesIncluded
        self.roomDescription = roomDescription
        self.amenities = amenities
        self.imageURLs = imageURLs
        self.checkInTime = checkInTime
        self.checkOutTime = checkOutTime
        self.cancellationPolicy = cancellationPolicy
        self.badges = badges
        self.bookingURL = bookingURL
        self.provenance = provenance
    }
}

enum PlaceCategory: String, Codable, CaseIterable, Sendable {
    case activity
    case attraction
    case cafe
    case entertainment
    case landmark
    case museum
    case nightlife
    case park
    case restaurant
    case shopping
    case sports
}

struct OpeningHours: Codable, Hashable, Sendable {
    var rawText: [String]
    var isOpenAtRetrieval: Bool?
}

struct PlaceRecommendation: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var providerPlaceIdentifier: String
    var name: String
    var location: TravelLocation
    var categories: Set<PlaceCategory>
    var summary: String?
    var rating: Double?
    var reviewCount: Int?
    var priceLevel: Int?
    var estimatedCostPerTraveler: Money?
    var estimatedDuration: TimeInterval?
    var openingHours: OpeningHours?
    var imageURLs: [URL]
    var websiteURL: URL?
    var bookingURL: URL?
    var dietaryOptions: Set<DietaryRequirement>
    var accessibilityFeatures: Set<AccessibilityRequirement>
    var indoor: Bool?
    var reservationRequired: Bool?
    var provenance: DataProvenance

    init(
        id: UUID = UUID(),
        providerPlaceIdentifier: String,
        name: String,
        location: TravelLocation,
        categories: Set<PlaceCategory>,
        summary: String? = nil,
        rating: Double? = nil,
        reviewCount: Int? = nil,
        priceLevel: Int? = nil,
        estimatedCostPerTraveler: Money? = nil,
        estimatedDuration: TimeInterval? = nil,
        openingHours: OpeningHours? = nil,
        imageURLs: [URL] = [],
        websiteURL: URL? = nil,
        bookingURL: URL? = nil,
        dietaryOptions: Set<DietaryRequirement> = [],
        accessibilityFeatures: Set<AccessibilityRequirement> = [],
        indoor: Bool? = nil,
        reservationRequired: Bool? = nil,
        provenance: DataProvenance
    ) {
        self.id = id
        self.providerPlaceIdentifier = providerPlaceIdentifier
        self.name = name
        self.location = location
        self.categories = categories
        self.summary = summary
        self.rating = rating
        self.reviewCount = reviewCount
        self.priceLevel = priceLevel
        self.estimatedCostPerTraveler =
            estimatedCostPerTraveler
        self.estimatedDuration = estimatedDuration
        self.openingHours = openingHours
        self.imageURLs = imageURLs
        self.websiteURL = websiteURL
        self.bookingURL = bookingURL
        self.dietaryOptions = dietaryOptions
        self.accessibilityFeatures = accessibilityFeatures
        self.indoor = indoor
        self.reservationRequired = reservationRequired
        self.provenance = provenance
    }
}
