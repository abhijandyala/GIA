import Foundation

struct LocationResolutionCriteria:
    Codable,
    Hashable,
    Sendable
{
    var query: String
    var includeNearestAirport: Bool
}

struct FlightSearchCriteria: Codable, Hashable, Sendable {
    var origin: TravelLocation
    var destination: TravelLocation
    var departureDate: Date
    var returnDate: Date?
    var adults: Int
    var children: Int
    var currencyCode: String
    var preferences: FlightPreferences
}

struct RoundTripFlightCompletionCriteria:
    Codable,
    Hashable,
    Sendable
{
    var searchCriteria: FlightSearchCriteria
    var outboundOffer: FlightOffer
}

struct HotelSearchCriteria: Codable, Hashable, Sendable {
    var destination: TravelLocation
    var checkInDate: Date
    var checkOutDate: Date
    var adults: Int
    var rooms: Int
    var currencyCode: String
    var preferences: HotelPreferences
}

struct PlaceSearchCriteria: Codable, Hashable, Sendable {
    var destination: TravelLocation
    var categories: Set<PlaceCategory>
    var interests: Set<TripInterest>
    var dietaryRequirements: Set<DietaryRequirement>
    var accessibilityRequirements: Set<AccessibilityRequirement>
    var radiusMeters: Int = 15_000
    var limit: Int
}

struct EventSearchCriteria: Codable, Hashable, Sendable {
    var destination: TravelLocation
    var dateRange: TripDateRange
    var query: String?
    var interests: Set<TripInterest>
    var limit: Int
}

struct RoutePlanningCriteria: Codable, Hashable, Sendable {
    var origin: TravelLocation
    var destination: TravelLocation
    var modes: Set<TransportationMode>
    var departure: Date?
    var currencyCode: String
}

struct WeatherSearchCriteria: Codable, Hashable, Sendable {
    var location: TravelLocation
    var dateRange: TripDateRange
    var includeAlerts: Bool
}

struct TripGenerationCriteria: Codable, Hashable, Sendable {
    var request: TripRequest
    var flightOffers: [FlightOffer]
    var hotelOffers: [HotelOffer]
    var places: [PlaceRecommendation]
    var events: [TimedEvent] = []
    var routes: [TransportationLeg]
    var weather: [WeatherSnapshot]
}

struct SpeechGenerationCriteria: Codable, Hashable, Sendable {
    var text: String
    var voiceIdentifier: String?
    var outputFormat: String
}

struct GeneratedSpeech: Hashable, Sendable {
    var audioData: Data
    var contentType: String
}

struct TranslationCriteria: Codable, Hashable, Sendable {
    var text: String
    var sourceLanguageCode: String?
    var targetLanguageCode: String
    var contentKind: TranslationContentKind = .plainText
    var protectedTerms: [String] = []
}

protocol FlightSearching: Sendable {
    func searchFlights(
        matching criteria: FlightSearchCriteria
    ) async throws -> [FlightOffer]
}

protocol RoundTripFlightCompleting: Sendable {
    func completeRoundTrip(
        matching criteria: RoundTripFlightCompletionCriteria
    ) async throws -> [FlightOffer]
}

protocol TravelLocationResolving: Sendable {
    func resolveLocation(
        matching criteria: LocationResolutionCriteria
    ) async throws -> TravelLocation
}

protocol HotelSearching: Sendable {
    func searchHotels(
        matching criteria: HotelSearchCriteria
    ) async throws -> [HotelOffer]
}

protocol PlaceSearching: Sendable {
    func searchPlaces(
        matching criteria: PlaceSearchCriteria
    ) async throws -> [PlaceRecommendation]
}

protocol EventSearching: Sendable {
    func searchEvents(
        matching criteria: EventSearchCriteria
    ) async throws -> [TimedEvent]
}

protocol RoutePlanning: Sendable {
    func planRoutes(
        matching criteria: RoutePlanningCriteria
    ) async throws -> [TransportationLeg]
}

protocol WeatherProviding: Sendable {
    func weather(
        matching criteria: WeatherSearchCriteria
    ) async throws -> [WeatherSnapshot]
}

protocol TripIntelligence: Sendable {
    func generatePlan(
        matching criteria: TripGenerationCriteria
    ) async throws -> TripPlanBlueprint
}

protocol SpeechGenerating: Sendable {
    func generateSpeech(
        matching criteria: SpeechGenerationCriteria
    ) async throws -> GeneratedSpeech
}

protocol TranslationProviding: Sendable {
    func translate(
        matching criteria: TranslationCriteria
    ) async throws -> TranslatedText
}

protocol TripPlanningServing:
    TravelLocationResolving,
    FlightSearching,
    RoundTripFlightCompleting,
    HotelSearching,
    PlaceSearching,
    EventSearching,
    RoutePlanning,
    WeatherProviding,
    TripIntelligence,
    Sendable
{
}
