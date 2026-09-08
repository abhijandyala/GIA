import Foundation

struct TripDomainIssue: Codable, Hashable, Identifiable, Sendable {
    enum Code: String, Codable, Sendable {
        case unsupportedSchema
        case missingOrganizer
        case duplicateTraveler
        case invalidDateRange
        case invalidDuration
        case invalidTravelerCount
        case invalidCurrency
        case invalidItineraryRange
        case missingSelectedFlight
        case missingSelectedHotel
        case missingSelectedPlace
        case misleadingDemoBooking
        case misleadingBookingState
        case missingBookingCheckout
        case invalidInvitation
        case missingAcceptedTraveler
        case duplicateDecisionVote
        case ineligibleDecisionVote
        case invalidDecisionRevision
        case invalidDecisionSubject
        case invalidMessage
        case duplicateMessageReaction
        case duplicateReadReceipt
        case invalidNotificationOwner
        case invalidCalendarExport
    }

    var code: Code
    var fieldPath: String
    var message: String

    var id: String {
        "\(code.rawValue):\(fieldPath)"
    }

    init(
        code: Code,
        fieldPath: String,
        message: String
    ) {
        self.code = code
        self.fieldPath = fieldPath
        self.message = message
    }
}

extension Trip {
    var structuralIssues: [TripDomainIssue] {
        var issues = request.structuralIssues

        if schemaVersion != TripDomainSchema.currentVersion {
            issues.append(
                TripDomainIssue(
                    code: .unsupportedSchema,
                    fieldPath: "schemaVersion",
                    message: "The trip schema version is unsupported."
                )
            )
        }

        if organizer == nil {
            issues.append(
                TripDomainIssue(
                    code: .missingOrganizer,
                    fieldPath: "organizerTravelerID",
                    message: "The trip organizer must be a traveler."
                )
            )
        }

        let travelerIDs = travelers.map(\.id)
        if Set(travelerIDs).count != travelerIDs.count {
            issues.append(
                TripDomainIssue(
                    code: .duplicateTraveler,
                    fieldPath: "travelers",
                    message: "Traveler identifiers must be unique."
                )
            )
        }

        for (dayIndex, day) in itinerary.days.enumerated() {
            for (itemIndex, item) in day.items.enumerated()
            where !item.isChronological {
                issues.append(
                    TripDomainIssue(
                        code: .invalidItineraryRange,
                        fieldPath:
                            "itinerary.days[\(dayIndex)]"
                            + ".items[\(itemIndex)]",
                        message:
                            "An itinerary item ends before it starts."
                    )
                )
            }
        }

        let flightIDs = Set(catalog.flightOffers.map(\.id))
        for selectedID in selections.flightOfferIDs
        where !flightIDs.contains(selectedID) {
            issues.append(
                TripDomainIssue(
                    code: .missingSelectedFlight,
                    fieldPath: "selections.flightOfferIDs",
                    message:
                        "A selected flight is missing from the catalog."
                )
            )
        }

        let hotelIDs = Set(catalog.hotelOffers.map(\.id))
        for selectedID in selections.hotelOfferIDs
        where !hotelIDs.contains(selectedID) {
            issues.append(
                TripDomainIssue(
                    code: .missingSelectedHotel,
                    fieldPath: "selections.hotelOfferIDs",
                    message:
                        "A selected hotel is missing from the catalog."
                )
            )
        }

        let placeIDs = Set(catalog.places.map(\.id))
        for selectedID in selections.placeIDs
        where !placeIDs.contains(selectedID) {
            issues.append(
                TripDomainIssue(
                    code: .missingSelectedPlace,
                    fieldPath: "selections.placeIDs",
                    message:
                        "A selected place is missing from the catalog."
                )
            )
        }

        for (index, booking) in bookings.enumerated()
        where
            booking.mode == .demo
            && booking.status == .confirmed
        {
            issues.append(
                TripDomainIssue(
                    code: .misleadingDemoBooking,
                    fieldPath: "bookings[\(index)].status",
                    message:
                        "Demo bookings must use demoConfirmed status."
                )
            )
        }

        for (index, booking) in bookings.enumerated()
        where
            (
                booking.status == .demoConfirmed
                && booking.mode != .demo
            )
            || (
                booking.status == .confirmed
                && booking.mode == .externalCheckout
            )
        {
            issues.append(
                TripDomainIssue(
                    code: .misleadingBookingState,
                    fieldPath: "bookings[\(index)].status",
                    message:
                        "Booking status must match its confirmation mode."
                )
            )
        }

        for (index, booking) in bookings.enumerated()
        where
            booking.mode == .externalCheckout
            && booking.status == .externalCheckoutRequired
            && booking.checkoutURL == nil
        {
            issues.append(
                TripDomainIssue(
                    code: .missingBookingCheckout,
                    fieldPath: "bookings[\(index)].checkoutURL",
                    message:
                        "External checkout requires a provider URL."
                )
            )
        }

        if let collaboration {
            let pendingEmails = collaboration.invitations
                .filter { $0.status == .pending }
                .map(\.inviteeEmailAddress)
            if Set(pendingEmails).count != pendingEmails.count {
                issues.append(
                    TripDomainIssue(
                        code: .invalidInvitation,
                        fieldPath: "collaboration.invitations",
                        message:
                            "Pending invitation email addresses "
                            + "must be unique."
                    )
                )
            }

            for (index, invitation) in
                collaboration.invitations.enumerated()
            where invitation.status == .accepted
            {
                guard
                    let travelerID = invitation.acceptedTravelerID,
                    travelers.contains(
                        where: { $0.id == travelerID }
                    )
                else {
                    issues.append(
                        TripDomainIssue(
                            code: .missingAcceptedTraveler,
                            fieldPath:
                                "collaboration.invitations[\(index)]"
                                + ".acceptedTravelerID",
                            message:
                                "An accepted invitation must reference "
                                + "an active trip member."
                        )
                    )
                    continue
                }
            }
        }

        let decisionIDs = Set(decisions.map(\.id))
        for (index, decision) in decisions.enumerated() {
            if !hasDecisionSubject(decision.subject) {
                issues.append(
                    TripDomainIssue(
                        code: .invalidDecisionSubject,
                        fieldPath: "decisions[\(index)].subject",
                        message:
                            "A decision must reference current trip data."
                    )
                )
            }
            let voterIDs = decision.votes.map(\.travelerID)
            if Set(voterIDs).count != voterIDs.count {
                issues.append(
                    TripDomainIssue(
                        code: .duplicateDecisionVote,
                        fieldPath: "decisions[\(index)].votes",
                        message:
                            "A traveler may vote only once per decision."
                    )
                )
            }
            if
                let eligibleIDs = decision.eligibleTravelerIDs,
                voterIDs.contains(
                    where: { !eligibleIDs.contains($0) }
                )
            {
                issues.append(
                    TripDomainIssue(
                        code: .ineligibleDecisionVote,
                        fieldPath: "decisions[\(index)].votes",
                        message:
                            "Every ballot must belong to an eligible "
                            + "traveler."
                    )
                )
            }
            if
                let supersededID = decision.supersedesDecisionID,
                (
                    supersededID == decision.id
                    || !decisionIDs.contains(supersededID)
                    || (
                        decisions.first {
                            $0.id == supersededID
                        }?.proposedAt ?? .distantFuture
                    ) > decision.proposedAt
                )
            {
                issues.append(
                    TripDomainIssue(
                        code: .invalidDecisionRevision,
                        fieldPath:
                            "decisions[\(index)]"
                            + ".supersedesDecisionID",
                        message:
                            "A revision must reference an earlier "
                            + "decision."
                    )
                )
            }
        }

        if let communication {
            for (index, message) in
                communication.messages.enumerated()
            {
                let hasValidAuthor =
                    (
                        message.authorKind == .member
                        && message.authorTravelerID != nil
                    )
                    || (
                        message.authorKind != .member
                        && message.authorTravelerID == nil
                    )
                if
                    message.body.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                    || message.body.count > 2_000
                    || !hasValidAuthor
                {
                    issues.append(
                        TripDomainIssue(
                            code: .invalidMessage,
                            fieldPath:
                                "communication.messages[\(index)]",
                            message:
                                "A message requires valid text and "
                                + "author metadata."
                        )
                    )
                }

                let reactionKeys = message.reactions.map {
                    "\($0.travelerID)-\($0.kind.rawValue)"
                }
                if
                    Set(reactionKeys).count
                    != reactionKeys.count
                {
                    issues.append(
                        TripDomainIssue(
                            code: .duplicateMessageReaction,
                            fieldPath:
                                "communication.messages[\(index)]"
                                + ".reactions",
                            message:
                                "A traveler may add each reaction "
                                + "only once."
                        )
                    )
                }

                let readerIDs = message.readReceipts.map(
                    \.travelerID
                )
                if Set(readerIDs).count != readerIDs.count {
                    issues.append(
                        TripDomainIssue(
                            code: .duplicateReadReceipt,
                            fieldPath:
                                "communication.messages[\(index)]"
                                + ".readReceipts",
                            message:
                                "A message may contain one read receipt "
                                + "per traveler."
                        )
                    )
                }
            }
        }

        if let integrations {
            if
                integrations.notificationSettings.isEnabled,
                let ownerID =
                    integrations.notificationSettings.ownerTravelerID,
                !travelers.contains(where: { $0.id == ownerID })
            {
                issues.append(
                    TripDomainIssue(
                        code: .invalidNotificationOwner,
                        fieldPath:
                            "integrations.notificationSettings"
                            + ".ownerTravelerID",
                        message:
                            "Enabled reminders must belong to "
                            + "an active trip member."
                    )
                )
            }
            let itineraryIDs = Set(
                itinerary.days.flatMap(\.items).map(\.id)
            )
            let exportItemIDs =
                integrations.calendarExports.map(\.itineraryItemID)
            if
                Set(exportItemIDs).count != exportItemIDs.count
                || exportItemIDs.contains(
                    where: { !itineraryIDs.contains($0) }
                )
            {
                issues.append(
                    TripDomainIssue(
                        code: .invalidCalendarExport,
                        fieldPath: "integrations.calendarExports",
                        message:
                            "Calendar export records must uniquely "
                            + "reference itinerary items."
                    )
                )
            }
        }

        return issues
    }

    private func hasDecisionSubject(
        _ subject: DecisionSubject
    ) -> Bool {
        switch subject {
        case .destination(let id):
            request.destinations.contains { $0.id == id }
        case .dateRange:
            request.dateRange != nil
        case .flightOffer(let id):
            catalog.flightOffers.contains { $0.id == id }
        case .hotelOffer(let id):
            catalog.hotelOffers.contains { $0.id == id }
        case .place(let id):
            catalog.places.contains { $0.id == id }
        case .itineraryItem(let id):
            itinerary.days.flatMap(\.items).contains {
                $0.id == id
            }
        case .budget:
            budget.totalLimit != nil || request.totalBudget != nil
        }
    }

    var isStructurallyValid: Bool {
        structuralIssues.isEmpty
    }
}

extension TripRequest {
    var structuralIssues: [TripDomainIssue] {
        var issues: [TripDomainIssue] = []

        if let dateRange, !dateRange.isChronological {
            issues.append(
                TripDomainIssue(
                    code: .invalidDateRange,
                    fieldPath: "request.dateRange",
                    message:
                        "The return date must not precede departure."
                )
            )
        }

        if let travelerCount, travelerCount < 1 {
            issues.append(
                TripDomainIssue(
                    code: .invalidTravelerCount,
                    fieldPath: "request.travelerCount",
                    message:
                        "A trip must include at least one traveler."
                )
            )
        }

        if
            let durationDays,
            !(1...90).contains(durationDays)
        {
            issues.append(
                TripDomainIssue(
                    code: .invalidDuration,
                    fieldPath: "request.durationDays",
                    message:
                        "Trip duration must be between 1 and 90 days."
                )
            )
        }

        if
            let totalBudget,
            totalBudget.currencyCode.count != 3
        {
            issues.append(
                TripDomainIssue(
                    code: .invalidCurrency,
                    fieldPath: "request.totalBudget.currencyCode",
                    message:
                        "Currency codes must use three ISO letters."
                )
            )
        }

        return issues
    }
}
