import Foundation

@main
enum TripPlanningSessionStateMachineMain {
    @MainActor
    static func main() throws {
        let session = TripPlanningSession()
        precondition(session.phase == .idle)
        precondition(!session.isAssistantPresented)

        let destination = TravelLocation(
            name: "Lisbon",
            city: "Lisbon",
            country: "Portugal",
            countryCode: "PT",
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let request = TripRequest(
            destinations: [destination],
            travelerCount: 1,
            totalBudget: Money(
                amount: 2_500,
                currencyCode: "USD"
            )
        )

        do {
            try session.beginValidation(request: request)
            fatalError("An invalid transition was accepted.")
        } catch let error as TripPlanningTransitionError {
            precondition(
                error
                    == .invalidTransition(
                        from: .idle,
                        to: .validating
                    )
            )
            precondition(session.currentRequest == nil)
        }

        do {
            try session.fail(
                code: "invalid",
                userMessage: "Invalid",
                isRecoverable: true
            )
            fatalError("An invalid failure transition was accepted.")
        } catch {
            precondition(session.failure == nil)
        }

        try session.registerWakePhrase()
        precondition(session.phase == .wakePhraseDetected)
        precondition(session.activationSource == .wakePhrase)

        try session.beginListening(source: .wakePhrase)
        precondition(session.phase == .listening)
        precondition(session.isAssistantPresented)

        try session.beginTranscribing()
        try session.beginValidation(request: request)
        try session.requestClarification(for: [.dates])
        precondition(
            session.clarificationFields == [.dates]
        )

        try session.beginListening()
        try session.beginValidation(request: request)
        try session.beginSearch()
        try session.beginComparison()
        try session.beginItineraryBuild()
        try session.beginPresentation()

        let organizer = Traveler(
            displayName: "Avery",
            initials: "AV",
            role: .organizer
        )
        let trip = Trip(
            title: "Lisbon",
            lifecycleState: .ready,
            organizerTravelerID: organizer.id,
            request: request,
            travelers: [organizer]
        )
        try session.complete(with: trip)

        precondition(session.phase == .ready)
        precondition(session.currentTrip == trip)
        precondition(!session.isAssistantPresented)

        try session.beginReturning()
        precondition(session.isReturning)
        try session.finishReturning()
        precondition(session.phase == .idle)
        precondition(session.currentTrip == trip)

        try session.beginListening(source: .manual)
        try session.fail(
            code: "network",
            userMessage: "Try again.",
            isRecoverable: true
        )
        precondition(session.phase == .failed)
        try session.retry()
        precondition(session.phase == .listening)

        try session.cancel()
        precondition(session.phase == .cancelled)
        try session.beginReturning()
        try session.finishReturning()

        precondition(session.transitionHistory.count >= 20)
        precondition(session.revision >= 20)

        session.resetForNewRequest()
        precondition(session.currentRequest == nil)
        precondition(session.currentTrip == nil)

        try session.beginListening(source: .manual)
        try session.beginTranscribing()
        try session.beginValidation(request: request)
        try session.beginSearch()
        try session.beginListening()
        precondition(session.phase == .listening)
        try session.beginValidation(request: request)
        try session.beginSearch()
        try session.beginComparison()
        try session.beginListening()
        precondition(session.phase == .listening)
        try session.beginValidation(request: request)
        try session.beginSearch()
        try session.beginComparison()
        try session.beginItineraryBuild()
        try session.beginListening()
        precondition(session.phase == .listening)

        print("Trip planning state machine passed.")
    }
}
