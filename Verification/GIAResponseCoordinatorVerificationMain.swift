import Foundation

@main
enum GIAResponseCoordinatorVerificationMain {
    @MainActor
    static func main() async {
        precondition(
            GIAResponsePhrase.requestCaptured.text
                == "Okay, I've got it."
        )
        precondition(
            GIAResponsePhrase.clarificationNeeded.text
                == "I need one more detail."
        )
        precondition(
            GIAResponsePhrase.betterFlightFound.text
                == "I found a better flight option."
        )
        precondition(
            GIAResponsePhrase.planReady.text
                == "Your plan is ready."
        )
        precondition(
            GIAResponsePhrase.timingConflict.text
                == "That change creates a timing conflict."
        )
        precondition(
            GIAResponsePhrase.greetingTrip.text
                == "What's up? What trip are we planning?"
        )
        precondition(
            GIAResponsePhrase.greetingDestination.text
                == "Hey, how are you doing? Where are we thinking of going?"
        )
        precondition(
            GIAResponsePhrase.greetingPlan.text
                == "I'm here. What's the plan?"
        )
        precondition(
            GIAResponsePhrase.goodbye.text == "See you later."
        )
        precondition(
            GIAResponsePhrase.keepGoing.text
                == "Oh, sorry, keep going."
        )
        precondition(
            GIAResponsePhrase.stillListening.text
                == "I'm here. Just tell me the trip."
        )
        precondition(
            GIAResponsePhrase.whatDoYouMean.text
                == "What do you mean?"
        )
        precondition(
            Set(GIAResponsePhrase.allCases.map(\.text)).count
                == GIAResponsePhrase.allCases.count
        )

        let coordinator = GIAResponseCoordinator(
            speechGenerator: nil,
            allowsSystemVoiceFallback: false
        )
        let played = await coordinator.speak(.planReady)
        precondition(!played)
        precondition(coordinator.state == .failed)
        precondition(
            coordinator.visibleText
                == "Your plan is ready to review."
        )
        precondition(coordinator.failureMessage != nil)
        precondition(coordinator.playbackLevel == 0)

        coordinator.stop()
        precondition(coordinator.state == .idle)
        precondition(coordinator.visibleText.isEmpty)
        precondition(coordinator.failureMessage == nil)

        let generatedCoordinator = GIAResponseCoordinator(
            speechGenerator: nil,
            responseGenerator: FixtureResponder(
                response: GIAConversationResponse(
                    spokenText:
                        "Okay—so, your request is ready.",
                    displayText: "Your request is ready.",
                    intent: .requestCaptured,
                    shouldContinueListening: false
                )
            ),
            allowsSystemVoiceFallback: false
        )
        _ = await generatedCoordinator.respond(
            to: GIAConversationContext(
                intent: .requestCaptured,
                requestSummary: "Destination: Chicago"
            )
        )
        precondition(!generatedCoordinator.usedFallbackResponse)
        precondition(
            generatedCoordinator.lastResponse?.spokenText
                == "Okay. So, your request is ready."
        )

        generatedCoordinator.presentText(
            GIAConversationResponse(
                spokenText: "Shown as text.",
                displayText: "Shown as text.",
                intent: .clarificationNeeded,
                shouldContinueListening: true
            )
        )
        precondition(
            generatedCoordinator.lastResponse?.displayText
                == "Shown as text."
        )
        precondition(generatedCoordinator.state == .idle)

        let invalidCoordinator = GIAResponseCoordinator(
            speechGenerator: nil,
            responseGenerator: FixtureResponder(
                response: GIAConversationResponse(
                    spokenText: "Wrong state.",
                    displayText: "Wrong state.",
                    intent: .resultsReady,
                    shouldContinueListening: false
                )
            ),
            allowsSystemVoiceFallback: false
        )
        _ = await invalidCoordinator.respond(
            to: GIAConversationContext(
                intent: .clarificationNeeded,
                requestSummary: "Travel dates are missing"
            )
        )
        precondition(invalidCoordinator.usedFallbackResponse)
        precondition(
            invalidCoordinator.lastResponse?.intent
                == .clarificationNeeded
        )
        precondition(
            invalidCoordinator.lastResponse?
                .shouldContinueListening == true
        )

        let slowCoordinator = GIAResponseCoordinator(
            speechGenerator: nil,
            responseGenerator: SlowResponder(),
            allowsSystemVoiceFallback: false
        )
        let startedAt = Date()
        _ = await slowCoordinator.respond(
            to: GIAConversationContext(
                intent: .requestCaptured,
                requestSummary: "Destination: Vancouver"
            )
        )
        precondition(Date().timeIntervalSince(startedAt) < 9.5)
        precondition(slowCoordinator.usedFallbackResponse)

        let cannedFallback = GIAConversationResponse(
            spokenText:
                "That's great — Paris is beautiful. "
                + "What dates work for you?",
            displayText:
                "That's great — Paris is beautiful. "
                + "What dates work for you?",
            intent: .clarificationNeeded,
            shouldContinueListening: true
        )
        let fallbackCoordinator = GIAResponseCoordinator(
            speechGenerator: nil,
            allowsSystemVoiceFallback: false
        )
        _ = await fallbackCoordinator.respond(
            to: GIAConversationContext(
                intent: .clarificationNeeded,
                requestSummary: "Destination: Paris"
            ),
            fallback: cannedFallback
        )
        precondition(fallbackCoordinator.usedFallbackResponse)
        precondition(
            fallbackCoordinator.lastResponse?.spokenText
                == cannedFallback.spokenText
        )

        var memory = GIAConversationMemory()
        precondition(
            memory.destinationComplimentFact(destination: "Paris")?
                .contains("Already complimented destination: no")
                == true
        )
        memory.remember(
            speaker: "GIA",
            text: "That's great — Paris is beautiful. What dates work?"
        )
        memory.markAsked("dates")
        memory.markDestinationComplimented("Paris")
        let nextFacts = memory.turnFacts(userUtterance: "mid-May")
        precondition(
            nextFacts.contains {
                $0.hasPrefix("User just replied to: dates")
            }
        )
        precondition(
            nextFacts.contains { $0.hasPrefix("Recent turns:") }
        )
        precondition(
            memory.destinationComplimentFact(destination: "Paris")?
                .contains("Already complimented destination: yes")
                == true
        )
        precondition(
            memory.hasComplimented("paris")
        )
        precondition(
            GIAConversationCopy.displayed(
                "Meet Mon, Sep 8. 4 hrs approx."
            )
                == "Meet Monday, September 8. 4 hours approximately."
        )
        precondition(
            GIAConversationCopy.spoken(
                "Nice – mid-May works."
            )
                == "Nice. Mid-May works."
        )
        precondition(
            GIASpokenPhraseSplitter.leadingPhrase(
                in:
                    "Nice — mid-May works. "
                    + "How many people are traveling?"
            )
                == "Nice — mid-May works."
        )
        precondition(
            GIASpokenPhraseSplitter.remainder(
                after: "Nice — mid-May works.",
                in:
                    "Nice — mid-May works. "
                    + "How many people are traveling?"
            )
                == "How many people are traveling?"
        )
        precondition(
            GIASpokenPhraseSplitter.leadingPhrase(
                in: "Okay, I've got it."
            )
                == "Okay, I've got it."
        )
        precondition(
            GIASpokenPhraseSplitter.remainder(
                after: "Okay, I've got it.",
                in: "Okay, I've got it."
            ).isEmpty
        )
        precondition(
            GIASpokenPhraseSplitter.leadingPhrase(
                in: "Ha! Paris is beautiful. What dates work?"
            )
                == "Ha! Paris is beautiful."
        )
        precondition(
            GIASpokenPhraseSplitter.remainder(
                after: "Ha! Paris is beautiful.",
                in: "Ha! Paris is beautiful. What dates work?"
            )
                == "What dates work?"
        )

        print("G.I.A. response coordinator verification passed.")
    }
}

private actor SlowResponder: AssistantResponding {
    func generateResponse(
        matching context: GIAConversationContext
    ) async throws -> GIAConversationResponse {
        try await Task.sleep(nanoseconds: 10_000_000_000)
        return GIAConversationFallback.response(
            for: context.intent
        )
    }
}

private actor FixtureResponder: AssistantResponding {
    let response: GIAConversationResponse

    init(response: GIAConversationResponse) {
        self.response = response
    }

    func generateResponse(
        matching context: GIAConversationContext
    ) async throws -> GIAConversationResponse {
        response
    }
}
