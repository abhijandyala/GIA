import Foundation

private struct FlightContractAuthorization:
    GatewayAuthorizationProviding
{
    func bearerToken() async throws -> String? {
        "fixture-session"
    }
}

private actor FlightContractTransport: GatewayTransport {
    private(set) var count = 0
    let response: GatewayHTTPResponse

    init(response: GatewayHTTPResponse) {
        self.response = response
    }

    func send(_ request: URLRequest) async throws
        -> GatewayHTTPResponse
    {
        count += 1
        precondition(request.url?.path == "/v1/search/flights")
        return response
    }
}

@main
enum SerpApiFlightContractVerificationMain {
    @MainActor
    static func main() async throws {
        let json = """
        {
          "data": {
            "offers": [
              {
                "id": "4d793b1b-a099-5d6f-8f0b-91ad4b59292e",
                "providerOfferIdentifier": "fixture-token",
                "continuationToken": "fixture-departure-token",
                "outboundSegments": [
                  {
                    "id": "28b49958-c217-5d6e-86d3-1c8cd6f9ff1b",
                    "airlineCode": "GA",
                    "airlineName": "GIA Airways",
                    "flightNumber": "GA 101",
                    "origin": {
                      "id": "5c43a59d-c9a4-55db-a5a2-66cca6ca8701",
                      "name": "Los Angeles International Airport",
                      "iataCode": "LAX",
                      "timeZoneIdentifier": "America/Los_Angeles"
                    },
                    "destination": {
                      "id": "f283c14e-0703-578f-91fa-63ce446f1cf7",
                      "name": "Narita International Airport",
                      "iataCode": "NRT",
                      "timeZoneIdentifier": "Asia/Tokyo"
                    },
                    "departure": "2027-06-10T17:00:00.000Z",
                    "arrival": "2027-06-11T05:00:00.000Z",
                    "departureLocalTimeText": "2027-06-10 10:00",
                    "arrivalLocalTimeText": "2027-06-11 14:00",
                    "departureTimeZoneIdentifier": "America/Los_Angeles",
                    "arrivalTimeZoneIdentifier": "Asia/Tokyo",
                    "departureTimeZoneIsResolved": true,
                    "arrivalTimeZoneIsResolved": true,
                    "duration": 39600,
                    "travelClass": "economy"
                  }
                ],
                "returnSegments": [],
                "totalDuration": 39600,
                "totalPrice": {
                  "amount": 900,
                  "currencyCode": "USD"
                },
                "baggage": {
                  "carryOnBags": 1,
                  "rawDescription": "1 free carry-on bag"
                },
                "badges": [
                  "lowestPrice",
                  "fastest",
                  "fewestStops"
                ],
                "carbonEmissionsGrams": 650000,
                "priceInsight": {
                  "level": "low",
                  "typicalLow": {
                    "amount": 1050,
                    "currencyCode": "USD"
                  },
                  "typicalHigh": {
                    "amount": 1400,
                    "currencyCode": "USD"
                  },
                  "observedLowest": {
                    "amount": 900,
                    "currencyCode": "USD"
                  }
                },
                "bookingURL": "https://www.google.com/travel/flights/search",
                "provenance": {
                  "provider": "serpapi",
                  "providerIdentifier": "fixture-token",
                  "origin": "live",
                  "retrievedAt": "2026-09-06T08:00:00.000Z",
                  "expiresAt": "2026-09-06T08:03:00.000Z",
                  "sourceURL": "https://www.google.com/travel/flights/search"
                }
              }
            ]
          }
        }
        """
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://gateway.example/v1/search/flights")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json"
            ]
        )!
        let transport = FlightContractTransport(
            response: GatewayHTTPResponse(
                data: Data(json.utf8),
                response: httpResponse
            )
        )
        let client = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: URL(string: "https://gateway.example")!,
                authorizationProvider: FlightContractAuthorization()
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
            name: "Los Angeles International Airport",
            iataCode: "LAX",
            timeZoneIdentifier: "America/Los_Angeles"
        )
        let destination = TravelLocation(
            name: "Narita International Airport",
            iataCode: "NRT",
            timeZoneIdentifier: "Asia/Tokyo"
        )
        let departureDate =
            Date(timeIntervalSince1970: 1_812_758_400)
        let returnDate =
            Date(timeIntervalSince1970: 1_813_363_200)
        let criteria = FlightSearchCriteria(
            origin: origin,
            destination: destination,
            departureDate: departureDate,
            returnDate: returnDate,
            adults: 4,
            children: 0,
            currencyCode: "USD",
            preferences: FlightPreferences()
        )
        let planningRequest = TripRequest(
            origin: origin,
            destinations: [destination],
            dateRange: TripDateRange(
                start: departureDate,
                end: returnDate,
                timeZoneIdentifier: "Asia/Tokyo"
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
        try session.beginValidation(request: planningRequest)
        try session.beginSearch()
        let coordinator = FlightSearchCoordinator(service: service)
        let offers = try await coordinator.search(
            criteria: criteria,
            session: session
        )

        precondition(offers.count == 1)
        let offer = offers[0]
        precondition(offer.totalPrice.amount == Decimal(900))
        precondition(offer.badges.contains(.lowestPrice))
        precondition(
            offer.continuationToken == "fixture-departure-token"
        )
        precondition(offer.outboundSegments.count == 1)
        precondition(
            offer.outboundSegments[0].departureLocalTimeText
                == "2027-06-10 10:00"
        )
        precondition(
            offer.outboundSegments[0].departureTimeZoneIsResolved
        )
        precondition(
            offer.provenance.provider == .serpApi
        )
        precondition(
            offer.provenance.origin == .live
        )
        precondition(
            session.progress.item(for: .flights).status == .complete
        )
        precondition(
            session.progress.item(for: .flights).resultCount == 1
        )
        let requestCount = await transport.count
        precondition(requestCount == 1)

        print("SerpApi flight gateway contract passed.")
    }
}
