import Foundation

@main
enum AssistantPresentationStateVerificationMain {
    static func main() {
        precondition(
            resolve(.idle, .idle) == .idle
        )
        precondition(
            resolve(.wakePhraseDetected, .idle)
                == .wakeDetected
        )
        precondition(
            resolve(.transcribing, .idle) == .listening
        )
        precondition(
            resolve(.validating, .idle) == .processing
        )
        precondition(
            GIAAssistantPresentationState.resolve(
                phase: .validating,
                responseState: .idle,
                discVisible: true
            ) == .listening
        )
        precondition(
            resolve(.needsClarification, .generating)
                == .speaking
        )
        precondition(
            resolve(.validating, .playing) == .speaking
        )
        precondition(
            resolve(.validating, .failed) == .error
        )
        precondition(
            resolve(.failed, .idle) == .error
        )
        precondition(
            resolve(.returning, .idle) == .returning
        )
        precondition(
            GIAAssistantPresentationState.resolve(
                phase: .idle,
                responseState: .idle,
                permissionDenied: true
            ) == .error
        )
        precondition(
            GIAAssistantPresentationState.allCases.allSatisfy {
                !$0.statusText.isEmpty
                    && !$0.accessibilityValue.isEmpty
            }
        )

        print("Assistant presentation state mapping passed.")
    }

    private static func resolve(
        _ phase: TripPlanningPhase,
        _ response: GIAResponseState
    ) -> GIAAssistantPresentationState {
        GIAAssistantPresentationState.resolve(
            phase: phase,
            responseState: response
        )
    }
}
