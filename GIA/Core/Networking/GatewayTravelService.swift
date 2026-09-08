import Foundation

actor GatewayTravelService:
    TripPlanningServing,
    AssistantResponding,
    TripReplyInterpreting,
    TravelLocationResolving,
    FlightSearching,
    HotelSearching,
    PlaceSearching,
    EventSearching,
    RoutePlanning,
    WeatherProviding,
    TripIntelligence,
    SpeechGenerating,
    TranslationProviding
{
    private struct FlightResponse: Codable, Sendable {
        var offers: [FlightOffer]
    }

    private struct HotelResponse: Codable, Sendable {
        var offers: [HotelOffer]
    }

    private struct PlaceResponse: Codable, Sendable {
        var places: [PlaceRecommendation]
    }

    private struct EventResponse: Codable, Sendable {
        var events: [TimedEvent]
    }

    private struct RouteResponse: Codable, Sendable {
        var routes: [TransportationLeg]
    }

    private struct WeatherResponse: Codable, Sendable {
        var snapshots: [WeatherSnapshot]
    }

    private let client: GIAGatewayClient

    init(client: GIAGatewayClient) {
        self.client = client
    }

    func searchFlights(
        matching criteria: FlightSearchCriteria
    ) async throws -> [FlightOffer] {
        let response: FlightResponse = try await client.send(
            criteria,
            to: .flights
        )
        return response.offers
    }

    func completeRoundTrip(
        matching criteria: RoundTripFlightCompletionCriteria
    ) async throws -> [FlightOffer] {
        let response: FlightResponse = try await client.send(
            criteria,
            to: .flightReturn
        )
        return response.offers
    }

    func generateResponse(
        matching context: GIAConversationContext
    ) async throws -> GIAConversationResponse {
        try await client.send(
            context,
            to: .assistantResponse
        )
    }

    func interpretReply(
        matching request: TripReplyInterpretationRequest
    ) async throws -> TripReplyInterpretation {
        try await client.send(
            request,
            to: .interpretReply
        )
    }

    func resolveLocation(
        matching criteria: LocationResolutionCriteria
    ) async throws -> TravelLocation {
        try await client.send(criteria, to: .location)
    }

    func searchHotels(
        matching criteria: HotelSearchCriteria
    ) async throws -> [HotelOffer] {
        let response: HotelResponse = try await client.send(
            criteria,
            to: .hotels
        )
        return response.offers
    }

    func searchPlaces(
        matching criteria: PlaceSearchCriteria
    ) async throws -> [PlaceRecommendation] {
        let response: PlaceResponse = try await client.send(
            criteria,
            to: .places
        )
        return response.places
    }

    func searchEvents(
        matching criteria: EventSearchCriteria
    ) async throws -> [TimedEvent] {
        let response: EventResponse = try await client.send(
            criteria,
            to: .events
        )
        return response.events
    }

    func planRoutes(
        matching criteria: RoutePlanningCriteria
    ) async throws -> [TransportationLeg] {
        let response: RouteResponse = try await client.send(
            criteria,
            to: .route
        )
        return response.routes
    }

    func weather(
        matching criteria: WeatherSearchCriteria
    ) async throws -> [WeatherSnapshot] {
        let response: WeatherResponse = try await client.send(
            criteria,
            to: .weather
        )
        return response.snapshots
    }

    func generatePlan(
        matching criteria: TripGenerationCriteria
    ) async throws -> TripPlanBlueprint {
        let blueprint: TripPlanBlueprint = try await client.send(
            criteria,
            to: .plan
        )
        let issues = TripPlanBlueprintValidator.issues(
            in: blueprint,
            criteria: criteria
        )
        guard issues.isEmpty else {
            throw GatewayClientError.providerUnavailable(
                code: "invalid_plan_blueprint",
                message:
                    "The generated plan referenced invalid travel data."
            )
        }
        return blueprint
    }

    func generateSpeech(
        matching criteria: SpeechGenerationCriteria
    ) async throws -> GeneratedSpeech {
        try await client.sendForData(
            criteria,
            to: .speech,
            acceptedContentType: "audio/mpeg"
        )
    }

    func translate(
        matching criteria: TranslationCriteria
    ) async throws -> TranslatedText {
        try await client.send(
            criteria,
            to: .translation
        )
    }
}
