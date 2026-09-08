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
        permissionDenied: Bool = false,
        recognitionUnavailable: Bool = false
    ) -> GIAAssistantPresentationState {
        if permissionDenied || recognitionUnavailable {
            return .error
        }
        switch responseState {
        case .playing:
            return .speaking
        case .generating:
            return .processing
        case .failed:
            return .error
        case .idle:
            break
        }

        switch phase {
        case .idle, .ready, .cancelled:
            return .idle
        case .wakePhraseDetected:
            return .wakeDetected
        case .listening, .transcribing:
            return .listening
        case .validating, .needsClarification:
            return .listening
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
