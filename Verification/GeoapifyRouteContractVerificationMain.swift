import Foundation

private struct RouteContractAuthorization:
    GatewayAuthorizationProviding
{
    func bearerToken() async throws -> String? {
        "fixture-session"
    }
}

private actor RouteContractTransport: GatewayTransport {
    private(set) var count = 0
    let response: GatewayHTTPResponse

    init(response: GatewayHTTPResponse) {
        self.response = response
    }

    func send(_ request: URLRequest) async throws
        -> GatewayHTTPResponse
    {
        count += 1
        precondition(request.url?.path == "/v1/route")
        return response
    }
}

@main
enum GeoapifyRouteContractVerificationMain {
    @MainActor
    static func main() async throws {
        let json = """
        {
          "data": {
            "routes": [
              {
                "id": "6aac2b7f-b8f8-598f-a205-450b734ee1d4",
                "origin": {
                  "id": "34227b76-4156-56b1-ad22-7325de8d2880",
                  "name": "Lisbon Hotel",
                  "coordinate": {
                    "latitude": 38.7223,
                    "longitude": -9.1393
                  },
                  "timeZoneIdentifier": "Europe/Lisbon"
                },
                "destination": {
                  "id": "5c43a59d-c9a4-55db-a5a2-66cca6ca8701",
                  "name": "Lisbon Museum",
                  "coordinate": {
                    "latitude": 38.7101,
                    "longitude": -9.129
                  },
                  "timeZoneIdentifier": "Europe/Lisbon"
                },
                "mode": "transit",
                "plannedDeparture": "2027-06-12T09:00:00.000Z",
                "plannedArrival": "2027-06-12T09:15:00.000Z",
                "duration": 900,
                "distanceMeters": 1200,
                "routeGeometry": [
                  {
                    "latitude": 38.7223,
                    "longitude": -9.1393
                  },
                  {
                    "latitude": 38.7101,
                    "longitude": -9.129
                  }
                ],
                "instructions": [
                  "Walk to the station",
                  "Take the metro"
                ],
                "bufferDuration": 600,
                "confidence": "scheduled",
                "provenance": {
                  "provider": "geoapify",
                  "providerIdentifier": "route-source-1",
                  "origin": "live",
                  "retrievedAt": "2026-09-06T08:00:00.000Z",
                  "expiresAt": "2026-09-06T08:15:00.000Z",
                  "sourceURL": "https://www.geoapify.com/routing-api/"
                }
              }
            ]
          }
        }
        """
        let response = HTTPURLResponse(
            url: URL(string: "https://gateway.example/v1/route")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json"
            ]
        )!
        let transport = RouteContractTransport(
            response: GatewayHTTPResponse(
                data: Data(json.utf8),
                response: response
            )
        )
        let client = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: URL(string: "https://gateway.example")!,
                authorizationProvider: RouteContractAuthorization()
            ),
            transport: transport,
            cache: GatewayResponseCache(
                directoryURL:
                    FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
            )
        )
        let service = GatewayTravelService(client: client)
        let origin = TravelLocation(
            name: "Lisbon Hotel",
            coordinate: GeoCoordinate(
                latitude: 38.7223,
                longitude: -9.1393
            ),
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let destination = TravelLocation(
            name: "Lisbon Museum",
            coordinate: GeoCoordinate(
                latitude: 38.7101,
                longitude: -9.129
            ),
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let criteria = RoutePlanningCriteria(
            origin: origin,
            destination: destination,
            modes: [.transit],
            departure:
                Date(timeIntervalSince1970: 1_813_053_600),
            currencyCode: "USD"
        )
        let dateRange = TripDateRange(
            start: Date(timeIntervalSince1970: 1_812_758_400),
            end: Date(timeIntervalSince1970: 1_813_363_200),
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let planningRequest = TripRequest(
            destinations: [destination],
            dateRange: dateRange,
            travelerCount: 4,
            totalBudget: Money(
                amount: 6_000,
                currencyCode: "USD"
            )
        )
        let session = TripPlanningSession()
        try session.beginListening(source: .manual)
        try session.beginTranscribing()
        try session.beginValidation(request: planningRequest)
        try session.beginSearch()
        let coordinator = RoutePlanningCoordinator(service: service)
        let routes = try await coordinator.plan(
            criteria: criteria,
            session: session
        )

        precondition(routes.count == 1)
        let route = routes[0]
        precondition(route.mode == .transit)
        precondition(route.confidence == .scheduled)
        precondition(route.duration == 900)
        precondition(route.distanceMeters == 1200)
        precondition(route.routeGeometry.count == 2)
        precondition(route.instructions.count == 2)
        precondition(route.bufferDuration == 600)
        precondition(route.estimatedCost == nil)
        precondition(route.provenance.provider == .geoapify)
        precondition(
            session.progress.item(for: .routes).status == .complete
        )
        precondition(
            session.progress.item(for: .routes).resultCount == 1
        )
        let requestCount = await transport.count
        precondition(requestCount == 1)

        print("Geoapify route gateway contract passed.")
    }
}
