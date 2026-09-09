enum GIAVoiceVisualState: Equatable {
    case world
    case activating
    case listening
    case speaking
    case pause
    case returningToWorld
}

enum GIAAssistantPresentationState:
    String,
    CaseIterable,
    Equatable
{
    case idle
    case wakeDetected
    case listening
    case processing
    case speaking
    case error
    case returning

    var statusText: String {
        switch self {
        case .idle:
            "Ready"
        case .wakeDetected:
            "Wake detected"
        case .listening:
            "Listening"
        case .processing:
            "Working on it"
        case .speaking:
            "Speaking"
        case .error:
            "Needs attention"
        case .returning:
            "Returning"
        }
    }

    var accessibilityValue: String {
        switch self {
        case .idle:
            "Waiting for activation"
        case .wakeDetected:
            "G.I.A. heard its name"
        case .listening:
            "Listening for a travel request"
        case .processing:
            "G.I.A. is thinking about the request"
        case .speaking:
            "G.I.A. is speaking"
        case .error:
            "A recoverable voice error occurred"
        case .returning:
            "Returning to the world view"
        }
    }

    static func resolve(
        phase: TripPlanningPhase,
        responseState: GIAResponseState,
        voiceMode: VoiceSessionMode = .stopped,
        permissionDenied: Bool = false,
        recognitionUnavailable: Bool = false,
        discVisible: Bool = false
    ) -> GIAAssistantPresentationState {
        if permissionDenied {
            return .error
        }

        let waitingForSpokenReply =
            discVisible
            && (
                phase == .wakePhraseDetected
                || phase == .listening
                || phase == .transcribing
                || phase == .needsClarification
                || phase == .validating
            )

        switch responseState {
        case .playing:
            return .speaking
        case .generating:
            return discVisible ? .speaking : .processing
        case .failed:
            return .error
        case .idle:
            break
        }

        if recognitionUnavailable && !waitingForSpokenReply {
            return .error
        }

        switch phase {
        case .idle, .ready, .cancelled:
            return discVisible ? .listening : .idle
        case .wakePhraseDetected:
            return .wakeDetected
        case .listening, .transcribing, .needsClarification, .validating:
            // The live disc should stay cyan Listening while G.I.A. is
            // still in a talk turn. "Working on it" is for Plan search,
            // not the speak-to-listen handoff.
            if waitingForSpokenReply {
                return .listening
            }
            return voiceMode == .requestTranscription
                ? .listening
                : .processing
        case
            .searching,
            .comparing,
            .buildingItinerary,
            .presenting,
            .partiallyAvailable:
            return .processing
        case .failed:
            return .error
        case .returning:
            return .returning
        }
    }
}
