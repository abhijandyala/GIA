import Foundation

enum GIAClarificationTurn: Equatable, Sendable {
    case required(TripClarificationField)
    case optionalPreferences
}

enum GIAVoiceResumeAction: Equatable, Sendable {
    case startRequestTranscription
    case startWakePhrase
    case none
}

enum GIAVoiceTurnPolicy {
    static func shouldArmWakePhrase(
        phase: TripPlanningPhase,
        clarificationTurnActive: Bool,
        isEndingConversation: Bool,
        usesTypedInput: Bool,
        isReplyModePickerPresented: Bool,
        isSpeakingOrGenerating: Bool
    ) -> Bool {
        if
            isEndingConversation
            || usesTypedInput
            || isReplyModePickerPresented
            || isSpeakingOrGenerating
            || clarificationTurnActive
        {
            return false
        }

        switch phase {
        case
            .wakePhraseDetected,
            .listening,
            .transcribing,
            .validating,
            .needsClarification,
            .returning,
            .cancelled:
            return false
        case
            .idle,
            .ready,
            .failed,
            .searching,
            .comparing,
            .buildingItinerary,
            .presenting,
            .partiallyAvailable:
            return true
        }
    }

    static func needsUserReply(
        phase: TripPlanningPhase,
        clarificationTurnActive: Bool,
        isFollowUpRequest: Bool
    ) -> Bool {
        if clarificationTurnActive || isFollowUpRequest {
            return true
        }
        switch phase {
        case
            .wakePhraseDetected,
            .listening,
            .transcribing,
            .needsClarification:
            return true
        default:
            return false
        }
    }

    static func isMicrophoneCapturing(_ mode: VoiceSessionMode) -> Bool {
        switch mode {
        case .wakePhrase, .requestTranscription, .bargeIn:
            true
        case .stopped:
            false
        }
    }

    static func shouldBlockNewWake(
        phase _: TripPlanningPhase,
        voiceMode: VoiceSessionMode,
        isReturningToWorld: Bool,
        isReplyModePickerPresented: Bool,
        isSpeakingOrGenerating: Bool
    ) -> Bool {
        if isReturningToWorld || isReplyModePickerPresented {
            return true
        }
        if isSpeakingOrGenerating {
            return true
        }
        return isMicrophoneCapturing(voiceMode)
    }

    static func shouldRecoverConversationListening(
        phase: TripPlanningPhase,
        voiceMode: VoiceSessionMode,
        clarificationTurnActive: Bool,
        isFollowUpRequest: Bool,
        isSpeakingOrGenerating: Bool
    ) -> Bool {
        if isSpeakingOrGenerating {
            return false
        }
        if isMicrophoneCapturing(voiceMode) {
            return false
        }
        return needsUserReply(
            phase: phase,
            clarificationTurnActive: clarificationTurnActive,
            isFollowUpRequest: isFollowUpRequest
        )
    }

    static func resumeActionAfterPlayback(
        phase: TripPlanningPhase,
        clarificationTurnActive: Bool,
        isFollowUpRequest: Bool,
        usesTypedInput: Bool
    ) -> GIAVoiceResumeAction {
        if usesTypedInput {
            return .none
        }
        if needsUserReply(
            phase: phase,
            clarificationTurnActive: clarificationTurnActive,
            isFollowUpRequest: isFollowUpRequest
        ) {
            return .startRequestTranscription
        }
        if shouldArmWakePhrase(
            phase: phase,
            clarificationTurnActive: clarificationTurnActive,
            isEndingConversation: false,
            usesTypedInput: usesTypedInput,
            isReplyModePickerPresented: false,
            isSpeakingOrGenerating: false
        ) {
            return .startWakePhrase
        }
        return .none
    }

    static func shouldQueueTranscriptDuringPlayback(
        isHearingOwnPlayback: Bool
    ) -> Bool {
        isHearingOwnPlayback
    }

    static func canPromoteToTranscribing(
        _ phase: TripPlanningPhase
    ) -> Bool {
        switch phase {
        case .listening, .needsClarification:
            true
        default:
            false
        }
    }
}
