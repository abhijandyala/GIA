#if DEBUG
import Foundation

enum TimelineDebugFixtures {
    static func itineraryTrip(
        preserving originalRequest: TripRequest,
        tripID: UUID = UUID()
    ) -> Trip {
        let timeZone = TimeZone(identifier: "Europe/Lisbon")!
        let hotel = location(
            "Memmo Príncipe Real",
            latitude: 38.7156,
            longitude: -9.1483
        )
        let cafe = location(
            "Dear Breakfast",
            latitude: 38.7138,
            longitude: -9.1439
        )
        let museum = location(
            "National Tile Museum",
            latitude: 38.7242,
            longitude: -9.1139
        )
        let restaurant = location(
            "Lisbon Garden Kitchen",
            latitude: 38.7175,
            longitude: -9.1398
        )
        let river = location(
            "River Stage",
            latitude: 38.7077,
            longitude: -9.1366
        )
        let dayOne = date(
            year: 2027,
            month: 6,
            day: 10,
            hour: 0,
            timeZone: timeZone
        )
        let dayTwo = date(
            year: 2027,
            month: 6,
            day: 11,
            hour: 0,
            timeZone: timeZone
        )
        let provenance = DataProvenance(
            provider: .gia,
            providerIdentifier: "debug-itinerary",
            origin: .demo,
            retrievedAt: Date()
        )
        let weatherOne = WeatherSnapshot(
            location: hotel,
            timeZoneIdentifier: timeZone.identifier,
            periods: [
                WeatherPeriod(
                    start: dayOne,
                    end: dayOne.addingTimeInterval(3_600),
                    condition: .clear,
                    providerConditionCode: 1000,
                    providerDescription: "Sunny",
                    temperatureCelsius: 24,
                    precipitationProbability: 0.1,
                    windKilometersPerHour: 12
                )
            ],
            provenance: DataProvenance(
                provider: .weatherAPI,
                origin: .demo,
                retrievedAt: Date()
            )
        )
        let weatherTwo = WeatherSnapshot(
            location: hotel,
            timeZoneIdentifier: timeZone.identifier,
            periods: [
                WeatherPeriod(
                    start: dayTwo,
                    end: dayTwo.addingTimeInterval(3_600),
                    condition: .cloudy,
                    providerConditionCode: 1006,
                    providerDescription: "Partly cloudy",
                    temperatureCelsius: 22,
                    precipitationProbability: 0.2,
                    windKilometersPerHour: 15
                )
            ],
            provenance: DataProvenance(
                provider: .weatherAPI,
                origin: .demo,
                retrievedAt: Date()
            )
        )
        let tileMuseum = PlaceRecommendation(
            providerPlaceIdentifier: "debug-tile-museum",
            name: museum.name,
            location: museum,
            categories: [.museum],
            estimatedCostPerTraveler: Money(
                amount: 15,
                currencyCode: "USD"
            ),
            estimatedDuration: 7_200,
            indoor: true,
            provenance: provenance
        )
        let gardenKitchen = PlaceRecommendation(
            providerPlaceIdentifier: "debug-garden-kitchen",
            name: restaurant.name,
            location: restaurant,
            categories: [.restaurant],
            estimatedCostPerTraveler: Money(
                amount: 32,
                currencyCode: "USD"
            ),
            dietaryOptions: [.vegetarian],
            provenance: provenance
        )
        let festivalStart = date(
            year: 2027,
            month: 6,
            day: 10,
            hour: 19,
            minute: 30,
            timeZone: timeZone
        )
        let festival = TimedEvent(
            providerEventIdentifier: "debug-river-festival",
            title: "Lisbon River Festival",
            summary: "Outdoor music beside the river.",
            venueName: river.name,
            location: river,
            start: festivalStart,
            end: festivalStart.addingTimeInterval(9_000),
            rawDateText: "Thu, Jun 10, 7:30 PM–10:00 PM",
            timeZoneIdentifier: timeZone.identifier,
            timeZoneIsResolved: true,
            status: .upcoming,
            schedulingTraits: [
                .fixedTime,
                .ticketRequired,
                .outdoor,
                .weatherDependent
            ],
            provenance: provenance
        )
        let dayOneItems = [
            itineraryItem(
                "Breakfast",
                kind: .meal,
                startHour: 9,
                durationMinutes: 60,
                day: dayOne,
                timeZone: timeZone,
                location: cafe,
                flexibility: .flexible,
                cost: 18,
                notes:
                    "Vegetarian options available from sourced place data."
            ),
            itineraryItem(
                tileMuseum.name,
                kind: .activity,
                startHour: 11,
                durationMinutes: 120,
                day: dayOne,
                timeZone: timeZone,
                location: museum,
                flexibility: .fixed,
                cost: 15,
                notes: "Timed museum entry selected by the group.",
                reference: .place(tileMuseum.id)
            ),
            itineraryItem(
                gardenKitchen.name,
                kind: .meal,
                startHour: 13,
                startMinute: 45,
                durationMinutes: 75,
                day: dayOne,
                timeZone: timeZone,
                location: restaurant,
                flexibility: .flexible,
                cost: 32,
                notes: "Lunch remains selected, not reserved.",
                reference: .place(gardenKitchen.id)
            ),
            ItineraryItem(
                title: festival.title,
                kind: .activity,
                status: .selected,
                flexibility: .fixed,
                start: festivalStart,
                end: festivalStart.addingTimeInterval(9_000),
                timeZoneIdentifier: timeZone.identifier,
                location: river,
                reference: .timedEvent(festival.id),
                estimatedCost: Money(
                    amount: 45,
                    currencyCode: "USD"
                ),
                notes: "External ticket purchase is still required."
            )
        ]
        let dayTwoItems = [
            itineraryItem(
                "Belém waterfront",
                kind: .activity,
                startHour: 10,
                durationMinutes: 120,
                day: dayTwo,
                timeZone: timeZone,
                location: location(
                    "Belém",
                    latitude: 38.6977,
                    longitude: -9.2068
                ),
                flexibility: .lockedByUser,
                cost: nil,
                notes: "Locked by the organizer."
            ),
            itineraryItem(
                "Open group time",
                kind: .freeTime,
                startHour: 15,
                durationMinutes: 120,
                day: dayTwo,
                timeZone: timeZone,
                location: hotel,
                flexibility: .flexible,
                cost: nil,
                notes: "Available for a future group choice."
            )
        ]
        var request = originalRequest
        request.destinations = [hotel]
        request.dateRange = TripDateRange(
            start: dayOne,
            end: date(
                year: 2027,
                month: 6,
                day: 17,
                hour: 0,
                timeZone: timeZone
            ),
            timeZoneIdentifier: timeZone.identifier
        )
        request.durationDays = 8
        request.travelerCount = 4
        request.totalBudget = Money(
            amount: 6_000,
            currencyCode: "USD"
        )
        let organizer = Traveler(
            displayName: "Avery",
            initials: "AV",
            role: .organizer
        )

        return Trip(
            id: tripID,
            title: "Lisbon Together",
            lifecycleState: .ready,
            organizerTravelerID: organizer.id,
            request: request,
            travelers: [organizer],
            catalog: TripCatalog(
                places: [tileMuseum, gardenKitchen],
                timedEvents: [festival],
                weatherSnapshots: [weatherOne, weatherTwo]
            ),
            itinerary: TripItinerary(
                days: [
                    ItineraryDay(
                        date: dayOne,
                        timeZoneIdentifier: timeZone.identifier,
                        items: dayOneItems,
                        weatherSnapshotID: weatherOne.id
                    ),
                    ItineraryDay(
                        date: dayTwo,
                        timeZoneIdentifier: timeZone.identifier,
                        items: dayTwoItems,
                        weatherSnapshotID: weatherTwo.id
                    )
                ],
                transportationLegs: [
                    route(
                        from: cafe,
                        to: museum,
                        mode: .transit,
                        minutes: 24
                    ),
                    route(
                        from: museum,
                        to: restaurant,
                        mode: .walking,
                        minutes: 16
                    ),
                    route(
                        from: restaurant,
                        to: river,
                        mode: .transit,
                        minutes: 20
                    )
                ]
            ),
            budget: TripBudget(totalLimit: request.totalBudget)
        )
    }

    private static func location(
        _ name: String,
        latitude: Double,
        longitude: Double
    ) -> TravelLocation {
        TravelLocation(
            name: name,
            city: "Lisbon",
            country: "Portugal",
            countryCode: "PT",
            coordinate: GeoCoordinate(
                latitude: latitude,
                longitude: longitude
            ),
            timeZoneIdentifier: "Europe/Lisbon"
        )
    }

    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }

    private static func itineraryItem(
        _ title: String,
        kind: ItineraryItemKind,
        startHour: Int,
        startMinute: Int = 0,
        durationMinutes: Int,
        day: Date,
        timeZone: TimeZone,
        location: TravelLocation,
        flexibility: ItineraryFlexibility,
        cost: Decimal?,
        notes: String,
        reference: ItineraryReference = .userCreated
    ) -> ItineraryItem {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: day
        )!
        return ItineraryItem(
            title: title,
            kind: kind,
            status: .selected,
            flexibility: flexibility,
            start: start,
            end: start.addingTimeInterval(
                TimeInterval(durationMinutes * 60)
            ),
            timeZoneIdentifier: timeZone.identifier,
            location: location,
            reference: reference,
            estimatedCost: cost.map {
                Money(amount: $0, currencyCode: "USD")
            },
            notes: notes
        )
    }

    private static func route(
        from origin: TravelLocation,
        to destination: TravelLocation,
        mode: TransportationMode,
        minutes: Int
    ) -> TransportationLeg {
        TransportationLeg(
            origin: origin,
            destination: destination,
            mode: mode,
            duration: TimeInterval(minutes * 60),
            distanceMeters: nil,
            routeGeometry: [],
            instructions: [],
            bufferDuration: mode == .walking ? 300 : 600,
            confidence: .estimated,
            provenance: DataProvenance(
                provider: .geoapify,
                origin: .demo,
                retrievedAt: Date()
            )
        )
    }
}
#endif
