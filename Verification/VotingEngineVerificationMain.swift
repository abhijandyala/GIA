import Foundation

@main
enum VotingEngineVerificationMain {
    @MainActor
    static func main() throws {
        let date = Date(timeIntervalSince1970: 1_812_758_400)
        let members = [
            traveler("Avery", "AV", role: .organizer),
            traveler("Maya", "MK"),
            traveler("Noah", "NR"),
            traveler("Sofia", "SL")
        ]
        let destination = TravelLocation(
            name: "Lisbon",
            city: "Lisbon",
            country: "Portugal",
            countryCode: "PT",
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let request = TripRequest(
            destinations: [destination],
            dateRange: TripDateRange(
                start: date,
                end: date.addingTimeInterval(604_800),
                timeZoneIdentifier: "Europe/Lisbon"
            ),
            travelerCount: members.count,
            totalBudget: Money(
                amount: 6_000,
                currencyCode: "USD"
            )
        )
        let trip = Trip(
            title: "Lisbon Together",
            lifecycleState: .ready,
            organizerTravelerID: members[0].id,
            request: request,
            travelers: members,
            budget: TripBudget(totalLimit: request.totalBudget),
            collaboration: TripCollaboration(),
            createdAt: date,
            updatedAt: date
        )
        let session = TripPlanningSession()
        try session.beginListening(source: .manual)
        try session.beginTranscribing()
        try session.beginValidation(request: request)
        try session.beginSearch()
        try session.beginComparison()
        try session.beginItineraryBuild()
        try session.beginPresentation()
        try session.complete(with: trip)

        let majority = try session.proposeDecision(
            title: "Approve Lisbon",
            subject: .destination(destination.id),
            rule: .majority
        )
        precondition(
            majority.eligibleTravelerIDs == Set(members.map(\.id))
        )
        try session.castVote(
            on: majority.id,
            choice: .approve
        )
        do {
            try session.castVote(
                on: majority.id,
                choice: .approve
            )
            fatalError("Duplicate vote was accepted.")
        } catch let error as DecisionVotingError {
            precondition(error == .duplicateVote(members[0].id))
        }
        try session.setActiveTraveler(members[1].id)
        try session.castVote(
            on: majority.id,
            choice: .approve
        )
        precondition(
            decision(majority.id, in: session).state == .voting
        )
        try session.setActiveTraveler(members[2].id)
        try session.castVote(
            on: majority.id,
            choice: .approve
        )
        precondition(
            decision(majority.id, in: session).state == .approved
        )
        try session.setActiveTraveler(members[3].id)
        do {
            try session.castVote(
                on: majority.id,
                choice: .reject
            )
            fatalError("A closed decision accepted another vote.")
        } catch let error as DecisionVotingError {
            precondition(error == .decisionClosed(majority.id))
        }

        try session.setActiveTraveler(members[0].id)
        let unanimous = try session.proposeDecision(
            title: "Approve exact dates",
            subject: .dateRange,
            rule: .unanimous
        )
        try session.setActiveTraveler(members[1].id)
        try session.castVote(
            on: unanimous.id,
            choice: .reject
        )
        precondition(
            decision(unanimous.id, in: session).state == .rejected
        )

        try session.setActiveTraveler(members[0].id)
        let organizerDecision = try session.proposeDecision(
            title: "Organizer chooses reserve",
            subject: .budget,
            rule: .organizer
        )
        try session.setActiveTraveler(members[1].id)
        do {
            try session.castVote(
                on: organizerDecision.id,
                choice: .approve
            )
            fatalError("Member voted on organizer-only decision.")
        } catch let error as DecisionVotingError {
            precondition(error == .ineligibleVoter(members[1].id))
        }
        try session.setActiveTraveler(members[0].id)
        try session.castVote(
            on: organizerDecision.id,
            choice: .approve
        )
        precondition(
            decision(organizerDecision.id, in: session).state
                == .approved
        )

        let tied = try session.proposeDecision(
            title: "Set the reserve",
            subject: .budget,
            rule: .majority
        )
        for (index, member) in members.enumerated() {
            try session.setActiveTraveler(member.id)
            try session.castVote(
                on: tied.id,
                choice: index < 2 ? .approve : .reject
            )
        }
        let tiedResult = decision(tied.id, in: session)
        precondition(tiedResult.state == .tied)
        precondition(
            GroupDecisionEngine.tally(
                decision: tiedResult,
                trip: session.currentTrip!
            ).approvalThreshold == 3
        )

        try session.setActiveTraveler(members[0].id)
        let replacement = try session.reviseDecision(tied.id)
        precondition(replacement.supersedesDecisionID == tied.id)
        precondition(replacement.revisionNumber == 2)
        precondition(replacement.votes.isEmpty)
        precondition(
            decision(tied.id, in: session).votes.count == 4
        )

        try session.setActiveTraveler(members[1].id)
        do {
            _ = try session.proposeDecision(
                title: "Unauthorized proposal",
                subject: .budget,
                rule: .majority
            )
            fatalError("Member selected an approval rule.")
        } catch let error as DecisionVotingError {
            precondition(error == .organizerRequired)
        }

        var invalidTrip = trip
        invalidTrip.decisions = [
            GroupDecision(
                title: "Duplicate ballots",
                subject: .budget,
                rule: .majority,
                state: .voting,
                votes: [
                    TripVote(
                        travelerID: members[0].id,
                        choice: .approve
                    ),
                    TripVote(
                        travelerID: members[0].id,
                        choice: .reject
                    )
                ],
                proposedByTravelerID: members[0].id,
                eligibleTravelerIDs: Set(members.map(\.id))
            )
        ]
        precondition(
            invalidTrip.structuralIssues.contains {
                $0.code == .duplicateDecisionVote
            }
        )

        print("Voting thresholds and decision history passed.")
    }

    @MainActor
    private static func decision(
        _ id: UUID,
        in session: TripPlanningSession
    ) -> GroupDecision {
        session.currentTrip!.decisions.first {
            $0.id == id
        }!
    }

    private static func traveler(
        _ name: String,
        _ initials: String,
        role: TravelerRole = .member
    ) -> Traveler {
        Traveler(
            accountIdentifier: "\(name.lowercased())@example.com",
            displayName: name,
            initials: initials,
            role: role
        )
    }
}
