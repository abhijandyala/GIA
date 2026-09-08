#if DEBUG
import Foundation

enum GroupDebugFixtures {
    static func collaborationTrip() -> Trip {
        let request = TripRequest(
            rawTranscript:
                "Plan Lisbon for four friends under six thousand dollars."
        )
        var trip = TimelineDebugFixtures.itineraryTrip(
            preserving: request,
            tripID: UUID(
                uuidString: "47000000-0000-0000-0000-000000000024"
            )!
        )
        let range = trip.request.dateRange!
        let joinedAt = trip.createdAt

        let organizer = Traveler(
            accountIdentifier: "avery@example.com",
            displayName: "Avery",
            initials: "AV",
            role: .organizer,
            preferences: TravelerPreferences(
                interests: [.culture, .food, .museums],
                dietaryRequirements: [.vegetarian],
                preferredPace: .balanced,
                visibility: .tripMembers
            ),
            availability: [
                availability(range, status: .available)
            ],
            personalBudgetLimit: Money(
                amount: 2_000,
                currencyCode: "USD"
            ),
            joinedAt: joinedAt
        )
        let maya = Traveler(
            accountIdentifier: "maya@example.com",
            displayName: "Maya",
            initials: "MK",
            role: .member,
            preferences: TravelerPreferences(
                interests: [.art, .food],
                dietaryRequirements: [.vegan, .glutenFree],
                accessibilityRequirements: [.reducedWalking],
                preferredPace: .relaxed,
                maximumWalkingMinutesPerLeg: 18,
                visibility: .organizers
            ),
            availability: [
                availability(range, status: .available)
            ],
            personalBudgetLimit: Money(
                amount: 1_500,
                currencyCode: "USD"
            ),
            joinedAt: joinedAt.addingTimeInterval(120)
        )
        let noah = Traveler(
            accountIdentifier: "noah@example.com",
            displayName: "Noah",
            initials: "NR",
            role: .member,
            preferences: TravelerPreferences(
                interests: [.nightlife, .technology],
                dietaryRequirements: [.nutFree],
                preferredPace: .active,
                notes: "Keep medical and food notes private.",
                visibility: .privateToTraveler
            ),
            availability: [
                availability(range, status: .available)
            ],
            personalBudgetLimit: Money(
                amount: 1_350,
                currencyCode: "USD"
            ),
            joinedAt: joinedAt.addingTimeInterval(240)
        )
        let sofia = Traveler(
            accountIdentifier: "sofia@example.com",
            displayName: "Sofia",
            initials: "SL",
            role: .member,
            preferences: TravelerPreferences(
                interests: [.beaches, .relaxation, .shopping],
                preferredPace: .balanced,
                visibility: .tripMembers
            ),
            availability: [
                availability(
                    range,
                    status: .tentative,
                    note: "Waiting on school schedule."
                )
            ],
            personalBudgetLimit: Money(
                amount: 1_400,
                currencyCode: "USD"
            ),
            joinedAt: joinedAt.addingTimeInterval(360)
        )
        let members = [organizer, maya, noah, sofia]
        let history = members.map {
            MembershipAuditRecord(
                action: .joined,
                actorTravelerID: $0.id,
                subjectTravelerID: $0.id,
                subjectDisplayName: $0.displayName,
                resultingRole: $0.role,
                occurredAt: $0.joinedAt
            )
        }
        let invitation = TripInvitation(
            inviteeName: "Jordan",
            inviteeEmailAddress: "jordan@example.com",
            invitedByTravelerID: organizer.id,
            invitedAt: joinedAt.addingTimeInterval(480)
        )

        trip.organizerTravelerID = organizer.id
        trip.travelers = members
        trip.collaboration = TripCollaboration(
            invitations: [invitation],
            membershipHistory: history + [
                MembershipAuditRecord(
                    action: .invited,
                    actorTravelerID: organizer.id,
                    subjectDisplayName: invitation.inviteeName,
                    resultingRole: .member,
                    occurredAt: invitation.invitedAt
                )
            ]
        )
        let eligibleIDs = Set(members.map(\.id))
        let destinationID = trip.request.destinations[0].id
        let placeID = trip.catalog.places[0].id
        trip.decisions = [
            GroupDecision(
                title: "Confirm Lisbon as our destination",
                subject: .destination(destinationID),
                rule: .majority,
                state: .approved,
                votes: [
                    vote(organizer, .approve, at: joinedAt),
                    vote(maya, .approve, at: joinedAt),
                    vote(sofia, .approve, at: joinedAt)
                ],
                proposedByTravelerID: organizer.id,
                proposedAt: joinedAt,
                resolvedAt: joinedAt.addingTimeInterval(420),
                eligibleTravelerIDs: eligibleIDs,
                revisionNumber: 1
            ),
            GroupDecision(
                title: "Protect a $500 emergency reserve",
                subject: .budget,
                rule: .majority,
                state: .tied,
                votes: [
                    vote(organizer, .approve, at: joinedAt),
                    vote(maya, .approve, at: joinedAt),
                    vote(noah, .reject, at: joinedAt),
                    vote(sofia, .reject, at: joinedAt)
                ],
                proposedByTravelerID: organizer.id,
                proposedAt: joinedAt.addingTimeInterval(500),
                resolvedAt: joinedAt.addingTimeInterval(900),
                eligibleTravelerIDs: eligibleIDs,
                revisionNumber: 1
            ),
            GroupDecision(
                title: "Add the National Tile Museum",
                subject: .place(placeID),
                rule: .unanimous,
                state: .voting,
                votes: [
                    vote(maya, .approve, at: joinedAt),
                    vote(noah, .approve, at: joinedAt)
                ],
                proposedByTravelerID: organizer.id,
                proposedAt: joinedAt.addingTimeInterval(1_000),
                eligibleTravelerIDs: eligibleIDs,
                revisionNumber: 1
            )
        ]
        let museumItemID = trip.itinerary.days
            .flatMap(\.items)
            .first {
                if case .place = $0.reference {
                    return true
                }
                return false
            }!.id
        trip.communication = TripCommunication(
            messages: [
                TripMessage(
                    authorKind: .system,
                    body: "Avery created the shared Lisbon plan.",
                    systemEvent: .planUpdated,
                    readReceipts: [
                        receipt(organizer, at: joinedAt)
                    ],
                    createdAt: joinedAt
                ),
                TripMessage(
                    authorKind: .gia,
                    body:
                        "I linked the latest schedule, routes, "
                        + "and group decisions.",
                    readReceipts: [
                        receipt(organizer, at: joinedAt)
                    ],
                    createdAt: joinedAt.addingTimeInterval(60)
                ),
                TripMessage(
                    authorKind: .member,
                    authorTravelerID: maya.id,
                    body:
                        "Could we keep the museum entry? "
                        + "The indoor timing works for me.",
                    context: .itineraryItem(museumItemID),
                    mentionedTravelerIDs: [organizer.id],
                    reactions: [
                        MessageReaction(
                            travelerID: noah.id,
                            kind: .approve,
                            createdAt:
                                joinedAt.addingTimeInterval(160)
                        ),
                        MessageReaction(
                            travelerID: sofia.id,
                            kind: .heart,
                            createdAt:
                                joinedAt.addingTimeInterval(180)
                        )
                    ],
                    readReceipts: [
                        receipt(maya, at: joinedAt),
                        receipt(noah, at: joinedAt),
                        receipt(sofia, at: joinedAt)
                    ],
                    createdAt: joinedAt.addingTimeInterval(120)
                ),
                TripMessage(
                    authorKind: .member,
                    authorTravelerID: organizer.id,
                    body:
                        "Yes — I locked it and left enough travel buffer.",
                    context: .itineraryItem(museumItemID),
                    mentionedTravelerIDs: [maya.id],
                    readReceipts: [
                        receipt(organizer, at: joinedAt)
                    ],
                    createdAt: joinedAt.addingTimeInterval(240)
                )
            ]
        )
        return trip
    }

    private static func availability(
        _ range: TripDateRange,
        status: AvailabilityStatus,
        note: String? = nil
    ) -> TravelerAvailability {
        TravelerAvailability(
            range: range,
            status: status,
            note: note
        )
    }

    private static func vote(
        _ traveler: Traveler,
        _ choice: VoteChoice,
        at date: Date
    ) -> TripVote {
        TripVote(
            travelerID: traveler.id,
            choice: choice,
            submittedAt: date
        )
    }

    private static func receipt(
        _ traveler: Traveler,
        at date: Date
    ) -> MessageReadReceipt {
        MessageReadReceipt(
            travelerID: traveler.id,
            readAt: date
        )
    }
}
#endif
