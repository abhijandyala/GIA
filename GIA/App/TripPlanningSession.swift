import Foundation
import Observation

enum TripPlanningPhase: String, Codable, CaseIterable, Sendable {
    case idle
    case wakePhraseDetected
    case listening
    case transcribing
    case validating
    case needsClarification
    case searching
    case comparing
    case buildingItinerary
    case presenting
    case ready
    case partiallyAvailable
    case failed
    case cancelled
    case returning

    var presentsAssistant: Bool {
        switch self {
        case
            .wakePhraseDetected,
            .listening,
            .transcribing,
            .validating,
            .needsClarification,
            .searching,
            .comparing,
            .buildingItinerary,
            .presenting,
            .partiallyAvailable,
            .failed:
            true
        case .idle, .ready, .cancelled, .returning:
            false
        }
    }

    var isTerminal: Bool {
        switch self {
        case .idle, .ready, .failed, .cancelled:
            true
        default:
            false
        }
    }
}

enum TripActivationSource: String, Codable, Sendable {
    case manual
    case wakePhrase
    case debug
}

enum TripClarificationField: String, Codable, CaseIterable, Sendable {
    case accessibility
    case budget
    case dates
    case destination
    case dietaryRequirements
    case origin
    case preferences
    case travelers
}

struct TripPlanningFailure: Codable, Hashable, Sendable {
    var code: String
    var userMessage: String
    var isRecoverable: Bool
    var occurredAt: Date
}

struct TripPlanningTransitionRecord:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: UUID
    var from: TripPlanningPhase
    var to: TripPlanningPhase
    var occurredAt: Date

    init(
        id: UUID = UUID(),
        from: TripPlanningPhase,
        to: TripPlanningPhase,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.occurredAt = occurredAt
    }
}

enum TripPlanningTransitionError: Error, Equatable {
    case invalidTransition(
        from: TripPlanningPhase,
        to: TripPlanningPhase
    )
    case missingRequest
    case invalidTrip([TripDomainIssue])
}

enum TripSelectionError: Error, Equatable {
    case invalidPhase(TripPlanningPhase)
    case noCurrentTrip
    case unknownFlightOffer(UUID)
    case unknownHotelOffer(UUID)
    case invalidFlightCompletion
}

enum BookingConfirmationError: Error, Equatable {
    case invalidPhase(TripPlanningPhase)
    case noCurrentTrip
    case unknownFlightOffer(UUID)
    case unknownHotelOffer(UUID)
    case missingProviderCheckout
    case providerConfirmedBookingExists
}

enum GroupWorkspaceError: Error, Equatable {
    case invalidPhase(TripPlanningPhase)
    case noCurrentTrip
    case noActiveTraveler
    case accessDenied
    case organizerRequired
    case invalidInvitation
    case duplicateInvitation
    case unknownInvitation(UUID)
    case unknownTraveler(UUID)
    case cannotRemoveOrganizer
}

enum DecisionVotingError: Error, Equatable {
    case invalidPhase(TripPlanningPhase)
    case noCurrentTrip
    case noActiveTraveler
    case accessDenied
    case organizerRequired
    case invalidTitle
    case invalidSubject
    case unknownDecision(UUID)
    case decisionClosed(UUID)
    case ineligibleVoter(UUID)
    case duplicateVote(UUID)
    case revisionNotAllowed(UUID)
}

enum TripCommunicationError: Error, Equatable {
    case invalidPhase(TripPlanningPhase)
    case noCurrentTrip
    case noActiveTraveler
    case accessDenied
    case emptyMessage
    case messageTooLong
    case invalidContext
    case invalidMention(UUID)
    case unknownMessage(UUID)
}

enum TripIntegrationError: Error, Equatable {
    case invalidPhase(TripPlanningPhase)
    case noCurrentTrip
    case noActiveTraveler
    case accessDenied
    case invalidCalendarRecord(UUID)
}

enum ItineraryEditingError: Error, Equatable {
    case invalidPhase(TripPlanningPhase)
    case noCurrentTrip
    case unknownItem(UUID)
    case fixedItem(UUID)
    case lockedItem(UUID)
    case invalidRange
    case outsideTrip
    case missingTargetDay
    case overlap(UUID)
}

@MainActor
@Observable
final class TripPlanningSession {
    private(set) var phase: TripPlanningPhase = .idle
    private(set) var activationSource: TripActivationSource?
    private(set) var currentRequest: TripRequest?
    private(set) var currentTrip: Trip?
    private(set) var activeTravelerID: UUID?
    private(set) var clarificationFields: Set<TripClarificationField> = []
    private(set) var unavailableProviders: Set<TravelProvider> = []
    private(set) var failure: TripPlanningFailure?
    private(set) var progress = TripPlanningProgress()
    private(set) var budgetConflictAnalysis:
        TripBudgetConflictAnalysis?
    private(set) var transitionHistory: [TripPlanningTransitionRecord] = []
    private(set) var revision = 0

    var isAssistantPresented: Bool {
        phase.presentsAssistant
    }

    var isReturning: Bool {
        phase == .returning
    }

    var activeTraveler: Traveler? {
        guard
            let activeTravelerID,
            let currentTrip
        else {
            return nil
        }
        return currentTrip.travelers.first {
            $0.id == activeTravelerID
        }
    }

    var canAccessGroupWorkspace: Bool {
        guard
            let activeTravelerID,
            let currentTrip
        else {
            return false
        }
        return GroupWorkspacePrivacy.canAccessTrip(
            travelerID: activeTravelerID,
            trip: currentTrip
        )
    }

    func registerWakePhrase() throws {
        try validateTransition(to: .wakePhraseDetected)
        activationSource = .wakePhrase
        commitTransition(to: .wakePhraseDetected)
    }

    func beginListening(
        source: TripActivationSource? = nil
    ) throws {
        try validateTransition(to: .listening)
        if let source {
            activationSource = source
        }
        failure = nil
        clarificationFields = []
        commitTransition(to: .listening)
    }

    func beginTranscribing() throws {
        try transition(to: .transcribing)
    }

    func resumeAfterFollowUp(
        returningTo returnPhase: TripPlanningPhase
    ) throws {
        guard
            phase == .listening || phase == .transcribing,
            currentRequest != nil,
            returnPhase == .ready
                || returnPhase == .partiallyAvailable
        else {
            throw TripPlanningTransitionError.invalidTransition(
                from: phase,
                to: returnPhase
            )
        }
        failure = nil
        clarificationFields = []
        commitTransition(to: returnPhase)
    }

    func beginValidation(
        request: TripRequest
    ) throws {
        try validateTransition(to: .validating)
        progress = TripPlanningProgress()
        progress.begin(
            .understanding,
            message: "Interpreting the travel request"
        )
        currentRequest = request
        clarificationFields = []
        commitTransition(to: .validating)
    }

    func requestClarification(
        for fields: Set<TripClarificationField>
    ) throws {
        try validateTransition(to: .needsClarification)
        progress.waitForInput(
            .understanding,
            message: "Waiting for required trip details"
        )
        clarificationFields = fields
        commitTransition(to: .needsClarification)
    }

    func replaceRequestDuringValidation(
        _ request: TripRequest
    ) throws {
        switch phase {
        case .needsClarification:
            try validateTransition(to: .validating)
            progress.begin(
                .understanding,
                message: "Revalidating corrected details"
            )
            currentRequest = request
            clarificationFields = []
            commitTransition(to: .validating)
        case .validating:
            currentRequest = request
            clarificationFields = []
            progress.begin(
                .understanding,
                message: "Revalidating corrected details"
            )
            revision &+= 1
        default:
            throw TripPlanningTransitionError.invalidTransition(
                from: phase,
                to: .validating
            )
        }
    }

    func mergeLiveRequest(_ request: TripRequest) {
        guard currentRequest != nil else {
            return
        }
        currentRequest = request
    }

    func beginSearch() throws {
        guard currentRequest != nil else {
            throw TripPlanningTransitionError.missingRequest
        }

        try validateTransition(to: .searching)
        progress.complete(
            .understanding,
            message: "Request validated"
        )
        if progress.item(for: .destination).status != .unavailable {
            progress.complete(
                .destination,
                resultCount: currentRequest?.destinations.count,
                message: "Destination resolved"
            )
        }
        unavailableProviders = []
        commitTransition(to: .searching)
    }

    func beginComparison() throws {
        try transition(to: .comparing)
    }

    func beginItineraryBuild() throws {
        try transition(to: .buildingItinerary)
    }

    func beginPresentation() throws {
        try transition(to: .presenting)
    }

    func beginWorkstream(
        _ workstream: PlanningWorkstream,
        providers: Set<TravelProvider> = [],
        message: String? = nil
    ) throws {
        try validateProgressMutation(for: workstream)
        progress.begin(
            workstream,
            providers: providers,
            message: message
        )
        revision &+= 1
    }

    func completeWorkstream(
        _ workstream: PlanningWorkstream,
        resultCount: Int? = nil,
        providers: Set<TravelProvider> = [],
        message: String? = nil
    ) throws {
        if let resultCount, resultCount < 0 {
            throw TripPlanningProgressError.invalidResultCount(
                resultCount
            )
        }

        try validateProgressMutation(for: workstream)
        progress.complete(
            workstream,
            resultCount: resultCount,
            providers: providers,
            message: message
        )
        revision &+= 1
    }

    func markWorkstreamUnavailable(
        _ workstream: PlanningWorkstream,
        providers: Set<TravelProvider> = [],
        message: String
    ) throws {
        try validateProgressMutation(for: workstream)
        progress.markUnavailable(
            workstream,
            providers: providers,
            message: message
        )
        revision &+= 1
    }

    func markPartiallyAvailable(
        unavailableProviders: Set<TravelProvider>
    ) throws {
        try validateTransition(to: .partiallyAvailable)
        self.unavailableProviders = unavailableProviders
        commitTransition(to: .partiallyAvailable)
    }

    func complete(with trip: Trip) throws {
        let issues = trip.structuralIssues
        guard issues.isEmpty else {
            throw TripPlanningTransitionError.invalidTrip(issues)
        }

        try validateTransition(to: .ready)
        currentTrip = trip
        if
            activeTravelerID == nil
            || !GroupWorkspacePrivacy.canAccessTrip(
                travelerID: activeTravelerID!,
                trip: trip
            )
        {
            activeTravelerID = trip.organizerTravelerID
        }
        budgetConflictAnalysis = TripBudgetConflictEngine.analyze(
            trip: trip
        )
        synchronizeProgress(with: trip)
        unavailableProviders = []
        failure = nil
        commitTransition(to: .ready)
    }

    func selectFlightOffer(_ offerID: UUID) throws {
        guard phase == .ready || phase == .partiallyAvailable else {
            throw TripSelectionError.invalidPhase(phase)
        }
        guard var trip = currentTrip else {
            throw TripSelectionError.noCurrentTrip
        }
        guard
            trip.catalog.flightOffers.contains(
                where: { $0.id == offerID }
            )
        else {
            throw TripSelectionError.unknownFlightOffer(offerID)
        }

        trip.selections.flightOfferIDs = [offerID]
        trip.updatedAt = Date()
        storeUpdatedTrip(trip)
    }

    @discardableResult
    func replaceOutboundFlightOffer(
        _ outboundOfferID: UUID,
        with completedOffers: [FlightOffer]
    ) throws -> UUID {
        guard phase == .ready || phase == .partiallyAvailable else {
            throw TripSelectionError.invalidPhase(phase)
        }
        guard var trip = currentTrip else {
            throw TripSelectionError.noCurrentTrip
        }
        guard
            let index = trip.catalog.flightOffers.firstIndex(
                where: { $0.id == outboundOfferID }
            )
        else {
            throw TripSelectionError.unknownFlightOffer(
                outboundOfferID
            )
        }
        let completedIDs = completedOffers.map(\.id)
        let existingIDs = Set(
            trip.catalog.flightOffers
                .filter { $0.id != outboundOfferID }
                .map(\.id)
        )
        let completedIDsAreUnique =
            Set(completedIDs).count == completedIDs.count
        let completedIDsAreNew = completedIDs.allSatisfy {
            !existingIDs.contains($0)
        }
        let offersAreComplete = completedOffers.allSatisfy {
            !$0.outboundSegments.isEmpty
                && !$0.returnSegments.isEmpty
                && $0.continuationToken == nil
                && $0.provenance.provider == .serpApi
        }
        guard
            !completedOffers.isEmpty,
            completedIDsAreUnique,
            completedIDsAreNew,
            offersAreComplete
        else {
            throw TripSelectionError.invalidFlightCompletion
        }

        trip.catalog.flightOffers.remove(at: index)
        trip.catalog.flightOffers.insert(
            contentsOf: completedOffers,
            at: index
        )
        let selectedID = completedOffers[0].id
        trip.selections.flightOfferIDs = [selectedID]
        trip.updatedAt = Date()
        storeUpdatedTrip(trip)
        return selectedID
    }

    func selectHotelOffer(_ offerID: UUID) throws {
        guard phase == .ready || phase == .partiallyAvailable else {
            throw TripSelectionError.invalidPhase(phase)
        }
        guard var trip = currentTrip else {
            throw TripSelectionError.noCurrentTrip
        }
        guard
            trip.catalog.hotelOffers.contains(
                where: { $0.id == offerID }
            )
        else {
            throw TripSelectionError.unknownHotelOffer(offerID)
        }

        trip.selections.hotelOfferIDs = [offerID]
        trip.updatedAt = Date()
        storeUpdatedTrip(trip)
    }

    @discardableResult
    func confirmFlightOffer(
        _ offerID: UUID,
        mode: BookingConfirmationMode
    ) throws -> BookingRecord {
        try validateBookingPhase()
        guard var trip = currentTrip else {
            throw BookingConfirmationError.noCurrentTrip
        }
        guard
            let offer = trip.catalog.flightOffers.first(
                where: { $0.id == offerID }
            )
        else {
            throw BookingConfirmationError.unknownFlightOffer(
                offerID
            )
        }
        if
            let confirmed = trip.bookings.first(
                where: {
                    $0.category == .flight
                        && $0.itemIdentifier == offerID
                        && $0.status == .confirmed
                }
            )
        {
            return confirmed
        }
        if mode == .externalProvider, offer.bookingURL == nil {
            throw BookingConfirmationError.missingProviderCheckout
        }
        guard
            !trip.bookings.contains(
                where: {
                    $0.category == .flight
                        && $0.status == .confirmed
                        && $0.itemIdentifier != offerID
                }
            )
        else {
            throw BookingConfirmationError
                .providerConfirmedBookingExists
        }

        let now = Date()
        trip.selections.flightOfferIDs = [offerID]
        retireUnfinishedBookings(
            in: &trip,
            category: .flight,
            except: offerID,
            at: now
        )
        replaceFlightItineraryItems(
            in: &trip,
            with: offer,
            mode: mode
        )
        let record = upsertBooking(
            in: &trip,
            category: .flight,
            itemIdentifier: offerID,
            amount: offer.totalPrice,
            checkoutURL: offer.bookingURL,
            source: offer.provenance,
            mode: mode,
            at: now
        )
        let actorName = activeTravelerName(in: trip)
        appendSystemMessage(
            to: &trip,
            body:
                "\(actorName) "
                + (
                    mode == .fblaDemo
                    ? "created a demo flight confirmation."
                    : "continued a flight selection to provider checkout."
                ),
            event: .bookingSelectionChanged,
            at: now
        )
        trip.updatedAt = now
        storeUpdatedTrip(trip)
        return record
    }

    @discardableResult
    func confirmHotelOffer(
        _ offerID: UUID,
        mode: BookingConfirmationMode
    ) throws -> BookingRecord {
        try validateBookingPhase()
        guard var trip = currentTrip else {
            throw BookingConfirmationError.noCurrentTrip
        }
        guard
            let offer = trip.catalog.hotelOffers.first(
                where: { $0.id == offerID }
            )
        else {
            throw BookingConfirmationError.unknownHotelOffer(
                offerID
            )
        }
        if
            let confirmed = trip.bookings.first(
                where: {
                    $0.category == .hotel
                        && $0.itemIdentifier == offerID
                        && $0.status == .confirmed
                }
            )
        {
            return confirmed
        }
        if mode == .externalProvider, offer.bookingURL == nil {
            throw BookingConfirmationError.missingProviderCheckout
        }
        guard
            !trip.bookings.contains(
                where: {
                    $0.category == .hotel
                        && $0.status == .confirmed
                        && $0.itemIdentifier != offerID
                }
            )
        else {
            throw BookingConfirmationError
                .providerConfirmedBookingExists
        }

        let now = Date()
        trip.selections.hotelOfferIDs = [offerID]
        retireUnfinishedBookings(
            in: &trip,
            category: .hotel,
            except: offerID,
            at: now
        )
        replaceHotelItineraryItems(
            in: &trip,
            with: offer,
            mode: mode
        )
        let record = upsertBooking(
            in: &trip,
            category: .hotel,
            itemIdentifier: offerID,
            amount: offer.totalPrice,
            checkoutURL: offer.bookingURL,
            source: offer.provenance,
            mode: mode,
            at: now
        )
        let actorName = activeTravelerName(in: trip)
        appendSystemMessage(
            to: &trip,
            body:
                "\(actorName) "
                + (
                    mode == .fblaDemo
                    ? "created a demo stay confirmation."
                    : "continued a stay selection to provider checkout."
                ),
            event: .bookingSelectionChanged,
            at: now
        )
        trip.updatedAt = now
        storeUpdatedTrip(trip)
        return record
    }

    func setActiveTraveler(_ travelerID: UUID) throws {
        guard let trip = currentTrip else {
            throw GroupWorkspaceError.noCurrentTrip
        }
        guard
            GroupWorkspacePrivacy.canAccessTrip(
                travelerID: travelerID,
                trip: trip
            )
        else {
            throw GroupWorkspaceError.accessDenied
        }
        activeTravelerID = travelerID
        revision &+= 1
    }

    @discardableResult
    func inviteTraveler(
        name: String,
        emailAddress: String
    ) throws -> TripInvitation {
        try validateGroupWorkspacePhase()
        guard var trip = currentTrip else {
            throw GroupWorkspaceError.noCurrentTrip
        }
        let actorID = try authorizedActiveTravelerID(in: trip)
        guard
            GroupWorkspacePrivacy.canManageMembers(
                travelerID: actorID,
                trip: trip
            )
        else {
            throw GroupWorkspaceError.organizerRequired
        }

        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalizedEmail = emailAddress
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard
            !trimmedName.isEmpty,
            Self.isValidEmailAddress(normalizedEmail)
        else {
            throw GroupWorkspaceError.invalidInvitation
        }
        let collaboration =
            trip.collaboration ?? TripCollaboration()
        guard
            !collaboration.invitations.contains(
                where: {
                    $0.inviteeEmailAddress == normalizedEmail
                        && $0.status == .pending
                }
            ),
            !trip.travelers.contains(
                where: {
                    $0.accountIdentifier?.lowercased()
                        == normalizedEmail
                }
            )
        else {
            throw GroupWorkspaceError.duplicateInvitation
        }

        let now = Date()
        let invitation = TripInvitation(
            inviteeName: trimmedName,
            inviteeEmailAddress: normalizedEmail,
            role: .member,
            invitedByTravelerID: actorID,
            invitedAt: now
        )
        var updatedCollaboration = collaboration
        updatedCollaboration.invitations.append(invitation)
        updatedCollaboration.membershipHistory.append(
            MembershipAuditRecord(
                action: .invited,
                actorTravelerID: actorID,
                subjectDisplayName: trimmedName,
                resultingRole: .member,
                occurredAt: now
            )
        )
        trip.collaboration = updatedCollaboration
        let actorName = activeTravelerName(in: trip)
        appendSystemMessage(
            to: &trip,
            body:
                "\(actorName) invited "
                + "\(trimmedName) to the trip.",
            event: .memberInvited,
            at: now
        )
        trip.updatedAt = now
        storeUpdatedTrip(trip)
        return invitation
    }

    func revokeInvitation(_ invitationID: UUID) throws {
        try validateGroupWorkspacePhase()
        guard var trip = currentTrip else {
            throw GroupWorkspaceError.noCurrentTrip
        }
        let actorID = try authorizedActiveTravelerID(in: trip)
        guard
            GroupWorkspacePrivacy.canManageMembers(
                travelerID: actorID,
                trip: trip
            )
        else {
            throw GroupWorkspaceError.organizerRequired
        }
        guard
            var collaboration = trip.collaboration,
            let index = collaboration.invitations.firstIndex(
                where: { $0.id == invitationID }
            )
        else {
            throw GroupWorkspaceError.unknownInvitation(
                invitationID
            )
        }
        guard collaboration.invitations[index].status == .pending else {
            throw GroupWorkspaceError.invalidInvitation
        }
        collaboration.invitations[index].status = .revoked
        collaboration.invitations[index].respondedAt = Date()
        trip.collaboration = collaboration
        trip.updatedAt = Date()
        storeUpdatedTrip(trip)
    }

    func acceptInvitation(
        _ invitationID: UUID,
        as traveler: Traveler
    ) throws {
        try validateGroupWorkspacePhase()
        guard var trip = currentTrip else {
            throw GroupWorkspaceError.noCurrentTrip
        }
        guard
            var collaboration = trip.collaboration,
            let index = collaboration.invitations.firstIndex(
                where: { $0.id == invitationID }
            )
        else {
            throw GroupWorkspaceError.unknownInvitation(
                invitationID
            )
        }
        let invitation = collaboration.invitations[index]
        guard
            invitation.status == .pending,
            !trip.travelers.contains(where: { $0.id == traveler.id }),
            traveler.accountIdentifier?.lowercased()
                == invitation.inviteeEmailAddress
        else {
            throw GroupWorkspaceError.invalidInvitation
        }

        let now = Date()
        var joinedTraveler = traveler
        joinedTraveler.role = .member
        joinedTraveler.joinedAt = now
        trip.travelers.append(joinedTraveler)
        collaboration.invitations[index].status = .accepted
        collaboration.invitations[index].respondedAt = now
        collaboration.invitations[index].acceptedTravelerID =
            joinedTraveler.id
        collaboration.membershipHistory.append(
            MembershipAuditRecord(
                action: .joined,
                actorTravelerID: joinedTraveler.id,
                subjectTravelerID: joinedTraveler.id,
                subjectDisplayName: joinedTraveler.displayName,
                resultingRole: .member,
                occurredAt: now
            )
        )
        trip.collaboration = collaboration
        appendSystemMessage(
            to: &trip,
            body:
                "\(joinedTraveler.displayName) joined the trip.",
            event: .memberJoined,
            at: now
        )
        trip.updatedAt = now
        activeTravelerID = joinedTraveler.id
        storeUpdatedTrip(trip)
    }

    func updateActiveTravelerProfile(
        preferences: TravelerPreferences,
        availability: [TravelerAvailability],
        personalBudgetLimit: Money?
    ) throws {
        try validateGroupWorkspacePhase()
        guard var trip = currentTrip else {
            throw GroupWorkspaceError.noCurrentTrip
        }
        let actorID = try authorizedActiveTravelerID(in: trip)
        guard
            let index = trip.travelers.firstIndex(
                where: { $0.id == actorID }
            )
        else {
            throw GroupWorkspaceError.unknownTraveler(actorID)
        }
        let previousVisibility =
            trip.travelers[index].preferences.visibility
        trip.travelers[index].preferences = preferences
        trip.travelers[index].availability = availability
        trip.travelers[index].personalBudgetLimit =
            personalBudgetLimit
        let now = Date()
        if previousVisibility != preferences.visibility {
            var collaboration =
                trip.collaboration ?? TripCollaboration()
            collaboration.membershipHistory.append(
                MembershipAuditRecord(
                    action: .preferenceVisibilityChanged,
                    actorTravelerID: actorID,
                    subjectTravelerID: actorID,
                    subjectDisplayName:
                        trip.travelers[index].displayName,
                    occurredAt: now,
                    note: preferences.visibility.rawValue
                )
            )
            trip.collaboration = collaboration
        }
        trip.updatedAt = now
        storeUpdatedTrip(trip)
    }

    func removeTraveler(_ travelerID: UUID) throws {
        try validateGroupWorkspacePhase()
        guard var trip = currentTrip else {
            throw GroupWorkspaceError.noCurrentTrip
        }
        let actorID = try authorizedActiveTravelerID(in: trip)
        guard
            GroupWorkspacePrivacy.canManageMembers(
                travelerID: actorID,
                trip: trip
            )
        else {
            throw GroupWorkspaceError.organizerRequired
        }
        guard travelerID != trip.organizerTravelerID else {
            throw GroupWorkspaceError.cannotRemoveOrganizer
        }
        guard
            let index = trip.travelers.firstIndex(
                where: { $0.id == travelerID }
            )
        else {
            throw GroupWorkspaceError.unknownTraveler(travelerID)
        }

        let removed = trip.travelers.remove(at: index)
        let now = Date()
        var collaboration =
            trip.collaboration ?? TripCollaboration()
        collaboration.membershipHistory.append(
            MembershipAuditRecord(
                action: .removed,
                actorTravelerID: actorID,
                subjectTravelerID: removed.id,
                subjectDisplayName: removed.displayName,
                previousRole: removed.role,
                occurredAt: now,
                note: "Membership removed; decision history retained."
            )
        )
        trip.collaboration = collaboration
        let actorName = activeTravelerName(in: trip)
        appendSystemMessage(
            to: &trip,
            body:
                "\(actorName) removed "
                + "\(removed.displayName) from the trip.",
            event: .memberRemoved,
            at: now
        )
        trip.updatedAt = now
        storeUpdatedTrip(trip)
    }

    @discardableResult
    func proposeDecision(
        title: String,
        subject: DecisionSubject,
        rule: DecisionRule
    ) throws -> GroupDecision {
        try validateDecisionPhase()
        guard var trip = currentTrip else {
            throw DecisionVotingError.noCurrentTrip
        }
        let actorID = try decisionActorID(in: trip)
        guard actorID == trip.organizerTravelerID else {
            throw DecisionVotingError.organizerRequired
        }
        let trimmedTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedTitle.isEmpty, trimmedTitle.count <= 120 else {
            throw DecisionVotingError.invalidTitle
        }
        guard Self.isValidDecisionSubject(subject, in: trip) else {
            throw DecisionVotingError.invalidSubject
        }

        let decision = GroupDecision(
            title: trimmedTitle,
            subject: subject,
            rule: rule,
            state: .voting,
            proposedByTravelerID: actorID,
            proposedAt: Date(),
            eligibleTravelerIDs: Set(
                trip.travelers.map(\.id)
            ),
            revisionNumber: 1
        )
        trip.decisions.append(decision)
        let actorName = activeTravelerName(in: trip)
        appendSystemMessage(
            to: &trip,
            body:
                "\(actorName) opened voting: "
                + trimmedTitle,
            event: .decisionOpened,
            context: .decision(decision.id),
            at: Date()
        )
        trip.updatedAt = Date()
        storeUpdatedTrip(trip)
        return decision
    }

    func castVote(
        on decisionID: UUID,
        choice: VoteChoice,
        comment: String? = nil
    ) throws {
        try validateDecisionPhase()
        guard var trip = currentTrip else {
            throw DecisionVotingError.noCurrentTrip
        }
        let actorID = try decisionActorID(in: trip)
        guard
            let index = trip.decisions.firstIndex(
                where: { $0.id == decisionID }
            )
        else {
            throw DecisionVotingError.unknownDecision(decisionID)
        }
        guard
            trip.decisions[index].state == .voting
            || trip.decisions[index].state == .proposed
        else {
            throw DecisionVotingError.decisionClosed(decisionID)
        }

        let tally = GroupDecisionEngine.tally(
            decision: trip.decisions[index],
            trip: trip
        )
        guard tally.eligibleTravelerIDs.contains(actorID) else {
            throw DecisionVotingError.ineligibleVoter(actorID)
        }
        guard
            !trip.decisions[index].votes.contains(
                where: { $0.travelerID == actorID }
            )
        else {
            throw DecisionVotingError.duplicateVote(actorID)
        }

        let cleanedComment = comment?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        trip.decisions[index].votes.append(
            TripVote(
                travelerID: actorID,
                choice: choice,
                comment:
                    cleanedComment?.isEmpty == false
                    ? String(cleanedComment!.prefix(280))
                    : nil,
                submittedAt: Date()
            )
        )
        let previousState = trip.decisions[index].state
        trip.decisions[index] = GroupDecisionEngine.applyingTally(
            to: trip.decisions[index],
            trip: trip,
            at: Date()
        )
        let resultingState = trip.decisions[index].state
        if resultingState != previousState,
           resultingState != .voting,
           resultingState != .proposed {
            appendSystemMessage(
                to: &trip,
                body:
                    "Voting closed for "
                    + "\(trip.decisions[index].title): "
                    + resultingState.rawValue + ".",
                event: .decisionResolved,
                context: .decision(decisionID),
                at: Date()
            )
        }
        trip.updatedAt = Date()
        storeUpdatedTrip(trip)
    }

    @discardableResult
    func reviseDecision(
        _ decisionID: UUID,
        title: String? = nil,
        rule: DecisionRule? = nil
    ) throws -> GroupDecision {
        try validateDecisionPhase()
        guard var trip = currentTrip else {
            throw DecisionVotingError.noCurrentTrip
        }
        let actorID = try decisionActorID(in: trip)
        guard actorID == trip.organizerTravelerID else {
            throw DecisionVotingError.organizerRequired
        }
        guard
            let original = trip.decisions.first(
                where: { $0.id == decisionID }
            )
        else {
            throw DecisionVotingError.unknownDecision(decisionID)
        }
        guard
            original.state == .tied
            || original.state == .needsRevision
            || original.state == .rejected
        else {
            throw DecisionVotingError.revisionNotAllowed(
                decisionID
            )
        }
        let revision = (original.revisionNumber ?? 1) + 1
        let revisedTitle = title?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle =
            revisedTitle?.isEmpty == false
            ? revisedTitle!
            : "\(original.title) · Revision \(revision)"

        let replacement = GroupDecision(
            title: finalTitle,
            subject: original.subject,
            rule: rule ?? original.rule,
            state: .voting,
            proposedByTravelerID: actorID,
            proposedAt: Date(),
            eligibleTravelerIDs: Set(
                trip.travelers.map(\.id)
            ),
            supersedesDecisionID: original.id,
            revisionNumber: revision
        )
        trip.decisions.append(replacement)
        let actorName = activeTravelerName(in: trip)
        appendSystemMessage(
            to: &trip,
            body:
                "\(actorName) opened revision "
                + "\(revision) for \(original.title).",
            event: .decisionOpened,
            context: .decision(replacement.id),
            at: Date()
        )
        trip.updatedAt = Date()
        storeUpdatedTrip(trip)
        return replacement
    }

    @discardableResult
    func sendMessage(
        _ body: String,
        context: TripMessageContext = .trip,
        mentionedTravelerIDs: Set<UUID> = []
    ) throws -> TripMessage {
        try validateCommunicationPhase()
        guard var trip = currentTrip else {
            throw TripCommunicationError.noCurrentTrip
        }
        let actorID = try communicationActorID(in: trip)
        let trimmed = body.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else {
            throw TripCommunicationError.emptyMessage
        }
        guard trimmed.count <= 2_000 else {
            throw TripCommunicationError.messageTooLong
        }
        guard Self.isValidMessageContext(context, in: trip) else {
            throw TripCommunicationError.invalidContext
        }
        let memberIDs = Set(trip.travelers.map(\.id))
        if
            let invalidMention = mentionedTravelerIDs.first(
                where: { !memberIDs.contains($0) }
            )
        {
            throw TripCommunicationError.invalidMention(
                invalidMention
            )
        }

        let now = Date()
        let message = TripMessage(
            authorKind: .member,
            authorTravelerID: actorID,
            body: trimmed,
            context: context,
            mentionedTravelerIDs:
                mentionedTravelerIDs.subtracting(Set([actorID])),
            readReceipts: [
                MessageReadReceipt(
                    travelerID: actorID,
                    readAt: now
                )
            ],
            createdAt: now
        )
        var communication =
            trip.communication ?? TripCommunication()
        communication.messages.append(message)
        trip.communication = communication
        trip.updatedAt = now
        storeUpdatedTrip(trip)
        return message
    }

    func toggleReaction(
        on messageID: UUID,
        kind: MessageReactionKind
    ) throws {
        try validateCommunicationPhase()
        guard var trip = currentTrip else {
            throw TripCommunicationError.noCurrentTrip
        }
        let actorID = try communicationActorID(in: trip)
        guard
            var communication = trip.communication,
            let index = communication.messages.firstIndex(
                where: { $0.id == messageID }
            )
        else {
            throw TripCommunicationError.unknownMessage(messageID)
        }

        if
            let reactionIndex =
                communication.messages[index].reactions.firstIndex(
                    where: {
                        $0.travelerID == actorID
                            && $0.kind == kind
                    }
                )
        {
            communication.messages[index].reactions.remove(
                at: reactionIndex
            )
        } else {
            communication.messages[index].reactions.append(
                MessageReaction(
                    travelerID: actorID,
                    kind: kind
                )
            )
        }
        trip.communication = communication
        trip.updatedAt = Date()
        storeUpdatedTrip(trip)
    }

    func markMessagesRead(
        context: TripMessageContext? = nil
    ) throws {
        try validateCommunicationPhase()
        guard var trip = currentTrip else {
            throw TripCommunicationError.noCurrentTrip
        }
        let actorID = try communicationActorID(in: trip)
        guard var communication = trip.communication else {
            return
        }
        let now = Date()
        var changed = false
        for index in communication.messages.indices
        where
            context == nil
            || communication.messages[index].context == context
        {
            if
                !communication.messages[index].readReceipts.contains(
                    where: { $0.travelerID == actorID }
                )
            {
                communication.messages[index].readReceipts.append(
                    MessageReadReceipt(
                        travelerID: actorID,
                        readAt: now
                    )
                )
                changed = true
            }
        }
        guard changed else { return }
        trip.communication = communication
        storeUpdatedTrip(trip)
    }

    @discardableResult
    func postGIAMessage(
        _ body: String,
        context: TripMessageContext = .trip
    ) throws -> TripMessage {
        try validateCommunicationPhase()
        guard var trip = currentTrip else {
            throw TripCommunicationError.noCurrentTrip
        }
        guard Self.isValidMessageContext(context, in: trip) else {
            throw TripCommunicationError.invalidContext
        }
        let trimmed = body.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else {
            throw TripCommunicationError.emptyMessage
        }
        guard trimmed.count <= 2_000 else {
            throw TripCommunicationError.messageTooLong
        }
        let message = TripMessage(
            authorKind: .gia,
            body: trimmed,
            context: context
        )
        var communication =
            trip.communication ?? TripCommunication()
        communication.messages.append(message)
        trip.communication = communication
        trip.updatedAt = Date()
        storeUpdatedTrip(trip)
        return message
    }

    func updateNotificationSettings(
        isEnabled: Bool,
        enabledKinds: Set<TripReminderKind> =
            Set(TripReminderKind.allCases)
    ) throws {
        try validateIntegrationPhase()
        guard var trip = currentTrip else {
            throw TripIntegrationError.noCurrentTrip
        }
        let actorID = try integrationActorID(in: trip)
        var integrations =
            trip.integrations ?? TripIntegrations()
        integrations.notificationSettings =
            TripNotificationSettings(
                isEnabled: isEnabled,
                enabledKinds: enabledKinds,
                ownerTravelerID: actorID,
                updatedAt: Date()
            )
        trip.integrations = integrations
        trip.updatedAt = Date()
        storeUpdatedTrip(trip)
    }

    func recordCalendarExports(
        _ records: [CalendarExportRecord]
    ) throws {
        try validateIntegrationPhase()
        guard var trip = currentTrip else {
            throw TripIntegrationError.noCurrentTrip
        }
        _ = try integrationActorID(in: trip)
        let itemIDs = Set(
            trip.itinerary.days.flatMap(\.items).map(\.id)
        )
        if
            let invalid = records.first(
                where: { !itemIDs.contains($0.itineraryItemID) }
            )
        {
            throw TripIntegrationError.invalidCalendarRecord(
                invalid.itineraryItemID
            )
        }
        var integrations =
            trip.integrations ?? TripIntegrations()
        var exports = Dictionary(
            uniqueKeysWithValues:
                integrations.calendarExports.map {
                    ($0.itineraryItemID, $0)
                }
        )
        for record in records {
            exports[record.itineraryItemID] = record
        }
        integrations.calendarExports = exports.values.sorted {
            $0.exportedStart < $1.exportedStart
        }
        trip.integrations = integrations
        trip.updatedAt = Date()
        storeUpdatedTrip(trip)
    }

    func moveItineraryItem(
        _ itemID: UUID,
        toStart start: Date,
        end: Date
    ) throws {
        guard phase == .ready || phase == .partiallyAvailable else {
            throw ItineraryEditingError.invalidPhase(phase)
        }
        guard var trip = currentTrip else {
            throw ItineraryEditingError.noCurrentTrip
        }
        guard
            let item = trip.itinerary.days
                .flatMap(\.items)
                .first(where: { $0.id == itemID })
        else {
            throw ItineraryEditingError.unknownItem(itemID)
        }
        switch item.flexibility {
        case .fixed:
            throw ItineraryEditingError.fixedItem(itemID)
        case .lockedByUser:
            throw ItineraryEditingError.lockedItem(itemID)
        case .flexible:
            break
        }
        guard start < end else {
            throw ItineraryEditingError.invalidRange
        }
        if
            let range = trip.request.dateRange,
            (
                start < range.start
                || end > range.end.addingTimeInterval(86_400)
            )
        {
            throw ItineraryEditingError.outsideTrip
        }

        guard
            let targetDayIndex = trip.itinerary.days.firstIndex(
                where: {
                    Self.isSameCalendarDay(
                        start,
                        as: $0.date,
                        timeZoneIdentifier: $0.timeZoneIdentifier
                    )
                }
            )
        else {
            throw ItineraryEditingError.missingTargetDay
        }

        if
            let overlap = trip.itinerary.days[targetDayIndex]
                .items
                .first(where: {
                    $0.id != itemID
                        && start < $0.end
                        && end > $0.start
                })
        {
            throw ItineraryEditingError.overlap(overlap.id)
        }

        for dayIndex in trip.itinerary.days.indices {
            trip.itinerary.days[dayIndex].items.removeAll {
                $0.id == itemID
            }
        }
        var updatedItem = item
        updatedItem.start = start
        updatedItem.end = end
        trip.itinerary.days[targetDayIndex].items.append(updatedItem)
        trip.itinerary.days[targetDayIndex].items.sort {
            $0.start < $1.start
        }
        trip.updatedAt = Date()
        let actorName = activeTravelerName(in: trip)
        let updatedAt = trip.updatedAt
        appendSystemMessage(
            to: &trip,
            body:
                "\(actorName) moved "
                + "\(updatedItem.title) in the shared plan.",
            event: .itineraryChanged,
            context: .itineraryItem(updatedItem.id),
            at: updatedAt
        )
        storeUpdatedTrip(trip)
    }

    func toggleItineraryItemLock(_ itemID: UUID) throws {
        guard phase == .ready || phase == .partiallyAvailable else {
            throw ItineraryEditingError.invalidPhase(phase)
        }
        guard var trip = currentTrip else {
            throw ItineraryEditingError.noCurrentTrip
        }

        for dayIndex in trip.itinerary.days.indices {
            guard
                let itemIndex = trip.itinerary.days[dayIndex]
                    .items
                    .firstIndex(where: { $0.id == itemID })
            else {
                continue
            }

            switch trip.itinerary.days[dayIndex]
                .items[itemIndex]
                .flexibility
            {
            case .fixed:
                throw ItineraryEditingError.fixedItem(itemID)
            case .flexible:
                trip.itinerary.days[dayIndex]
                    .items[itemIndex]
                    .flexibility = .lockedByUser
            case .lockedByUser:
                trip.itinerary.days[dayIndex]
                    .items[itemIndex]
                    .flexibility = .flexible
            }

            trip.updatedAt = Date()
            storeUpdatedTrip(trip)
            return
        }

        throw ItineraryEditingError.unknownItem(itemID)
    }

    func fail(
        code: String,
        userMessage: String,
        isRecoverable: Bool
    ) throws {
        try validateTransition(to: .failed)
        failure = TripPlanningFailure(
            code: code,
            userMessage: userMessage,
            isRecoverable: isRecoverable,
            occurredAt: Date()
        )
        commitTransition(to: .failed)
    }

    func retry() throws {
        guard phase == .failed else {
            throw TripPlanningTransitionError.invalidTransition(
                from: phase,
                to: currentRequest == nil ? .listening : .validating
            )
        }

        failure = nil
        if currentRequest == nil {
            commitTransition(to: .listening)
        } else {
            commitTransition(to: .validating)
        }
    }

    func cancel() throws {
        try validateTransition(to: .cancelled)
        progress.cancelOpenWork()
        commitTransition(to: .cancelled)
    }

    func beginReturning() throws {
        try transition(to: .returning)
    }

    func finishReturning() throws {
        try transition(to: .idle)
        clearTransientState()
        currentRequest = nil
        if currentTrip == nil {
            progress = TripPlanningProgress()
        }
    }

    func resetForNewRequest() {
        let previousPhase = phase
        phase = .idle
        appendTransition(from: previousPhase, to: .idle)
        clearTransientState()
        currentRequest = nil
        currentTrip = nil
        activeTravelerID = nil
        budgetConflictAnalysis = nil
        progress = TripPlanningProgress()
    }

    func restorePersistedTrip(
        _ trip: Trip,
        viewerID: UUID? = nil
    ) throws {
        let issues = trip.structuralIssues
        guard issues.isEmpty else {
            throw TripPlanningTransitionError.invalidTrip(issues)
        }
        let previousPhase = phase
        phase = .ready
        currentRequest = trip.request
        currentTrip = trip
        let requestedViewer = viewerID ?? trip.organizerTravelerID
        activeTravelerID =
            GroupWorkspacePrivacy.canAccessTrip(
                travelerID: requestedViewer,
                trip: trip
            )
            ? requestedViewer
            : trip.organizerTravelerID
        clarificationFields = []
        unavailableProviders = []
        failure = nil
        progress = TripPlanningProgress()
        synchronizeProgress(with: trip)
        budgetConflictAnalysis = TripBudgetConflictEngine.analyze(
            trip: trip
        )
        appendTransition(from: previousPhase, to: .ready)
        revision &+= 1
    }

    func clearCurrentTrip() {
        let previousPhase = phase
        phase = .idle
        currentRequest = nil
        currentTrip = nil
        activeTravelerID = nil
        budgetConflictAnalysis = nil
        progress = TripPlanningProgress()
        clearTransientState()
        appendTransition(from: previousPhase, to: .idle)
        revision &+= 1
    }

    private func transition(to newPhase: TripPlanningPhase) throws {
        try validateTransition(to: newPhase)
        commitTransition(to: newPhase)
    }

    private func validateTransition(
        to newPhase: TripPlanningPhase
    ) throws {
        guard Self.allowsTransition(from: phase, to: newPhase) else {
            throw TripPlanningTransitionError.invalidTransition(
                from: phase,
                to: newPhase
            )
        }
    }

    private func commitTransition(to newPhase: TripPlanningPhase) {
        let previousPhase = phase
        phase = newPhase
        revision &+= 1
        appendTransition(from: previousPhase, to: newPhase)
    }

    private func appendTransition(
        from: TripPlanningPhase,
        to: TripPlanningPhase
    ) {
        guard from != to else { return }

        transitionHistory.append(
            TripPlanningTransitionRecord(from: from, to: to)
        )
        if transitionHistory.count > 100 {
            transitionHistory.removeFirst(
                transitionHistory.count - 100
            )
        }
    }

    private func clearTransientState() {
        activationSource = nil
        clarificationFields = []
        unavailableProviders = []
        failure = nil
    }

    private func validateBookingPhase() throws {
        guard phase == .ready || phase == .partiallyAvailable else {
            throw BookingConfirmationError.invalidPhase(phase)
        }
    }

    private func validateGroupWorkspacePhase() throws {
        guard phase == .ready || phase == .partiallyAvailable else {
            throw GroupWorkspaceError.invalidPhase(phase)
        }
    }

    private func validateDecisionPhase() throws {
        guard phase == .ready || phase == .partiallyAvailable else {
            throw DecisionVotingError.invalidPhase(phase)
        }
    }

    private func validateCommunicationPhase() throws {
        guard phase == .ready || phase == .partiallyAvailable else {
            throw TripCommunicationError.invalidPhase(phase)
        }
    }

    private func validateIntegrationPhase() throws {
        guard phase == .ready || phase == .partiallyAvailable else {
            throw TripIntegrationError.invalidPhase(phase)
        }
    }

    private func integrationActorID(in trip: Trip) throws -> UUID {
        guard let activeTravelerID else {
            throw TripIntegrationError.noActiveTraveler
        }
        guard
            GroupWorkspacePrivacy.canAccessTrip(
                travelerID: activeTravelerID,
                trip: trip
            )
        else {
            throw TripIntegrationError.accessDenied
        }
        return activeTravelerID
    }

    private func communicationActorID(
        in trip: Trip
    ) throws -> UUID {
        guard let activeTravelerID else {
            throw TripCommunicationError.noActiveTraveler
        }
        guard
            GroupWorkspacePrivacy.canAccessTrip(
                travelerID: activeTravelerID,
                trip: trip
            )
        else {
            throw TripCommunicationError.accessDenied
        }
        return activeTravelerID
    }

    private func decisionActorID(in trip: Trip) throws -> UUID {
        guard let activeTravelerID else {
            throw DecisionVotingError.noActiveTraveler
        }
        guard
            GroupWorkspacePrivacy.canAccessTrip(
                travelerID: activeTravelerID,
                trip: trip
            )
        else {
            throw DecisionVotingError.accessDenied
        }
        return activeTravelerID
    }

    private static func isValidDecisionSubject(
        _ subject: DecisionSubject,
        in trip: Trip
    ) -> Bool {
        switch subject {
        case .destination(let id):
            trip.request.destinations.contains { $0.id == id }
        case .dateRange:
            trip.request.dateRange != nil
        case .flightOffer(let id):
            trip.catalog.flightOffers.contains { $0.id == id }
        case .hotelOffer(let id):
            trip.catalog.hotelOffers.contains { $0.id == id }
        case .place(let id):
            trip.catalog.places.contains { $0.id == id }
        case .itineraryItem(let id):
            trip.itinerary.days
                .flatMap(\.items)
                .contains { $0.id == id }
        case .budget:
            trip.budget.totalLimit != nil
                || trip.request.totalBudget != nil
        }
    }

    private static func isValidMessageContext(
        _ context: TripMessageContext,
        in trip: Trip
    ) -> Bool {
        switch context {
        case .trip:
            true
        case .itineraryItem(let id):
            trip.itinerary.days
                .flatMap(\.items)
                .contains { $0.id == id }
        case .decision(let id):
            trip.decisions.contains { $0.id == id }
        }
    }

    private func appendSystemMessage(
        to trip: inout Trip,
        body: String,
        event: SystemMessageEvent,
        context: TripMessageContext = .trip,
        at date: Date
    ) {
        var communication =
            trip.communication ?? TripCommunication()
        communication.messages.append(
            TripMessage(
                authorKind: .system,
                body: body,
                context: context,
                systemEvent: event,
                createdAt: date
            )
        )
        trip.communication = communication
    }

    private func activeTravelerName(in trip: Trip) -> String {
        guard let activeTravelerID else { return "A trip member" }
        return trip.travelers.first {
            $0.id == activeTravelerID
        }?.displayName ?? "A trip member"
    }

    private func authorizedActiveTravelerID(
        in trip: Trip
    ) throws -> UUID {
        guard let activeTravelerID else {
            throw GroupWorkspaceError.noActiveTraveler
        }
        guard
            GroupWorkspacePrivacy.canAccessTrip(
                travelerID: activeTravelerID,
                trip: trip
            )
        else {
            throw GroupWorkspaceError.accessDenied
        }
        return activeTravelerID
    }

    private static func isValidEmailAddress(_ value: String) -> Bool {
        guard
            let at = value.firstIndex(of: "@"),
            at != value.startIndex,
            let dot = value[at...].lastIndex(of: "."),
            dot > at,
            dot < value.index(before: value.endIndex)
        else {
            return false
        }
        return !value.contains(where: \.isWhitespace)
    }

    private func retireUnfinishedBookings(
        in trip: inout Trip,
        category: BookingCategory,
        except itemIdentifier: UUID,
        at date: Date
    ) {
        for index in trip.bookings.indices
        where
            trip.bookings[index].category == category
            && trip.bookings[index].itemIdentifier != itemIdentifier
            && trip.bookings[index].status != .confirmed
            && trip.bookings[index].status != .cancelled
        {
            trip.bookings[index].status = .cancelled
            trip.bookings[index].updatedAt = date
        }
    }

    private func upsertBooking(
        in trip: inout Trip,
        category: BookingCategory,
        itemIdentifier: UUID,
        amount: Money,
        checkoutURL: URL?,
        source: DataProvenance,
        mode: BookingConfirmationMode,
        at date: Date
    ) -> BookingRecord {
        let recordMode: BookingMode =
            mode == .fblaDemo ? .demo : .externalCheckout
        let status: BookingStatus =
            mode == .fblaDemo
            ? .demoConfirmed
            : .externalCheckoutRequired
        let provenance = DataProvenance(
            provider: mode == .fblaDemo ? .gia : source.provider,
            providerIdentifier: source.providerIdentifier,
            origin: mode == .fblaDemo ? .demo : source.origin,
            retrievedAt: date,
            sourceURL: checkoutURL ?? source.sourceURL
        )

        if
            let index = trip.bookings.firstIndex(
                where: {
                    $0.category == category
                        && $0.itemIdentifier == itemIdentifier
                        && $0.mode == recordMode
                        && $0.status != .cancelled
                }
            )
        {
            trip.bookings[index].status = status
            trip.bookings[index].amount = amount
            trip.bookings[index].checkoutURL = checkoutURL
            trip.bookings[index].updatedAt = date
            trip.bookings[index].provenance = provenance
            return trip.bookings[index]
        }

        let record = BookingRecord(
            category: category,
            mode: recordMode,
            status: status,
            itemIdentifier: itemIdentifier,
            providerName:
                mode == .fblaDemo
                ? "GIA FBLA Demonstration"
                : source.provider.rawValue,
            amount: amount,
            checkoutURL: checkoutURL,
            createdAt: date,
            updatedAt: date,
            provenance: provenance
        )
        trip.bookings.append(record)
        return record
    }

    private func replaceFlightItineraryItems(
        in trip: inout Trip,
        with offer: FlightOffer,
        mode: BookingConfirmationMode
    ) {
        for dayIndex in trip.itinerary.days.indices {
            trip.itinerary.days[dayIndex].items.removeAll {
                if case .flightOffer = $0.reference {
                    return true
                }
                return false
            }
        }

        let journeys = [
            offer.outboundSegments,
            offer.returnSegments
        ].filter { !$0.isEmpty }
        for segments in journeys {
            guard
                let first = segments.first,
                let last = segments.last
            else { continue }
            let origin =
                first.origin.iataCode ?? first.origin.name
            let destination =
                last.destination.iataCode ?? last.destination.name
            let airlineNames = Set(segments.map(\.airlineName))
                .sorted()
                .joined(separator: ", ")
            let item = ItineraryItem(
                title: "Flight \(origin) → \(destination)",
                subtitle: airlineNames,
                kind: .flight,
                status: .selected,
                flexibility: .fixed,
                start: first.departure,
                end: last.arrival,
                timeZoneIdentifier:
                    first.departureTimeZoneIdentifier,
                location: first.origin,
                reference: .flightOffer(offer.id),
                estimatedCost: nil,
                notes:
                    mode == .fblaDemo
                    ? "Demo booking confirmed. No real ticket was issued."
                    : "External checkout required. Selection is not booked."
            )
            appendItineraryItem(
                item,
                to: &trip
            )
        }
    }

    private func replaceHotelItineraryItems(
        in trip: inout Trip,
        with offer: HotelOffer,
        mode: BookingConfirmationMode
    ) {
        for dayIndex in trip.itinerary.days.indices {
            trip.itinerary.days[dayIndex].items.removeAll {
                if case .hotelOffer = $0.reference {
                    return true
                }
                return false
            }
        }
        guard let range = trip.request.dateRange else { return }
        let timeZoneIdentifier =
            offer.location.timeZoneIdentifier
            ?? range.timeZoneIdentifier
        let checkIn = Self.date(
            on: range.start,
            timeText: offer.checkInTime,
            fallbackHour: 15,
            timeZoneIdentifier: timeZoneIdentifier
        )
        let checkOut = Self.date(
            on: range.end,
            timeText: offer.checkOutTime,
            fallbackHour: 11,
            timeZoneIdentifier: timeZoneIdentifier
        )
        let note =
            mode == .fblaDemo
            ? "Demo booking confirmed. No real room was reserved."
            : "External checkout required. Selection is not reserved."
        let checkInItem = ItineraryItem(
            title: "Check in · \(offer.name)",
            kind: .hotelCheckIn,
            status: .selected,
            flexibility: .fixed,
            start: checkIn,
            end: checkIn.addingTimeInterval(1_800),
            timeZoneIdentifier: timeZoneIdentifier,
            location: offer.location,
            reference: .hotelOffer(offer.id),
            estimatedCost: nil,
            notes: note
        )
        let checkOutItem = ItineraryItem(
            title: "Check out · \(offer.name)",
            kind: .hotelCheckOut,
            status: .selected,
            flexibility: .fixed,
            start: checkOut,
            end: checkOut.addingTimeInterval(1_800),
            timeZoneIdentifier: timeZoneIdentifier,
            location: offer.location,
            reference: .hotelOffer(offer.id),
            estimatedCost: nil,
            notes: note
        )
        appendItineraryItem(checkInItem, to: &trip)
        appendItineraryItem(checkOutItem, to: &trip)
    }

    private func appendItineraryItem(
        _ item: ItineraryItem,
        to trip: inout Trip
    ) {
        if
            let dayIndex = trip.itinerary.days.firstIndex(
                where: {
                    Self.isSameCalendarDay(
                        item.start,
                        as: $0.date,
                        timeZoneIdentifier:
                            item.timeZoneIdentifier
                    )
                }
            )
        {
            trip.itinerary.days[dayIndex].items.append(item)
            trip.itinerary.days[dayIndex].items.sort {
                $0.start < $1.start
            }
            return
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: item.timeZoneIdentifier)
            ?? .current
        let day = ItineraryDay(
            date: calendar.startOfDay(for: item.start),
            timeZoneIdentifier: item.timeZoneIdentifier,
            items: [item]
        )
        trip.itinerary.days.append(day)
        trip.itinerary.days.sort { $0.date < $1.date }
    }

    private static func date(
        on day: Date,
        timeText: String?,
        fallbackHour: Int,
        timeZoneIdentifier: String
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: timeZoneIdentifier) ?? .current
        var hour = fallbackHour
        var minute = 0

        if let timeText {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = calendar.timeZone
            for format in ["h:mm a", "h a", "HH:mm"] {
                formatter.dateFormat = format
                if let parsed = formatter.date(from: timeText) {
                    let components = calendar.dateComponents(
                        [.hour, .minute],
                        from: parsed
                    )
                    hour = components.hour ?? fallbackHour
                    minute = components.minute ?? 0
                    break
                }
            }
        }

        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day
        ) ?? day
    }

    private func storeUpdatedTrip(_ trip: Trip) {
        currentTrip = trip
        budgetConflictAnalysis = TripBudgetConflictEngine.analyze(
            trip: trip
        )
        revision &+= 1
    }

    private func validateProgressMutation(
        for workstream: PlanningWorkstream
    ) throws {
        let isAllowed: Bool

        switch phase {
        case .validating, .needsClarification:
            isAllowed =
                workstream == .understanding
                || workstream == .destination
        case .searching, .comparing:
            isAllowed =
                workstream.isProviderWork
                || workstream == .destination
        case .buildingItinerary:
            isAllowed =
                workstream == .routes
                || workstream == .schedule
                || workstream == .budget
        case .presenting, .partiallyAvailable:
            isAllowed = true
        default:
            isAllowed = false
        }

        guard isAllowed else {
            throw TripPlanningProgressError.invalidPhase(
                phase: phase,
                workstream: workstream
            )
        }
    }

    private func synchronizeProgress(with trip: Trip) {
        progress.complete(
            .understanding,
            message: "Request validated"
        )
        progress.complete(
            .destination,
            resultCount: trip.request.destinations.count,
            message: "Destination resolved"
        )

        if !trip.catalog.flightOffers.isEmpty {
            progress.complete(
                .flights,
                resultCount: trip.catalog.flightOffers.count,
                providers: Set(
                    trip.catalog.flightOffers.map {
                        $0.provenance.provider
                    }
                )
            )
        }
        if !trip.catalog.hotelOffers.isEmpty {
            progress.complete(
                .stay,
                resultCount: trip.catalog.hotelOffers.count,
                providers: Set(
                    trip.catalog.hotelOffers.map {
                        $0.provenance.provider
                    }
                )
            )
        }
        if
            !trip.catalog.places.isEmpty
            || !trip.catalog.timedEvents.isEmpty
        {
            progress.complete(
                .experiences,
                resultCount:
                    trip.catalog.places.count
                    + trip.catalog.timedEvents.count,
                providers: Set(
                    trip.catalog.places.map {
                        $0.provenance.provider
                    }
                    + trip.catalog.timedEvents.map {
                        $0.provenance.provider
                    }
                )
            )
        }
        if !trip.catalog.weatherSnapshots.isEmpty {
            progress.complete(
                .weather,
                resultCount: trip.catalog.weatherSnapshots.count,
                providers: Set(
                    trip.catalog.weatherSnapshots.map {
                        $0.provenance.provider
                    }
                )
            )
        }
        if !trip.itinerary.transportationLegs.isEmpty {
            progress.complete(
                .routes,
                resultCount: trip.itinerary.transportationLegs.count,
                providers: Set(
                    trip.itinerary.transportationLegs.map {
                        $0.provenance.provider
                    }
                )
            )
        }
        if !trip.itinerary.days.isEmpty {
            progress.complete(
                .schedule,
                resultCount: trip.itinerary.days.count
            )
        }
        if
            trip.budget.totalLimit != nil
            || !trip.budget.allocations.isEmpty
        {
            progress.complete(.budget)
        }
    }

    private static func isSameCalendarDay(
        _ date: Date,
        as referenceDate: Date,
        timeZoneIdentifier: String
    ) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: timeZoneIdentifier)
            ?? .current
        return calendar.isDate(date, inSameDayAs: referenceDate)
    }

    private static func allowsTransition(
        from: TripPlanningPhase,
        to: TripPlanningPhase
    ) -> Bool {
        switch (from, to) {
        case
            (.idle, .wakePhraseDetected),
            (.idle, .listening),
            (.wakePhraseDetected, .listening),
            (.wakePhraseDetected, .failed),
            (.wakePhraseDetected, .returning),
            (.listening, .transcribing),
            (.listening, .validating),
            (.listening, .failed),
            (.listening, .cancelled),
            (.listening, .returning),
            (.transcribing, .listening),
            (.transcribing, .validating),
            (.transcribing, .failed),
            (.transcribing, .cancelled),
            (.transcribing, .returning),
            (.validating, .wakePhraseDetected),
            (.validating, .needsClarification),
            (.validating, .searching),
            (.validating, .failed),
            (.validating, .cancelled),
            (.validating, .returning),
            (.needsClarification, .wakePhraseDetected),
            (.needsClarification, .listening),
            (.needsClarification, .validating),
            (.needsClarification, .cancelled),
            (.needsClarification, .returning),
            (.searching, .wakePhraseDetected),
            (.searching, .listening),
            (.searching, .comparing),
            (.searching, .partiallyAvailable),
            (.searching, .failed),
            (.searching, .cancelled),
            (.searching, .returning),
            (.comparing, .wakePhraseDetected),
            (.comparing, .listening),
            (.comparing, .buildingItinerary),
            (.comparing, .partiallyAvailable),
            (.comparing, .failed),
            (.comparing, .cancelled),
            (.comparing, .returning),
            (.buildingItinerary, .wakePhraseDetected),
            (.buildingItinerary, .listening),
            (.buildingItinerary, .presenting),
            (.buildingItinerary, .partiallyAvailable),
            (.buildingItinerary, .failed),
            (.buildingItinerary, .cancelled),
            (.buildingItinerary, .returning),
            (.partiallyAvailable, .wakePhraseDetected),
            (.partiallyAvailable, .listening),
            (.partiallyAvailable, .comparing),
            (.partiallyAvailable, .buildingItinerary),
            (.partiallyAvailable, .presenting),
            (.partiallyAvailable, .ready),
            (.partiallyAvailable, .failed),
            (.partiallyAvailable, .cancelled),
            (.partiallyAvailable, .returning),
            (.presenting, .wakePhraseDetected),
            (.presenting, .listening),
            (.presenting, .ready),
            (.presenting, .partiallyAvailable),
            (.presenting, .failed),
            (.presenting, .cancelled),
            (.presenting, .returning),
            (.ready, .wakePhraseDetected),
            (.ready, .listening),
            (.ready, .returning),
            (.failed, .wakePhraseDetected),
            (.failed, .listening),
            (.failed, .validating),
            (.failed, .cancelled),
            (.failed, .returning),
            (.cancelled, .returning),
            (.returning, .idle):
            true
        default:
            false
        }
    }
}
