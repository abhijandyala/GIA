import Foundation

private struct PlaceContractAuthorization:
    GatewayAuthorizationProviding
{
    func bearerToken() async throws -> String? {
        "fixture-session"
    }
}

private actor PlaceContractTransport: GatewayTransport {
    private(set) var count = 0
    let response: GatewayHTTPResponse

    init(response: GatewayHTTPResponse) {
        self.response = response
    }

    func send(_ request: URLRequest) async throws
        -> GatewayHTTPResponse
    {
        count += 1
        precondition(request.url?.path == "/v1/search/places")
        return response
    }
}

@main
enum PlaceDiscoveryContractVerificationMain {
    @MainActor
    static func main() async throws {
        let json = """
        {
          "data": {
            "places": [
              {
                "id": "6aac2b7f-b8f8-598f-a205-450b734ee1d4",
                "providerPlaceIdentifier": "geo-place-1",
                "name": "Lisbon Garden Kitchen",
                "location": {
                  "id": "34227b76-4156-56b1-ad22-7325de8d2880",
                  "name": "Lisbon Garden Kitchen",
                  "city": "Lisbon",
                  "country": "Portugal",
                  "countryCode": "PT",
                  "coordinate": {
                    "latitude": 38.72,
                    "longitude": -9.14
                  },
                  "timeZoneIdentifier": "Europe/Lisbon"
                },
                "categories": ["restaurant"],
                "summary": "1 Garden Street, Lisbon",
                "openingHours": {
                  "rawText": ["Mo-Su 11:00-22:00"],
                  "isOpenAtRetrieval": true
                },
                "imageURLs": [],
                "websiteURL": "https://garden.example",
                "dietaryOptions": ["vegetarian"],
                "accessibilityFeatures": ["wheelchairAccess"],
                "provenance": {
                  "provider": "geoapify",
                  "providerIdentifier": "geo-place-1",
                  "origin": "live",
                  "retrievedAt": "2026-09-06T08:00:00.000Z",
                  "expiresAt": "2026-09-06T14:00:00.000Z",
                  "sourceURL": "https://www.geoapify.com/places-api/"
                }
              },
              {
                "id": "28b49958-c217-5d6e-86d3-1c8cd6f9ff1b",
                "providerPlaceIdentifier": "serp-place-1",
                "name": "Lisbon Art Museum",
                "location": {
                  "id": "5c43a59d-c9a4-55db-a5a2-66cca6ca8701",
                  "name": "Lisbon Art Museum",
                  "city": "Lisbon",
                  "country": "Portugal",
                  "countryCode": "PT",
                  "coordinate": {
                    "latitude": 38.71,
                    "longitude": -9.13
                  },
                  "timeZoneIdentifier": "Europe/Lisbon"
                },
                "categories": ["museum"],
                "summary": "Modern and historic Portuguese art.",
                "rating": 4.8,
                "reviewCount": 820,
                "priceLevel": 2,
                "openingHours": {
                  "rawText": ["monday: 10 AM–6 PM"],
                  "isOpenAtRetrieval": true
                },
                "imageURLs": ["https://images.example/museum.jpg"],
                "websiteURL": "https://museum.example",
                "bookingURL": "https://museum.example/tickets",
                "dietaryOptions": [],
                "accessibilityFeatures": [],
                "provenance": {
                  "provider": "serpapi",
                  "providerIdentifier": "serp-place-1",
                  "origin": "live",
                  "retrievedAt": "2026-09-06T08:00:00.000Z",
                  "expiresAt": "2026-09-06T14:00:00.000Z",
                  "sourceURL": "https://www.google.com/maps"
                }
              }
            ]
          }
        }
        """
        let response = HTTPURLResponse(
            url: URL(string: "https://gateway.example/v1/search/places")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json"
            ]
        )!
        let transport = PlaceContractTransport(
            response: GatewayHTTPResponse(
                data: Data(json.utf8),
                response: response
            )
        )
        let client = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: URL(string: "https://gateway.example")!,
                authorizationProvider: PlaceContractAuthorization()
            ),
            transport: transport,
            cache: GatewayResponseCache(
                directoryURL:
                    FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
            )
        )
        let service = GatewayTravelService(client: client)
        let destination = TravelLocation(
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
        let criteria = PlaceSearchCriteria(
            destination: destination,
            categories: [.restaurant, .museum],
            interests: [.food, .museums],
            dietaryRequirements: [.vegetarian],
            accessibilityRequirements: [.wheelchairAccess],
            radiusMeters: 12_000,
            limit: 12
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
        let coordinator = PlaceSearchCoordinator(service: service)
        let places = try await coordinator.search(
            criteria: criteria,
            session: session
        )

        precondition(places.count == 2)
        precondition(places[0].categories.contains(.restaurant))
        precondition(
            places[0].dietaryOptions.contains(.vegetarian)
        )
        precondition(
            places[0].accessibilityFeatures
                .contains(.wheelchairAccess)
        )
        precondition(places[0].rating == nil)
        precondition(places[0].provenance.provider == .geoapify)
        precondition(places[1].categories.contains(.museum))
        precondition(places[1].rating == 4.8)
        precondition(places[1].priceLevel == 2)
        precondition(places[1].bookingURL != nil)
        precondition(places[1].provenance.provider == .serpApi)
        precondition(
            session.progress.item(for: .experiences).status
                == .complete
        )
        precondition(
            session.progress.item(for: .experiences).resultCount
                == 2
        )
        precondition(
            session.progress.item(for: .experiences).providers
                == [.geoapify, .serpApi]
        )
        let requestCount = await transport.count
        precondition(requestCount == 1)

        print("Place discovery gateway contract passed.")
    }
}
