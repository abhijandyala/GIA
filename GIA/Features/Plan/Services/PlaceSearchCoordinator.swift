import Foundation

@MainActor
final class PlaceSearchCoordinator {
    private let service: any PlaceSearching

    init(service: any PlaceSearching) {
        self.service = service
    }

    func search(
        criteria: PlaceSearchCriteria,
        session: TripPlanningSession
    ) async throws -> [PlaceRecommendation] {
        try session.beginWorkstream(
            .experiences,
            providers: [.geoapify, .serpApi],
            message: "Discovering relevant places"
        )

        do {
            let places = try await service.searchPlaces(
                matching: criteria
            )
            try Task.checkCancellation()
            let providers = Set(
                places.map { $0.provenance.provider }
            )
            try session.completeWorkstream(
                .experiences,
                resultCount: places.count,
                providers: providers,
                message:
                    places.isEmpty
                    ? "No matching places found"
                    : "Relevant places received"
            )
            return places
        } catch is CancellationError {
            throw GatewayClientError.cancelled
        } catch let error as GatewayClientError
        where error == .cancelled {
            throw error
        } catch {
            try? session.markWorkstreamUnavailable(
                .experiences,
                providers: [.geoapify, .serpApi],
                message: "Place discovery is temporarily unavailable"
            )
            throw error
        }
    }
}
