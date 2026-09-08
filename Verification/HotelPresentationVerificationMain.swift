import Foundation

@main
enum HotelPresentationVerificationMain {
    @MainActor
    static func main() throws {
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
        let provenance = DataProvenance(
            provider: .serpApi,
            origin: .live,
            retrievedAt: Date(timeIntervalSince1970: 1_788_000_000)
        )
        let lowest = HotelOffer(
            providerOfferIdentifier: "lowest",
            name: "Lisbon Garden Stay",
            location: destination,
            lodgingType: .hotel,
            starRating: 4,
            guestRating: 4.5,
            guestRatingScale: 5,
            reviewCount: 1_240,
            nightlyPrice: Money(
                amount: 154,
                currencyCode: "USD"
            ),
            totalPrice: Money(
                amount: 1_078,
                currencyCode: "USD"
            ),
            taxesAndFeesIncluded: nil,
            amenities: [.breakfast, .wifi],
            badges: [.lowestPrice],
            provenance: provenance
        )
        let selected = HotelOffer(
            providerOfferIdentifier: "selected",
            name: "Memmo Príncipe Real",
            location: destination,
            lodgingType: .hotel,
            starRating: 5,
            guestRating: 4.8,
            guestRatingScale: 5,
            reviewCount: 684,
            nightlyPrice: Money(
                amount: 238,
                currencyCode: "USD"
            ),
            totalPrice: Money(
                amount: 1_666,
                currencyCode: "USD"
            ),
            taxesAndFeesIncluded: true,
            roomDescription: "Design-focused rooms.",
            amenities: [
                .accessibleRoom,
                .breakfast,
                .pool,
                .wifi
            ],
            checkInTime: "3:00 PM",
            checkOutTime: "11:00 AM",
            cancellationPolicy: CancellationPolicy(
                summary: "Free cancellation available",
                refundableUntil: nil,
                penalty: nil
            ),
            badges: [.giaRecommended, .flexible],
            provenance: provenance
        )
        let presentations = HotelPresentationBuilder.sortedOffers(
            [lowest, selected],
            selectedIDs: [selected.id]
        )

        precondition(presentations.first?.id == selected.id)
        precondition(
            presentations[0].locationLabel == "Lisbon, Portugal"
        )
        precondition(presentations[0].ratingText.contains("4"))
        precondition(presentations[0].ratingText.hasSuffix("/5"))
        precondition(presentations[0].reviewText == "684 reviews")
        precondition(presentations[0].nightlyPrice.contains("238"))
        precondition(
            presentations[0].totalPrice
                .replacingOccurrences(of: ",", with: "")
                .contains("1666")
        )
        precondition(
            presentations[0].taxDescription
                == "Taxes and fees included"
        )
        precondition(
            presentations[0].cancellationDescription
                == "Free cancellation available"
        )
        precondition(
            presentations[0].amenityTitles.contains("Accessible room")
        )
        precondition(
            presentations[0].primaryBadge == "GIA RECOMMENDED"
        )
        precondition(
            presentations[1].taxDescription
                == "Tax and fee total not confirmed"
        )
        precondition(
            presentations[1].primaryBadge == "LOWEST TOTAL"
        )

        let dateRange = TripDateRange(
            start: Date(timeIntervalSince1970: 1_812_758_400),
            end: Date(timeIntervalSince1970: 1_813_363_200),
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let request = TripRequest(
            destinations: [destination],
            dateRange: dateRange,
            travelerCount: 4,
            totalBudget: Money(
                amount: 6_000,
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
                hotelOffers: [lowest, selected]
            ),
            selections: TripSelections(
                hotelOfferIDs: [selected.id]
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
        try session.selectHotelOffer(lowest.id)

        precondition(
            session.currentTrip?.selections.hotelOfferIDs
                == [lowest.id]
        )
        do {
            try session.selectHotelOffer(UUID())
            fatalError("Unknown hotel selection was accepted.")
        } catch let error as TripSelectionError {
            if case .unknownHotelOffer = error {
                // Expected.
            } else {
                fatalError("Unexpected selection error.")
            }
        }

        print("Hotel presentation and selection passed.")
    }
}
