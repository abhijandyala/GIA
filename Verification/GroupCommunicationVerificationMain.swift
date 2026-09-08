import Foundation

@main
enum GroupCommunicationVerificationMain {
    @MainActor
    static func main() throws {
        let date = Date(timeIntervalSince1970: 1_812_758_400)
        let destination = TravelLocation(
            name: "Lisbon",
            city: "Lisbon",
            country: "Portugal",
            countryCode: "PT",
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let travelers = [
            traveler("Avery", "AV", role: .organizer),
            traveler("Maya", "MK"),
            traveler("Noah", "NR")
        ]
        let item = ItineraryItem(
            title: "National Tile Museum",
            kind: .activity,
            status: .selected,
            flexibility: .flexible,
            start: date.addingTimeInterval(36_000),
            end: date.addingTimeInterval(39_600),
            timeZoneIdentifier: "Europe/Lisbon",
            location: destination
        )
        let request = TripRequest(
            destinations: [destination],
            dateRange: TripDateRange(
                start: date,
                end: date.addingTimeInterval(604_800),
                timeZoneIdentifier: "Europe/Lisbon"
            ),
            travelerCount: travelers.count,
            totalBudget: Money(
                amount: 5_000,
                currencyCode: "USD"
            )
        )
        let trip = Trip(
            title: "Lisbon Together",
            lifecycleState: .ready,
            organizerTravelerID: travelers[0].id,
            request: request,
            travelers: travelers,
            itinerary: TripItinerary(
                days: [
                    ItineraryDay(
                        date: date,
                        timeZoneIdentifier: "Europe/Lisbon",
                        items: [item]
                    )
                ]
            ),
            budget: TripBudget(totalLimit: request.totalBudget),
            collaboration: TripCollaboration(),
            communication: TripCommunication(),
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

        let message = try session.sendMessage(
            "Can we keep this museum?",
            context: .itineraryItem(item.id),
            mentionedTravelerIDs: [travelers[1].id]
        )
        precondition(message.authorKind == .member)
        precondition(
            message.authorTravelerID == travelers[0].id
        )
        precondition(
            message.mentionedTravelerIDs == [travelers[1].id]
        )
        precondition(
            message.readReceipts.map(\.travelerID)
                == [travelers[0].id]
        )

        do {
            _ = try session.sendMessage("   ")
            fatalError("Empty message was accepted.")
        } catch let error as TripCommunicationError {
            precondition(error == .emptyMessage)
        }
        let outsiderID = UUID()
        do {
            _ = try session.sendMessage(
                "Invalid mention",
                mentionedTravelerIDs: [outsiderID]
            )
            fatalError("Unknown mention was accepted.")
        } catch let error as TripCommunicationError {
            precondition(error == .invalidMention(outsiderID))
        }
        do {
            _ = try session.sendMessage(
                "Invalid context",
                context: .itineraryItem(UUID())
            )
            fatalError("Unknown context was accepted.")
        } catch let error as TripCommunicationError {
            precondition(error == .invalidContext)
        }

        try session.toggleReaction(
            on: message.id,
            kind: .approve
        )
        precondition(
            currentMessage(message.id, in: session).reactions.count == 1
        )
        try session.toggleReaction(
            on: message.id,
            kind: .approve
        )
        precondition(
            currentMessage(message.id, in: session).reactions.isEmpty
        )

        try session.setActiveTraveler(travelers[1].id)
        try session.markMessagesRead()
        try session.markMessagesRead()
        precondition(
            currentMessage(message.id, in: session).readReceipts
                .filter { $0.travelerID == travelers[1].id }
                .count == 1
        )
        do {
            try session.setActiveTraveler(outsiderID)
            fatalError("Outsider identity was accepted.")
        } catch let error as GroupWorkspaceError {
            precondition(error == .accessDenied)
        }

        let giaMessage = try session.postGIAMessage(
            "I linked this discussion to the museum.",
            context: .itineraryItem(item.id)
        )
        precondition(giaMessage.authorKind == .gia)
        precondition(giaMessage.authorTravelerID == nil)

        try session.setActiveTraveler(travelers[0].id)
        let decision = try session.proposeDecision(
            title: "Keep the museum",
            subject: .itineraryItem(item.id),
            rule: .majority
        )
        try session.castVote(
            on: decision.id,
            choice: .approve
        )
        try session.setActiveTraveler(travelers[1].id)
        try session.castVote(
            on: decision.id,
            choice: .approve
        )
        let events = session.currentTrip?.communication?.messages
            .compactMap(\.systemEvent) ?? []
        precondition(events.contains(.decisionOpened))
        precondition(events.contains(.decisionResolved))

        try session.setActiveTraveler(travelers[0].id)
        try session.moveItineraryItem(
            item.id,
            toStart: item.start.addingTimeInterval(900),
            end: item.end.addingTimeInterval(900)
        )
        precondition(
            session.currentTrip?.communication?.messages.contains {
                $0.systemEvent == .itineraryChanged
                    && $0.context == .itineraryItem(item.id)
            } == true
        )

        let shareText = TripShareSummaryBuilder.text(
            for: session.currentTrip!
        )
        precondition(shareText.contains("Lisbon Together"))
        precondition(shareText.contains("Travelers: 3"))
        precondition(!shareText.contains("@example.com"))

        var invalidTrip = trip
        let duplicateReaction = MessageReaction(
            travelerID: travelers[0].id,
            kind: .heart
        )
        let duplicateReceipt = MessageReadReceipt(
            travelerID: travelers[0].id
        )
        invalidTrip.communication = TripCommunication(
            messages: [
                TripMessage(
                    authorKind: .member,
                    authorTravelerID: travelers[0].id,
                    body: "Duplicate metadata",
                    reactions: [
                        duplicateReaction,
                        MessageReaction(
                            travelerID: travelers[0].id,
                            kind: .heart
                        )
                    ],
                    readReceipts: [
                        duplicateReceipt,
                        MessageReadReceipt(
                            travelerID: travelers[0].id
                        )
                    ]
                )
            ]
        )
        precondition(
            invalidTrip.structuralIssues.contains {
                $0.code == .duplicateMessageReaction
            }
        )
        precondition(
            invalidTrip.structuralIssues.contains {
                $0.code == .duplicateReadReceipt
            }
        )

        let encoded = try JSONEncoder().encode(trip)
        var legacyObject = try JSONSerialization.jsonObject(
            with: encoded
        ) as! [String: Any]
        legacyObject.removeValue(forKey: "communication")
        let legacyTrip = try JSONDecoder().decode(
            Trip.self,
            from: JSONSerialization.data(
                withJSONObject: legacyObject
            )
        )
        precondition(legacyTrip.communication == nil)

        print("Group communication lifecycle passed.")
    }

    @MainActor
    private static func currentMessage(
        _ id: UUID,
        in session: TripPlanningSession
    ) -> TripMessage {
        session.currentTrip!.communication!.messages.first {
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
            role: role,
            preferences: TravelerPreferences(
                notes: "Private note",
                visibility: .privateToTraveler
            )
        )
    }
}
