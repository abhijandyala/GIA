import Foundation

@main
enum PlanPresentationVerificationMain {
    @MainActor
    static func main() {
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
                start: Date(timeIntervalSince1970: 1_800_000_000),
                end: Date(timeIntervalSince1970: 1_800_604_800),
                timeZoneIdentifier: "Europe/Lisbon"
            ),
            travelerCount: 4,
            totalBudget: Money(
                amount: 6_000,
                currencyCode: "USD"
            )
        )
        let metrics = PlanPresentationBuilder.contextMetrics(
            for: request
        )

        precondition(metrics.count == 4)
        precondition(metrics.allSatisfy(\.isResolved))
        precondition(
            metrics.first { $0.kind == .destination }?.value
                == "Lisbon"
        )
        precondition(
            metrics.first { $0.kind == .travelers }?.value
                == "4 people"
        )

        let emptyRequestMetrics =
            PlanPresentationBuilder.contextMetrics(
                for: TripRequest()
            )
        precondition(
            emptyRequestMetrics.allSatisfy {
                !$0.isResolved && $0.value == "Resolving"
            }
        )

        let queuedProgress = TripPlanningProgress()
        precondition(
            PlanPresentationBuilder.moduleStatus(
                for: .flights,
                progress: queuedProgress,
                trip: nil
            ) == .queued
        )

        var activeProgress = TripPlanningProgress()
        activeProgress.begin(.flights)
        precondition(
            PlanPresentationBuilder.moduleStatus(
                for: .flights,
                progress: activeProgress,
                trip: nil
            ) == .active("Active")
        )

        var unavailableProgress = TripPlanningProgress()
        unavailableProgress.markUnavailable(
            .weather,
            message: "Provider unavailable"
        )
        precondition(
            PlanPresentationBuilder.moduleStatus(
                for: .weather,
                progress: unavailableProgress,
                trip: nil
            ) == .unavailable
        )

        let organizer = Traveler(
            displayName: "Avery",
            initials: "AV",
            role: .organizer
        )
        let provenance = DataProvenance(
            provider: .geoapify,
            origin: .demo,
            retrievedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let place = PlaceRecommendation(
            providerPlaceIdentifier: "fixture",
            name: "Lisbon Oceanarium",
            location: destination,
            categories: [.activity],
            provenance: provenance
        )
        let trip = Trip(
            title: "Lisbon",
            organizerTravelerID: organizer.id,
            request: request,
            travelers: [organizer],
            catalog: TripCatalog(places: [place])
        )

        precondition(
            PlanPresentationBuilder.moduleStatus(
                for: .experiences,
                progress: queuedProgress,
                trip: trip
            ) == .ready("Ready")
        )
        precondition(
            PlanPresentationBuilder.moduleStatus(
                for: .flights,
                progress: queuedProgress,
                trip: trip
            ) == .queued
        )

        print("Plan presentation rules passed.")
    }
}
