import Foundation

enum TransportationMode: String, Codable, CaseIterable, Sendable {
    case airplane
    case bicycle
    case bus
    case car
    case ferry
    case rideshare
    case subway
    case train
    case transit
    case walking
}

enum RouteConfidence: String, Codable, CaseIterable, Sendable {
    case live
    case scheduled
    case estimated
    case approximated
}

struct TransportationLeg: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var origin: TravelLocation
    var destination: TravelLocation
    var mode: TransportationMode
    var plannedDeparture: Date?
    var plannedArrival: Date?
    var duration: TimeInterval
    var distanceMeters: Double?
    var estimatedCost: Money?
    var routeGeometry: [GeoCoordinate]
    var instructions: [String]
    var bufferDuration: TimeInterval
    var confidence: RouteConfidence
    var externalBookingURL: URL?
    var provenance: DataProvenance

    init(
        id: UUID = UUID(),
        origin: TravelLocation,
        destination: TravelLocation,
        mode: TransportationMode,
        plannedDeparture: Date? = nil,
        plannedArrival: Date? = nil,
        duration: TimeInterval,
        distanceMeters: Double? = nil,
        estimatedCost: Money? = nil,
        routeGeometry: [GeoCoordinate] = [],
        instructions: [String] = [],
        bufferDuration: TimeInterval = 0,
        confidence: RouteConfidence,
        externalBookingURL: URL? = nil,
        provenance: DataProvenance
    ) {
        self.id = id
        self.origin = origin
        self.destination = destination
        self.mode = mode
        self.plannedDeparture = plannedDeparture
        self.plannedArrival = plannedArrival
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.estimatedCost = estimatedCost
        self.routeGeometry = routeGeometry
        self.instructions = instructions
        self.bufferDuration = bufferDuration
        self.confidence = confidence
        self.externalBookingURL = externalBookingURL
        self.provenance = provenance
    }
}

enum WeatherConditionCategory: String, Codable, CaseIterable, Sendable {
    case clear
    case cloudy
    case fog
    case rain
    case snow
    case storm
    case wind
    case unknown
}

struct WeatherPeriod: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var start: Date
    var end: Date
    var condition: WeatherConditionCategory
    var providerConditionCode: Int?
    var providerDescription: String
    var temperatureCelsius: Double?
    var feelsLikeCelsius: Double?
    var precipitationProbability: Double?
    var windKilometersPerHour: Double?

    init(
        id: UUID = UUID(),
        start: Date,
        end: Date,
        condition: WeatherConditionCategory,
        providerConditionCode: Int? = nil,
        providerDescription: String,
        temperatureCelsius: Double? = nil,
        feelsLikeCelsius: Double? = nil,
        precipitationProbability: Double? = nil,
        windKilometersPerHour: Double? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.condition = condition
        self.providerConditionCode = providerConditionCode
        self.providerDescription = providerDescription
        self.temperatureCelsius = temperatureCelsius
        self.feelsLikeCelsius = feelsLikeCelsius
        self.precipitationProbability = precipitationProbability
        self.windKilometersPerHour = windKilometersPerHour
    }
}

enum WeatherAlertSeverity: String, Codable, CaseIterable, Sendable {
    case minor
    case moderate
    case severe
    case extreme
    case unknown
}

struct WeatherAlert: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var headline: String
    var reportingAgency: String?
    var severity: WeatherAlertSeverity
    var effectiveAt: Date?
    var expiresAt: Date?
    var instructions: String?
    var sourceURL: URL?

    init(
        id: UUID = UUID(),
        headline: String,
        reportingAgency: String? = nil,
        severity: WeatherAlertSeverity,
        effectiveAt: Date? = nil,
        expiresAt: Date? = nil,
        instructions: String? = nil,
        sourceURL: URL? = nil
    ) {
        self.id = id
        self.headline = headline
        self.reportingAgency = reportingAgency
        self.severity = severity
        self.effectiveAt = effectiveAt
        self.expiresAt = expiresAt
        self.instructions = instructions
        self.sourceURL = sourceURL
    }
}

struct WeatherSnapshot: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var location: TravelLocation
    var timeZoneIdentifier: String
    var periods: [WeatherPeriod]
    var alerts: [WeatherAlert]
    var provenance: DataProvenance

    init(
        id: UUID = UUID(),
        location: TravelLocation,
        timeZoneIdentifier: String,
        periods: [WeatherPeriod],
        alerts: [WeatherAlert] = [],
        provenance: DataProvenance
    ) {
        self.id = id
        self.location = location
        self.timeZoneIdentifier = timeZoneIdentifier
        self.periods = periods
        self.alerts = alerts
        self.provenance = provenance
    }
}
