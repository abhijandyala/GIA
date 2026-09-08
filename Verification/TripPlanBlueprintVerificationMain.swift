import Foundation

@main
enum TripPlanBlueprintVerificationMain {
    static func main() {
        let tripStart = Date(timeIntervalSince1970: 1_812_758_400)
        let tripEnd = Date(timeIntervalSince1970: 1_813_363_200)
        let destination = TravelLocation(
            name: "Lisbon",
            city: "Lisbon",
            country: "Portugal",
            countryCode: "PT",
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let request = TripRequest(
            destinations: [destination],
            dateRange: TripDateRange(
                start: tripStart,
                end: tripEnd,
                timeZoneIdentifier: "Europe/Lisbon"
            ),
            travelerCount: 4,
            totalBudget: Money(
                amount: 6_000,
                currencyCode: "USD"
            )
        )
        let provenance = DataProvenance(
            provider: .serpApi,
            origin: .live,
            retrievedAt: tripStart
        )
        let flight = FlightOffer(
            providerOfferIdentifier: "flight-source",
            outboundSegments: [],
            totalDuration: 30_000,
            totalPrice: Money(
                amount: 900,
                currencyCode: "USD"
            ),
            provenance: provenance
        )
        let hotel = HotelOffer(
            providerOfferIdentifier: "hotel-source",
            name: "Lisbon Hotel",
            location: destination,
            lodgingType: .hotel,
            totalPrice: Money(
                amount: 1_200,
                currencyCode: "USD"
            ),
            provenance: provenance
        )
        let place = PlaceRecommendation(
            providerPlaceIdentifier: "place-source",
            name: "Art Museum",
            location: destination,
            categories: [.museum],
            provenance: provenance
        )
        let route = TransportationLeg(
            origin: hotel.location,
            destination: place.location,
            mode: .walking,
            duration: 900,
            confidence: .live,
            provenance: DataProvenance(
                provider: .geoapify,
                origin: .live,
                retrievedAt: tripStart
            )
        )
        let criteria = TripGenerationCriteria(
            request: request,
            flightOffers: [flight],
            hotelOffers: [hotel],
            places: [place],
            routes: [route],
            weather: []
        )
        let itemStart = tripStart.addingTimeInterval(36_000)
        let itemEnd = itemStart.addingTimeInterval(7_200)
        let blueprint = TripPlanBlueprint(
            title: "Lisbon Together",
            summary: "A balanced sourced itinerary.",
            selectedFlightOfferIDs: [flight.id],
            selectedHotelOfferIDs: [hotel.id],
            days: [
                PlannedItineraryDay(
                    date: "2027-06-10",
                    timeZoneIdentifier: "Europe/Lisbon",
                    items: [
                        PlannedItineraryItem(
                            sourceKind: .place,
                            sourceIdentifier: place.id,
                            start: itemStart,
                            end: itemEnd,
                            rationale:
                                "Matches the group's museum interest."
                        )
                    ]
                )
            ],
            recommendationRationales: [
                PlanRecommendationRationale(
                    sourceKind: .flight,
                    sourceIdentifier: flight.id,
                    reasons: ["Balances cost and travel time."]
                )
            ],
            warnings: [
                "Availability must be rechecked before checkout."
            ]
        )

        precondition(
            TripPlanBlueprintValidator.isValid(
                blueprint,
                criteria: criteria
            )
        )
        let assembled = TransientTripAssembler.finalizedTrip(
            request: request,
            results: TransientPlanningResults(
                flightOffers: [flight],
                hotelOffers: [hotel],
                places: [place],
                events: [],
                weather: [],
                routes: [route]
            ),
            blueprint: blueprint
        )
        precondition(assembled?.title == "Lisbon Together")
        precondition(
            assembled?.selections.flightOfferIDs == [flight.id]
        )
        precondition(
            assembled?.selections.hotelOfferIDs == [hotel.id]
        )
        precondition(
            assembled?.itinerary.days.first?.items.first?.reference
                == .place(place.id)
        )
        precondition(
            assembled?.itinerary.days.first?.items.first?.notes
                == "Matches the group's museum interest."
        )

        var inventedSource = blueprint
        inventedSource.days[0].items[0].sourceIdentifier = UUID()
        precondition(
            TripPlanBlueprintValidator.issues(
                in: inventedSource,
                criteria: criteria
            ).contains { $0.code == .unknownSource }
        )
        precondition(
            TransientTripAssembler.finalizedTrip(
                request: request,
                results: TransientPlanningResults(
                    flightOffers: [flight],
                    hotelOffers: [hotel],
                    places: [place],
                    events: [],
                    weather: [],
                    routes: [route]
                ),
                blueprint: inventedSource
            ) == nil
        )

        var overlapping = blueprint
        overlapping.days[0].items.append(
            PlannedItineraryItem(
                sourceKind: .freeTime,
                sourceIdentifier: nil,
                start: itemStart.addingTimeInterval(1_800),
                end: itemEnd.addingTimeInterval(1_800),
                rationale: "Unstructured group time."
            )
        )
        precondition(
            TripPlanBlueprintValidator.issues(
                in: overlapping,
                criteria: criteria
            ).contains { $0.code == .overlappingItems }
        )

        var falseFreeTime = blueprint
        falseFreeTime.days[0].items[0] = PlannedItineraryItem(
            sourceKind: .freeTime,
            sourceIdentifier: place.id,
            start: itemStart,
            end: itemEnd,
            rationale: "Free time."
        )
        precondition(
            TripPlanBlueprintValidator.issues(
                in: falseFreeTime,
                criteria: criteria
            ).contains { $0.code == .unexpectedSource }
        )

        var inventedFlight = blueprint
        inventedFlight.selectedFlightOfferIDs = [UUID()]
        precondition(
            TripPlanBlueprintValidator.issues(
                in: inventedFlight,
                criteria: criteria
            ).contains { $0.code == .unknownFlightSelection }
        )

        var invalidDay = blueprint
        invalidDay.days[0].date = "2027-99-99"
        precondition(
            TripPlanBlueprintValidator.issues(
                in: invalidDay,
                criteria: criteria
            ).contains { $0.code == .invalidDay }
        )

        var inventedRecommendation = blueprint
        inventedRecommendation
            .recommendationRationales[0]
            .sourceIdentifier = UUID()
        precondition(
            TripPlanBlueprintValidator.issues(
                in: inventedRecommendation,
                criteria: criteria
            ).contains { $0.code == .unknownSource }
        )

        let encoded = try! JSONEncoder().encode(blueprint)
        let decoded = try! JSONDecoder().decode(
            TripPlanBlueprint.self,
            from: encoded
        )
        precondition(decoded == blueprint)

        print("Trip plan blueprint grounding passed.")
    }
}
