import Foundation

@MainActor
final class FlightSearchCoordinator {
    private let service: any FlightSearching

    init(service: any FlightSearching) {
        self.service = service
    }

    func search(
        criteria: FlightSearchCriteria,
        session: TripPlanningSession
    ) async throws -> [FlightOffer] {
        try session.beginWorkstream(
            .flights,
            providers: [.serpApi],
            message: "Comparing live fares"
        )

        do {
            let offers = try await service.searchFlights(
                matching: criteria
            )
            try Task.checkCancellation()
            try session.completeWorkstream(
                .flights,
                resultCount: offers.count,
                providers: [.serpApi],
                message:
                    offers.isEmpty
                    ? "No matching fares found"
                    : "Live fares received"
            )
            return offers
        } catch is CancellationError {
            throw GatewayClientError.cancelled
        } catch let error as GatewayClientError
        where error == .cancelled {
            throw error
        } catch {
            try? session.markWorkstreamUnavailable(
                .flights,
                providers: [.serpApi],
                message: "Flight search is temporarily unavailable"
            )
            throw error
        }
    }
}
