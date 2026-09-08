#if DEBUG
import Foundation

enum HotelDebugFixtures {
    static func comparisonTrip(
        preserving originalRequest: TripRequest
    ) -> Trip {
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
        let checkIn = Date(timeIntervalSince1970: 1_812_758_400)
        let checkOut = Date(timeIntervalSince1970: 1_813_363_200)
        var request = originalRequest
        request.destinations = [destination]
        request.dateRange = TripDateRange(
            start: checkIn,
            end: checkOut,
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
            providerIdentifier: "debug-hotel-search",
            origin: .demo,
            retrievedAt: Date(),
            expiresAt: Date().addingTimeInterval(300),
            sourceURL: URL(
                string: "https://www.google.com/travel/hotels"
            )
        )
        let recommended = hotel(
            identifier: "debug-hotel-recommended",
            name: "Memmo Príncipe Real",
            location: destination,
            starRating: 5,
            guestRating: 4.8,
            reviews: 684,
            nightly: 238,
            total: 1_666,
            amenities: [
                .breakfast,
                .pool,
                .wifi,
                .accessibleRoom
            ],
            badges: [.giaRecommended, .flexible],
            description:
                "Design-focused rooms overlooking Lisbon's historic center.",
            provenance: provenance
        )
        let lowest = hotel(
            identifier: "debug-hotel-lowest",
            name: "Lisboa Garden Stay",
            location: destination,
            starRating: 4,
            guestRating: 4.5,
            reviews: 1_240,
            nightly: 154,
            total: 1_078,
            amenities: [
                .breakfast,
                .wifi,
                .laundry
            ],
            badges: [.lowestPrice],
            description:
                "Quiet central rooms with quick access to metro lines.",
            provenance: provenance
        )
        let highestRated = hotel(
            identifier: "debug-hotel-rated",
            name: "Bairro Alto Hotel",
            location: destination,
            starRating: 5,
            guestRating: 4.9,
            reviews: 912,
            nightly: 286,
            total: 2_002,
            amenities: [
                .breakfast,
                .fitnessCenter,
                .spa,
                .wifi,
                .accessibleRoom
            ],
            badges: [.flexible],
            description:
                "Refined rooms near cultural landmarks and evening dining.",
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
                hotelOffers: [recommended, lowest, highestRated]
            ),
            selections: TripSelections(
                hotelOfferIDs: [recommended.id]
            ),
            budget: TripBudget(totalLimit: request.totalBudget)
        )
    }

    private static func hotel(
        identifier: String,
        name: String,
        location: TravelLocation,
        starRating: Int,
        guestRating: Double,
        reviews: Int,
        nightly: Decimal,
        total: Decimal,
        amenities: Set<HotelAmenity>,
        badges: Set<OfferBadge>,
        description: String,
        provenance: DataProvenance
    ) -> HotelOffer {
        HotelOffer(
            providerOfferIdentifier: identifier,
            name: name,
            location: location,
            lodgingType: .hotel,
            starRating: starRating,
            guestRating: guestRating,
            guestRatingScale: 5,
            reviewCount: reviews,
            nightlyPrice: Money(
                amount: nightly,
                currencyCode: "USD"
            ),
            totalPrice: Money(
                amount: total,
                currencyCode: "USD"
            ),
            taxesAndFeesIncluded: true,
            roomDescription: description,
            amenities: amenities,
            imageURLs: [],
            checkInTime: "3:00 PM",
            checkOutTime: "11:00 AM",
            cancellationPolicy:
                badges.contains(.flexible)
                ? CancellationPolicy(
                    summary: "Free cancellation available",
                    refundableUntil: nil,
                    penalty: nil
                )
                : nil,
            badges: badges,
            bookingURL: URL(
                string: "https://www.google.com/travel/hotels"
            ),
            provenance: provenance
        )
    }
}
#endif
