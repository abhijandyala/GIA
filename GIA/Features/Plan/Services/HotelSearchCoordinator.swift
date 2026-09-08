import Foundation

@MainActor
final class HotelSearchCoordinator {
    private let service: any HotelSearching

    init(service: any HotelSearching) {
        self.service = service
    }

    func search(
        criteria: HotelSearchCriteria,
        session: TripPlanningSession
    ) async throws -> [HotelOffer] {
        try session.beginWorkstream(
            .stay,
            providers: [.serpApi],
            message: "Evaluating live stays"
        )

        do {
            let offers = try await service.searchHotels(
                matching: criteria
            )
            try Task.checkCancellation()
            try session.completeWorkstream(
                .stay,
                resultCount: offers.count,
                providers: [.serpApi],
                message:
                    offers.isEmpty
                    ? "No matching stays found"
                    : "Live stays received"
            )
            return offers
        } catch is CancellationError {
            throw GatewayClientError.cancelled
        } catch let error as GatewayClientError
        where error == .cancelled {
            throw error
        } catch {
            try? session.markWorkstreamUnavailable(
                .stay,
                providers: [.serpApi],
                message: "Hotel search is temporarily unavailable"
            )
            throw error
        }
    }
}
