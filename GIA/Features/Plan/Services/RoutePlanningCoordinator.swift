import Foundation

@MainActor
final class RoutePlanningCoordinator {
    private let service: any RoutePlanning

    init(service: any RoutePlanning) {
        self.service = service
    }

    func plan(
        criteria: RoutePlanningCriteria,
        session: TripPlanningSession
    ) async throws -> [TransportationLeg] {
        try session.beginWorkstream(
            .routes,
            providers: [.geoapify],
            message: "Connecting itinerary locations"
        )

        do {
            let routes = try await service.planRoutes(
                matching: criteria
            )
            try Task.checkCancellation()
            try session.completeWorkstream(
                .routes,
                resultCount: routes.count,
                providers: [.geoapify],
                message:
                    routes.isEmpty
                    ? "No supported routes found"
                    : "Transportation routes received"
            )
            return routes
        } catch is CancellationError {
            throw GatewayClientError.cancelled
        } catch let error as GatewayClientError
        where error == .cancelled {
            throw error
        } catch {
            try? session.markWorkstreamUnavailable(
                .routes,
                providers: [.geoapify],
                message: "Route planning is temporarily unavailable"
            )
            throw error
        }
    }
}
