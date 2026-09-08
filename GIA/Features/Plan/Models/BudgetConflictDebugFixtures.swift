#if DEBUG
import Foundation

enum BudgetConflictDebugFixtures {
    static func analysisTrip(
        preserving request: TripRequest
    ) -> Trip {
        var trip = TimelineDebugFixtures.itineraryTrip(
            preserving: request
        )
        let rateTimestamp = trip.updatedAt

        trip.request.dietaryRequirements = [
            .vegetarian,
            .glutenFree
        ]
        trip.request.accessibilityRequirements = [
            .wheelchairAccess
        ]

        for index in trip.catalog.places.indices {
            if trip.catalog.places[index].categories.contains(.museum) {
                trip.catalog.places[index].accessibilityFeatures = [
                    .wheelchairAccess
                ]
            }
            if
                trip.catalog.places[index].categories.contains(
                    .restaurant
                )
            {
                trip.catalog.places[index].openingHours = OpeningHours(
                    rawText: ["Thursday: Closed"],
                    isOpenAtRetrieval: false
                )
                trip.catalog.places[index].reservationRequired = true
            }
        }

        if
            let day = trip.itinerary.days.first,
            let eventItem = day.items.first(
                where: {
                    if case .timedEvent = $0.reference {
                        return true
                    }
                    return false
                }
            ),
            let snapshotIndex =
                trip.catalog.weatherSnapshots.firstIndex(
                    where: { $0.id == day.weatherSnapshotID }
                )
        {
            trip.catalog.weatherSnapshots[snapshotIndex].periods.append(
                WeatherPeriod(
                    start: eventItem.start.addingTimeInterval(-1_800),
                    end: eventItem.end,
                    condition: .storm,
                    providerConditionCode: 1276,
                    providerDescription: "Heavy rain and thunder",
                    temperatureCelsius: 20,
                    precipitationProbability: 0.9,
                    windKilometersPerHour: 48
                )
            )
        }

        if !trip.itinerary.transportationLegs.isEmpty {
            trip.itinerary.transportationLegs[0].duration = 3_300
            trip.itinerary.transportationLegs[0].bufferDuration = 600
            trip.itinerary.transportationLegs[0].estimatedCost = Money(
                amount: 5,
                currencyCode: "EUR"
            )
        }
        if trip.itinerary.transportationLegs.count > 1 {
            trip.itinerary.transportationLegs[1].estimatedCost = Money(
                amount: 3,
                currencyCode: "USD"
            )
        }
        if trip.itinerary.transportationLegs.count > 2 {
            trip.itinerary.transportationLegs[2].estimatedCost = Money(
                amount: 6,
                currencyCode: "USD"
            )
        }

        trip.budget = TripBudget(
            totalLimit: Money(
                amount: 6_000,
                currencyCode: "USD"
            ),
            allocations: [
                allocation(.flights, limit: 2_400),
                allocation(.lodging, limit: 1_800),
                allocation(.food, limit: 40),
                allocation(.activities, limit: 550),
                allocation(.transportation, limit: 300),
                allocation(.emergencyReserve, limit: 500)
            ],
            currencyConversionRates: [
                CurrencyConversionRate(
                    sourceCurrencyCode: "EUR",
                    destinationCurrencyCode: "USD",
                    rate: 1.08,
                    retrievedAt: rateTimestamp,
                    provenance: DataProvenance(
                        provider: .gia,
                        providerIdentifier: "debug-eur-usd",
                        origin: .demo,
                        retrievedAt: rateTimestamp
                    )
                )
            ]
        )
        trip.updatedAt = rateTimestamp
        return trip
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
}
#endif
