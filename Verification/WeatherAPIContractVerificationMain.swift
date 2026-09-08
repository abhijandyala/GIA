import Foundation

private struct WeatherContractAuthorization:
    GatewayAuthorizationProviding
{
    func bearerToken() async throws -> String? {
        "fixture-session"
    }
}

private actor WeatherContractTransport: GatewayTransport {
    private(set) var count = 0
    let response: GatewayHTTPResponse

    init(response: GatewayHTTPResponse) {
        self.response = response
    }

    func send(_ request: URLRequest) async throws
        -> GatewayHTTPResponse
    {
        count += 1
        precondition(request.url?.path == "/v1/weather")
        return response
    }
}

@main
enum WeatherAPIContractVerificationMain {
    @MainActor
    static func main() async throws {
        let json = """
        {
          "data": {
            "snapshots": [
              {
                "id": "6aac2b7f-b8f8-598f-a205-450b734ee1d4",
                "location": {
                  "id": "34227b76-4156-56b1-ad22-7325de8d2880",
                  "name": "Lisbon",
                  "city": "Lisbon",
                  "country": "Portugal",
                  "countryCode": "PT",
                  "coordinate": {
                    "latitude": 38.7223,
                    "longitude": -9.1393
                  },
                  "timeZoneIdentifier": "Europe/Lisbon"
                },
                "timeZoneIdentifier": "Europe/Lisbon",
                "periods": [
                  {
                    "id": "5c43a59d-c9a4-55db-a5a2-66cca6ca8701",
                    "start": "2027-06-10T14:00:00.000Z",
                    "end": "2027-06-10T15:00:00.000Z",
                    "condition": "rain",
                    "providerConditionCode": 1195,
                    "providerDescription": "Heavy rain",
                    "temperatureCelsius": 23,
                    "feelsLikeCelsius": 24,
                    "precipitationProbability": 0.75,
                    "windKilometersPerHour": 18
                  }
                ],
                "alerts": [
                  {
                    "id": "28b49958-c217-5d6e-86d3-1c8cd6f9ff1b",
                    "headline": "Severe thunderstorm warning",
                    "reportingAgency": "IPMA",
                    "severity": "severe",
                    "effectiveAt": "2027-06-10T11:00:00.000Z",
                    "expiresAt": "2027-06-10T18:00:00.000Z",
                    "instructions": "Move indoors.",
                    "sourceURL": "https://alerts.example/severe"
                  }
                ],
                "provenance": {
                  "provider": "weatherapi",
                  "providerIdentifier": "weather-source-1",
                  "origin": "live",
                  "retrievedAt": "2027-06-10T08:00:00.000Z",
                  "expiresAt": "2027-06-10T08:15:00.000Z",
                  "sourceURL": "https://www.weatherapi.com/"
                }
              }
            ]
          }
        }
        """
        let response = HTTPURLResponse(
            url: URL(string: "https://gateway.example/v1/weather")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json"
            ]
        )!
        let transport = WeatherContractTransport(
            response: GatewayHTTPResponse(
                data: Data(json.utf8),
                response: response
            )
        )
        let client = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: URL(string: "https://gateway.example")!,
                authorizationProvider: WeatherContractAuthorization()
            ),
            transport: transport,
            cache: GatewayResponseCache(
                directoryURL:
                    FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
            )
        )
        let service = GatewayTravelService(client: client)
        let location = TravelLocation(
            name: "Lisbon",
            city: "Lisbon",
            country: "Portugal",
            countryCode: "PT",
            coordinate: GeoCoordinate(
                latitude: 38.7223,
                longitude: -9.1393
            ),
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let dateRange = TripDateRange(
            start: Date(timeIntervalSince1970: 1_812_758_400),
            end: Date(timeIntervalSince1970: 1_812_931_200),
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let criteria = WeatherSearchCriteria(
            location: location,
            dateRange: dateRange,
            includeAlerts: true
        )
        let request = TripRequest(
            destinations: [location],
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
        try session.beginValidation(request: request)
        try session.beginSearch()
        let coordinator = WeatherSearchCoordinator(service: service)
        let snapshots = try await coordinator.search(
            criteria: criteria,
            session: session
        )

        precondition(snapshots.count == 1)
        let snapshot = snapshots[0]
        precondition(snapshot.periods.count == 1)
        precondition(snapshot.periods[0].condition == .rain)
        precondition(
            snapshot.periods[0].precipitationProbability == 0.75
        )
        precondition(snapshot.alerts.count == 1)
        precondition(snapshot.alerts[0].severity == .severe)
        precondition(snapshot.provenance.provider == .weatherAPI)

        let advisories = WeatherAdvisoryEngine.advisories(
            for: snapshots
        )
        precondition(
            advisories.contains {
                $0.severity == .critical
                    && $0.action == .avoidOutdoor
            }
        )
        precondition(
            advisories.contains {
                $0.severity == .caution
                    && $0.action == .preferIndoor
            }
        )
        precondition(
            session.progress.item(for: .weather).status == .complete
        )
        precondition(
            session.progress.item(for: .weather).resultCount == 1
        )
        let requestCount = await transport.count
        precondition(requestCount == 1)

        print("WeatherAPI gateway and advisory contract passed.")
    }
}
