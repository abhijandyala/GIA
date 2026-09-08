import Foundation

private struct EventContractAuthorization:
    GatewayAuthorizationProviding
{
    func bearerToken() async throws -> String? {
        "fixture-session"
    }
}

private actor EventContractTransport: GatewayTransport {
    private(set) var count = 0
    let response: GatewayHTTPResponse

    init(response: GatewayHTTPResponse) {
        self.response = response
    }

    func send(_ request: URLRequest) async throws
        -> GatewayHTTPResponse
    {
        count += 1
        precondition(request.url?.path == "/v1/search/events")
        return response
    }
}

@main
enum SerpApiEventContractVerificationMain {
    @MainActor
    static func main() async throws {
        let json = """
        {
          "data": {
            "events": [
              {
                "id": "6aac2b7f-b8f8-598f-a205-450b734ee1d4",
                "providerEventIdentifier": "event-source-1",
                "title": "Lisbon River Festival",
                "summary": "Outdoor music festival beside the river.",
                "venueName": "River Stage",
                "location": {
                  "id": "34227b76-4156-56b1-ad22-7325de8d2880",
                  "name": "River Stage",
                  "city": "Lisbon",
                  "country": "Portugal",
                  "countryCode": "PT",
                  "timeZoneIdentifier": "Europe/Lisbon"
                },
                "start": "2027-06-12T18:30:00.000Z",
                "end": "2027-06-12T21:00:00.000Z",
                "rawDateText": "Sat, Jun 12, 7:30 PM–10:00 PM",
                "timeZoneIdentifier": "Europe/Lisbon",
                "timeZoneIsResolved": true,
                "status": "upcoming",
                "schedulingTraits": [
                  "fixedTime",
                  "ticketRequired",
                  "reservationAvailable",
                  "outdoor",
                  "weatherDependent"
                ],
                "venueRating": 4.6,
                "venueRatingScale": 5,
                "venueReviewCount": 320,
                "imageURL": "https://images.example/festival.jpg",
                "sourceURL": "https://events.example/festival",
                "ticketURLs": [
                  "https://tickets.example/festival"
                ],
                "provenance": {
                  "provider": "serpapi",
                  "providerIdentifier": "event-source-1",
                  "origin": "live",
                  "retrievedAt": "2026-09-06T08:00:00.000Z",
                  "expiresAt": "2026-09-06T08:30:00.000Z",
                  "sourceURL": "https://events.example/festival"
                }
              },
              {
                "id": "28b49958-c217-5d6e-86d3-1c8cd6f9ff1b",
                "providerEventIdentifier": "event-source-2",
                "title": "Lisbon Design Exhibition",
                "venueName": "Design Museum",
                "location": {
                  "id": "5c43a59d-c9a4-55db-a5a2-66cca6ca8701",
                  "name": "Design Museum",
                  "city": "Lisbon",
                  "country": "Portugal",
                  "countryCode": "PT",
                  "timeZoneIdentifier": "Europe/Lisbon"
                },
                "rawDateText": "Sun, Jun 13",
                "timeZoneIdentifier": "Europe/Lisbon",
                "timeZoneIsResolved": true,
                "status": "upcoming",
                "schedulingTraits": ["indoor"],
                "ticketURLs": [],
                "provenance": {
                  "provider": "serpapi",
                  "providerIdentifier": "event-source-2",
                  "origin": "live",
                  "retrievedAt": "2026-09-06T08:00:00.000Z",
                  "expiresAt": "2026-09-06T08:30:00.000Z",
                  "sourceURL": "https://events.example/design"
                }
              }
            ]
          }
        }
        """
        let response = HTTPURLResponse(
            url: URL(string: "https://gateway.example/v1/search/events")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json"
            ]
        )!
        let transport = EventContractTransport(
            response: GatewayHTTPResponse(
                data: Data(json.utf8),
                response: response
            )
        )
        let client = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: URL(string: "https://gateway.example")!,
                authorizationProvider: EventContractAuthorization()
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
        let dateRange = TripDateRange(
            start: Date(timeIntervalSince1970: 1_812_758_400),
            end: Date(timeIntervalSince1970: 1_813_363_200),
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let criteria = EventSearchCriteria(
            destination: destination,
            dateRange: dateRange,
            query: nil,
            interests: [.nightlife],
            limit: 20
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
        let coordinator = EventSearchCoordinator(service: service)
        let events = try await coordinator.search(
            criteria: criteria,
            session: session
        )

        precondition(events.count == 2)
        precondition(events[0].hasResolvedSchedule)
        precondition(
            events[0].schedulingTraits.contains(.fixedTime)
        )
        precondition(
            events[0].schedulingTraits.contains(.ticketRequired)
        )
        precondition(
            events[0].schedulingTraits.contains(.weatherDependent)
        )
        precondition(events[0].venueRating == 4.6)
        precondition(events[0].venueRatingScale == 5)
        precondition(events[0].ticketURLs.count == 1)
        precondition(events[0].provenance.provider == .serpApi)
        precondition(!events[1].hasResolvedSchedule)
        precondition(events[1].start == nil)
        precondition(
            session.progress.item(for: .experiences).status
                == .complete
        )
        precondition(
            session.progress.item(for: .experiences).resultCount
                == 2
        )
        let requestCount = await transport.count
        precondition(requestCount == 1)

        print("SerpApi event gateway contract passed.")
    }
}
