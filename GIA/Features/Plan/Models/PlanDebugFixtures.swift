#if DEBUG
import Foundation

enum PlanDebugFixtures {
    static func flightComparisonTrip(
        preserving originalRequest: TripRequest
    ) -> Trip {
        let origin = TravelLocation(
            name: "Hartsfield–Jackson Atlanta International Airport",
            city: "Atlanta",
            country: "United States",
            countryCode: "US",
            iataCode: "ATL",
            coordinate: GeoCoordinate(
                latitude: 33.6407,
                longitude: -84.4277
            ),
            timeZoneIdentifier: "America/New_York"
        )
        let destination = TravelLocation(
            name: "Humberto Delgado Airport",
            city: "Lisbon",
            country: "Portugal",
            countryCode: "PT",
            iataCode: "LIS",
            coordinate: GeoCoordinate(
                latitude: 38.7742,
                longitude: -9.1342
            ),
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let departure = Date(timeIntervalSince1970: 1_812_816_000)
        let returnDeparture =
            Date(timeIntervalSince1970: 1_813_420_800)
        var request = originalRequest
        request.origin = origin
        request.destinations = [destination]
        request.dateRange = TripDateRange(
            start: departure,
            end: returnDeparture,
            timeZoneIdentifier: "Europe/Lisbon"
        )
        request.durationDays = 8
        request.travelerCount = 4
        request.totalBudget = Money(
            amount: 6_000,
            currencyCode: "USD"
        )

        let provenance = DataProvenance(
            provider: .serpApi,
            providerIdentifier: "debug-flight-search",
            origin: .demo,
            retrievedAt: Date(),
            expiresAt: Date().addingTimeInterval(180),
            sourceURL: URL(
                string: "https://www.google.com/travel/flights"
            )
        )
        let recommended = FlightOffer(
            providerOfferIdentifier: "debug-recommended",
            outboundSegments: [
                segment(
                    airlineCode: "TP",
                    airlineName: "TAP Air Portugal",
                    flightNumber: "TP 109",
                    origin: origin,
                    destination: destination,
                    departure: departure,
                    arrival: departure.addingTimeInterval(30_000),
                    localDeparture: "2027-06-10 18:00",
                    localArrival: "2027-06-11 07:20"
                )
            ],
            returnSegments: [
                segment(
                    airlineCode: "TP",
                    airlineName: "TAP Air Portugal",
                    flightNumber: "TP 110",
                    origin: destination,
                    destination: origin,
                    departure: returnDeparture,
                    arrival:
                        returnDeparture.addingTimeInterval(31_200),
                    localDeparture: "2027-06-17 11:00",
                    localArrival: "2027-06-17 15:40"
                )
            ],
            totalDuration: 30_000,
            totalPrice: Money(
                amount: 980,
                currencyCode: "USD"
            ),
            baggage: BaggageAllowance(
                personalItems: 1,
                carryOnBags: 1,
                checkedBags: 1,
                checkedBagFee: nil,
                rawDescription:
                    "1 carry-on · 1 checked bag included"
            ),
            badges: [.giaRecommended, .fewestStops],
            carbonEmissionsGrams: 612_000,
            priceInsight: PriceInsight(
                level: .typical,
                typicalLow: Money(
                    amount: 850,
                    currencyCode: "USD"
                ),
                typicalHigh: Money(
                    amount: 1_180,
                    currencyCode: "USD"
                ),
                observedLowest: Money(
                    amount: 820,
                    currencyCode: "USD"
                )
            ),
            refundable: false,
            bookingURL: URL(
                string: "https://www.google.com/travel/flights"
            ),
            provenance: provenance
        )
        let lowest = FlightOffer(
            providerOfferIdentifier: "debug-lowest",
            outboundSegments: [
                segment(
                    airlineCode: "B6",
                    airlineName: "JetBlue",
                    flightNumber: "B6 420",
                    origin: origin,
                    destination: TravelLocation(
                        name: "John F. Kennedy International Airport",
                        city: "New York",
                        country: "United States",
                        countryCode: "US",
                        iataCode: "JFK",
                        timeZoneIdentifier: "America/New_York"
                    ),
                    departure: departure.addingTimeInterval(-3_600),
                    arrival: departure.addingTimeInterval(3_600),
                    localDeparture: "2027-06-10 17:00",
                    localArrival: "2027-06-10 19:00"
                ),
                segment(
                    airlineCode: "B6",
                    airlineName: "JetBlue",
                    flightNumber: "B6 17",
                    origin: TravelLocation(
                        name: "John F. Kennedy International Airport",
                        city: "New York",
                        country: "United States",
                        countryCode: "US",
                        iataCode: "JFK",
                        timeZoneIdentifier: "America/New_York"
                    ),
                    destination: destination,
                    departure: departure.addingTimeInterval(9_000),
                    arrival: departure.addingTimeInterval(39_600),
                    localDeparture: "2027-06-10 20:30",
                    localArrival: "2027-06-11 10:00"
                )
            ],
            totalDuration: 42_000,
            totalPrice: Money(
                amount: 820,
                currencyCode: "USD"
            ),
            baggage: BaggageAllowance(
                personalItems: 1,
                carryOnBags: 1,
                checkedBags: 0,
                checkedBagFee: Money(
                    amount: 70,
                    currencyCode: "USD"
                ),
                rawDescription:
                    "1 carry-on · checked bag available for a fee"
            ),
            badges: [.lowestPrice],
            carbonEmissionsGrams: 710_000,
            priceInsight: PriceInsight(
                level: .low,
                typicalLow: Money(
                    amount: 850,
                    currencyCode: "USD"
                ),
                typicalHigh: Money(
                    amount: 1_180,
                    currencyCode: "USD"
                ),
                observedLowest: Money(
                    amount: 820,
                    currencyCode: "USD"
                )
            ),
            bookingURL: URL(
                string: "https://www.google.com/travel/flights"
            ),
            provenance: provenance
        )
        let fastest = FlightOffer(
            providerOfferIdentifier: "debug-fastest",
            outboundSegments: [
                segment(
                    airlineCode: "DL",
                    airlineName: "Delta",
                    flightNumber: "DL 192",
                    origin: origin,
                    destination: destination,
                    departure: departure.addingTimeInterval(7_200),
                    arrival: departure.addingTimeInterval(35_400),
                    localDeparture: "2027-06-10 20:00",
                    localArrival: "2027-06-11 08:50"
                )
            ],
            totalDuration: 28_200,
            totalPrice: Money(
                amount: 1_120,
                currencyCode: "USD"
            ),
            baggage: BaggageAllowance(
                personalItems: 1,
                carryOnBags: 1,
                checkedBags: 1,
                checkedBagFee: nil,
                rawDescription:
                    "1 carry-on · 1 checked bag included"
            ),
            badges: [.fastest, .lowerEmissions],
            carbonEmissionsGrams: 570_000,
            priceInsight: PriceInsight(
                level: .typical,
                typicalLow: Money(
                    amount: 850,
                    currencyCode: "USD"
                ),
                typicalHigh: Money(
                    amount: 1_180,
                    currencyCode: "USD"
                ),
                observedLowest: Money(
                    amount: 820,
                    currencyCode: "USD"
                )
            ),
            bookingURL: URL(
                string: "https://www.google.com/travel/flights"
            ),
            provenance: provenance
        )
        let organizer = Traveler(
            displayName: "Avery",
            initials: "AV",
            role: .organizer
        )

        return Trip(
            title: "Lisbon Together",
            lifecycleState: .ready,
            organizerTravelerID: organizer.id,
            request: request,
            travelers: [organizer],
            catalog: TripCatalog(
                flightOffers: [recommended, lowest, fastest]
            ),
            selections: TripSelections(
                flightOfferIDs: [recommended.id]
            ),
            budget: TripBudget(totalLimit: request.totalBudget)
        )
    }

    private static func segment(
        airlineCode: String,
        airlineName: String,
        flightNumber: String,
        origin: TravelLocation,
        destination: TravelLocation,
        departure: Date,
        arrival: Date,
        localDeparture: String,
        localArrival: String
    ) -> FlightSegment {
        FlightSegment(
            airlineCode: airlineCode,
            airlineName: airlineName,
            flightNumber: flightNumber,
            origin: origin,
            destination: destination,
            departure: departure,
            arrival: arrival,
            departureLocalTimeText: localDeparture,
            arrivalLocalTimeText: localArrival,
            departureTimeZoneIdentifier:
                origin.timeZoneIdentifier ?? "UTC",
            arrivalTimeZoneIdentifier:
                destination.timeZoneIdentifier ?? "UTC",
            departureTimeZoneIsResolved:
                origin.timeZoneIdentifier != nil,
            arrivalTimeZoneIsResolved:
                destination.timeZoneIdentifier != nil,
            duration: arrival.timeIntervalSince(departure),
            aircraftName: nil,
            travelClass: .economy
        )
    }
}
#endif
