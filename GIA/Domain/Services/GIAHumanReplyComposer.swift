import Foundation

enum GIAHumanReplyComposer {
    static func clarificationQuestion(
        for field: TripClarificationField,
        request: TripRequest?,
        userUtterance: String? = nil,
        retrying: Bool = false,
        alreadyComplimentedDestination: Bool = false
    ) -> String {
        let question = question(for: field, retrying: retrying)
        if retrying {
            return question
        }
        return joining(
            reaction(
                destination: spokenDestination(in: request),
                field: field,
                seed: seed(
                    field: field,
                    destination: spokenDestination(in: request),
                    utterance: userUtterance
                ),
                alreadyComplimentedDestination:
                    alreadyComplimentedDestination
            ),
            question
        )
    }

    static func optionalPreferenceQuestion(
        omittedExamples: [String],
        request: TripRequest?,
        userUtterance: String? = nil,
        retrying: Bool = false,
        alreadyComplimentedDestination: Bool = false
    ) -> String {
        if retrying {
            return
                "I didn't catch that. You can add something, "
                + "or say that's it."
        }

        let question: String
        switch omittedExamples.count {
        case 0:
            question =
                "Anything else, or should I go ahead? "
                + "You can add a preference, or say that's it."
        case 1:
            question =
                "Anything else? I don't have \(omittedExamples[0]) yet, "
                + "if you want that in. Or say that's it."
        default:
            question =
                "Anything else? Share your departure city, budget, or "
                + "preferences for flights, hotels, and things to do. "
                + "Or say that's it."
        }

        return joining(
            reaction(
                destination: spokenDestination(in: request),
                field: .preferences,
                seed: seed(
                    field: .preferences,
                    destination: spokenDestination(in: request),
                    utterance: userUtterance
                ),
                alreadyComplimentedDestination:
                    alreadyComplimentedDestination
            ),
            question
        )
    }

    static func spokenDestination(
        in request: TripRequest?
    ) -> String? {
        guard let location = request?.destinations.first else {
            return nil
        }
        let raw =
            (location.city?.isEmpty == false ? location.city : nil)
            ?? location.name
        let trimmed = raw.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard trimmed.count >= 2 else { return nil }
        return trimmed
    }

    private static func question(
        for field: TripClarificationField,
        retrying: Bool
    ) -> String {
        switch field {
        case .destination:
            retrying
                ? "I still need the destination. Where would you like to go?"
                : "Where would you like to go?"
        case .dates:
            retrying
                ? "I still need travel dates to check availability. "
                    + "What dates work for you?"
                : "What dates work for you?"
        case .travelers:
            retrying
                ? "I still need the group size. How many people are traveling?"
                : "How many people are traveling?"
        case .budget:
            retrying
                ? "I didn't catch the budget. What limit should I use?"
                : "What budget would you like me to stay under?"
        case .origin:
            retrying
                ? "Where are you leaving from?"
                : "Where will you be departing from?"
        case .dietaryRequirements:
            "Are there any dietary needs I should protect?"
        case .accessibility:
            "Are there any accessibility needs I should plan for?"
        case .preferences:
            "What else would you like me to account for?"
        }
    }

    private static func reaction(
        destination: String?,
        field: TripClarificationField,
        seed: String,
        alreadyComplimentedDestination: Bool
    ) -> String {
        let warm = pick(
            ["That's great", "Nice", "Love that", "Perfect"],
            seed: seed + "|warm"
        )
        guard
            let destination,
            !alreadyComplimentedDestination,
            shouldComplimentDestination(for: field)
        else {
            return "\(warm)."
        }

        let remark = pick(
            [
                "\(destination) is beautiful",
                "\(destination) is gorgeous",
                "\(destination) is a great pick"
            ],
            seed: seed + "|place"
        )
        return "\(warm). \(remark)."
    }

    private static func shouldComplimentDestination(
        for field: TripClarificationField
    ) -> Bool {
        field == .dates || field == .travelers || field == .preferences
    }

    private static func joining(
        _ reaction: String,
        _ question: String
    ) -> String {
        "\(reaction) \(question)"
    }

    private static func seed(
        field: TripClarificationField,
        destination: String?,
        utterance: String?
    ) -> String {
        [
            field.rawValue,
            destination ?? "",
            utterance?.prefix(48).description ?? ""
        ]
        .joined(separator: "|")
    }

    private static func pick(
        _ items: [String],
        seed: String
    ) -> String {
        guard !items.isEmpty else { return "" }
        let sum = seed.unicodeScalars.reduce(into: 0) { total, scalar in
            total = total &+ Int(scalar.value)
        }
        return items[abs(sum) % items.count]
    }
}
