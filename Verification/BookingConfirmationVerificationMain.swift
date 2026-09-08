import Foundation

@main
enum BookingConfirmationVerificationMain {
    @MainActor
    static func main() throws {
        let origin = TravelLocation(
            name: "Atlanta Airport",
            city: "Atlanta",
            country: "United States",
            countryCode: "US",
            iataCode: "ATL",
            timeZoneIdentifier: "America/New_York"
        )
        let destination = TravelLocation(
            name: "Lisbon",
            city: "Lisbon",
            country: "Portugal",
            countryCode: "PT",
            iataCode: "LIS",
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let departure = Date(timeIntervalSince1970: 1_812_816_000)
        let checkOut = departure.addingTimeInterval(604_800)
        let liveProvenance = DataProvenance(
            provider: .serpApi,
            providerIdentifier: "live-search",
            origin: .live,
            retrievedAt: departure,
            sourceURL: URL(
                string: "https://www.google.com/travel"
            )
        )
        let demoProvenance = DataProvenance(
            provider: .serpApi,
            providerIdentifier: "demo-search",
            origin: .demo,
            retrievedAt: departure,
            sourceURL: URL(
                string: "https://www.google.com/travel"
            )
        )
        let flight = FlightOffer(
            providerOfferIdentifier: "flight",
            outboundSegments: [
                FlightSegment(
                    airlineCode: "TP",
                    airlineName: "TAP Air Portugal",
                    flightNumber: "TP 109",
                    origin: origin,
                    destination: destination,
                    departure: departure,
                    arrival: departure.addingTimeInterval(28_800),
                    departureTimeZoneIdentifier:
                        "America/New_York",
                    arrivalTimeZoneIdentifier: "Europe/Lisbon",
                    duration: 28_800,
                    travelClass: .economy
                )
            ],
            totalDuration: 28_800,
            totalPrice: Money(
                amount: 980,
                currencyCode: "USD"
            ),
            refundable: false,
            bookingURL: URL(
                string: "https://www.google.com/travel/flights"
            ),
            provenance: demoProvenance
        )
        let hotel = HotelOffer(
            providerOfferIdentifier: "hotel",
            name: "Memmo Príncipe Real",
            location: destination,
            lodgingType: .hotel,
            totalPrice: Money(
                amount: 1_666,
                currencyCode: "USD"
            ),
            taxesAndFeesIncluded: true,
            checkInTime: "3:00 PM",
            checkOutTime: "11:00 AM",
            cancellationPolicy: CancellationPolicy(
                summary: "Free cancellation available"
            ),
            bookingURL: URL(
                string: "https://www.google.com/travel/hotels"
            ),
            provenance: liveProvenance
        )
        let hotelWithoutCheckout = HotelOffer(
            providerOfferIdentifier: "hotel-no-link",
            name: "No Link Hotel",
            location: destination,
            lodgingType: .hotel,
            totalPrice: Money(
                amount: 900,
                currencyCode: "USD"
            ),
            provenance: liveProvenance
        )
        let request = TripRequest(
            origin: origin,
            destinations: [destination],
            dateRange: TripDateRange(
                start: departure,
                end: checkOut,
                timeZoneIdentifier: "Europe/Lisbon"
            ),
            travelerCount: 2,
            totalBudget: Money(
                amount: 5_000,
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
                flightOffers: [flight],
                hotelOffers: [hotel, hotelWithoutCheckout]
            ),
            budget: TripBudget(totalLimit: request.totalBudget),
            createdAt: departure,
            updatedAt: departure
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

        let flightRecord = try session.confirmFlightOffer(
            flight.id,
            mode: .fblaDemo
        )
        precondition(flightRecord.mode == .demo)
        precondition(flightRecord.status == .demoConfirmed)
        precondition(flightRecord.providerConfirmationCode == nil)
        precondition(flightRecord.provenance.origin == .demo)
        precondition(flightRecord.provenance.provider == .gia)
        precondition(
            session.currentTrip?.selections.flightOfferIDs
                == [flight.id]
        )
        precondition(
            session.currentTrip?.itinerary.days
                .flatMap(\.items)
                .contains {
                    if case .flightOffer(let id) = $0.reference {
                        return
                            id == flight.id
                            && $0.status == .selected
                            && $0.notes?.contains("No real ticket")
                                == true
                    }
                    return false
                } == true
        )
        precondition(
            session.currentTrip?.structuralIssues.isEmpty == true
        )
        let bookingCount = session.currentTrip?.bookings.count
        _ = try session.confirmFlightOffer(
            flight.id,
            mode: .fblaDemo
        )
        precondition(
            session.currentTrip?.bookings.count == bookingCount
        )

        let hotelRecord = try session.confirmHotelOffer(
            hotel.id,
            mode: .externalProvider
        )
        precondition(hotelRecord.mode == .externalCheckout)
        precondition(
            hotelRecord.status == .externalCheckoutRequired
        )
        precondition(hotelRecord.checkoutURL == hotel.bookingURL)
        precondition(hotelRecord.providerConfirmationCode == nil)
        let hotelItems = session.currentTrip?.itinerary.days
            .flatMap(\.items)
            .filter {
                if case .hotelOffer(let id) = $0.reference {
                    return id == hotel.id
                }
                return false
            }
        precondition(hotelItems?.count == 2)
        precondition(
            hotelItems?.allSatisfy {
                $0.status == .selected
                    && $0.notes?.contains("not reserved") == true
            } == true
        )

        do {
            _ = try session.confirmHotelOffer(
                hotelWithoutCheckout.id,
                mode: .externalProvider
            )
            fatalError("Missing provider checkout was accepted.")
        } catch let error as BookingConfirmationError {
            precondition(error == .missingProviderCheckout)
        }

        let flightPresentation =
            BookingReviewBuilder.presentation(
                for: .flight(flight.id),
                in: trip
            )
        precondition(flightPresentation?.price == flight.totalPrice)
        precondition(
            BookingReviewBuilder.confirmationMode(
                for: flightPresentation!,
                environment: [:]
            ) == .fblaDemo
        )
        let hotelPresentation =
            BookingReviewBuilder.presentation(
                for: .hotel(hotel.id),
                in: trip
            )
        precondition(
            hotelPresentation?.cancellationSummary
                == "Free cancellation available"
        )
        precondition(
            BookingReviewBuilder.confirmationMode(
                for: hotelPresentation!,
                environment: [:]
            ) == .externalProvider
        )
        precondition(
            BookingReviewBuilder.confirmationMode(
                for: hotelPresentation!,
                environment: ["GIA_FBLA_DEMO_MODE": "1"]
            ) == .fblaDemo
        )

        var invalidCheckoutTrip = trip
        invalidCheckoutTrip.bookings = [
            BookingRecord(
                category: .hotel,
                mode: .externalCheckout,
                status: .externalCheckoutRequired,
                itemIdentifier: hotel.id,
                providerName: "Provider",
                amount: hotel.totalPrice,
                checkoutURL: nil,
                provenance: liveProvenance
            )
        ]
        precondition(
            invalidCheckoutTrip.structuralIssues.contains {
                $0.code == .missingBookingCheckout
            }
        )

        print("Booking selection and confirmation verification passed.")
    }
}
