import Foundation

@main
enum TripPlanningProgressVerificationMain {
    @MainActor
    static func main() throws {
        let initial = TripPlanningProgress()
        precondition(
            initial.items.count == PlanningWorkstream.allCases.count
        )
        precondition(
            initial.items.allSatisfy { $0.status == .queued }
        )
        precondition(!initial.hasStartedProviderWork)

        let destination = TravelLocation(name: "Lisbon")
        let request = TripRequest(
            destinations: [destination],
            dateRange: TripDateRange(
                start: Date(timeIntervalSince1970: 1_812_758_400),
                end: Date(timeIntervalSince1970: 1_813_363_200),
                timeZoneIdentifier: "Europe/Lisbon"
            ),
            travelerCount: 4,
            totalBudget: Money(
                amount: 6_000,
                currencyCode: "USD"
            )
        )
        let session = TripPlanningSession()

        try session.beginListening(source: .manual)
        try session.beginTranscribing()
        try session.beginValidation(request: request)
        precondition(
            session.progress.item(for: .understanding).status
                == .active
        )
        precondition(!session.progress.hasStartedProviderWork)

        try session.beginSearch()
        precondition(
            session.progress.item(for: .understanding).status
                == .complete
        )
        precondition(
            session.progress.item(for: .destination).resultCount
                == 1
        )

        do {
            try session.beginWorkstream(.budget)
            fatalError("Invalid workstream phase was accepted.")
        } catch let error as TripPlanningProgressError {
            precondition(
                error
                    == .invalidPhase(
                        phase: .searching,
                        workstream: .budget
                    )
            )
        }

        try session.beginWorkstream(
            .flights,
            providers: [.serpApi],
            message: "Comparing live fares"
        )
        precondition(session.progress.hasStartedProviderWork)
        precondition(
            session.progress.activeItem?.workstream == .flights
        )

        try session.completeWorkstream(
            .flights,
            resultCount: 24,
            providers: [.serpApi],
            message: "Flight options received"
        )
        precondition(
            session.progress.item(for: .flights).resultCount == 24
        )
        precondition(
            session.progress.item(for: .flights).providers
                == [.serpApi]
        )

        do {
            try session.completeWorkstream(
                .stay,
                resultCount: -1
            )
            fatalError("A negative result count was accepted.")
        } catch let error as TripPlanningProgressError {
            precondition(error == .invalidResultCount(-1))
            precondition(
                session.progress.item(for: .stay).status == .queued
            )
        }

        try session.markWorkstreamUnavailable(
            .weather,
            providers: [.weatherAPI],
            message: "Weather provider unavailable"
        )
        precondition(
            session.progress.item(for: .weather).status
                == .unavailable
        )

        let encodedProgress = try JSONEncoder().encode(
            session.progress
        )
        let decodedProgress = try JSONDecoder().decode(
            TripPlanningProgress.self,
            from: encodedProgress
        )
        precondition(decodedProgress == session.progress)

        try session.cancel()
        precondition(session.phase == .cancelled)
        precondition(
            session.progress.item(for: .flights).status
                == .complete
        )
        precondition(
            session.progress.item(for: .stay).status
                == .cancelled
        )

        try session.beginReturning()
        try session.finishReturning()
        precondition(session.phase == .idle)
        precondition(
            session.progress.items.allSatisfy {
                $0.status == .queued
            }
        )

        print("Trip planning progress invariants passed.")
    }
}
