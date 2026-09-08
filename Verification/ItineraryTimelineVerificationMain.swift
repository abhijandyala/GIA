import Foundation

@main
enum ItineraryTimelineVerificationMain {
    @MainActor
    static func main() throws {
        let timeZone = TimeZone(identifier: "Europe/Lisbon")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.date(
            from: DateComponents(
                year: 2027,
                month: 6,
                day: 10
            )
        )!
        let hotel = location(
            "Hotel",
            latitude: 38.72,
            longitude: -9.14
        )
        let museum = location(
            "Museum",
            latitude: 38.71,
            longitude: -9.13
        )
        let breakfastStart = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: day
        )!
        let museumStart = calendar.date(
            bySettingHour: 11,
            minute: 0,
            second: 0,
            of: day
        )!
        let breakfast = ItineraryItem(
            title: "Breakfast",
            kind: .meal,
            status: .selected,
            flexibility: .flexible,
            start: breakfastStart,
            end: breakfastStart.addingTimeInterval(3_600),
            timeZoneIdentifier: timeZone.identifier,
            location: hotel,
            estimatedCost: Money(
                amount: 18,
                currencyCode: "USD"
            )
        )
        let museumItem = ItineraryItem(
            title: "Museum",
            kind: .activity,
            status: .selected,
            flexibility: .fixed,
            start: museumStart,
            end: museumStart.addingTimeInterval(3_600),
            timeZoneIdentifier: timeZone.identifier,
            location: museum
        )
        let route = TransportationLeg(
            origin: hotel,
            destination: museum,
            mode: .walking,
            duration: 900,
            distanceMeters: 1_200,
            bufferDuration: 300,
            confidence: .estimated,
            provenance: DataProvenance(
                provider: .geoapify,
                origin: .demo,
                retrievedAt: day
            )
        )
        let weather = WeatherSnapshot(
            location: hotel,
            timeZoneIdentifier: timeZone.identifier,
            periods: [
                WeatherPeriod(
                    start: day,
                    end: day.addingTimeInterval(3_600),
                    condition: .clear,
                    providerDescription: "Sunny",
                    temperatureCelsius: 24
                )
            ],
            provenance: DataProvenance(
                provider: .weatherAPI,
                origin: .demo,
                retrievedAt: day
            )
        )
        let itineraryDay = ItineraryDay(
            date: day,
            timeZoneIdentifier: timeZone.identifier,
            items: [museumItem, breakfast],
            weatherSnapshotID: weather.id
        )
        let request = TripRequest(
            destinations: [hotel],
            dateRange: TripDateRange(
                start: day,
                end: day.addingTimeInterval(604_800),
                timeZoneIdentifier: timeZone.identifier
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
                weatherSnapshots: [weather]
            ),
            itinerary: TripItinerary(
                days: [itineraryDay],
                transportationLegs: [route]
            )
        )
        let dayPresentations =
            ItineraryPresentationBuilder.days(for: trip)

        precondition(dayPresentations.count == 1)
        precondition(
            dayPresentations[0].items.map(\.item.id)
                == [breakfast.id, museumItem.id]
        )
        precondition(
            dayPresentations[0].weatherSummary == "Sunny · 24°C"
        )
        precondition(
            dayPresentations[0].items[0].costText?.contains("18")
                == true
        )
        precondition(
            ItineraryPresentationBuilder.route(
                from: breakfast,
                to: museumItem,
                in: trip
            )?.durationText == "15 min"
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

        try session.moveItineraryItem(
            breakfast.id,
            toStart: breakfastStart.addingTimeInterval(900),
            end: breakfastStart.addingTimeInterval(4_500)
        )
        let moved = session.currentTrip?.itinerary.days[0]
            .items
            .first { $0.id == breakfast.id }
        precondition(
            moved?.start == breakfastStart.addingTimeInterval(900)
        )
        precondition(
            moved?.end.timeIntervalSince(moved!.start) == 3_600
        )

        do {
            try session.moveItineraryItem(
                breakfast.id,
                toStart: museumStart.addingTimeInterval(-1_800),
                end: museumStart.addingTimeInterval(1_800)
            )
            fatalError("Overlapping move was accepted.")
        } catch let error as ItineraryEditingError {
            if case .overlap(let conflictingID) = error {
                precondition(conflictingID == museumItem.id)
            } else {
                fatalError("Unexpected overlap error.")
            }
        }

        do {
            try session.moveItineraryItem(
                museumItem.id,
                toStart: museumStart.addingTimeInterval(900),
                end: museumStart.addingTimeInterval(4_500)
            )
            fatalError("Fixed item was moved.")
        } catch let error as ItineraryEditingError {
            precondition(error == .fixedItem(museumItem.id))
        }

        try session.toggleItineraryItemLock(breakfast.id)
        do {
            try session.moveItineraryItem(
                breakfast.id,
                toStart: breakfastStart,
                end: breakfastStart.addingTimeInterval(3_600)
            )
            fatalError("Locked item was moved.")
        } catch let error as ItineraryEditingError {
            precondition(error == .lockedItem(breakfast.id))
        }
        try session.toggleItineraryItemLock(breakfast.id)

        print("Itinerary timeline presentation and editing passed.")
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
}
