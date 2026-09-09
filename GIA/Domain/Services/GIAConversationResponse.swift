import Foundation

enum GIAConversationIntent:
    String,
    Codable,
    CaseIterable,
    Sendable
{
    case requestCaptured
    case clarificationNeeded
    case resultsReady
    case timingConflict
    case providerUnavailable
}

struct GIAConversationContext:
    Codable,
    Hashable,
    Sendable
{
    var intent: GIAConversationIntent
    var requestSummary: String
    var groundedFacts: [String]

    init(
        intent: GIAConversationIntent,
        requestSummary: String,
        groundedFacts: [String] = []
    ) {
        self.intent = intent
        self.requestSummary = String(
            requestSummary.prefix(600)
        )
        self.groundedFacts = groundedFacts
            .prefix(12)
            .map { String($0.prefix(240)) }
    }
}

struct GIASpokenTurn: Equatable, Hashable, Sendable {
    var speaker: String
    var text: String
}

struct GIAConversationMemory: Equatable, Sendable {
    private(set) var turns: [GIASpokenTurn] = []
    private(set) var lastAskedField: String?
    private(set) var complimentedDestinations: Set<String> = []

    mutating func reset() {
        self = GIAConversationMemory()
    }

    mutating func remember(speaker: String, text: String?) {
        let trimmed = text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        let clipped = String(trimmed.prefix(120))
        if
            turns.last?.speaker == speaker,
            turns.last?.text == clipped
        {
            return
        }
        turns.append(
            GIASpokenTurn(speaker: speaker, text: clipped)
        )
        if turns.count > 8 {
            turns.removeFirst(turns.count - 8)
        }
    }

    mutating func markAsked(_ field: String?) {
        lastAskedField = field
    }

    mutating func markDestinationComplimented(_ destination: String?) {
        guard let key = Self.normalizedDestination(destination) else {
            return
        }
        complimentedDestinations.insert(key)
    }

    func hasComplimented(_ destination: String?) -> Bool {
        guard let key = Self.normalizedDestination(destination) else {
            return false
        }
        return complimentedDestinations.contains(key)
    }

    func turnFacts(userUtterance: String?) -> [String] {
        var facts: [String] = []
        let spoken = userUtterance?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let lastAskedField, !spoken.isEmpty {
            facts.append("User just replied to: \(lastAskedField).")
        }
        if let recent = recentTurnsFact() {
            facts.append(recent)
        }
        return facts
    }

    func destinationComplimentFact(destination: String?) -> String? {
        guard Self.normalizedDestination(destination) != nil else {
            return nil
        }
        if hasComplimented(destination) {
            return
                "Already complimented destination: yes. "
                + "Do not say it is beautiful again. "
                + "React to this turn only."
        }
        return
            "Already complimented destination: no. "
            + "You may compliment this place once."
    }

    private func recentTurnsFact() -> String? {
        let recent = turns.suffix(4)
        guard !recent.isEmpty else { return nil }
        let body = recent.map { turn in
            "\(turn.speaker): \(String(turn.text.prefix(48)))"
        }.joined(separator: " / ")
        return String(("Recent turns: " + body).prefix(240))
    }

    static func normalizedDestination(_ name: String?) -> String? {
        let trimmed = name?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct GIAConversationResponse:
    Codable,
    Hashable,
    Sendable
{
    var spokenText: String
    var displayText: String
    var intent: GIAConversationIntent
    var shouldContinueListening: Bool

    private enum CodingKeys: String, CodingKey {
        case spokenText
        case displayText
        case intent
        case shouldContinueListening
    }

    init(
        spokenText: String,
        displayText: String,
        intent: GIAConversationIntent,
        shouldContinueListening: Bool
    ) {
        self.spokenText = GIAConversationCopy.spoken(spokenText)
        self.displayText = GIAConversationCopy.displayed(displayText)
        self.intent = intent
        self.shouldContinueListening = shouldContinueListening
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spokenText = GIAConversationCopy.spoken(
            try container.decode(String.self, forKey: .spokenText)
        )
        displayText = GIAConversationCopy.displayed(
            try container.decode(String.self, forKey: .displayText)
        )
        intent = try container.decode(
            GIAConversationIntent.self,
            forKey: .intent
        )
        shouldContinueListening = try container.decode(
            Bool.self,
            forKey: .shouldContinueListening
        )
    }
}

enum GIAConversationCopy {
    static func displayed(_ text: String) -> String {
        cleaned(text)
    }

    static func spoken(_ text: String) -> String {
        cleaned(text)
    }

    static func firstSpokenPhrase(_ text: String) -> String {
        let trimmed = spoken(text)
        guard trimmed.count >= 12 else {
            return trimmed
        }

        var index = trimmed.index(trimmed.startIndex, offsetBy: 11)
        while index < trimmed.endIndex {
            let character = trimmed[index]
            if character == "." || character == "!" || character == "?" {
                let phrase = String(trimmed[trimmed.startIndex...index])
                let remainder = trimmed[trimmed.index(after: index)...]
                    .drop(while: { $0.isWhitespace })
                if remainder.isEmpty {
                    return trimmed
                }
                let next = remainder[remainder.startIndex]
                if next.isNumber || next.isUppercase {
                    return phrase.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
            }
            index = trimmed.index(after: index)
        }
        return trimmed
    }

    static func spokenPlaybackSegments(for text: String) -> [String] {
        let spokenText = spoken(text)
        guard !spokenText.isEmpty else {
            return []
        }
        let first = firstSpokenPhrase(spokenText)
        guard first.count >= 12, first.count < spokenText.count else {
            return [spokenText]
        }
        let rest = spokenText.dropFirst(first.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rest.isEmpty else {
            return [spokenText]
        }
        return [first, rest]
    }

    private static func cleaned(_ text: String) -> String {
        let expanded = expandAbbreviations(
            capitalizeAfterBreaks(stripDashes(text))
        )
        return expanded
            .replacingOccurrences(
                of: "\\s{2,}",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripDashes(_ text: String) -> String {
        text
            .replacingOccurrences(of: " — ", with: ". ")
            .replacingOccurrences(of: " – ", with: ". ")
            .replacingOccurrences(of: "—", with: ". ")
            .replacingOccurrences(of: "–", with: ". ")
    }

    private static func capitalizeAfterBreaks(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var characters = Array(text)
        var capitalizeNext = false
        for index in characters.indices {
            let character = characters[index]
            if character.isWhitespace {
                continue
            }
            if capitalizeNext, character.isLetter {
                if let uppercased = character.uppercased().first {
                    characters[index] = uppercased
                }
                capitalizeNext = false
                continue
            }
            capitalizeNext = ".!?".contains(character)
        }
        return String(characters)
    }

    private static let abbreviationPairs: [(String, String, Bool)] = [
        ("approx", "approximately", true),
        ("intl", "international", true),
        ("blvd", "Boulevard", true),
        ("dept", "department", true),
        ("info", "information", true),
        ("incl", "including", true),
        ("excl", "excluding", true),
        ("asap", "as soon as possible", true),
        ("thru", "through", true),
        ("nite", "night", true),
        ("mins", "minutes", true),
        ("secs", "seconds", true),
        ("hrs", "hours", true),
        ("wks", "weeks", true),
        ("ppl", "people", true),
        ("avg", "average", true),
        ("thx", "thanks", true),
        ("pls", "please", true),
        ("btw", "by the way", true),
        ("hwy", "Highway", true),
        ("etc", "and so on", true),
        ("vs", "versus", true),
        ("Sept", "September", true),
        ("Sep", "September", true),
        ("Jan", "January", true),
        ("Feb", "February", true),
        ("Mar", "March", true),
        ("Apr", "April", true),
        ("Jun", "June", true),
        ("Jul", "July", true),
        ("Aug", "August", true),
        ("Oct", "October", true),
        ("Nov", "November", true),
        ("Dec", "December", true),
        ("Thurs", "Thursday", true),
        ("Thur", "Thursday", true),
        ("Thu", "Thursday", true),
        ("Tues", "Tuesday", true),
        ("Tue", "Tuesday", true),
        ("Mon", "Monday", true),
        ("Fri", "Friday", true),
        ("Wed", "Wednesday", false),
        ("WED", "Wednesday", false),
        ("Sat", "Saturday", false),
        ("SAT", "Saturday", false),
        ("Sun", "Sunday", false),
        ("SUN", "Sunday", false),
        ("Ave", "Avenue", false),
        ("AVE", "Avenue", false),
        ("Rd", "Road", false)
    ]

    private static func expandAbbreviations(_ text: String) -> String {
        var result = text
            .replacingOccurrences(
                of: "w/o",
                with: "without",
                options: .caseInsensitive
            )
            .replacingOccurrences(
                of: "w/",
                with: "with",
                options: .caseInsensitive
            )
            .replacingOccurrences(of: " & ", with: " and ")
            .replacingOccurrences(
                of: "e.g.",
                with: "for example",
                options: .caseInsensitive
            )
            .replacingOccurrences(
                of: "i.e.",
                with: "that is",
                options: .caseInsensitive
            )
        for (abbreviation, fullWord, caseInsensitive) in abbreviationPairs {
            let pattern =
                "\\b"
                + NSRegularExpression.escapedPattern(for: abbreviation)
                + "\\.?\\b"
            var options: String.CompareOptions = .regularExpression
            if caseInsensitive {
                options.insert(.caseInsensitive)
            }
            result = result.replacingOccurrences(
                of: pattern,
                with: fullWord,
                options: options
            )
        }
        return result
    }
}

protocol AssistantResponding: Sendable {
    func generateResponse(
        matching context: GIAConversationContext
    ) async throws -> GIAConversationResponse
}

enum TripReplyUnderstanding: String, Codable, Sendable {
    case understood
    case unclear
}

struct TripReplyInterpretationRequest:
    Codable,
    Hashable,
    Sendable
{
    var utterance: String
    var askedField: String
    var today: String
    var requestSummary: String
    var knownFacts: [String]
}

struct TripReplyInterpretation: Codable, Hashable, Sendable {
    var understanding: TripReplyUnderstanding
    var spokenText: String?
    var destination: String?
    var origin: String?
    var dateStart: String?
    var dateEnd: String?
    var durationDays: Int?
    var travelerCount: Int?
    var budgetAmount: Double?
    var budgetCurrency: String?

    var isUnderstood: Bool {
        understanding == .understood
    }

    var hasUsablePatch: Bool {
        destination?.isEmpty == false
            || origin?.isEmpty == false
            || dateStart?.isEmpty == false
            || dateEnd?.isEmpty == false
            || durationDays != nil
            || travelerCount != nil
            || budgetAmount != nil
    }
}

protocol TripReplyInterpreting: Sendable {
    func interpretReply(
        matching request: TripReplyInterpretationRequest
    ) async throws -> TripReplyInterpretation
}
