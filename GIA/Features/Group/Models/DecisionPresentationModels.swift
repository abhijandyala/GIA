import Foundation

struct GroupDecisionPresentation: Identifiable {
    let decision: GroupDecision
    let trip: Trip
    let viewerID: UUID

    var id: UUID { decision.id }

    var tally: DecisionVoteTally {
        GroupDecisionEngine.tally(
            decision: decision,
            trip: trip
        )
    }

    var subjectLabel: String {
        DecisionSubjectResolver.label(
            for: decision.subject,
            in: trip
        )
    }

    var subjectIcon: String {
        DecisionSubjectResolver.icon(for: decision.subject)
    }

    var ruleLabel: String {
        switch decision.rule {
        case .organizer:
            "Organizer decides"
        case .majority:
            "Majority"
        case .unanimous:
            "Unanimous"
        }
    }

    var stateLabel: String {
        switch decision.state {
        case .proposed:
            "Proposed"
        case .voting:
            "Voting"
        case .approved:
            "Approved"
        case .rejected:
            "Rejected"
        case .tied:
            "Tie — resolution needed"
        case .needsRevision:
            "Needs revision"
        }
    }

    var viewerVote: TripVote? {
        decision.votes.first { $0.travelerID == viewerID }
    }

    var canViewerVote: Bool {
        (decision.state == .voting
            || decision.state == .proposed)
            && tally.eligibleTravelerIDs.contains(viewerID)
            && viewerVote == nil
    }

    var canViewerRevise: Bool {
        viewerID == trip.organizerTravelerID
            && (
                decision.state == .tied
                || decision.state == .needsRevision
                || decision.state == .rejected
            )
    }

    var progressDescription: String {
        switch decision.rule {
        case .organizer:
            return viewerVote == nil
                ? "Waiting for organizer"
                : "Organizer ballot recorded"
        case .majority, .unanimous:
            return
                "\(tally.castCount)/"
                + "\(tally.eligibleTravelerIDs.count) voted · "
                + "\(tally.approvalThreshold) approvals needed"
        }
    }

    var revisionLabel: String? {
        let revision = decision.revisionNumber ?? 1
        guard revision > 1 else { return nil }
        return "REVISION \(revision)"
    }

    func voterInitials(for choice: VoteChoice) -> [String] {
        decision.votes
            .filter { $0.choice == choice }
            .compactMap { vote in
                trip.travelers.first {
                    $0.id == vote.travelerID
                }?.initials
            }
    }
}

enum DecisionSubjectResolver {
    static func availableSubjects(
        in trip: Trip
    ) -> [(DecisionSubject, String)] {
        var subjects: [(DecisionSubject, String)] = []
        subjects += trip.request.destinations.map {
            (.destination($0.id), "Destination · \($0.name)")
        }
        if trip.request.dateRange != nil {
            subjects.append((.dateRange, "Trip dates"))
        }
        if
            trip.budget.totalLimit != nil
            || trip.request.totalBudget != nil
        {
            subjects.append((.budget, "Trip budget"))
        }
        subjects += trip.catalog.flightOffers.map {
            let route = FlightOptionPresentation(offer: $0)
            return (
                .flightOffer($0.id),
                "Flight · \(route.originCode) → "
                    + route.destinationCode
            )
        }
        subjects += trip.catalog.hotelOffers.map {
            (.hotelOffer($0.id), "Stay · \($0.name)")
        }
        subjects += trip.catalog.places.map {
            (.place($0.id), "Place · \($0.name)")
        }
        subjects += trip.itinerary.days
            .flatMap(\.items)
            .prefix(20)
            .map {
                (.itineraryItem($0.id), "Plan · \($0.title)")
            }
        return subjects
    }

    static func label(
        for subject: DecisionSubject,
        in trip: Trip
    ) -> String {
        switch subject {
        case .destination(let id):
            return trip.request.destinations.first {
                $0.id == id
            }?.name ?? "Destination"
        case .dateRange:
            return "Trip dates"
        case .flightOffer(let id):
            guard
                let offer = trip.catalog.flightOffers.first(
                    where: { $0.id == id }
                )
            else { return "Flight option" }
            let route = FlightOptionPresentation(offer: offer)
            return "\(route.originCode) → \(route.destinationCode)"
        case .hotelOffer(let id):
            return trip.catalog.hotelOffers.first {
                $0.id == id
            }?.name ?? "Stay option"
        case .place(let id):
            return trip.catalog.places.first {
                $0.id == id
            }?.name ?? "Place option"
        case .itineraryItem(let id):
            return trip.itinerary.days
                .flatMap(\.items)
                .first { $0.id == id }?.title
                ?? "Itinerary item"
        case .budget:
            return "Trip budget"
        }
    }

    static func icon(for subject: DecisionSubject) -> String {
        switch subject {
        case .destination:
            "mappin.and.ellipse"
        case .dateRange:
            "calendar"
        case .flightOffer:
            "airplane"
        case .hotelOffer:
            "bed.double"
        case .place:
            "sparkles"
        case .itineraryItem:
            "list.bullet"
        case .budget:
            "wallet.pass"
        }
    }
}
