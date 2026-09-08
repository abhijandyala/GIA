import Foundation

@main
enum TransientRequestFlowVerificationMain {
    @MainActor
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let session = TripPlanningSession()

        let first = TripRequestInterpreter.interpret(
            transcript:
                "Plan a four-day trip to Chicago for two people "
                + "under $2400 from 2027-05-10 to 2027-05-13.",
            now: now
        )
        try session.beginListening(source: .manual)
        try session.beginTranscribing()
        try session.beginValidation(request: first.request)

        precondition(
            session.currentRequest?.destinations.first?.name
                == "Chicago"
        )
        precondition(session.currentTrip == nil)
        precondition(session.phase == .validating)

        session.clearCurrentTrip()
        precondition(session.phase == .idle)
        precondition(session.currentRequest == nil)
        precondition(session.currentTrip == nil)

        let second = TripRequestInterpreter.interpret(
            transcript:
                "Plan a five-day trip to Vancouver for three people "
                + "under $3200 from 2027-07-01 to 2027-07-05.",
            now: now
        )
        try session.beginListening(source: .manual)
        try session.beginTranscribing()
        try session.beginValidation(request: second.request)

        precondition(
            session.currentRequest?.destinations.first?.name
                == "Vancouver"
        )
        precondition(session.currentRequest?.travelerCount == 3)
        precondition(
            session.currentRequest?.totalBudget?.amount
                == Decimal(3_200)
        )
        precondition(session.currentTrip == nil)

        print("Repeatable in-memory request flow passed.")
    }
}
