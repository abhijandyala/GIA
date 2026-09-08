import Foundation

enum VoiceSessionTiming {
    static let initialSilenceTimeout: TimeInterval = 12
    static let finishedUtteranceSilence: TimeInterval = 0.82
    static let openUtteranceSilence: TimeInterval = 1.15
    static let hangingUtteranceSilence: TimeInterval = 1.7
    static let endOfSpeechSilence: TimeInterval = finishedUtteranceSilence
    static let incompleteUtteranceSilence: TimeInterval = hangingUtteranceSilence
    static let lateTranscriptGrace: TimeInterval = 0.18
    static let trailingAudioDuration: TimeInterval = 0.12
    static let finalResultWait: TimeInterval = 0.38
    static let maximumRequestDuration: TimeInterval = 30
    static let minimumRequestDuration: TimeInterval = 0.8
    static let transcriptVoiceActivityWindow: TimeInterval = 1.6
    static let wakeOnlyHandoffSilence: TimeInterval = 1.8
    static let bargeInGracePeriod: TimeInterval = 1.1
    static let bargeInHoldDuration: TimeInterval = 0.35
    static let playbackEchoSettle: TimeInterval = 0.28
    static let recognitionRestartDelay: UInt64 = 180_000_000
    static let voiceActivityResetDecibels: Float = 16
    static let bargeInVoiceResetDecibels: Float = 18
}

enum VoiceRequestCompletionDecision: Equatable, Sendable {
    case continueListening
    case complete
    case noSpeech
}

enum VoiceRecognitionRules {
    static func isStopCommand(_ transcript: String) -> Bool {
        let normalized = transcript
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US")
            )
            .lowercased()
            .components(
                separatedBy: CharacterSet.alphanumerics.inverted
            )
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return [
            "stop",
            "stop gia",
            "gia stop",
            "goodbye",
            "goodbye gia",
            "bye",
            "bye gia",
            "see you later",
            "that is all",
            "that s all"
        ].contains(normalized)
    }

    static func shouldVisualizeMicrophoneLevel(
        hasTranscript: Bool,
        transcriptInactivity: TimeInterval
    ) -> Bool {
        hasTranscript
            && transcriptInactivity
                <= VoiceSessionTiming.transcriptVoiceActivityWindow
    }

    static func containsWakePhrase(
        _ transcript: String
    ) -> Bool {
        let words = wakeWords(in: transcript)
        guard !words.isEmpty else { return false }

        if words.contains(where: isStrongWakeWord) {
            return true
        }

        if words.contains(where: isCollapsedWakePhrase) {
            return true
        }

        if words.count >= 2 {
            for index in 1..<words.count {
                let previous = words[index - 1]
                let current = words[index]
                if
                    wakePrefixes.contains(previous),
                    isWakeName(current)
                {
                    return true
                }
                if
                    current == "gee",
                    index + 1 < words.count,
                    geeFollowers.contains(words[index + 1])
                {
                    return true
                }
                if
                    previous == "gee",
                    geeFollowers.contains(current)
                {
                    return true
                }
                if
                    misheardWakePrefixes.contains(previous),
                    misheardWakeNames.contains(current)
                {
                    return true
                }
            }
        }

        guard words.count >= 3 else { return false }

        for index in 0...(words.count - 3) {
            let phrase = Array(words[index...(index + 2)])
            if spelledWakeLetters.contains(phrase) {
                return true
            }
        }

        return false
    }

    static func strippingWakePhrasePrefix(
        from transcript: String
    ) -> String {
        let trimmed = transcript.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return "" }

        let pattern =
            #"(?<!\p{L})(?:(?:hey|hi|okay|ok|yo|hello)\s*[,.-]?\s*)?(?:g\s*[.\-]?\s*i\s*[.\-]?\s*a|giah?|jia|gigi|geeuh|geea|jeea|jaia|gya|chia|agia|aegia|giya|gee\s+(?:eye|i|ay|ah|uh|a)(?:\s+(?:ay|a))?)(?!\p{L})[^\p{L}\p{N}]*"#
        guard
            let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            )
        else {
            return trimmed
        }
        let fullRange = NSRange(trimmed.startIndex..., in: trimmed)
        let matches = expression.matches(
            in: trimmed,
            range: fullRange
        )
        guard
            let lastMatch = matches.last,
            let matchRange = Range(lastMatch.range, in: trimmed)
        else {
            return trimmed
        }
        return String(trimmed[matchRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func spokenRequestAfterWake(
        from transcript: String
    ) -> String {
        let stripped = strippingWakePhrasePrefix(from: transcript)
        if isWakeCaptureFiller(stripped) {
            return ""
        }
        return stripped
    }

    static let wakeContextualStrings = [
        "GIA",
        "Hey GIA",
        "Hi GIA",
        "Okay GIA",
        "OK GIA",
        "Yo GIA",
        "Hello GIA",
        "G I A",
        "Gee eye ay",
        "Gee ay",
        "Jia",
        "Hey Jia",
        "Giah",
        "Geeuh",
        "Hey chia",
        "Hey gee",
        "Hey gigi",
        "agia",
        "aegia",
        "giya",
        "Hey ya",
        "Hey ja",
        "Hey yeah",
        "Hey yea",
        "Hey yah"
    ]

    private static let strongWakeWords: Set<String> = [
        "gia",
        "giah",
        "jia",
        "jeea",
        "geea",
        "geeuh",
        "jaia",
        "gya",
        "agia",
        "aegia",
        "giya"
    ]

    private static let weakWakeWords: Set<String> = [
        "chia",
        "gee",
        "gigi",
        "ya",
        "ja"
    ]

    private static let wakePrefixes: Set<String> = [
        "hey",
        "hi",
        "okay",
        "ok",
        "yo",
        "hello"
    ]

    private static let geeFollowers: Set<String> = [
        "ay",
        "ah",
        "uh",
        "a",
        "eye",
        "i"
    ]

    private static let misheardWakePrefixes: Set<String> = [
        "hey",
        "hi"
    ]

    private static let misheardWakeNames: Set<String> = [
        "yeah",
        "yea",
        "yah"
    ]

    private static let spelledWakeLetters: Set<[String]> = [
        ["g", "i", "a"],
        ["gee", "eye", "ay"],
        ["gee", "i", "a"],
        ["g", "eye", "a"],
        ["gee", "eye", "a"],
        ["gee", "i", "ay"],
        ["g", "i", "ay"],
        ["gee", "eye", "ah"],
        ["j", "i", "a"]
    ]

    private static func wakeWords(in transcript: String) -> [String] {
        transcript
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US")
            )
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
    }

    private static func isStrongWakeWord(_ word: String) -> Bool {
        strongWakeWords.contains(word)
    }

    private static func isWakeName(_ word: String) -> Bool {
        strongWakeWords.contains(word) || weakWakeWords.contains(word)
    }

    private static func isCollapsedWakePhrase(_ word: String) -> Bool {
        for prefix in wakePrefixes where word.hasPrefix(prefix) {
            let remainder = String(word.dropFirst(prefix.count))
            if isWakeName(remainder) {
                return true
            }
        }
        return false
    }

    static func mergingTranscript(
        existing: String,
        incoming: String
    ) -> String {
        let incomingText = incoming.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if incomingText.isEmpty {
            return existing
        }
        if existing.isEmpty || incomingText.count >= existing.count {
            return incomingText
        }
        if existing.localizedCaseInsensitiveContains(incomingText) {
            return existing
        }
        return existing + " " + incomingText
    }

    static func spokenContent(from transcript: String) -> String {
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
            .joined(separator: " ")
    }

    static func appendingSpokenRequest(
        existing: String,
        incoming: String
    ) -> String {
        let next = spokenRequestAfterWake(from: incoming)
        guard !next.isEmpty else { return existing }
        if existing.isEmpty {
            return next
        }
        let existingSpoken = spokenContent(from: existing)
        let nextSpoken = spokenContent(from: next)
        if existingSpoken.contains(nextSpoken) {
            return existing
        }
        if nextSpoken.contains(existingSpoken) {
            return next
        }
        return existing + " " + next
    }

    static func hasNewSpokenContent(
        previous: String,
        incoming: String
    ) -> Bool {
        spokenContent(from: previous) != spokenContent(from: incoming)
    }

    static func isWakeCaptureFiller(_ transcript: String) -> Bool {
        let words = spokenContent(from: transcript)
            .split(separator: " ")
            .map(String.init)
        guard !words.isEmpty else { return true }
        return words.allSatisfy { wakeCaptureFillerWords.contains($0) }
    }

    static func isAssistantChatter(_ transcript: String) -> Bool {
        let spoken = spokenContent(from: transcript)
        if spoken.isEmpty {
            return true
        }
        if assistantChatterPhrases.contains(spoken) {
            return true
        }
        let words = spoken.split(separator: " ").map(String.init)
        return words.allSatisfy {
            wakeCaptureFillerWords.contains($0)
                || assistantChatterWords.contains($0)
        }
    }

    static func hasTravelIntent(_ transcript: String) -> Bool {
        if isAssistantChatter(transcript) {
            return false
        }
        let spoken = spokenContent(from: transcript)
        if spoken.isEmpty {
            return false
        }
        if travelIntentPhrases.contains(where: { spoken.contains($0) }) {
            return true
        }
        return looksLikeBarePlace(transcript)
    }

    static func looksLikeBarePlace(_ transcript: String) -> Bool {
        if isAssistantChatter(transcript) || isWakeCaptureFiller(transcript) {
            return false
        }
        let words = spokenContent(from: transcript)
            .split(separator: " ")
            .map(String.init)
        guard (1...4).contains(words.count) else {
            return false
        }
        if words.contains(where: { nonPlaceWords.contains($0) }) {
            return false
        }
        if travelIntentPhrases.contains(where: { words.contains($0) }) {
            return false
        }
        return true
    }

    static func isPlaybackEcho(
        _ transcript: String,
        spokenText: String
    ) -> Bool {
        let heard = spokenContent(from: transcript)
        let spoken = spokenContent(from: spokenText)
        if heard.isEmpty {
            return true
        }
        if spoken.isEmpty {
            return false
        }
        if spoken.contains(heard) {
            return true
        }
        if heard.contains(spoken) {
            let extra = heard
                .replacingOccurrences(of: spoken, with: "")
                .trimmingCharacters(in: .whitespaces)
            return extra.isEmpty || isAssistantChatter(extra)
        }
        let heardWords = heard.split(separator: " ").map(String.init)
        let spokenWords = Set(spoken.split(separator: " ").map(String.init))
        guard !heardWords.isEmpty else { return true }
        let overlap = heardWords.filter { spokenWords.contains($0) }.count
        return Double(overlap) / Double(heardWords.count) >= 0.6
    }

    private static let wakeCaptureFillerWords: Set<String> = [
        "yes",
        "yeah",
        "yep",
        "yup",
        "no",
        "nope",
        "hey",
        "hi",
        "hello",
        "okay",
        "ok",
        "uh",
        "um",
        "please",
        "listen",
        "ya",
        "ja",
        "yeah",
        "yea",
        "yah"
    ]

    private static let assistantChatterWords: Set<String> = [
        "greeting",
        "greetings",
        "there",
        "testing",
        "test",
        "louder",
        "quiet",
        "quieter",
        "volume",
        "hear",
        "hearing",
        "listening",
        "speak",
        "talk",
        "wait",
        "sorry",
        "what",
        "huh",
        "hmm"
    ]

    private static let assistantChatterPhrases: Set<String> = [
        "no greeting",
        "no greetings",
        "where is the greeting",
        "say hello",
        "say hi",
        "say something",
        "can you hear me",
        "can you hear",
        "are you there",
        "you there",
        "are you listening",
        "hello there",
        "what did you say",
        "speak up",
        "talk to me",
        "how are you",
        "whats up",
        "what s up",
        "hold on",
        "one second",
        "hang on",
        "i can t hear you",
        "i cannot hear you",
        "too quiet",
        "too loud"
    ]

    private static let travelIntentPhrases: [String] = [
        "trip",
        "travel",
        "vacation",
        "holiday",
        "fly",
        "flying",
        "flight",
        "flights",
        "go to",
        "going to",
        "visit",
        "visiting",
        "book",
        "booking",
        "hotel",
        "hotels",
        "itinerary",
        "destination",
        "next week",
        "this weekend",
        "tomorrow",
        "days in",
        "nights in"
    ]

    private static let nonPlaceWords: Set<String> = [
        "next",
        "week",
        "weekend",
        "tomorrow",
        "today",
        "tonight",
        "people",
        "person",
        "travelers",
        "travellers",
        "budget",
        "dollars",
        "please",
        "maybe",
        "something",
        "anything"
    ]

    static func looksIncomplete(_ transcript: String) -> Bool {
        SpeechEndpointRules.looksIncomplete(transcript)
    }

    static func requiredEndOfSpeechSilence(
        for transcript: String
    ) -> TimeInterval {
        SpeechEndpointRules.requiredSilence(for: transcript)
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
        SpeechEndpointRules.requestCompletionDecision(
            hasDetectedSpeech: hasDetectedSpeech,
            hasTranscript: hasTranscript,
            elapsed: elapsed,
            silenceDuration: silenceDuration,
            transcript: transcript,
            isSpeaking: isSpeaking,
            transcriptStableFor: transcriptStableFor
        )
    }
}
