import Foundation

@main
enum GroupWorkspaceVerificationMain {
    @MainActor
    static func main() throws {
        let date = Date(timeIntervalSince1970: 1_812_758_400)
        let range = TripDateRange(
            start: date,
            end: date.addingTimeInterval(604_800),
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let organizer = Traveler(
            accountIdentifier: "organizer@example.com",
            displayName: "Avery",
            initials: "AV",
            role: .organizer,
            preferences: TravelerPreferences(
                interests: [.culture],
                visibility: .tripMembers
            ),
            availability: [
                TravelerAvailability(
                    range: range,
                    status: .available
                )
            ]
        )
        let member = Traveler(
            accountIdentifier: "member@example.com",
            displayName: "Maya",
            initials: "MK",
            role: .member,
            preferences: TravelerPreferences(
                dietaryRequirements: [.vegan],
                accessibilityRequirements: [.reducedWalking],
                visibility: .organizers
            ),
            availability: [
                TravelerAvailability(
                    range: range,
                    status: .tentative
                )
            ],
            personalBudgetLimit: Money(
                amount: 1_500,
                currencyCode: "USD"
            )
        )
        let vote = TripVote(
            travelerID: member.id,
            choice: .approve,
            submittedAt: date
        )
        let request = TripRequest(
            destinations: [
                TravelLocation(
                    name: "Lisbon",
                    city: "Lisbon",
                    country: "Portugal",
                    countryCode: "PT",
                    timeZoneIdentifier: "Europe/Lisbon"
                )
            ],
            dateRange: range,
            travelerCount: 2,
            totalBudget: Money(
                amount: 5_000,
                currencyCode: "USD"
            )
        )
        let trip = Trip(
            title: "Lisbon Together",
            lifecycleState: .ready,
            organizerTravelerID: organizer.id,
            request: request,
            travelers: [organizer, member],
            decisions: [
                GroupDecision(
                    title: "Approve dates",
                    subject: .dateRange,
                    rule: .majority,
                    state: .approved,
                    votes: [vote],
                    proposedByTravelerID: organizer.id,
                    proposedAt: date,
                    resolvedAt: date
                )
            ],
            collaboration: TripCollaboration(),
            createdAt: date,
            updatedAt: date
        )

        let outsiderID = UUID()
        precondition(
            GroupWorkspacePrivacy.canAccessTrip(
                travelerID: organizer.id,
                trip: trip
            )
        )
        precondition(
            !GroupWorkspacePrivacy.canAccessTrip(
                travelerID: outsiderID,
                trip: trip
            )
        )
        precondition(
            GroupWorkspacePrivacy.canViewPreferences(
                of: member,
                viewerID: organizer.id,
                trip: trip
            )
        )
        precondition(
            !GroupWorkspacePrivacy.canViewPreferences(
                of: member,
                viewerID: outsiderID,
                trip: trip
            )
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
        precondition(session.activeTravelerID == organizer.id)
        precondition(session.canAccessGroupWorkspace)

        do {
            _ = try session.inviteTraveler(
                name: "",
                emailAddress: "not-an-email"
            )
            fatalError("Invalid invitation was accepted.")
        } catch let error as GroupWorkspaceError {
            precondition(error == .invalidInvitation)
        }

        let invitation = try session.inviteTraveler(
            name: "Jordan",
            emailAddress: "jordan@example.com"
        )
        do {
            _ = try session.inviteTraveler(
                name: "Jordan",
                emailAddress: "jordan@example.com"
            )
            fatalError("Duplicate invitation was accepted.")
        } catch let error as GroupWorkspaceError {
            precondition(error == .duplicateInvitation)
        }

        let joined = Traveler(
            accountIdentifier: "jordan@example.com",
            displayName: "Jordan",
            initials: "JT",
            role: .organizer,
            preferences: TravelerPreferences(
                interests: [.food],
                visibility: .tripMembers
            )
        )
        try session.acceptInvitation(invitation.id, as: joined)
        precondition(session.activeTravelerID == joined.id)
        precondition(
            session.currentTrip?.travelers.first {
                $0.id == joined.id
            }?.role == .member
        )
        precondition(
            session.currentTrip?.collaboration?.invitations.first {
                $0.id == invitation.id
            }?.status == .accepted
        )

        var joinedPreferences =
            session.activeTraveler!.preferences
        joinedPreferences.visibility = .privateToTraveler
        try session.updateActiveTravelerProfile(
            preferences: joinedPreferences,
            availability: [],
            personalBudgetLimit: Money(
                amount: 1_200,
                currencyCode: "USD"
            )
        )
        precondition(
            session.currentTrip?.collaboration?.membershipHistory
                .contains {
                    $0.action == .preferenceVisibilityChanged
                        && $0.subjectTravelerID == joined.id
                } == true
        )

        do {
            try session.removeTraveler(member.id)
            fatalError("A member removed another traveler.")
        } catch let error as GroupWorkspaceError {
            precondition(error == .organizerRequired)
        }

        try session.setActiveTraveler(organizer.id)
        let voteCount = session.currentTrip?.decisions[0].votes.count
        try session.removeTraveler(member.id)
        precondition(
            session.currentTrip?.travelers.contains {
                $0.id == member.id
            } == false
        )
        precondition(
            session.currentTrip?.decisions[0].votes.count == voteCount
        )
        precondition(
            session.currentTrip?.collaboration?.membershipHistory
                .contains {
                    $0.action == .removed
                        && $0.subjectTravelerID == member.id
                        && $0.subjectDisplayName == "Maya"
                } == true
        )
        do {
            try session.removeTraveler(organizer.id)
            fatalError("The organizer was removed.")
        } catch let error as GroupWorkspaceError {
            precondition(error == .cannotRemoveOrganizer)
        }
        do {
            try session.setActiveTraveler(outsiderID)
            fatalError("An uninvited traveler gained access.")
        } catch let error as GroupWorkspaceError {
            precondition(error == .accessDenied)
        }

        let encoded = try JSONEncoder().encode(trip)
        var legacyObject = try JSONSerialization.jsonObject(
            with: encoded
        ) as! [String: Any]
        legacyObject.removeValue(forKey: "collaboration")
        let legacyData = try JSONSerialization.data(
            withJSONObject: legacyObject
        )
        let legacyTrip = try JSONDecoder().decode(
            Trip.self,
            from: legacyData
        )
        precondition(legacyTrip.collaboration == nil)

        print("Group workspace authorization and privacy passed.")
    }
}
