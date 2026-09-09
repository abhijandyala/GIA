import XCTest
@testable import GIA

final class GIAConversationRegressionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    func testMissingInformationAndSeveralFactsInOneAnswer() throws {
        let initial = TripRequestInterpreter.interpret(
            transcript: "Plan a trip to Lisbon",
            now: now
        )
        XCTAssertEqual(
            Set(initial.clarificationFields),
            [.dates, .travelers]
        )

        let answered = try XCTUnwrap(
            TripRequestInterpreter.interpretClarificationAnswer(
                "May 10 to May 14, 2027 for four travelers under $6000",
                for: .dates,
                applyingTo: initial.request,
                now: now
            )
        )
        XCTAssertEqual(answered.durationDays, 5)
        XCTAssertEqual(answered.travelerCount, 4)
        XCTAssertEqual(answered.totalBudget?.amount, Decimal(6_000))
        XCTAssertTrue(
            TripRequestInterpreter.validate(answered, now: now).isEmpty
        )
    }

    func testChangingAnswersPreservesUnchangedFacts() throws {
        let original = TripRequestInterpreter.interpret(
            transcript:
                "Fly from Atlanta to Paris for two travelers under $4000 "
                + "from May 10 to May 14, 2027",
            now: now
        ).request
        let originalDates = try XCTUnwrap(original.dateRange)

        guard
            case .updated(let changed, _) =
                TripRequestInterpreter.interpretFollowUp(
                    transcript:
                        "Change the destination to Vancouver, make it six "
                        + "travelers, and change the budget to 6500 CAD",
                    applyingTo: original,
                    now: now
                )
        else {
            return XCTFail("Expected a supported multi-field change")
        }

        XCTAssertEqual(changed.destinations.first?.name, "Vancouver")
        XCTAssertEqual(changed.travelerCount, 6)
        XCTAssertEqual(changed.totalBudget?.amount, Decimal(6_500))
        XCTAssertEqual(changed.totalBudget?.currencyCode, "CAD")
        XCTAssertEqual(changed.dateRange, originalDates)
        XCTAssertEqual(changed.origin?.name, "Atlanta")
    }

    func testRepeatedQuestionUsesRetryCopyWithoutRepeatedCompliment() {
        let request = TripRequest(
            destinations: [TravelLocation(name: "Paris")],
            travelerCount: 2
        )
        let first = GIAHumanReplyComposer.clarificationQuestion(
            for: .dates,
            request: request,
            userUtterance: "Paris sounds good",
            retrying: false
        )
        let retry = GIAHumanReplyComposer.clarificationQuestion(
            for: .dates,
            request: request,
            retrying: true,
            alreadyComplimentedDestination: true
        )

        XCTAssertNotEqual(first, retry)
        XCTAssertTrue(
            retry.localizedCaseInsensitiveContains("still need travel dates")
        )
        XCTAssertFalse(retry.localizedCaseInsensitiveContains("beautiful"))
        XCTAssertFalse(retry.localizedCaseInsensitiveContains("gorgeous"))
    }

    func testJapanRequestAsksForDatesInsteadOfEditCommands() throws {
        let interpretation = TripRequestInterpreter.interpret(
            transcript: "I want to go to Japan",
            now: now
        )
        let field = try XCTUnwrap(
            TripRequestInterpreter.preferredClarificationField(
                in: interpretation.issues
            )
        )
        let reply = GIAHumanReplyComposer.clarificationQuestion(
            for: field,
            request: interpretation.request,
            userUtterance: "I want to go to Japan"
        )

        XCTAssertEqual(field, .dates)
        XCTAssertTrue(
            reply.localizedCaseInsensitiveContains("what dates")
        )
        XCTAssertFalse(
            reply.localizedCaseInsensitiveContains("change")
        )
        XCTAssertFalse(
            reply.localizedCaseInsensitiveContains("remove")
        )
    }

    func testRelativePhrasesFillTravelDatesFromTodayThroughNextWeek() throws {
        let expected = todayThroughNextWeek(now: now)
        let phrases = [
            "today through next week",
            "today to next week",
            "today from next week",
            "today for next week",
            "from today through next week",
            "today form next week",
            "today form enxt week",
            "today thru next week",
            "today until next week"
        ]

        for phrase in phrases {
            let initial = TripRequestInterpreter.interpret(
                transcript: "Plan a trip to Japan",
                now: now
            )
            let answered = try XCTUnwrap(
                TripRequestInterpreter.interpretClarificationAnswer(
                    phrase,
                    for: .dates,
                    applyingTo: initial.request,
                    now: now
                ),
                phrase
            )
            let range = try XCTUnwrap(answered.dateRange, phrase)
            XCTAssertEqual(range.start, expected.start, phrase)
            XCTAssertEqual(range.end, expected.end, phrase)
            XCTAssertEqual(
                answered.durationDays,
                expected.durationDays,
                phrase
            )
            XCTAssertFalse(
                TripRequestInterpreter.validate(answered, now: now)
                    .contains { $0.field == .dates },
                phrase
            )
        }
    }

    func testStayLengthStillWinsOverASpanningNextWeekWindow() throws {
        let initial = TripRequestInterpreter.interpret(
            transcript: "Plan a trip to Paris",
            now: now
        )
        let answered = try XCTUnwrap(
            TripRequestInterpreter.interpretClarificationAnswer(
                "now till next week i can go there, "
                    + "and from there i want to stay for a week",
                for: .dates,
                applyingTo: initial.request,
                now: now
            )
        )
        let range = try XCTUnwrap(answered.dateRange)
        let calendar = tripCalendar()
        let today = calendar.startOfDay(for: now)
        let end = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 6, to: today)
        )

        XCTAssertEqual(range.start, today)
        XCTAssertEqual(range.end, end)
        XCTAssertEqual(answered.durationDays, 7)
    }

    func testBareNextWeekStillUsesThatWeekNotToday() throws {
        let expected = nextWeek(now: now)
        let result = TripRequestInterpreter.interpret(
            transcript: "plan a trip to Paris next week",
            now: now
        ).request
        let range = try XCTUnwrap(result.dateRange)
        XCTAssertEqual(range.start, expected.start)
        XCTAssertEqual(range.end, expected.end)
        XCTAssertEqual(result.durationDays, 7)
    }

    func testOptionalFollowUpCoversFlightsHotelsAndActivities() {
        let request = TripRequest(
            destinations: [TravelLocation(name: "Japan")],
            dateRange: TripDateRange(
                start: now.addingTimeInterval(86_400 * 30),
                end: now.addingTimeInterval(86_400 * 35),
                timeZoneIdentifier: "Asia/Tokyo"
            ),
            travelerCount: 4
        )
        let omitted = TripRequestInterpreter.omittedOptionalExamples(
            for: request
        )
        let reply = GIAHumanReplyComposer.optionalPreferenceQuestion(
            omittedExamples: omitted,
            request: request,
            alreadyComplimentedDestination: true
        )

        XCTAssertTrue(omitted.contains("where you're leaving from"))
        XCTAssertTrue(omitted.contains("your budget"))
        XCTAssertTrue(omitted.contains("flight timing or stop preferences"))
        XCTAssertTrue(omitted.contains("what you need from a hotel"))
        XCTAssertTrue(omitted.contains("what you want to do there"))
        XCTAssertTrue(reply.localizedCaseInsensitiveContains("flights"))
        XCTAssertTrue(reply.localizedCaseInsensitiveContains("hotels"))
        XCTAssertTrue(
            reply.localizedCaseInsensitiveContains("things to do")
        )
        XCTAssertLessThanOrEqual(reply.count, 140)
    }

    func testDatesBudgetsAndGroupSizes() {
        let cases: [(String, Int, Decimal, String)] = [
            (
                "Tokyo for a couple under $3,500 from 2027-06-10 to 2027-06-17",
                2,
                3_500,
                "USD"
            ),
            (
                "Lisbon for eight travelers under 9000 EUR May 10 to May 14, 2027",
                8,
                9_000,
                "EUR"
            ),
            (
                "Vancouver for twelve people under 12000 CAD next week",
                12,
                12_000,
                "CAD"
            )
        ]

        for (transcript, travelers, budget, currency) in cases {
            let result = TripRequestInterpreter.interpret(
                transcript: transcript,
                now: now
            ).request
            XCTAssertEqual(result.travelerCount, travelers, transcript)
            XCTAssertEqual(result.totalBudget?.amount, budget, transcript)
            XCTAssertEqual(result.totalBudget?.currencyCode, currency, transcript)
            XCTAssertNotNil(result.dateRange, transcript)
        }
    }

    @MainActor
    func testDebugTranscriptInjectionPublishesSpeechCompletionEvent() {
        let coordinator = VoiceSessionCoordinator()
        let oldSequence = coordinator.transcriptionSequence

        coordinator.injectCompletedTranscript(
            "Hey GIA, plan a trip to Chicago next week"
        )

        XCTAssertEqual(
            coordinator.completedTranscript,
            "plan a trip to Chicago next week"
        )
        XCTAssertEqual(coordinator.transcriptionSequence, oldSequence + 1)
    }

    @MainActor
    func testPlaybackCompletionLeavesPromptVisibleAndReleasesSpeakingState() {
        let coordinator = GIAResponseCoordinator(
            speechGenerator: nil,
            allowsSystemVoiceFallback: false
        )

        coordinator.simulateSuccessfulPlaybackCompletionForTesting(
            visibleText: "Where would you like to go?",
            clearsVisibleText: false
        )

        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertEqual(
            coordinator.visibleText,
            "Where would you like to go?"
        )
        XCTAssertFalse(coordinator.preservesListening)
    }

    @MainActor
    func testSpokenReplyStartsOnTheFirstSentence() {
        let text = "Japan is beautiful. What dates work for you?"

        XCTAssertEqual(
            GIAConversationCopy.firstSpokenPhrase(text),
            "Japan is beautiful."
        )
        XCTAssertEqual(
            GIAResponseCoordinator.speechRequestTexts(for: text),
            ["Japan is beautiful.", "What dates work for you?"]
        )
        XCTAssertEqual(
            GIAConversationCopy.spokenPlaybackSegments(
                for: "Nice."
            ),
            ["Nice."]
        )
        XCTAssertEqual(
            Set(GIAConversationBackchannel.phrases.map(\.text)).count,
            3
        )
        XCTAssertEqual(
            GIAConversationBackchannel.phrase(for: "today through next week"),
            GIAConversationBackchannel.phrase(for: "today through next week")
        )
        let coordinator = GIAResponseCoordinator(
            speechGenerator: nil,
            allowsSystemVoiceFallback: false
        )
        coordinator.beginHeldTurn()
        XCTAssertEqual(coordinator.state, .generating)
        XCTAssertTrue(coordinator.isHoldingConversationTurn)
        XCTAssertEqual(coordinator.visibleText, "")
    }

    func testPresentationStateOnlySaysListeningWhenMicrophoneIsOpen() {
        XCTAssertEqual(
            GIAAssistantPresentationState.resolve(
                phase: .needsClarification,
                responseState: .idle,
                voiceMode: .stopped
            ),
            .processing
        )
        XCTAssertEqual(
            GIAAssistantPresentationState.resolve(
                phase: .needsClarification,
                responseState: .idle,
                voiceMode: .requestTranscription
            ),
            .listening
        )
        XCTAssertEqual(
            GIAAssistantPresentationState.resolve(
                phase: .listening,
                responseState: .generating,
                voiceMode: .stopped,
                discVisible: true
            ),
            .speaking
        )
        XCTAssertEqual(
            GIAAssistantPresentationState.resolve(
                phase: .listening,
                responseState: .idle,
                voiceMode: .stopped,
                discVisible: true
            ),
            .listening
        )
        XCTAssertEqual(
            GIAAssistantPresentationState.resolve(
                phase: .needsClarification,
                responseState: .playing,
                voiceMode: .stopped
            ),
            .speaking
        )
        XCTAssertEqual(
            GIAAssistantPresentationState.resolve(
                phase: .validating,
                responseState: .idle,
                voiceMode: .stopped
            ),
            .processing
        )
    }

    @MainActor
    func testMockedAPIFailureIsRecoverableAndMakesNoBooking() async {
        let request = completeRequest()
        let session = preparedSession(for: request)
        let orchestrator = TripPlanningOrchestrator(
            service: MockTravelService(mode: .failure),
            strictProviderFailures: true
        )

        orchestrator.start(request: request, session: session)
        await waitUntil { orchestrator.state == .failed }

        XCTAssertEqual(orchestrator.state, .failed)
        XCTAssertEqual(session.phase, .failed)
        XCTAssertEqual(session.currentTrip?.bookings.count ?? 0, 0)
        XCTAssertEqual(orchestrator.fallbackReason, .serviceFailure)
    }

    @MainActor
    func testEmptyAPIResultsFinishWithoutInventedResults() async {
        let request = completeRequest()
        let session = preparedSession(for: request)
        let orchestrator = TripPlanningOrchestrator(
            service: MockTravelService(mode: .empty),
            strictProviderFailures: false
        )

        orchestrator.start(request: request, session: session)
        await waitUntil {
            orchestrator.state == .ready
                || orchestrator.state == .partiallyAvailable
                || orchestrator.state == .failed
        }

        XCTAssertNotEqual(orchestrator.state, .failed)
        let trip = try? XCTUnwrap(session.currentTrip)
        XCTAssertTrue(trip?.catalog.flightOffers.isEmpty == true)
        XCTAssertTrue(trip?.catalog.hotelOffers.isEmpty == true)
        XCTAssertTrue(trip?.catalog.places.isEmpty == true)
        XCTAssertTrue(trip?.itinerary.days.isEmpty == true)
        XCTAssertTrue(trip?.bookings.isEmpty == true)
    }

    func testItineraryGenerationUsesOnlyMockedFixtureSources() {
        let fixture = JudgeDemoTripFactory.makeTrip(retrievedAt: now)
        let results = TransientPlanningResults(
            flightOffers: fixture.catalog.flightOffers,
            hotelOffers: fixture.catalog.hotelOffers,
            places: fixture.catalog.places,
            events: fixture.catalog.timedEvents,
            weather: fixture.catalog.weatherSnapshots,
            routes: fixture.itinerary.transportationLegs
        )
        let assembled = TransientTripAssembler.finalizedTrip(
            request: fixture.request,
            results: results
        )

        XCTAssertFalse(assembled.itinerary.days.isEmpty)
        XCTAssertTrue(assembled.structuralIssues.isEmpty)
        XCTAssertTrue(
            assembled.catalog.flightOffers.allSatisfy {
                $0.provenance.origin == .demo
            }
        )
    }

    @MainActor
    func testBookingConfirmationStaysSimulatedAndIdempotent() throws {
        let fixture = JudgeDemoTripFactory.makeTrip(retrievedAt: now)
        let session = TripPlanningSession()
        try session.restorePersistedTrip(fixture)
        let offerID = try XCTUnwrap(fixture.catalog.flightOffers.first?.id)

        let first = try session.confirmFlightOffer(
            offerID,
            mode: .fblaDemo
        )
        let count = session.currentTrip?.bookings.count
        let repeated = try session.confirmFlightOffer(
            offerID,
            mode: .fblaDemo
        )

        XCTAssertEqual(first.mode, .demo)
        XCTAssertEqual(first.status, .demoConfirmed)
        XCTAssertNil(first.providerConfirmationCode)
        XCTAssertEqual(
            first.checkoutURL,
            fixture.catalog.flightOffers.first?.bookingURL
        )
        XCTAssertEqual(repeated.id, first.id)
        XCTAssertEqual(session.currentTrip?.bookings.count, count)
    }

    private func completeRequest() -> TripRequest {
        TripRequest(
            origin: TravelLocation(
                name: "Atlanta",
                city: "Atlanta",
                country: "United States",
                countryCode: "US",
                iataCode: "ATL",
                coordinate: GeoCoordinate(latitude: 33.64, longitude: -84.43),
                timeZoneIdentifier: "America/New_York"
            ),
            destinations: [
                TravelLocation(
                    name: "Lisbon",
                    city: "Lisbon",
                    country: "Portugal",
                    countryCode: "PT",
                    iataCode: "LIS",
                    coordinate: GeoCoordinate(latitude: 38.72, longitude: -9.14),
                    timeZoneIdentifier: "Europe/Lisbon"
                )
            ],
            dateRange: TripDateRange(
                start: Date(timeIntervalSince1970: 1_810_080_000),
                end: Date(timeIntervalSince1970: 1_810_425_600),
                timeZoneIdentifier: "Europe/Lisbon"
            ),
            travelerCount: 4,
            totalBudget: Money(amount: 6_000, currencyCode: "USD")
        )
    }

    @MainActor
    private func preparedSession(for request: TripRequest) -> TripPlanningSession {
        let session = TripPlanningSession()
        try? session.beginListening(source: .debug)
        try? session.beginTranscribing()
        try? session.beginValidation(request: request)
        return session
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 3,
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func tripCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    private func nextWeek(
        now: Date
    ) -> (start: Date, end: Date, durationDays: Int) {
        let calendar = tripCalendar()
        let today = calendar.startOfDay(for: now)
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: today
        )
        let thisWeekStart = calendar.date(from: components) ?? today
        let start = calendar.date(
            byAdding: .weekOfYear,
            value: 1,
            to: thisWeekStart
        ) ?? today
        let end = calendar.date(byAdding: .day, value: 6, to: start)
            ?? start
        return (start, end, 7)
    }

    private func todayThroughNextWeek(
        now: Date
    ) -> (start: Date, end: Date, durationDays: Int) {
        let calendar = tripCalendar()
        let start = calendar.startOfDay(for: now)
        let week = nextWeek(now: now)
        let duration = (calendar.dateComponents(
            [.day],
            from: start,
            to: week.end
        ).day ?? 0) + 1
        return (start, week.end, duration)
    }
}

private actor MockTravelService: TripPlanningServing {
    enum Mode {
        case empty
        case failure
    }

    let mode: Mode

    init(mode: Mode) {
        self.mode = mode
    }

    func resolveLocation(
        matching criteria: LocationResolutionCriteria
    ) async throws -> TravelLocation {
        try failIfNeeded()
        if criteria.query.localizedCaseInsensitiveContains("atlanta") {
            return TravelLocation(
                name: "Atlanta",
                city: "Atlanta",
                country: "United States",
                countryCode: "US",
                iataCode: "ATL",
                coordinate: GeoCoordinate(latitude: 33.64, longitude: -84.43),
                timeZoneIdentifier: "America/New_York"
            )
        }
        return TravelLocation(
            name: "Lisbon",
            city: "Lisbon",
            country: "Portugal",
            countryCode: "PT",
            iataCode: "LIS",
            coordinate: GeoCoordinate(latitude: 38.72, longitude: -9.14),
            timeZoneIdentifier: "Europe/Lisbon"
        )
    }

    func searchFlights(
        matching criteria: FlightSearchCriteria
    ) async throws -> [FlightOffer] {
        try failIfNeeded()
        return []
    }

    func completeRoundTrip(
        matching criteria: RoundTripFlightCompletionCriteria
    ) async throws -> [FlightOffer] {
        try failIfNeeded()
        return []
    }

    func searchHotels(
        matching criteria: HotelSearchCriteria
    ) async throws -> [HotelOffer] {
        try failIfNeeded()
        return []
    }

    func searchPlaces(
        matching criteria: PlaceSearchCriteria
    ) async throws -> [PlaceRecommendation] {
        try failIfNeeded()
        return []
    }

    func searchEvents(
        matching criteria: EventSearchCriteria
    ) async throws -> [TimedEvent] {
        try failIfNeeded()
        return []
    }

    func planRoutes(
        matching criteria: RoutePlanningCriteria
    ) async throws -> [TransportationLeg] {
        try failIfNeeded()
        return []
    }

    func weather(
        matching criteria: WeatherSearchCriteria
    ) async throws -> [WeatherSnapshot] {
        try failIfNeeded()
        return []
    }

    func generatePlan(
        matching criteria: TripGenerationCriteria
    ) async throws -> TripPlanBlueprint {
        try failIfNeeded()
        throw GatewayClientError.providerUnavailable(
            code: "mock_no_sources",
            message: "The mock has no itinerary sources."
        )
    }

    private func failIfNeeded() throws {
        if mode == .failure {
            throw GatewayClientError.providerUnavailable(
                code: "mock_api_failure",
                message: "The mocked provider is unavailable."
            )
        }
    }
}
