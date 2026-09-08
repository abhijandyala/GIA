import Foundation

let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
let provenance = DataProvenance(
    provider: .serpApi,
    providerIdentifier: "fixture-provider-id",
    origin: .demo,
    retrievedAt: baseDate,
    expiresAt: baseDate.addingTimeInterval(3_600),
    sourceURL: URL(string: "https://example.com/source")
)
let origin = TravelLocation(
    name: "Los Angeles International Airport",
    city: "Los Angeles",
    country: "United States",
    countryCode: "US",
    iataCode: "LAX",
    coordinate: GeoCoordinate(
        latitude: 33.9416,
        longitude: -118.4085
    ),
    timeZoneIdentifier: "America/Los_Angeles"
)
let destination = TravelLocation(
    name: "Tokyo",
    city: "Tokyo",
    country: "Japan",
    countryCode: "JP",
    coordinate: GeoCoordinate(
        latitude: 35.6762,
        longitude: 139.6503
    ),
    timeZoneIdentifier: "Asia/Tokyo"
)
let organizer = Traveler(
    displayName: "Avery",
    initials: "AV",
    role: .organizer,
    preferences: TravelerPreferences(
        interests: [.food, .technology],
        dietaryRequirements: [.vegetarian]
    )
)
let request = TripRequest(
    rawTranscript: "Plan a group trip to Tokyo.",
    origin: origin,
    destinations: [destination],
    dateRange: TripDateRange(
        start: baseDate,
        end: baseDate.addingTimeInterval(604_800),
        timeZoneIdentifier: "Asia/Tokyo"
    ),
    travelerCount: 1,
    totalBudget: Money(amount: 4_000, currencyCode: "usd"),
    interests: [.food, .technology]
)
let outboundSegment = FlightSegment(
    airlineCode: "GA",
    airlineName: "GIA Airways",
    flightNumber: "GA 101",
    origin: origin,
    destination: destination,
    departure: baseDate,
    arrival: baseDate.addingTimeInterval(39_600),
    departureTimeZoneIdentifier: "America/Los_Angeles",
    arrivalTimeZoneIdentifier: "Asia/Tokyo",
    duration: 39_600,
    travelClass: .economy
)
let flight = FlightOffer(
    providerOfferIdentifier: "flight-fixture",
    outboundSegments: [outboundSegment],
    totalDuration: 39_600,
    totalPrice: Money(amount: 940, currencyCode: "USD"),
    badges: [.giaRecommended, .lowestPrice],
    bookingURL: URL(string: "https://example.com/flight"),
    provenance: provenance
)
let hotel = HotelOffer(
    providerOfferIdentifier: "hotel-fixture",
    name: "GIA Tokyo",
    location: destination,
    lodgingType: .hotel,
    starRating: 4,
    guestRating: 9.1,
    nightlyPrice: Money(amount: 180, currencyCode: "USD"),
    totalPrice: Money(amount: 1_260, currencyCode: "USD"),
    taxesAndFeesIncluded: true,
    amenities: [.breakfast, .wifi],
    provenance: provenance
)
let place = PlaceRecommendation(
    providerPlaceIdentifier: "place-fixture",
    name: "Digital Art Museum",
    location: destination,
    categories: [.activity, .museum],
    rating: 4.8,
    estimatedCostPerTraveler: Money(
        amount: 32,
        currencyCode: "USD"
    ),
    estimatedDuration: 7_200,
    indoor: true,
    provenance: provenance
)
let weather = WeatherSnapshot(
    location: destination,
    timeZoneIdentifier: "Asia/Tokyo",
    periods: [
        WeatherPeriod(
            start: baseDate,
            end: baseDate.addingTimeInterval(3_600),
            condition: .clear,
            providerDescription: "Clear",
            temperatureCelsius: 23
        )
    ],
    provenance: provenance
)
let itineraryItem = ItineraryItem(
    title: place.name,
    kind: .activity,
    start: baseDate.addingTimeInterval(86_400),
    end: baseDate.addingTimeInterval(93_600),
    timeZoneIdentifier: "Asia/Tokyo",
    location: destination,
    reference: .place(place.id),
    estimatedCost: place.estimatedCostPerTraveler
)
let route = TransportationLeg(
    origin: hotel.location,
    destination: place.location,
    mode: .transit,
    duration: 1_200,
    confidence: .estimated,
    provenance: DataProvenance(
        provider: .geoapify,
        origin: .demo,
        retrievedAt: baseDate
    )
)
let decision = GroupDecision(
    title: "Approve the recommended hotel",
    subject: .hotelOffer(hotel.id),
    rule: .majority,
    state: .approved,
    votes: [
        TripVote(
            travelerID: organizer.id,
            choice: .approve,
            submittedAt: baseDate
        )
    ],
    proposedByTravelerID: organizer.id,
    proposedAt: baseDate,
    resolvedAt: baseDate
)
let booking = BookingRecord(
    category: .hotel,
    mode: .demo,
    status: .demoConfirmed,
    itemIdentifier: hotel.id,
    providerName: "GIA Demo",
    amount: hotel.totalPrice,
    provenance: provenance
)
let trip = Trip(
    title: "Tokyo",
    lifecycleState: .ready,
    organizerTravelerID: organizer.id,
    request: request,
    travelers: [organizer],
    catalog: TripCatalog(
        flightOffers: [flight],
        hotelOffers: [hotel],
        places: [place],
        weatherSnapshots: [weather]
    ),
    selections: TripSelections(
        flightOfferIDs: [flight.id],
        hotelOfferIDs: [hotel.id],
        placeIDs: [place.id]
    ),
    itinerary: TripItinerary(
        days: [
            ItineraryDay(
                date: baseDate,
                timeZoneIdentifier: "Asia/Tokyo",
                items: [itineraryItem],
                weatherSnapshotID: weather.id
            )
        ],
        transportationLegs: [route]
    ),
    budget: TripBudget(totalLimit: request.totalBudget),
    decisions: [decision],
    bookings: [booking],
    createdAt: baseDate,
    updatedAt: baseDate
)

@main
enum TripDomainRoundTripMain {
    static func main() throws {
        guard trip.isStructurallyValid else {
            fatalError("Fixture failed structural validation.")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(trip)
        let decoded = try JSONDecoder().decode(
            Trip.self,
            from: encoded
        )

        guard decoded == trip else {
            fatalError("Trip changed during Codable round trip.")
        }

        var misleadingTrip = trip
        misleadingTrip.bookings[0].status = .confirmed
        guard misleadingTrip.structuralIssues.contains(
            where: { $0.code == .misleadingDemoBooking }
        ) else {
            fatalError(
                "Demo booking invariant was not enforced."
            )
        }

        print("Trip domain round trip and invariants passed.")
    }
}
