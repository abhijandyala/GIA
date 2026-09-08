import Foundation

enum TripDomainSchema {
    static let currentVersion = 1
}

struct Money: Codable, Hashable, Sendable {
    let amount: Decimal
    let currencyCode: String

    init(amount: Decimal, currencyCode: String) {
        self.amount = amount
        self.currencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    static func zero(currencyCode: String) -> Money {
        Money(amount: 0, currencyCode: currencyCode)
    }
}

struct GeoCoordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    init?(latitude: Double, longitude: Double) {
        guard
            (-90...90).contains(latitude),
            (-180...180).contains(longitude)
        else {
            return nil
        }

        self.latitude = latitude
        self.longitude = longitude
    }
}

struct TravelLocation: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var city: String?
    var region: String?
    var country: String?
    var countryCode: String?
    var iataCode: String?
    var coordinate: GeoCoordinate?
    var timeZoneIdentifier: String?

    init(
        id: UUID = UUID(),
        name: String,
        city: String? = nil,
        region: String? = nil,
        country: String? = nil,
        countryCode: String? = nil,
        iataCode: String? = nil,
        coordinate: GeoCoordinate? = nil,
        timeZoneIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.region = region
        self.country = country
        self.countryCode = countryCode?.uppercased()
        self.iataCode = iataCode?.uppercased()
        self.coordinate = coordinate
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var timeZone: TimeZone? {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
    }
}

struct TripDateRange: Codable, Hashable, Sendable {
    var start: Date
    var end: Date
    var timeZoneIdentifier: String

    init(
        start: Date,
        end: Date,
        timeZoneIdentifier: String
    ) {
        self.start = start
        self.end = end
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var timeZone: TimeZone? {
        TimeZone(identifier: timeZoneIdentifier)
    }

    var isChronological: Bool {
        start <= end
    }
}

enum DataOrigin: String, Codable, CaseIterable, Sendable {
    case live
    case cached
    case demo
    case userEntered
}

struct TravelProvider: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let serpApi = TravelProvider(rawValue: "serpapi")
    static let openAI = TravelProvider(rawValue: "openai")
    static let elevenLabs = TravelProvider(rawValue: "elevenlabs")
    static let geoapify = TravelProvider(rawValue: "geoapify")
    static let weatherAPI = TravelProvider(rawValue: "weatherapi")
    static let translation = TravelProvider(rawValue: "translation")
    static let user = TravelProvider(rawValue: "user")
    static let gia = TravelProvider(rawValue: "gia")
}

struct DataProvenance: Codable, Hashable, Sendable {
    var provider: TravelProvider
    var providerIdentifier: String?
    var origin: DataOrigin
    var retrievedAt: Date
    var expiresAt: Date?
    var sourceURL: URL?

    init(
        provider: TravelProvider,
        providerIdentifier: String? = nil,
        origin: DataOrigin,
        retrievedAt: Date,
        expiresAt: Date? = nil,
        sourceURL: URL? = nil
    ) {
        self.provider = provider
        self.providerIdentifier = providerIdentifier
        self.origin = origin
        self.retrievedAt = retrievedAt
        self.expiresAt = expiresAt
        self.sourceURL = sourceURL
    }

    func isExpired(at date: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return date >= expiresAt
    }
}

enum AccessibilityRequirement: String, Codable, CaseIterable, Sendable {
    case wheelchairAccess
    case stepFreeAccess
    case visualAssistance
    case hearingAssistance
    case serviceAnimal
    case reducedWalking
    case quietEnvironment
}

enum DietaryRequirement: String, Codable, CaseIterable, Sendable {
    case vegetarian
    case vegan
    case halal
    case kosher
    case glutenFree
    case dairyFree
    case nutFree
    case shellfishFree
}

enum TripInterest: String, Codable, CaseIterable, Sendable {
    case adventure
    case art
    case beaches
    case culture
    case family
    case food
    case history
    case museums
    case nature
    case nightlife
    case relaxation
    case shopping
    case sports
    case technology
}
