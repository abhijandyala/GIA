import Foundation

@main
enum FlightPresentationVerificationMain {
    @MainActor
    static func main() throws {
        let origin = TravelLocation(
            name: "Atlanta Airport",
            iataCode: "ATL",
            timeZoneIdentifier: "America/New_York"
        )
        let destination = TravelLocation(
            name: "Lisbon Airport",
            iataCode: "LIS",
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let departure = Date(timeIntervalSince1970: 1_812_816_000)
        let provenance = DataProvenance(
            provider: .serpApi,
            origin: .live,
            retrievedAt: departure
        )
        let lowest = FlightOffer(
            providerOfferIdentifier: "lowest",
            outboundSegments: [
                segment(
                    origin: origin,
                    destination: destination,
                    departure: departure,
                    duration: 36_000,
                    resolved: true
                )
            ],
            totalDuration: 36_000,
            totalPrice: Money(
                amount: 800,
                currencyCode: "USD"
            ),
            baggage: BaggageAllowance(
                personalItems: nil,
                carryOnBags: 1,
                checkedBags: 0,
                checkedBagFee: nil,
                rawDescription: nil
            ),
            badges: [.lowestPrice],
            priceInsight: PriceInsight(
                level: .low,
                typicalLow: nil,
                typicalHigh: nil,
                observedLowest: nil
            ),
            provenance: provenance
        )
        let selected = FlightOffer(
            providerOfferIdentifier: "selected",
            outboundSegments: [
                segment(
                    origin: origin,
                    destination: destination,
                    departure: departure,
                    duration: 32_400,
                    resolved: false
                )
            ],
            totalDuration: 32_400,
            totalPrice: Money(
                amount: 950,
                currencyCode: "USD"
            ),
            badges: [.fastest],
            priceInsight: PriceInsight(
                level: .typical,
                typicalLow: nil,
                typicalHigh: nil,
                observedLowest: nil
            ),
            provenance: provenance
        )
        let presentations = FlightPresentationBuilder.sortedOffers(
            [lowest, selected],
            selectedIDs: [selected.id]
        )

        precondition(presentations.first?.id == selected.id)
        precondition(presentations[0].originCode == "ATL")
        precondition(presentations[0].destinationCode == "LIS")
        precondition(presentations[0].departureTime == "18:00")
        precondition(presentations[0].duration == "9h")
        precondition(presentations[0].stopDescription == "Nonstop")
        precondition(presentations[0].totalPrice.contains("950"))
        precondition(
            presentations[0].priceInsightDescription == "Typical price"
        )
        precondition(presentations[0].priceInsightSymbol == "equal")
        precondition(!presentations[0].hasResolvedTimeZones)
        precondition(
            presentations[0].returnStatus
                == "Return flight selection pending"
        )
        precondition(presentations[1].baggageDescription == "1 carry-on")
        precondition(
            presentations[1].priceInsightSymbol
                == "arrow.down.right"
        )

        let request = TripRequest(
            origin: origin,
            destinations: [destination],
            dateRange: TripDateRange(
                start: departure,
                end: departure.addingTimeInterval(604_800),
                timeZoneIdentifier: "Europe/Lisbon"
            ),
            travelerCount: 1,
            totalBudget: Money(
                amount: 3_000,
                currencyCode: "USD"
            )
        )
        let organizer = Traveler(
            displayName: "Avery",
            initials: "AV",
            role: .organizer
        )
        let trip = Trip(
            title: "Lisbon",
            lifecycleState: .ready,
            organizerTravelerID: organizer.id,
            request: request,
            travelers: [organizer],
            catalog: TripCatalog(
                flightOffers: [lowest, selected]
            ),
            selections: TripSelections(
                flightOfferIDs: [selected.id]
            )
        )
        let session = TripPlanningSession()
        try session.beginListening(source: .manual)
        try session.beginTranscribing()
        try session.beginValidation(request: request)
        try session.beginSearch()
        try session.beginComparison()
        try session.beginItineraryBuild()
        try session.beginPresentation()
        try session.complete(with: trip)
        try session.selectFlightOffer(lowest.id)

        precondition(
            session.currentTrip?.selections.flightOfferIDs
                == [lowest.id]
        )
        let completed = FlightOffer(
            providerOfferIdentifier: "completed-booking-token",
            outboundSegments: lowest.outboundSegments,
            returnSegments: [
                segment(
                    origin: destination,
                    destination: origin,
                    departure:
                        departure.addingTimeInterval(604_800),
                    duration: 36_000,
                    resolved: true
                )
            ],
            totalDuration: 72_000,
            totalPrice: Money(
                amount: 840,
                currencyCode: "USD"
            ),
            provenance: provenance
        )
        let completedID = try session.replaceOutboundFlightOffer(
            lowest.id,
            with: [completed]
        )
        precondition(completedID == completed.id)
        precondition(
            session.currentTrip?.selections.flightOfferIDs
                == [completed.id]
        )
        precondition(
            session.currentTrip?.catalog.flightOffers.contains {
                $0.id == lowest.id
            } == false
        )
        let completedPresentation = FlightOptionPresentation(
            offer: completed
        )
        precondition(completedPresentation.returnStatus == nil)
        precondition(
            completedPresentation.stopDescription
                == "Nonstop out · Nonstop back"
        )
        do {
            try session.selectFlightOffer(UUID())
            fatalError("Unknown flight selection was accepted.")
        } catch let error as TripSelectionError {
            if case .unknownFlightOffer = error {
                // Expected.
            } else {
                fatalError("Unexpected selection error.")
            }
        }

        print("Flight presentation and selection passed.")
    }

    private static func segment(
        origin: TravelLocation,
        destination: TravelLocation,
        departure: Date,
        duration: TimeInterval,
        resolved: Bool
    ) -> FlightSegment {
        FlightSegment(
            airlineCode: "GA",
            airlineName: "GIA Airways",
            flightNumber: "GA 101",
            origin: origin,
            destination: destination,
            departure: departure,
            arrival: departure.addingTimeInterval(duration),
            departureLocalTimeText: "2027-06-10 18:00",
            arrivalLocalTimeText: "2027-06-11 07:00",
            departureTimeZoneIdentifier: "America/New_York",
            arrivalTimeZoneIdentifier: "Europe/Lisbon",
            departureTimeZoneIsResolved: resolved,
            arrivalTimeZoneIsResolved: resolved,
            duration: duration,
            travelClass: .economy
        )
    }
}
