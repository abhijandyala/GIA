import Foundation

@main
enum TripRequestInterpreterVerificationMain {
    @MainActor
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let spoken = TripRequestInterpreter.interpret(
            transcript:
                "Plan seven days in Lisbon for four travelers "
                + "under six thousand dollars. We like beaches, "
                + "museums, vegetarian food, and limited walking.",
            now: now
        )

        precondition(
            spoken.request.destinations.first?.name == "Lisbon"
        )
        precondition(spoken.request.durationDays == 7)
        precondition(spoken.request.travelerCount == 4)
        precondition(
            spoken.request.totalBudget?.amount == Decimal(6_000)
        )
        precondition(
            spoken.request.totalBudget?.currencyCode == "USD"
        )
        precondition(spoken.request.interests.contains(.beaches))
        precondition(spoken.request.interests.contains(.museums))
        precondition(
            spoken.request.dietaryRequirements.contains(.vegetarian)
        )
        precondition(
            spoken.request.accessibilityRequirements
                .contains(.reducedWalking)
        )
        precondition(spoken.clarificationFields == [.dates])
        let spokenPrompts = PlanClarificationBuilder.prompts(
            for: spoken.request,
            now: now
        )
        precondition(spokenPrompts.count == 1)
        precondition(spokenPrompts[0].field == .dates)
        precondition(spokenPrompts[0].editableMetric == .dates)
        precondition(spokenPrompts[0].title == "Travel dates")

        let italy = TripRequestInterpreter.interpret(
            transcript:
                "Book a trip to Italy and make sure that you book "
                + "two or three authentic Italian restaurants",
            now: now
        )
        precondition(
            italy.request.destinations.first?.name == "Italy"
        )
        precondition(italy.request.interests.contains(.food))
        precondition(
            italy.clarificationFields == [.dates, .travelers]
        )
        let parisWeek = TripRequestInterpreter.interpret(
            transcript: "Paris next week",
            now: now
        )
        precondition(
            parisWeek.request.destinations.first?.name == "Paris"
        )
        precondition(parisWeek.request.dateRange != nil)
        precondition(parisWeek.request.durationDays == 7)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: now)
        func dayString(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
        func addingDays(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: days, to: today)
                ?? today
        }

        guard
            let spokenDates =
                TripRequestInterpreter.interpretClarificationAnswer(
                    "now till next week i can go there, "
                        + "and from there i want to stay for a week",
                    for: .dates,
                    applyingTo: spoken.request,
                    now: now
                )
        else {
            preconditionFailure(
                "Expected relative dates like now till next week"
            )
        }
        precondition(spokenDates.durationDays == 7)
        precondition(
            dayString(spokenDates.dateRange?.start ?? .distantPast)
                == dayString(today)
        )
        precondition(
            dayString(spokenDates.dateRange?.end ?? .distantPast)
                == dayString(addingDays(6))
        )
        precondition(
            !TripRequestInterpreter.validate(
                spokenDates,
                now: now
            ).contains { $0.field == .dates }
        )

        let patched = TripRequestInterpreter.applying(
            TripReplyInterpretation(
                understanding: .understood,
                spokenText: nil,
                destination: nil,
                origin: nil,
                dateStart: "2026-09-07",
                dateEnd: "2026-09-13",
                durationDays: 7,
                travelerCount: 2,
                budgetAmount: nil,
                budgetCurrency: nil
            ),
            to: spoken.request,
            now: now
        )
        precondition(patched.travelerCount == 2)
        precondition(patched.durationDays == 7)
        precondition(patched.dateRange != nil)

        guard
            let weekOnly =
                TripRequestInterpreter.interpretClarificationAnswer(
                    "for a week",
                    for: .dates,
                    applyingTo: spoken.request,
                    now: now
                )
        else {
            preconditionFailure("Expected a week-long stay")
        }
        precondition(weekOnly.durationDays == 7)
        precondition(
            dayString(weekOnly.dateRange?.end ?? .distantPast)
                == dayString(addingDays(6))
        )

        let weekendTrip = TripRequestInterpreter.interpret(
            transcript: "this weekend",
            now: now
        )
        precondition(weekendTrip.request.dateRange != nil)
        precondition(
            (weekendTrip.request.durationDays ?? 0) >= 2
        )
        guard
            let italyDates =
                TripRequestInterpreter.interpretClarificationAnswer(
                    "May 10 to May 14, 2027",
                    for: .dates,
                    applyingTo: italy.request,
                    now: now
                ),
            let italyTravelers =
                TripRequestInterpreter.interpretClarificationAnswer(
                    "two people",
                    for: .travelers,
                    applyingTo: italyDates,
                    now: now
                )
        else {
            preconditionFailure(
                "Expected contextual clarification answers"
            )
        }
        precondition(
            TripRequestInterpreter.validate(
                italyTravelers,
                now: now
            ).isEmpty
        )
        precondition(italyTravelers.totalBudget == nil)
        precondition(
            TripRequestInterpreter.isConversationCompletion(
                "That's it"
            )
        )
        precondition(
            TripRequestInterpreter.isConversationCompletion(
                "Use that"
            )
        )
        precondition(
            TripRequestInterpreter.isConversationCompletion(
                "that's all"
            )
        )
        precondition(
            TripRequestInterpreter.isConversationCompletion(
                "all good"
            )
        )
        precondition(
            TripRequestInterpreter.isConversationCompletion(
                "plan it"
            )
        )

        let emptyExamples =
            TripRequestInterpreter.omittedOptionalExamples(
                for: TripRequest()
            )
        precondition(emptyExamples == ["a budget", "where you're leaving from"])

        let emptyPrompts = PlanClarificationBuilder.prompts(
            for: TripRequest(),
            now: now
        )
        precondition(emptyPrompts.count == 3)
        precondition(
            Set(emptyPrompts.map(\.field))
                == [.destination, .dates, .travelers]
        )

        let complete = TripRequestInterpreter.interpret(
            transcript:
                "Fly from Atlanta to Tokyo for two travelers "
                + "under €4,500 from 2027-06-10 to 2027-06-17.",
            now: now
        )

        precondition(complete.request.origin?.name == "Atlanta")
        precondition(
            complete.request.destinations.first?.name == "Tokyo"
        )
        precondition(complete.request.travelerCount == 2)
        precondition(
            complete.request.totalBudget?.amount == Decimal(4_500)
        )
        precondition(
            complete.request.totalBudget?.currencyCode == "EUR"
        )
        precondition(complete.request.durationDays == 8)
        precondition(complete.issues.isEmpty)
        precondition(
            TripRequestInterpreter.omittedOptionalExamples(
                for: complete.request
            ) == ["dietary needs", "accessibility needs"]
        )

        guard
            case .updated(let enriched, let enrichedSummary) =
                TripRequestInterpreter.interpretFollowUp(
                    transcript:
                        "Hey GIA, add museums, vegetarian food, "
                        + "a pool, and nonstop flights",
                    applyingTo: complete.request,
                    now: now
                )
        else {
            preconditionFailure("Expected an additive follow-up")
        }
        precondition(enriched.interests.contains(.museums))
        precondition(
            enriched.dietaryRequirements.contains(.vegetarian)
        )
        precondition(
            enriched.hotelPreferences.requiredAmenities.contains(.pool)
        )
        precondition(
            enriched.flightPreferences.stopPreference == .nonstopOnly
        )
        precondition(!enrichedSummary.isEmpty)

        guard
            case .updated(let reduced, _) =
                TripRequestInterpreter.interpretFollowUp(
                    transcript:
                        "Remove museums, the pool, and vegetarian food",
                    applyingTo: enriched,
                    now: now
                )
        else {
            preconditionFailure("Expected a removal follow-up")
        }
        precondition(!reduced.interests.contains(.museums))
        precondition(
            !reduced.dietaryRequirements.contains(.vegetarian)
        )
        precondition(
            !reduced.hotelPreferences.requiredAmenities.contains(.pool)
        )

        guard
            case .updated(let resized, _) =
                TripRequestInterpreter.interpretFollowUp(
                    transcript:
                        "Change it to four travelers and budget to $6000",
                    applyingTo: reduced,
                    now: now
                )
        else {
            preconditionFailure("Expected a numeric follow-up")
        }
        precondition(resized.travelerCount == 4)
        precondition(
            resized.totalBudget?.amount == Decimal(6_000)
        )

        guard
            case .updated(let redirected, _) =
                TripRequestInterpreter.interpretFollowUp(
                    transcript: "Change the destination to Vancouver",
                    applyingTo: resized,
                    now: now
                )
        else {
            preconditionFailure("Expected a destination follow-up")
        }
        precondition(
            redirected.destinations.first?.name == "Vancouver"
        )
        if case .cancelled =
            TripRequestInterpreter.interpretFollowUp(
                transcript: "Never mind",
                applyingTo: redirected,
                now: now
            )
        {
            // Expected.
        } else {
            preconditionFailure("Expected follow-up cancellation")
        }

        let international = TripRequestInterpreter.interpret(
            transcript:
                "Plan a five-day trip to São Paulo for a couple "
                + "under €3k from May 10 to May 14, 2027. "
                + "We want business class nonstop flights, a checked "
                + "bag, and a refundable 4-star hotel with a pool, "
                + "wifi, and free cancellation. Keep a relaxed pace.",
            now: now
        )
        precondition(
            international.request.destinations.first?.name
                == "São Paulo"
        )
        precondition(international.request.travelerCount == 2)
        precondition(
            international.request.totalBudget?.amount
                == Decimal(3_000)
        )
        precondition(
            international.request.totalBudget?.currencyCode == "EUR"
        )
        precondition(international.request.dateRange != nil)
        precondition(international.request.durationDays == 5)
        precondition(
            international.request.flightPreferences.travelClass
                == .business
        )
        precondition(
            international.request.flightPreferences.stopPreference
                == .nonstopOnly
        )
        precondition(
            international.request.flightPreferences
                .checkedBagRequired
        )
        precondition(
            international.request.hotelPreferences
                .minimumStarRating == 4
        )
        precondition(
            international.request.hotelPreferences
                .requiredAmenities.contains(.pool)
        )
        precondition(
            international.request.hotelPreferences
                .requiredAmenities.contains(.wifi)
        )
        precondition(
            international.request.hotelPreferences
                .refundablePreferred
        )
        precondition(international.request.preferredPace == .relaxed)
        precondition(international.issues.isEmpty)

        let unicodeRoute = TripRequestInterpreter.interpret(
            transcript:
                "Fly from Montréal to Reykjavík for three travelers "
                + "under 5000 CAD from 2027-08-02 to 2027-08-08.",
            now: now
        )
        precondition(unicodeRoute.request.origin?.name == "Montréal")
        precondition(
            unicodeRoute.request.destinations.first?.name
                == "Reykjavík"
        )
        precondition(
            unicodeRoute.request.totalBudget?.currencyCode == "CAD"
        )
        precondition(unicodeRoute.issues.isEmpty)

        let destinationMatrix = [
            (
                "Chicago",
                "Plan a trip to Chicago for two travelers under $3000 "
                    + "from May 1 to May 4, 2027."
            ),
            (
                "Tokyo",
                "Plan a trip to Tokyo for two travelers under $5000 "
                    + "from May 1 to May 4, 2027."
            ),
            (
                "Lisbon",
                "Plan a trip to Lisbon for two travelers under $3000 "
                    + "from May 1 to May 4, 2027."
            ),
            (
                "Vancouver",
                "Plan a trip to Vancouver for two travelers under 4000 CAD "
                    + "from May 1 to May 4, 2027."
            ),
            (
                "Reykjavík",
                "Plan a trip to Reykjavík for two travelers under €4000 "
                    + "from May 1 to May 4, 2027."
            )
        ]
        let replacementSession = TripPlanningSession()
        for (destination, transcript) in destinationMatrix {
            let interpretation = TripRequestInterpreter.interpret(
                transcript: transcript,
                now: now
            )
            precondition(
                interpretation.request.destinations.first?.name
                    == destination
            )
            precondition(interpretation.issues.isEmpty)

            if replacementSession.phase != .idle {
                replacementSession.resetForNewRequest()
            }
            try replacementSession.beginListening(source: .manual)
            try replacementSession.beginTranscribing()
            try replacementSession.beginValidation(
                request: interpretation.request
            )
            precondition(
                replacementSession.currentRequest?
                    .destinations.first?.name == destination
            )
            precondition(
                replacementSession.currentRequest?
                    .destinations.first?.name != "Japan"
            )
        }

        let session = TripPlanningSession()
        try session.beginListening(source: .manual)
        try session.beginTranscribing()
        try session.beginValidation(request: spoken.request)
        try session.requestClarification(
            for: spoken.clarificationFields
        )
        precondition(session.phase == .needsClarification)

        var correctedRequest = spoken.request
        correctedRequest.dateRange = complete.request.dateRange
        try session.replaceRequestDuringValidation(correctedRequest)
        let correctedIssues = TripRequestInterpreter.validate(
            correctedRequest,
            now: now
        )

        precondition(correctedIssues.isEmpty)
        precondition(
            PlanClarificationBuilder.prompts(
                for: correctedRequest,
                now: now
            ).isEmpty
        )
        precondition(session.phase == .validating)
        precondition(
            session.currentRequest?.dateRange
                == complete.request.dateRange
        )

        let paris = TripRequest(
            destinations: [TravelLocation(name: "Paris")],
            travelerCount: 3
        )
        let datesQuestion = GIAHumanReplyComposer.clarificationQuestion(
            for: .dates,
            request: paris,
            userUtterance: "Me and two other buddies",
            retrying: false
        )
        precondition(
            datesQuestion.localizedCaseInsensitiveContains("paris")
        )
        precondition(
            datesQuestion.localizedCaseInsensitiveContains("that's great")
                || datesQuestion.localizedCaseInsensitiveContains("nice")
                || datesQuestion.localizedCaseInsensitiveContains("love that")
                || datesQuestion.localizedCaseInsensitiveContains("perfect")
        )
        precondition(
            datesQuestion.localizedCaseInsensitiveContains("beautiful")
                || datesQuestion.localizedCaseInsensitiveContains("gorgeous")
                || datesQuestion.localizedCaseInsensitiveContains("great pick")
        )
        precondition(
            datesQuestion.localizedCaseInsensitiveContains("dates")
        )
        let laterDatesQuestion = GIAHumanReplyComposer.clarificationQuestion(
            for: .travelers,
            request: paris,
            userUtterance: "mid-May",
            retrying: false,
            alreadyComplimentedDestination: true
        )
        precondition(
            laterDatesQuestion.localizedCaseInsensitiveContains("people")
        )
        precondition(
            !laterDatesQuestion.localizedCaseInsensitiveContains("beautiful")
        )
        precondition(
            !laterDatesQuestion.localizedCaseInsensitiveContains("gorgeous")
        )
        let retryQuestion = GIAHumanReplyComposer.clarificationQuestion(
            for: .dates,
            request: paris,
            retrying: true
        )
        precondition(
            retryQuestion.localizedCaseInsensitiveContains(
                "I still need travel dates"
            )
        )
        precondition(
            !retryQuestion.localizedCaseInsensitiveContains("beautiful")
        )

        print("Trip request interpretation and correction passed.")
    }
}
