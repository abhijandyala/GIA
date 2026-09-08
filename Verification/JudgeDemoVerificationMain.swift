import Foundation

@main
enum JudgeDemoVerificationMain {
    @MainActor
    static func main() throws {
        let retrievedAt =
            Date(timeIntervalSince1970: 1_789_000_000)
        let trip = JudgeDemoTripFactory.makeTrip(
            retrievedAt: retrievedAt
        )

        precondition(trip.id == JudgeDemoTripFactory.tripID)
        precondition(trip.title == "Tokyo Together")
        precondition(trip.structuralIssues.isEmpty)
        precondition(trip.usesDemoData)
        precondition(trip.catalog.flightOffers.count >= 2)
        precondition(trip.catalog.hotelOffers.count >= 2)
        precondition(trip.catalog.places.count >= 4)
        precondition(!trip.catalog.timedEvents.isEmpty)
        precondition(trip.catalog.weatherSnapshots.count >= 2)
        precondition(trip.itinerary.days.count >= 2)
        precondition(
            trip.itinerary.transportationLegs.count >= 3
        )
        precondition(trip.travelers.count == 4)
        precondition(trip.decisions.count >= 2)
        precondition(
            (trip.communication?.messages.count ?? 0) >= 3
        )
        precondition(!trip.selections.flightOfferIDs.isEmpty)
        precondition(!trip.selections.hotelOfferIDs.isEmpty)
        precondition(
            trip.budget.allocations.map(\.category).contains(
                .emergencyReserve
            )
        )

        let origins =
            trip.catalog.flightOffers.map {
                $0.provenance.origin
            }
            + trip.catalog.hotelOffers.map {
                $0.provenance.origin
            }
            + trip.catalog.places.map {
                $0.provenance.origin
            }
            + trip.catalog.timedEvents.map {
                $0.provenance.origin
            }
            + trip.catalog.weatherSnapshots.map {
                $0.provenance.origin
            }
            + trip.itinerary.transportationLegs.map {
                $0.provenance.origin
            }
        precondition(origins.allSatisfy { $0 == .demo })

        let controller = JudgeDemoController()
        precondition(controller.state == .inactive)
        controller.activate(reason: .manual)
        precondition(controller.isActive)
        precondition(
            controller.statusLabel
                == "Judge demo started manually"
        )
        controller.reset()
        precondition(controller.state == .inactive)
        precondition(controller.resetSequence == 1)

        let session = TripPlanningSession()
        try session.beginListening(source: .debug)
        try session.beginTranscribing()
        try session.beginValidation(request: trip.request)
        try session.beginSearch()
        try session.beginComparison()
        try session.beginItineraryBuild()
        try session.beginPresentation()
        try session.complete(with: trip)
        precondition(session.currentTrip?.id == trip.id)
        try session.registerWakePhrase()
        try session.beginListening()
        try session.beginTranscribing()
        try session.resumeAfterFollowUp(returningTo: .ready)
        precondition(session.phase == .ready)
        precondition(session.currentTrip?.id == trip.id)
        session.clearCurrentTrip()
        precondition(session.phase == .idle)
        precondition(session.currentTrip == nil)

        let partialSession = TripPlanningSession()
        try partialSession.beginListening(source: .manual)
        try partialSession.beginTranscribing()
        try partialSession.beginValidation(request: trip.request)
        try partialSession.beginSearch()
        try partialSession.markPartiallyAvailable(
            unavailableProviders: [.serpApi]
        )
        try partialSession.registerWakePhrase()
        try partialSession.beginListening()
        try partialSession.beginTranscribing()
        try partialSession.resumeAfterFollowUp(
            returningTo: .partiallyAvailable
        )
        precondition(partialSession.phase == .partiallyAvailable)
        precondition(partialSession.currentRequest?.id == trip.request.id)

        let activeSession = TripPlanningSession()
        try activeSession.beginListening(source: .manual)
        try activeSession.beginTranscribing()
        try activeSession.beginValidation(request: trip.request)
        try activeSession.beginSearch()
        try activeSession.registerWakePhrase()
        try activeSession.beginListening()
        try activeSession.beginTranscribing()
        try activeSession.beginValidation(request: trip.request)
        try activeSession.beginSearch()
        precondition(activeSession.phase == .searching)
        precondition(activeSession.currentRequest?.id == trip.request.id)

        let repeated = JudgeDemoTripFactory.makeTrip(
            retrievedAt: retrievedAt.addingTimeInterval(60)
        )
        precondition(repeated.id == trip.id)
        precondition(repeated.structuralIssues.isEmpty)

        print("Judge-safe offline demo fixture passed.")
    }
}
