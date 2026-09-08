import Foundation

struct DecisionVoteTally: Hashable, Sendable {
    var eligibleTravelerIDs: Set<UUID>
    var approveCount: Int
    var rejectCount: Int
    var abstainCount: Int
    var pendingCount: Int
    var approvalThreshold: Int
    var resultingState: DecisionState

    var castCount: Int {
        approveCount + rejectCount + abstainCount
    }
}

enum GroupDecisionEngine {
    static func tally(
        decision: GroupDecision,
        trip: Trip
    ) -> DecisionVoteTally {
        let activeIDs = Set(trip.travelers.map(\.id))
        var eligibleIDs =
            decision.eligibleTravelerIDs ?? activeIDs
        eligibleIDs.formIntersection(activeIDs)
        if decision.rule == .organizer {
            eligibleIDs = activeIDs.contains(
                trip.organizerTravelerID
            )
                ? [trip.organizerTravelerID]
                : []
        }

        let ballots = decision.votes.filter {
            eligibleIDs.contains($0.travelerID)
        }
        let uniqueBallots = Dictionary(
            ballots.map { ($0.travelerID, $0) },
            uniquingKeysWith: { first, _ in first }
        ).values
        let approveCount = uniqueBallots.count {
            $0.choice == .approve
        }
        let rejectCount = uniqueBallots.count {
            $0.choice == .reject
        }
        let abstainCount = uniqueBallots.count {
            $0.choice == .abstain
        }
        let castCount =
            approveCount + rejectCount + abstainCount
        let pendingCount = max(eligibleIDs.count - castCount, 0)
        let approvalThreshold: Int
        switch decision.rule {
        case .organizer:
            approvalThreshold = eligibleIDs.isEmpty ? 0 : 1
        case .majority:
            approvalThreshold = (eligibleIDs.count / 2) + 1
        case .unanimous:
            approvalThreshold = eligibleIDs.count
        }

        let state = resultingState(
            rule: decision.rule,
            eligibleCount: eligibleIDs.count,
            approveCount: approveCount,
            rejectCount: rejectCount,
            castCount: castCount,
            approvalThreshold: approvalThreshold
        )
        return DecisionVoteTally(
            eligibleTravelerIDs: eligibleIDs,
            approveCount: approveCount,
            rejectCount: rejectCount,
            abstainCount: abstainCount,
            pendingCount: pendingCount,
            approvalThreshold: approvalThreshold,
            resultingState: state
        )
    }

    static func applyingTally(
        to decision: GroupDecision,
        trip: Trip,
        at date: Date
    ) -> GroupDecision {
        var updated = decision
        let tally = tally(decision: decision, trip: trip)
        updated.state = tally.resultingState
        switch tally.resultingState {
        case .approved, .rejected, .tied:
            updated.resolvedAt = date
        case .proposed, .voting, .needsRevision:
            updated.resolvedAt = nil
        }
        return updated
    }

    private static func resultingState(
        rule: DecisionRule,
        eligibleCount: Int,
        approveCount: Int,
        rejectCount: Int,
        castCount: Int,
        approvalThreshold: Int
    ) -> DecisionState {
        guard eligibleCount > 0 else {
            return .needsRevision
        }

        switch rule {
        case .organizer:
            if approveCount == 1 {
                return .approved
            }
            if rejectCount == 1 {
                return .rejected
            }
            return castCount == 1 ? .tied : .voting
        case .majority:
            if approveCount >= approvalThreshold {
                return .approved
            }
            if rejectCount >= approvalThreshold {
                return .rejected
            }
            return castCount == eligibleCount ? .tied : .voting
        case .unanimous:
            if rejectCount > 0 {
                return .rejected
            }
            if approveCount == eligibleCount {
                return .approved
            }
            return castCount == eligibleCount ? .tied : .voting
        }
    }
}
