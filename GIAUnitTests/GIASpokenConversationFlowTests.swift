import XCTest
@testable import GIA

final class GIASpokenConversationFlowTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    func testWakeIsNotArmedWhileConversationNeedsAReply() {
        XCTAssertFalse(
            GIAVoiceTurnPolicy.shouldArmWakePhrase(
                phase: .listening,
                clarificationTurnActive: false,
                isEndingConversation: false,
                usesTypedInput: false,
                isReplyModePickerPresented: false,
                isSpeakingOrGenerating: false
            )
        )
        XCTAssertFalse(
            GIAVoiceTurnPolicy.shouldArmWakePhrase(
                phase: .needsClarification,
                clarificationTurnActive: true,
                isEndingConversation: false,
                usesTypedInput: false,
                isReplyModePickerPresented: false,
                isSpeakingOrGenerating: false
            )
        )
        XCTAssertEqual(
            GIAVoiceTurnPolicy.resumeActionAfterPlayback(
                phase: .listening,
                clarificationTurnActive: false,
                isFollowUpRequest: false,
                usesTypedInput: false
            ),
            .startRequestTranscription
        )
        XCTAssertEqual(
            GIAVoiceTurnPolicy.resumeActionAfterPlayback(
                phase: .needsClarification,
                clarificationTurnActive: true,
                isFollowUpRequest: false,
                usesTypedInput: false
            ),
            .startRequestTranscription
        )
    }

    func testClosedMicrophoneDuringListeningIsRecoverable() {
        XCTAssertTrue(
            GIAVoiceTurnPolicy.shouldRecoverConversationListening(
                phase: .listening,
                voiceMode: .stopped,
                clarificationTurnActive: false,
                isFollowUpRequest: false,
                isSpeakingOrGenerating: false
            )
        )
        XCTAssertFalse(
            GIAVoiceTurnPolicy.shouldRecoverConversationListening(
                phase: .listening,
                voiceMode: .requestTranscription,
                clarificationTurnActive: false,
                isFollowUpRequest: false,
                isSpeakingOrGenerating: false
            )
        )
        XCTAssertFalse(
            GIAVoiceTurnPolicy.shouldBlockNewWake(
                phase: .listening,
                voiceMode: .stopped,
                isReturningToWorld: false,
                isReplyModePickerPresented: false,
                isSpeakingOrGenerating: false
            )
        )
        XCTAssertTrue(
            GIAVoiceTurnPolicy.shouldQueueTranscriptDuringPlayback(
                isHearingOwnPlayback: true
            )
        )
        XCTAssertTrue(
            GIAVoiceTurnPolicy.canPromoteToTranscribing(.needsClarification)
        )
    }

    @MainActor
    func testJapanCountryConversationReachesSearchWithoutEditCommands() throws {
        let request = try GIASpokenConversationFlow().runVoiceScript(
            destinationUtterance: "I want to go to Japan",
            dateUtterance: "May 10 to May 14, 2027",
            travelerUtterance: "four travelers",
            now: now
        )

        XCTAssertEqual(request.destinations.first?.name, "Japan")
        XCTAssertEqual(request.travelerCount, 4)
        XCTAssertEqual(request.durationDays, 5)
        let datesQuestion = GIAHumanReplyComposer.clarificationQuestion(
            for: .dates,
            request: TripRequest(
                destinations: [TravelLocation(name: "Japan")]
            ),
            userUtterance: "I want to go to Japan"
        )
        XCTAssertFalse(datesQuestion.localizedCaseInsensitiveContains("change"))
        XCTAssertFalse(datesQuestion.localizedCaseInsensitiveContains("remove"))
    }

    @MainActor
    func testTodayThroughNextWeekDoesNotAskForDatesAgain() throws {
        let flow = GIASpokenConversationFlow()
        try flow.startListening()

        XCTAssertEqual(
            flow.ingestInitial("I want to go to Japan", now: now),
            .askRequired(.dates)
        )
        XCTAssertEqual(
            flow.ingestClarification(
                "today through next week",
                now: now
            ),
            .askRequired(.travelers)
        )

        let request = try XCTUnwrap(flow.session.currentRequest)
        XCTAssertNotNil(request.dateRange)
        XCTAssertFalse(
            TripRequestInterpreter.validate(request, now: now)
                .contains { $0.field == .dates }
        )
    }

    @MainActor
    func testLisbonCityConversationAcceptsSeveralFactsInOneAnswer() throws {
        let flow = GIASpokenConversationFlow()
        try flow.startListening()

        XCTAssertEqual(
            flow.ingestInitial("Plan a trip to Lisbon", now: now),
            .askRequired(.dates)
        )
        XCTAssertEqual(
            flow.ingestClarification(
                "May 10 to May 14, 2027 for four travelers under $6000",
                now: now
            ),
            .askOptionalPreferences
        )
        XCTAssertEqual(
            flow.ingestClarification("that's it", now: now),
            .readyToSearch
        )

        let request = try XCTUnwrap(flow.session.currentRequest)
        XCTAssertEqual(request.destinations.first?.name, "Lisbon")
        XCTAssertEqual(request.travelerCount, 4)
        XCTAssertEqual(request.totalBudget?.amount, Decimal(6_000))
        XCTAssertTrue(
            TripRequestInterpreter.validate(request, now: now).isEmpty
        )
    }

    @MainActor
    func testNewYorkCityConversationCompletesAcrossTurns() throws {
        let request = try GIASpokenConversationFlow().runVoiceScript(
            destinationUtterance: "I want to go to New York",
            dateUtterance: "June 10 to June 17, 2027",
            travelerUtterance: "two people",
            now: now
        )

        XCTAssertEqual(request.destinations.first?.name, "New York")
        XCTAssertEqual(request.travelerCount, 2)
        XCTAssertEqual(request.durationDays, 8)
        XCTAssertTrue(
            TripRequestInterpreter.validate(request, now: now).isEmpty
        )
    }

    func testLiveDiscKeepsSpeakingAndListeningChrome() {
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
                responseState: .idle,
                voiceMode: .stopped,
                recognitionUnavailable: true,
                discVisible: true
            ),
            .listening
        )
        XCTAssertEqual(
            GIAAssistantPresentationState.resolve(
                phase: .searching,
                responseState: .generating,
                voiceMode: .stopped,
                discVisible: true
            ),
            .speaking
        )
        XCTAssertEqual(
            GIAAssistantPresentationState.resolve(
                phase: .validating,
                responseState: .idle,
                voiceMode: .stopped,
                discVisible: true
            ),
            .listening
        )
        XCTAssertEqual(
            GIAAssistantPresentationState.resolve(
                phase: .validating,
                responseState: .generating,
                voiceMode: .stopped,
                discVisible: true
            ),
            .speaking
        )
        XCTAssertEqual(
            GIAAssistantPresentationState.resolve(
                phase: .searching,
                responseState: .idle,
                voiceMode: .stopped,
                discVisible: true
            ),
            .processing
        )
    }

    @MainActor
    func testPresentationNeverSaysListeningWhenMicrophoneIsClosed() {
        XCTAssertEqual(
            GIAAssistantPresentationState.resolve(
                phase: .listening,
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
                responseState: .playing,
                voiceMode: .stopped
            ),
            .speaking
        )
    }
}
