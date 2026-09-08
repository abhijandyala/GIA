import Foundation

private struct HotelContractAuthorization:
    GatewayAuthorizationProviding
{
    func bearerToken() async throws -> String? {
        "fixture-session"
    }
}

private actor HotelContractTransport: GatewayTransport {
    private(set) var count = 0
    let response: GatewayHTTPResponse

    init(response: GatewayHTTPResponse) {
        self.response = response
    }

    func send(_ request: URLRequest) async throws
        -> GatewayHTTPResponse
    {
        count += 1
        precondition(request.url?.path == "/v1/search/hotels")
        return response
    }
}

@main
enum SerpApiHotelContractVerificationMain {
    @MainActor
    static func main() async throws {
        let json = """
        {
          "data": {
            "offers": [
              {
                "id": "6aac2b7f-b8f8-598f-a205-450b734ee1d4",
                "providerOfferIdentifier": "hotel-token",
                "name": "Lisbon Riverside Hotel",
                "location": {
                  "id": "34227b76-4156-56b1-ad22-7325de8d2880",
                  "name": "Lisbon Riverside Hotel",
                  "city": "Lisbon",
                  "country": "Portugal",
                  "countryCode": "PT",
                  "coordinate": {
                    "latitude": 38.7223,
                    "longitude": -9.1393
                  },
                  "timeZoneIdentifier": "Europe/Lisbon"
                },
                "lodgingType": "hotel",
                "starRating": 4,
                "guestRating": 4.7,
                "guestRatingScale": 5,
                "reviewCount": 421,
                "nightlyPrice": {
                  "amount": 200,
                  "currencyCode": "USD"
                },
                "totalPrice": {
                  "amount": 1400,
                  "currencyCode": "USD"
                },
                "taxesAndFeesIncluded": true,
                "roomDescription": "Modern rooms near central Lisbon.",
                "amenities": [
                  "wifi",
                  "breakfast",
                  "accessibleRoom"
                ],
                "imageURLs": [
                  "https://images.example/hotel.jpg"
                ],
                "checkInTime": "3:00 PM",
                "checkOutTime": "11:00 AM",
                "cancellationPolicy": {
                  "summary": "Free cancellation available"
                },
                "badges": [
                  "flexible",
                  "lowestPrice"
                ],
                "bookingURL": "https://hotel.example/book",
                "provenance": {
                  "provider": "serpapi",
                  "providerIdentifier": "hotel-token",
                  "origin": "live",
                  "retrievedAt": "2026-09-06T08:00:00.000Z",
                  "expiresAt": "2026-09-06T08:05:00.000Z",
                  "sourceURL": "https://www.google.com/travel/search?q=Lisbon"
                }
              }
            ]
          }
        }
        """
        let response = HTTPURLResponse(
            url: URL(string: "https://gateway.example/v1/search/hotels")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json"
            ]
        )!
        let transport = HotelContractTransport(
            response: GatewayHTTPResponse(
                data: Data(json.utf8),
                response: response
            )
        )
        let client = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: URL(string: "https://gateway.example")!,
                authorizationProvider: HotelContractAuthorization()
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
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let checkIn = Date(timeIntervalSince1970: 1_812_758_400)
        let checkOut = Date(timeIntervalSince1970: 1_813_363_200)
        let criteria = HotelSearchCriteria(
            destination: destination,
            checkInDate: checkIn,
            checkOutDate: checkOut,
            adults: 4,
            rooms: 2,
            currencyCode: "USD",
            preferences: HotelPreferences()
        )
        let request = TripRequest(
            destinations: [destination],
            dateRange: TripDateRange(
                start: checkIn,
                end: checkOut,
                timeZoneIdentifier: "Europe/Lisbon"
            ),
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
        let coordinator = HotelSearchCoordinator(service: service)
        let offers = try await coordinator.search(
            criteria: criteria,
            session: session
        )

        precondition(offers.count == 1)
        let offer = offers[0]
        precondition(offer.name == "Lisbon Riverside Hotel")
        precondition(offer.totalPrice.amount == Decimal(1_400))
        precondition(offer.guestRating == 4.7)
        precondition(offer.guestRatingScale == 5)
        precondition(offer.amenities.contains(.accessibleRoom))
        precondition(offer.badges.contains(.flexible))
        precondition(offer.badges.contains(.lowestPrice))
        precondition(
            offer.location.coordinate
                == GeoCoordinate(
                    latitude: 38.7223,
                    longitude: -9.1393
                )
        )
        precondition(offer.provenance.provider == .serpApi)
        precondition(
            session.progress.item(for: .stay).status == .complete
        )
        precondition(
            session.progress.item(for: .stay).resultCount == 1
        )
        let requestCount = await transport.count
        precondition(requestCount == 1)

        print("SerpApi hotel gateway contract passed.")
    }
}
