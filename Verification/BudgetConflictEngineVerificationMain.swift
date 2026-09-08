import Foundation

@main
enum BudgetConflictEngineVerificationMain {
    static func main() throws {
        let zone = TimeZone(identifier: "Europe/Lisbon")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = calendar.date(
            from: DateComponents(
                year: 2027,
                month: 6,
                day: 10
            )
        )!
        let mealStart = calendar.date(
            bySettingHour: 10,
            minute: 0,
            second: 0,
            of: day
        )!
        let eventStart = calendar.date(
            bySettingHour: 11,
            minute: 30,
            second: 0,
            of: day
        )!
        let cafe = location(
            "Cafe",
            latitude: 38.71,
            longitude: -9.14
        )
        let venue = location(
            "Outdoor stage",
            latitude: 38.72,
            longitude: -9.13
        )
        let provenance = DataProvenance(
            provider: .gia,
            origin: .demo,
            retrievedAt: day
        )
        let place = PlaceRecommendation(
            providerPlaceIdentifier: "cafe",
            name: cafe.name,
            location: cafe,
            categories: [.restaurant],
            estimatedCostPerTraveler: Money(
                amount: 30,
                currencyCode: "USD"
            ),
            openingHours: OpeningHours(
                rawText: ["Thursday: Closed"],
                isOpenAtRetrieval: false
            ),
            reservationRequired: true,
            provenance: provenance
        )
        let event = TimedEvent(
            providerEventIdentifier: "event",
            title: "Outdoor concert",
            location: venue,
            start: eventStart,
            end: eventStart.addingTimeInterval(3_600),
            rawDateText: "June 10 at 11:30 AM",
            timeZoneIdentifier: zone.identifier,
            timeZoneIsResolved: true,
            status: .upcoming,
            schedulingTraits: [
                .fixedTime,
                .outdoor,
                .ticketRequired,
                .weatherDependent
            ],
            provenance: provenance
        )
        let meal = ItineraryItem(
            title: place.name,
            kind: .meal,
            status: .selected,
            flexibility: .flexible,
            start: mealStart,
            end: mealStart.addingTimeInterval(3_600),
            timeZoneIdentifier: zone.identifier,
            location: cafe,
            reference: .place(place.id),
            estimatedCost: Money(
                amount: 30,
                currencyCode: "USD"
            )
        )
        let eventItem = ItineraryItem(
            title: event.title,
            kind: .activity,
            status: .selected,
            flexibility: .fixed,
            start: eventStart,
            end: eventStart.addingTimeInterval(3_600),
            timeZoneIdentifier: zone.identifier,
            location: venue,
            reference: .timedEvent(event.id),
            estimatedCost: Money(
                amount: 10,
                currencyCode: "USD"
            )
        )
        let route = TransportationLeg(
            origin: cafe,
            destination: venue,
            mode: .transit,
            duration: 1_500,
            estimatedCost: Money(
                amount: 2,
                currencyCode: "EUR"
            ),
            bufferDuration: 600,
            confidence: .estimated,
            provenance: provenance
        )
        let weather = WeatherSnapshot(
            location: venue,
            timeZoneIdentifier: zone.identifier,
            periods: [
                WeatherPeriod(
                    start: eventStart,
                    end: eventStart.addingTimeInterval(3_600),
                    condition: .storm,
                    providerDescription: "Thunderstorms",
                    precipitationProbability: 0.9
                )
            ],
            provenance: provenance
        )
        let request = TripRequest(
            destinations: [venue],
            dateRange: TripDateRange(
                start: day,
                end: day.addingTimeInterval(86_400),
                timeZoneIdentifier: zone.identifier
            ),
            travelerCount: 1,
            totalBudget: Money(
                amount: 35,
                currencyCode: "USD"
            ),
            dietaryRequirements: [.vegan],
            accessibilityRequirements: [.wheelchairAccess]
        )
        let traveler = Traveler(
            displayName: "Avery",
            initials: "AV",
            role: .organizer
        )
        let rate = CurrencyConversionRate(
            sourceCurrencyCode: "EUR",
            destinationCurrencyCode: "USD",
            rate: 2,
            retrievedAt: day,
            provenance: provenance
        )
        let itineraryDay = ItineraryDay(
            date: day,
            timeZoneIdentifier: zone.identifier,
            items: [meal, eventItem],
            weatherSnapshotID: weather.id
        )
        let trip = Trip(
            title: "Conflict verification",
            lifecycleState: .ready,
            organizerTravelerID: traveler.id,
            request: request,
            travelers: [traveler],
            catalog: TripCatalog(
                places: [place],
                timedEvents: [event],
                weatherSnapshots: [weather]
            ),
            itinerary: TripItinerary(
                days: [itineraryDay],
                transportationLegs: [route]
            ),
            budget: TripBudget(
                totalLimit: request.totalBudget,
                allocations: [
                    allocation(.food, limit: 20),
                    allocation(.activities, limit: 20),
                    allocation(.transportation, limit: 10),
                    allocation(.emergencyReserve, limit: 5)
                ],
                currencyConversionRates: [rate]
            ),
            createdAt: day,
            updatedAt: day
        )

        let analysis = TripBudgetConflictEngine.analyze(
            trip: trip,
            at: day
        )
        precondition(analysis.budget.estimatedSpend.amount == 44)
        precondition(analysis.budget.emergencyReserve.amount == 5)
        precondition(analysis.budget.remainingAfterReserve?.amount == -14)
        precondition(
            analysis.budget.conversionTimestamps == [day]
        )
        precondition(
            analysis.conflicts.contains {
                $0.kind == .budgetOverflow
            }
        )
        precondition(
            analysis.conflicts.contains {
                $0.kind == .budgetCategoryOverflow
            }
        )
        precondition(
            analysis.conflicts.contains {
                $0.kind == .insufficientTravelTime
            }
        )
        precondition(
            analysis.conflicts.contains { $0.kind == .closedVenue }
        )
        precondition(
            analysis.conflicts.contains { $0.kind == .dietary }
        )
        precondition(
            analysis.conflicts.contains {
                $0.kind == .accessibility
            }
        )
        precondition(
            analysis.conflicts.contains { $0.kind == .weather }
        )
        precondition(
            analysis.conflicts.contains {
                $0.kind == .missingReservation
            }
        )
        precondition(
            analysis.conflicts == analysis.conflicts.sorted {
                if $0.severity != $1.severity {
                    return
                        $0.severity.rawValue > $1.severity.rawValue
                }
                if $0.kind != $1.kind {
                    return $0.kind.rawValue < $1.kind.rawValue
                }
                return $0.id < $1.id
            }
        )

        var confirmedEventTrip = trip
        confirmedEventTrip.bookings = [
            BookingRecord(
                category: .activity,
                mode: .providerConfirmed,
                status: .confirmed,
                itemIdentifier: event.id,
                providerName: "Event provider",
                amount: Money(
                    amount: 10,
                    currencyCode: "USD"
                ),
                provenance: provenance
            )
        ]
        let confirmedEventAnalysis =
            TripBudgetConflictEngine.analyze(
                trip: confirmedEventTrip,
                at: day
            )
        precondition(
            confirmedEventAnalysis.budget.estimatedSpend.amount == 34
        )
        precondition(
            confirmedEventAnalysis.budget.confirmedSpend.amount == 10
        )
        precondition(
            !confirmedEventAnalysis.conflicts.contains {
                $0.id == "reservation-item-\(eventItem.id)"
            }
        )

        let legacyBudget = try JSONDecoder().decode(
            TripBudget.self,
            from: Data(#"{"allocations":[]}"#.utf8)
        )
        precondition(legacyBudget.currencyConversionRates.isEmpty)

        print("Budget and conflict engine verification passed.")
    }

    private static func allocation(
        _ category: BudgetCategory,
        limit: Decimal
    ) -> BudgetAllocation {
        BudgetAllocation(
            category: category,
            limit: Money(amount: limit, currencyCode: "USD"),
            estimatedSpend: .zero(currencyCode: "USD"),
            confirmedSpend: .zero(currencyCode: "USD")
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
}
