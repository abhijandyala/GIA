import Foundation

@MainActor
final class EventSearchCoordinator {
    private let service: any EventSearching

    init(service: any EventSearching) {
        self.service = service
    }

    func search(
        criteria: EventSearchCriteria,
        session: TripPlanningSession
    ) async throws -> [TimedEvent] {
        try session.beginWorkstream(
            .experiences,
            providers: [.serpApi],
            message: "Finding timed events"
        )

        do {
            let events = try await service.searchEvents(
                matching: criteria
            )
            try Task.checkCancellation()
            try session.completeWorkstream(
                .experiences,
                resultCount: events.count,
                providers: [.serpApi],
                message:
                    events.isEmpty
                    ? "No matching timed events found"
                    : "Timed events received"
            )
            return events
        } catch is CancellationError {
            throw GatewayClientError.cancelled
        } catch let error as GatewayClientError
        where error == .cancelled {
            throw error
        } catch {
            try? session.markWorkstreamUnavailable(
                .experiences,
                providers: [.serpApi],
                message: "Event search is temporarily unavailable"
            )
            throw error
        }
    }
}
