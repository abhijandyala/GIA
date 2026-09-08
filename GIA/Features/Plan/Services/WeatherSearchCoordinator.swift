import Foundation

@MainActor
final class WeatherSearchCoordinator {
    private let service: any WeatherProviding

    init(service: any WeatherProviding) {
        self.service = service
    }

    func search(
        criteria: WeatherSearchCriteria,
        session: TripPlanningSession
    ) async throws -> [WeatherSnapshot] {
        try session.beginWorkstream(
            .weather,
            providers: [.weatherAPI],
            message: "Checking forecast and alerts"
        )

        do {
            let snapshots = try await service.weather(
                matching: criteria
            )
            try Task.checkCancellation()
            try session.completeWorkstream(
                .weather,
                resultCount: snapshots.count,
                providers: [.weatherAPI],
                message:
                    snapshots.isEmpty
                    ? "Forecast not yet available for these dates"
                    : "Forecast and alerts received"
            )
            return snapshots
        } catch is CancellationError {
            throw GatewayClientError.cancelled
        } catch let error as GatewayClientError
        where error == .cancelled {
            throw error
        } catch {
            try? session.markWorkstreamUnavailable(
                .weather,
                providers: [.weatherAPI],
                message: "Weather intelligence is temporarily unavailable"
            )
            throw error
        }
    }
}
