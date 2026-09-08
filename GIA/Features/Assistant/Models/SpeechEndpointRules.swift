import Foundation

enum UtteranceCompleteness: Equatable, Sendable {
    case hanging
    case open
    case finished
}

enum SpeechEndpointRules {
    static func completeness(
        of transcript: String
    ) -> UtteranceCompleteness {
        let trimmed = transcript.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return .open }

        if hasClosingPhrase(trimmed) {
            return .finished
        }
        if hasCutoffPunctuation(trimmed) {
            return .hanging
        }

        let words = words(in: trimmed)
        guard let last = words.last else { return .open }

        if hasHangingPhrase(words) || hangingTokens.contains(last) {
            return .hanging
        }
        if hasOpenListPunctuation(trimmed) {
            return .open
        }
        return .finished
    }

    static func requiredSilence(
        for transcript: String
    ) -> TimeInterval {
        switch completeness(of: transcript) {
        case .finished:
            VoiceSessionTiming.finishedUtteranceSilence
        case .open:
            VoiceSessionTiming.openUtteranceSilence
        case .hanging:
            VoiceSessionTiming.hangingUtteranceSilence
        }
    }

    static func looksIncomplete(_ transcript: String) -> Bool {
        completeness(of: transcript) != .finished
    }

    static func looksCutOff(_ transcript: String) -> Bool {
        hasCutoffPunctuation(transcript)
    }

    static func requestCompletionDecision(
        hasDetectedSpeech: Bool,
        hasTranscript: Bool,
        elapsed: TimeInterval,
        silenceDuration: TimeInterval,
        transcript: String = "",
        isSpeaking: Bool = false,
        transcriptStableFor: TimeInterval = .greatestFiniteMagnitude
    ) -> VoiceRequestCompletionDecision {
        if elapsed >= VoiceSessionTiming.maximumRequestDuration {
            return hasTranscript ? .complete : .noSpeech
        }

        if isSpeaking {
            return .continueListening
        }

        if
            !hasDetectedSpeech,
            elapsed >= VoiceSessionTiming.initialSilenceTimeout
        {
            return .noSpeech
        }

        if
            hasDetectedSpeech,
            hasTranscript,
            elapsed >= VoiceSessionTiming.minimumRequestDuration,
            silenceDuration
                >= requiredSilence(for: transcript)
                + VoiceSessionTiming.lateTranscriptGrace,
            transcriptStableFor
                >= VoiceSessionTiming.lateTranscriptGrace
        {
            return .complete
        }

        return .continueListening
    }

    private static func words(in transcript: String) -> [String] {
        transcript
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US")
            )
            .lowercased()
            .components(
                separatedBy: CharacterSet.alphanumerics.inverted
            )
            .filter { !$0.isEmpty }
    }

    private static func hasCutoffPunctuation(_ transcript: String) -> Bool {
        let trimmed = transcript.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return
            trimmed.hasSuffix("...")
            || trimmed.hasSuffix("…")
            || trimmed.hasSuffix("-")
            || trimmed.hasSuffix("—")
            || trimmed.hasSuffix("--")
    }

    private static func hasOpenListPunctuation(_ transcript: String) -> Bool {
        transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .hasSuffix(",")
    }

    private static func hasClosingPhrase(_ transcript: String) -> Bool {
        let spoken = words(in: transcript).joined(separator: " ")
        return closingPhrases.contains { spoken.hasSuffix($0) }
    }

    private static func hasHangingPhrase(_ words: [String]) -> Bool {
        if words.count >= 3 {
            let trigram = words.suffix(3).joined(separator: " ")
            if hangingTrigrams.contains(trigram) {
                return true
            }
        }
        guard words.count >= 2 else { return false }
        let bigram = words.suffix(2).joined(separator: " ")
        return hangingBigrams.contains(bigram)
    }

    private static let closingPhrases: [String] = [
        "that is all",
        "that s all",
        "that is it",
        "that s it",
        "thats it",
        "thats all",
        "all set",
        "i am done",
        "i m done",
        "thank you",
        "thanks"
    ]

    private static let hangingBigrams: Set<String> = [
        "and then",
        "and also",
        "as well",
        "as if",
        "because of",
        "going to",
        "have to",
        "instead of",
        "kind of",
        "looking for",
        "need to",
        "or maybe",
        "or something",
        "out of",
        "sort of",
        "such as",
        "trying to",
        "want to",
        "you know"
    ]

    private static let hangingTrigrams: Set<String> = [
        "i want to",
        "i need to",
        "i have to",
        "going to go",
        "and then also"
    ]

    private static let hangingTokens: Set<String> = [
        "a",
        "about",
        "an",
        "and",
        "any",
        "around",
        "at",
        "because",
        "before",
        "but",
        "for",
        "from",
        "gonna",
        "how",
        "if",
        "in",
        "including",
        "into",
        "like",
        "maybe",
        "my",
        "need",
        "next",
        "of",
        "on",
        "or",
        "our",
        "plus",
        "some",
        "than",
        "the",
        "then",
        "to",
        "uh",
        "um",
        "versus",
        "vs",
        "wanna",
        "want",
        "what",
        "when",
        "where",
        "which",
        "who",
        "with"
    ]
}
