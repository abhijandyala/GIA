import Foundation

enum RequestValidationSeverity: String, Codable, Sendable {
    case clarification
    case invalid
}

struct RequestValidationIssue:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    var field: TripClarificationField
    var severity: RequestValidationSeverity
    var message: String

    var id: String {
        "\(field.rawValue):\(severity.rawValue)"
    }
}

struct TripRequestInterpretation: Sendable {
    var request: TripRequest
    var issues: [RequestValidationIssue]

    var clarificationFields: Set<TripClarificationField> {
        Set(issues.map(\.field))
    }

    var requiresClarification: Bool {
        !issues.isEmpty
    }
}

enum TripFollowUpInterpretation: Sendable {
    case cancelled
    case updated(request: TripRequest, summary: String)
    case unsupported
}

enum TripRequestInterpreter {
    static func preferredClarificationField(
        in issues: [RequestValidationIssue]
    ) -> TripClarificationField? {
        let fields = Set(issues.map(\.field))
        return [
            .destination,
            .dates,
            .travelers,
            .budget,
            .origin,
            .dietaryRequirements,
            .accessibility,
            .preferences
        ].first { fields.contains($0) }
    }

    static func interpret(
        transcript: String,
        now: Date = Date()
    ) -> TripRequestInterpretation {
        var request = TripRequest(
            rawTranscript: transcript,
            origin: parseOrigin(in: transcript),
            destinations: parseDestination(in: transcript).map {
                [$0]
            } ?? [],
            dateRange: parseDateRange(in: transcript, now: now),
            durationDays: parseDurationDays(in: transcript),
            travelerCount: parseTravelerCount(in: transcript),
            totalBudget: parseBudget(in: transcript),
            interests: parseInterests(in: transcript),
            dietaryRequirements:
                parseDietaryRequirements(in: transcript),
            accessibilityRequirements:
                parseAccessibilityRequirements(in: transcript),
            preferredPace: parseTravelPace(in: transcript),
            flightPreferences:
                parseFlightPreferences(in: transcript),
            hotelPreferences:
                parseHotelPreferences(in: transcript)
        )

        if
            request.durationDays == nil,
            let range = request.dateRange
        {
            request.durationDays = durationDays(in: range)
        }

        return TripRequestInterpretation(
            request: request,
            issues: validate(request, now: now)
        )
    }

    static func interpretFollowUp(
        transcript: String,
        applyingTo currentRequest: TripRequest,
        now: Date = Date()
    ) -> TripFollowUpInterpretation {
        let cleaned = strippingInvocationPrefix(from: transcript)
        let text = normalized(cleaned)
        if
            text == "cancel"
            || text == "never mind"
            || text == "nevermind"
            || text.contains("do not change anything")
            || text.contains("don't change anything")
        {
            return .cancelled
        }

        var request = currentRequest
        var changes: [String] = []
        let isRemoving =
            text.contains("remove")
            || text.contains("delete")
            || text.contains("without")
            || text.contains("no more")

        if
            let destination =
                parseDestination(in: cleaned)
                ?? parseFollowUpDestination(in: cleaned),
            normalized(destination.name)
                != normalized(
                    request.destinations.first?.name ?? ""
                )
        {
            request.destinations = [destination]
            changes.append("destination")
        }

        if
            let origin =
                parseOrigin(in: cleaned)
                ?? parseFollowUpOrigin(in: cleaned),
            normalized(origin.name)
                != normalized(request.origin?.name ?? "")
        {
            request.origin = origin
            changes.append("origin")
        }

        if let range = resolvedDateRange(in: cleaned, now: now) {
            applyDateRange(range, to: &request)
            changes.append("dates")
        } else if let duration = parseDurationDays(in: cleaned) {
            request.durationDays = duration
            changes.append("trip length")
        }

        if
            let added = firstCapture(
                #"\badd\s+([A-Za-z0-9\-]+)\s+(?:traveler|traveller|person|people|guest)s?\b"#,
                in: cleaned
            ).flatMap(parseNumberPhrase)
        {
            request.travelerCount =
                min((request.travelerCount ?? 0) + added, 30)
            changes.append("travelers")
        } else if
            let removed = firstCapture(
                #"\b(?:remove|delete)\s+([A-Za-z0-9\-]+)\s+(?:traveler|traveller|person|people|guest)s?\b"#,
                in: cleaned
            ).flatMap(parseNumberPhrase)
        {
            request.travelerCount =
                max((request.travelerCount ?? 1) - removed, 1)
            changes.append("travelers")
        } else if
            let travelers =
                parseTravelerCount(in: cleaned)
                ?? parseFollowUpTravelerCount(in: cleaned)
        {
            request.travelerCount = travelers
            changes.append("travelers")
        }

        let budgetText = cleaned.replacingOccurrences(
            of: "budget to",
            with: "budget of",
            options: .caseInsensitive
        )
        if let budget = parseBudget(in: budgetText) {
            request.totalBudget = budget
            changes.append("budget")
        }

        let interests = parseInterests(in: cleaned)
        if !interests.isEmpty {
            if isRemoving {
                request.interests.subtract(interests)
            } else {
                request.interests.formUnion(interests)
            }
            changes.append("interests")
        }

        let dietary = parseDietaryRequirements(in: cleaned)
        if !dietary.isEmpty {
            if isRemoving {
                request.dietaryRequirements.subtract(dietary)
            } else {
                request.dietaryRequirements.formUnion(dietary)
            }
            changes.append("dietary needs")
        }

        let accessibility =
            parseAccessibilityRequirements(in: cleaned)
        if !accessibility.isEmpty {
            if isRemoving {
                request.accessibilityRequirements
                    .subtract(accessibility)
            } else {
                request.accessibilityRequirements
                    .formUnion(accessibility)
            }
            changes.append("accessibility needs")
        }

        applyFlightPreferenceChanges(
            from: cleaned,
            removing: isRemoving,
            to: &request,
            changes: &changes
        )
        applyHotelPreferenceChanges(
            from: cleaned,
            removing: isRemoving,
            to: &request,
            changes: &changes
        )

        if
            text.contains("relaxed pace")
            || text.contains("slow pace")
            || text.contains("active pace")
            || text.contains("packed itinerary")
            || text.contains("balanced pace")
        {
            request.preferredPace = parseTravelPace(in: cleaned)
            changes.append("pace")
        }

        guard !changes.isEmpty else {
            return .unsupported
        }
        request.rawTranscript = [
            currentRequest.rawTranscript,
            "Update: \(cleaned)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
        request.requestedAt = now
        let uniqueChanges = Array(NSOrderedSet(array: changes))
            .compactMap { $0 as? String }
        return .updated(
            request: request,
            summary: naturalList(uniqueChanges)
        )
    }

    static func interpretClarificationAnswer(
        _ transcript: String,
        for field: TripClarificationField,
        applyingTo currentRequest: TripRequest,
        now: Date = Date()
    ) -> TripRequest? {
        var request = currentRequest
        switch field {
        case .destination:
            guard
                let destination = parseDestination(
                    in: "trip to \(transcript)"
                )
            else {
                return nil
            }
            request.destinations = [destination]
        case .dates:
            guard
                let range = resolvedDateRange(
                    in: transcript,
                    now: now
                )
            else {
                return nil
            }
            applyDateRange(range, to: &request)
        case .travelers:
            guard
                let travelers = parseTravelerCount(
                    in: "for \(transcript)"
                )
            else {
                return nil
            }
            request.travelerCount = travelers
        case .budget:
            guard
                let budget = parseBudget(
                    in: "budget of \(transcript)"
                )
            else {
                return nil
            }
            request.totalBudget = budget
        case .origin:
            guard
                let origin = parseFollowUpOrigin(
                    in: "origin from \(transcript)"
                )
            else {
                return nil
            }
            request.origin = origin
        case
            .preferences,
            .dietaryRequirements,
            .accessibility:
            guard
                case .updated(let updated, _) =
                    interpretFollowUp(
                        transcript: transcript,
                        applyingTo: currentRequest,
                        now: now
                    )
            else {
                return nil
            }
            request = updated
        }

        // A person will often answer one question with several useful facts,
        // such as dates, party size, and budget in the same sentence. Merge
        // every additional fact the normal follow-up parser understands so
        // those details are not silently discarded after clarification.
        if
            case .updated(let supplemented, _) = interpretFollowUp(
                transcript: transcript,
                applyingTo: request,
                now: now
            )
        {
            request = supplemented
        }

        request.rawTranscript = [
            currentRequest.rawTranscript,
            "Answer: \(transcript)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
        request.requestedAt = now
        return request
    }

    static func applying(
        _ reply: TripReplyInterpretation,
        to currentRequest: TripRequest,
        now: Date = Date()
    ) -> TripRequest {
        var request = currentRequest
        if
            let destination = reply.destination,
            !destination.isEmpty
        {
            request.destinations = [
                TravelLocation(name: cleanPlaceName(destination))
            ]
        }
        if
            let origin = reply.origin,
            !origin.isEmpty
        {
            request.origin = TravelLocation(
                name: cleanPlaceName(origin)
            )
        }
        if let travelers = reply.travelerCount {
            request.travelerCount = travelers
        }
        if
            let amount = reply.budgetAmount,
            amount > 0
        {
            request.totalBudget = Money(
                amount: Decimal(amount),
                currencyCode: reply.budgetCurrency ?? "USD"
            )
        }

        let start = parseISODate(reply.dateStart)
        let end = parseISODate(reply.dateEnd)
        if let start, let end {
            applyDateRange(
                makeDateRange(start: start, end: end),
                to: &request
            )
        } else if let start, let duration = reply.durationDays {
            applyDateRange(
                range(from: start, durationDays: duration),
                to: &request
            )
        } else if let end, let duration = reply.durationDays {
            let calendar = tripCalendar()
            let startDate =
                calendar.date(
                    byAdding: .day,
                    value: -(max(duration, 1) - 1),
                    to: calendar.startOfDay(for: end)
                ) ?? end
            applyDateRange(
                makeDateRange(start: startDate, end: end),
                to: &request
            )
        } else if let duration = reply.durationDays {
            applyDateRange(
                range(
                    from: tripCalendar().startOfDay(for: now),
                    durationDays: duration
                ),
                to: &request
            )
        }

        request.requestedAt = now
        return request
    }

    private static func parseISODate(_ value: String?) -> Date? {
        guard
            let value,
            !value.isEmpty
        else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    static func isConversationCompletion(
        _ transcript: String
    ) -> Bool {
        let text = normalized(
            strippingInvocationPrefix(from: transcript)
        )
        return
            text == "that's it"
            || text == "thats it"
            || text == "that is it"
            || text == "that's all"
            || text == "thats all"
            || text == "that is all"
            || text == "done"
            || text == "i'm done"
            || text == "im done"
            || text == "no"
            || text == "no thanks"
            || text == "nope"
            || text == "nah"
            || text == "nothing"
            || text == "nothing else"
            || text == "all good"
            || text == "looks good"
            || text == "go ahead"
            || text == "go for it"
            || text == "use that"
            || text == "plan it"
            || text == "start planning"
            || text == "make the plan"
    }

    static func omittedOptionalExamples(
        for request: TripRequest
    ) -> [String] {
        var examples: [String] = []
        if request.origin == nil {
            examples.append("where you're leaving from")
        }
        if request.totalBudget == nil {
            examples.append("your budget")
        }
        if
            request.flightPreferences.stopPreference == .any,
            request.flightPreferences.departureTimeWindow == nil,
            request.flightPreferences.preferredAirlines.isEmpty
        {
            examples.append("flight timing or stop preferences")
        }
        if
            request.hotelPreferences.minimumStarRating == nil,
            request.hotelPreferences.requiredAmenities.isEmpty,
            request.hotelPreferences.maximumNightlyRate == nil
        {
            examples.append("what you need from a hotel")
        }
        if request.interests.isEmpty {
            examples.append("what you want to do there")
        }
        if request.dietaryRequirements.isEmpty {
            examples.append("dietary needs")
        }
        if request.accessibilityRequirements.isEmpty {
            examples.append("accessibility needs")
        }
        return examples
    }

    private static func parseFollowUpDestination(
        in transcript: String
    ) -> TravelLocation? {
        let pattern =
            #"\b(?:destination|location|city)\s+(?:to|for)\s+([\p{L}][\p{L} .'\-]{1,60}?)(?=\s+(?:and|with|for|under|from)\b|[,.;]|$)"#
        return firstCapture(pattern, in: transcript).map {
            TravelLocation(name: cleanPlaceName($0))
        }
    }

    private static func parseFollowUpOrigin(
        in transcript: String
    ) -> TravelLocation? {
        let pattern =
            #"\b(?:origin|departure|depart|leave|leaving)\s+(?:to|from|at)\s+([\p{L}][\p{L} .'\-]{1,60}?)(?=\s+(?:and|with|for|under)\b|[,.;]|$)"#
        return firstCapture(pattern, in: transcript).map {
            TravelLocation(name: cleanPlaceName($0))
        }
    }

    private static func parseFollowUpTravelerCount(
        in transcript: String
    ) -> Int? {
        firstCapture(
            #"\b(?:make|change|set|update)(?:\s+it)?(?:\s+to)?\s+([A-Za-z0-9\-]+)\s+(?:travelers|travellers|people|guests)\b"#,
            in: transcript
        ).flatMap(parseNumberPhrase)
    }

    private static func applyFlightPreferenceChanges(
        from transcript: String,
        removing: Bool,
        to request: inout TripRequest,
        changes: inout [String]
    ) {
        let text = normalized(transcript)
        let hasFlightPreference =
            text.contains("class")
            || text.contains("nonstop")
            || text.contains("direct flight")
            || text.contains("stop")
            || text.contains("checked bag")
            || text.contains("checked luggage")
            || text.contains("refundable flight")
            || text.contains("refundable fare")
            || text.contains("morning flight")
            || text.contains("afternoon flight")
            || text.contains("evening flight")
            || text.contains("night flight")
        guard hasFlightPreference else { return }

        if removing {
            if text.contains("checked bag")
                || text.contains("checked luggage") {
                request.flightPreferences.checkedBagRequired = false
            }
            if text.contains("refundable") {
                request.flightPreferences.refundablePreferred = false
            }
            if text.contains("nonstop") || text.contains("stop") {
                request.flightPreferences.stopPreference = .any
            }
            if text.contains("class") {
                request.flightPreferences.travelClass = .economy
            }
            if text.contains("flight") {
                request.flightPreferences.departureTimeWindow = nil
            }
        } else {
            let parsed = parseFlightPreferences(in: transcript)
            if text.contains("class") {
                request.flightPreferences.travelClass =
                    parsed.travelClass
            }
            if
                text.contains("nonstop")
                || text.contains("direct flight")
                || text.contains("stop")
            {
                request.flightPreferences.stopPreference =
                    parsed.stopPreference
            }
            if text.contains("checked") {
                request.flightPreferences.checkedBagRequired =
                    parsed.checkedBagRequired
            }
            if text.contains("refundable") {
                request.flightPreferences.refundablePreferred =
                    parsed.refundablePreferred
            }
            if parsed.departureTimeWindow != nil {
                request.flightPreferences.departureTimeWindow =
                    parsed.departureTimeWindow
            }
        }
        changes.append("flight preferences")
    }

    private static func applyHotelPreferenceChanges(
        from transcript: String,
        removing: Bool,
        to request: inout TripRequest,
        changes: inout [String]
    ) {
        let text = normalized(transcript)
        let parsed = parseHotelPreferences(in: transcript)
        let mentionedAmenities = parsed.requiredAmenities
        let hasHotelPreference =
            !mentionedAmenities.isEmpty
            || text.contains("star hotel")
            || text.contains("star stay")
            || text.contains("hostel")
            || text.contains("resort")
            || text.contains("vacation rental")
            || text.contains("apartment")
            || text.contains("free cancellation")
            || text.contains("refundable hotel")
            || text.contains("per night")
            || text.contains("nightly")
        guard hasHotelPreference else { return }

        if removing {
            request.hotelPreferences.requiredAmenities
                .subtract(mentionedAmenities)
            if text.contains("star") {
                request.hotelPreferences.minimumStarRating = nil
            }
            if text.contains("refundable")
                || text.contains("free cancellation") {
                request.hotelPreferences.refundablePreferred = false
            }
            if text.contains("per night") || text.contains("nightly") {
                request.hotelPreferences.maximumNightlyRate = nil
            }
        } else {
            request.hotelPreferences.requiredAmenities
                .formUnion(mentionedAmenities)
            if let stars = parsed.minimumStarRating {
                request.hotelPreferences.minimumStarRating = stars
            }
            if parsed.allowedTypes != [.hotel]
                || text.contains("hotel") {
                request.hotelPreferences.allowedTypes =
                    parsed.allowedTypes
            }
            if parsed.refundablePreferred {
                request.hotelPreferences.refundablePreferred = true
            }
            if let rate = parsed.maximumNightlyRate {
                request.hotelPreferences.maximumNightlyRate = rate
            }
        }
        changes.append("stay preferences")
    }

    private static func strippingInvocationPrefix(
        from transcript: String
    ) -> String {
        transcript.replacingOccurrences(
            of:
                #"^\s*(?:hey\s+)?(?:g[\s.]*i[\s.]*a|gia|gee\s+eye\s+ay)[\s,.:;!\-]*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func naturalList(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return "your plan"
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            return
                values.dropLast().joined(separator: ", ")
                + ", and \(values.last ?? "your plan")"
        }
    }

    static func validate(
        _ request: TripRequest,
        now: Date = Date()
    ) -> [RequestValidationIssue] {
        var issues: [RequestValidationIssue] = []

        if request.destinations.isEmpty {
            issues.append(
                RequestValidationIssue(
                    field: .destination,
                    severity: .clarification,
                    message: "Where would you like to go?"
                )
            )
        }

        if let range = request.dateRange {
            if !range.isChronological {
                issues.append(
                    RequestValidationIssue(
                        field: .dates,
                        severity: .invalid,
                        message:
                            "The return date must follow departure."
                    )
                )
            } else if range.end < Calendar.current.startOfDay(for: now) {
                issues.append(
                    RequestValidationIssue(
                        field: .dates,
                        severity: .invalid,
                        message: "Travel dates must be in the future."
                    )
                )
            }
        } else {
            let durationDetail = request.durationDays.map {
                " for the \($0)-day trip"
            } ?? ""
            issues.append(
                RequestValidationIssue(
                    field: .dates,
                    severity: .clarification,
                    message:
                        "Which dates work\(durationDetail)?"
                )
            )
        }

        if let duration = request.durationDays {
            if !(1...90).contains(duration) {
                issues.append(
                    RequestValidationIssue(
                        field: .dates,
                        severity: .invalid,
                        message:
                            "Trip length must be between 1 and 90 days."
                    )
                )
            }
        }

        if let travelerCount = request.travelerCount {
            if !(1...30).contains(travelerCount) {
                issues.append(
                    RequestValidationIssue(
                        field: .travelers,
                        severity: .invalid,
                        message:
                            "Group size must be between 1 and 30."
                    )
                )
            }
        } else {
            issues.append(
                RequestValidationIssue(
                    field: .travelers,
                    severity: .clarification,
                    message: "How many people are traveling?"
                )
            )
        }

        if let budget = request.totalBudget {
            if
                budget.amount <= 0
                || budget.currencyCode.count != 3
            {
                issues.append(
                    RequestValidationIssue(
                        field: .budget,
                        severity: .invalid,
                        message:
                            "Enter a positive budget and currency."
                    )
                )
            }
        }

        if
            let originName = request.origin?.name,
            let destinationName = request.destinations.first?.name,
            normalized(originName) == normalized(destinationName)
        {
            issues.append(
                RequestValidationIssue(
                    field: .destination,
                    severity: .invalid,
                    message:
                        "Origin and destination must be different."
                )
            )
        }

        return issues
    }

    private static func parseDestination(
        in transcript: String
    ) -> TravelLocation? {
        let place = #"[\p{L}][\p{L} .'\-]{1,60}?"#
        let stop =
            #"(?=\s+(?:for|from|under|below|with|during|between|on|starting|leaving|returning|departing|and\s+(?:(?:a|an|the)\s+budget|make|add|include|find|book|keep|we|i))\b|[,.;]|$)"#
        let patterns = [
            #"\bfrom\s+[\p{L}][\p{L} .'\-]{1,60}?\s+to\s+("#
                + place + #")"# + stop,
            #"\b(?:trip|travel|fly|go|going)\s+to\s+("#
                + place + #")"# + stop,
            #"\b(?:visit|visiting)\s+("#
                + place + #")"# + stop,
            #"\b(?:days?|nights?|weeks?)\s+in\s+("#
                + place + #")"# + stop,
            #"\b(?:vacation|holiday)\s+in\s+("#
                + place + #")"# + stop,
            #"^("# + place + #")(?=\s+(?:next|this|tomorrow|on|from|for)\b)"#
        ]

        for pattern in patterns {
            if let value = firstCapture(pattern, in: transcript) {
                return TravelLocation(name: cleanPlaceName(value))
            }
        }

        return nil
    }

    private static func parseOrigin(
        in transcript: String
    ) -> TravelLocation? {
        let pattern =
            #"\b(?:(?:departing|leaving|flying)\s+from|from)\s+([\p{L}][\p{L} .'\-]{1,60}?)(?=\s+(?:to|into)\b)"#
        guard let value = firstCapture(pattern, in: transcript) else {
            return nil
        }
        return TravelLocation(name: cleanPlaceName(value))
    }

    private static func parseTravelerCount(
        in transcript: String
    ) -> Int? {
        let normalizedText = normalized(transcript)
        if
            normalizedText.contains("solo trip")
            || normalizedText.contains("traveling alone")
            || normalizedText.contains("travelling alone")
        {
            return 1
        }
        if normalizedText.contains("for a couple") {
            return 2
        }

        let patterns = [
            #"\bfor\s+([A-Za-z0-9\-]+)\s+(?:travelers|travellers|people|adults|guests|friends)\b"#,
            #"\b(?:group|party|family)\s+of\s+([A-Za-z0-9\-]+)\b"#,
            #"\b([A-Za-z0-9\-]+)\s+of\s+us\b"#
        ]

        for pattern in patterns {
            if
                let value = firstCapture(pattern, in: transcript),
                let count = parseNumberPhrase(value)
            {
                return count
            }
        }
        return nil
    }

    private static func parseDurationDays(
        in transcript: String
    ) -> Int? {
        let pattern =
            #"\b([A-Za-z0-9\-]+)\s*[- ]\s*(day|days|night|nights|week|weeks)\b"#
        guard
            let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            )
        else {
            return nil
        }

        let skippedAmounts: Set<String> = [
            "this",
            "next",
            "last",
            "coming",
            "following",
            "past"
        ]
        let fullRange = NSRange(transcript.startIndex..., in: transcript)
        for match in expression.matches(in: transcript, range: fullRange) {
            guard
                match.numberOfRanges >= 3,
                let amountRange = Range(match.range(at: 1), in: transcript),
                let unitRange = Range(match.range(at: 2), in: transcript)
            else {
                continue
            }

            let amountWord = String(transcript[amountRange])
            if skippedAmounts.contains(normalized(amountWord)) {
                continue
            }
            if isLeadInOffset(
                in: transcript,
                matchStart: match.range.location
            ) {
                continue
            }
            guard let amount = parseNumberPhrase(amountWord) else {
                continue
            }

            switch normalized(String(transcript[unitRange])) {
            case "week", "weeks":
                return amount * 7
            case "night", "nights":
                return amount + 1
            default:
                return amount
            }
        }
        return nil
    }

    private static func isLeadInOffset(
        in text: String,
        matchStart: Int
    ) -> Bool {
        let prefixLength = min(matchStart, 4)
        guard prefixLength > 0 else { return false }
        let start = text.index(
            text.startIndex,
            offsetBy: matchStart - prefixLength
        )
        let end = text.index(text.startIndex, offsetBy: matchStart)
        let prefix = String(text[start..<end]).lowercased()
        return prefix.hasSuffix("in ") || prefix == "in "
    }

    private static func parseBudget(
        in transcript: String
    ) -> Money? {
        let compactPattern =
            #"\b(?:under|below|up to|budget(?:\s+of)?|maximum(?:\s+of)?)\s*(\$|€|£|¥)?\s*([0-9]+(?:\.[0-9]{1,2})?)\s*(k|grand)\b"#
        if
            let values = captures(compactPattern, in: transcript),
            values.count >= 3,
            let amount = Decimal(string: values[1])
        {
            return Money(
                amount: amount * 1_000,
                currencyCode: currencyCode(
                    symbol: values[0],
                    word: ""
                )
            )
        }

        let numericPattern =
            #"\b(?:under|below|up to|budget(?:\s+of)?|maximum(?:\s+of)?)\s*(\$|€|£|¥)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(USD|EUR|GBP|JPY|CAD|AUD|dollars?|euros?|pounds?|yen)?"#
        if
            let values = captures(numericPattern, in: transcript),
            values.count >= 2,
            let amount = Decimal(
                string: values[1].replacingOccurrences(of: ",", with: "")
            )
        {
            return Money(
                amount: amount,
                currencyCode: currencyCode(
                    symbol: values[0],
                    word: values.count > 2 ? values[2] : ""
                )
            )
        }

        let wordsPattern =
            #"\b(?:under|below|up to|budget(?:\s+of)?|maximum(?:\s+of)?)\s+([A-Za-z][A-Za-z \-]+?)\s+(dollars?|euros?|pounds?|yen|USD|EUR|GBP|JPY|CAD|AUD)\b"#
        if
            let values = captures(wordsPattern, in: transcript),
            values.count >= 2,
            let amount = parseNumberPhrase(values[0])
        {
            return Money(
                amount: Decimal(amount),
                currencyCode: currencyCode(
                    symbol: "",
                    word: values[1]
                )
            )
        }

        return nil
    }

    private static func resolvedDateRange(
        in transcript: String,
        now: Date
    ) -> TripDateRange? {
        if let range = parseDateRange(in: transcript, now: now) {
            return range
        }
        if let duration = parseDurationDays(in: transcript) {
            return range(
                from: tripCalendar().startOfDay(for: now),
                durationDays: duration
            )
        }
        return nil
    }

    private static func applyDateRange(
        _ range: TripDateRange,
        to request: inout TripRequest
    ) {
        request.dateRange = range
        request.durationDays = durationDays(in: range)
    }

    private static func parseDateRange(
        in transcript: String,
        now: Date
    ) -> TripDateRange? {
        if let range = parseISODateRange(in: transcript) {
            return range
        }
        if let range = parseNamedMonthDateRange(in: transcript, now: now) {
            return range
        }
        return parseRelativeDateRange(in: transcript, now: now)
    }

    private static func parseISODateRange(
        in transcript: String
    ) -> TripDateRange? {
        let isoPattern =
            #"\b(\d{4}-\d{2}-\d{2})\s*(?:to|through|–|-)\s*(\d{4}-\d{2}-\d{2})\b"#
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        guard
            let values = captures(isoPattern, in: transcript),
            values.count >= 2,
            let start = formatter.date(from: values[0]),
            let end = formatter.date(from: values[1])
        else {
            return nil
        }
        return makeDateRange(start: start, end: end)
    }

    private static func parseNamedMonthDateRange(
        in transcript: String,
        now: Date
    ) -> TripDateRange? {
        let month =
            #"(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)"#
        let naturalPattern =
            #"\b"# + month
            + #"\s+(\d{1,2})(?:st|nd|rd|th)?(?:,\s*|\s+)?(\d{4})?\s*(?:to|through|–|-)\s*(?:"#
            + month
            + #"\s+)?(\d{1,2})(?:st|nd|rd|th)?(?:,\s*|\s+)?(\d{4})?\b"#
        guard
            let values = captures(naturalPattern, in: transcript),
            values.count >= 6,
            let startMonth = monthNumber(values[0]),
            let startDay = Int(values[1]),
            let endDay = Int(values[4])
        else {
            return nil
        }

        let calendar = tripCalendar()
        let currentYear = calendar.component(.year, from: now)
        let explicitStartYear = Int(values[2])
        let explicitEndYear = Int(values[5])
        var startYear =
            explicitStartYear ?? explicitEndYear ?? currentYear
        let endMonth =
            values[3].isEmpty
            ? startMonth
            : monthNumber(values[3]) ?? startMonth
        var endYear =
            explicitEndYear ?? explicitStartYear ?? startYear

        guard
            var start = calendar.date(
                from: DateComponents(
                    year: startYear,
                    month: startMonth,
                    day: startDay
                )
            ),
            var end = calendar.date(
                from: DateComponents(
                    year: endYear,
                    month: endMonth,
                    day: endDay
                )
            )
        else {
            return nil
        }

        if
            explicitStartYear == nil,
            explicitEndYear == nil,
            end < start,
            endMonth < startMonth
        {
            endYear += 1
            end = calendar.date(
                from: DateComponents(
                    year: endYear,
                    month: endMonth,
                    day: endDay
                )
            ) ?? end
        }
        if
            explicitStartYear == nil,
            explicitEndYear == nil,
            end < calendar.startOfDay(for: now)
        {
            startYear += 1
            endYear += 1
            start = calendar.date(
                from: DateComponents(
                    year: startYear,
                    month: startMonth,
                    day: startDay
                )
            ) ?? start
            end = calendar.date(
                from: DateComponents(
                    year: endYear,
                    month: endMonth,
                    day: endDay
                )
            ) ?? end
        }

        return makeDateRange(start: start, end: end)
    }

    private static func parseRelativeDateRange(
        in transcript: String,
        now: Date
    ) -> TripDateRange? {
        let text = normalizingRelativeDateText(transcript)
        let calendar = tripCalendar()
        let duration = parseDurationDays(in: text)
        let relativeToken = Self.relativeDateTokenPattern
        let connector =
            #"(?:to|till|til|until|through|thru|from|form|for|up to|starting(?:\s+from)?|–|-)"#
        let rangePattern =
            #"\b(?:(?:from|starting(?:\s+from)?)\s+)?"#
            + relativeToken
            + #"\s*"# + connector + #"\s*"#
            + relativeToken
            + #"\b"#

        if
            let values = captures(rangePattern, in: text),
            values.count >= 2,
            let first = relativePeriod(
                values[0],
                now: now,
                calendar: calendar
            ),
            let second = relativePeriod(
                values[1],
                now: now,
                calendar: calendar
            )
        {
            return dateRange(
                from: first,
                to: second,
                durationDays: duration
            )
        }

        let periods = relativePeriods(
            in: text,
            now: now,
            calendar: calendar
        )
        if periods.count >= 2 {
            return dateRange(
                from: periods[0],
                to: periods[periods.count - 1],
                durationDays: duration
            )
        }

        if let period = periods.first {
            if let duration {
                return range(from: period.start, durationDays: duration)
            }
            if calendar.startOfDay(for: period.start)
                < calendar.startOfDay(for: period.end)
            {
                return makeDateRange(start: period.start, end: period.end)
            }
        }

        return nil
    }

    private static let relativeDateTokenPattern =
        #"(next\s+weekend|this\s+weekend|day\s+after\s+tomorrow|next\s+week|this\s+week|tomorrow|tonight|today|now)"#

    private static func relativePeriods(
        in transcript: String,
        now: Date,
        calendar: Calendar
    ) -> [RelativePeriod] {
        guard
            let expression = try? NSRegularExpression(
                pattern: #"\b"# + relativeDateTokenPattern + #"\b"#,
                options: [.caseInsensitive]
            )
        else {
            return []
        }

        let fullRange = NSRange(transcript.startIndex..., in: transcript)
        return expression.matches(in: transcript, range: fullRange)
            .compactMap { match in
                guard
                    match.numberOfRanges >= 2,
                    let tokenRange = Range(match.range(at: 1), in: transcript)
                else {
                    return nil
                }
                return relativePeriod(
                    String(transcript[tokenRange]),
                    now: now,
                    calendar: calendar
                )
            }
    }

    private static func dateRange(
        from first: RelativePeriod,
        to second: RelativePeriod,
        durationDays: Int?
    ) -> TripDateRange {
        let start = min(first.start, second.start)
        if let durationDays {
            return range(from: start, durationDays: durationDays)
        }
        let end = max(first.end, second.end)
        return makeDateRange(start: start, end: end)
    }

    private static func normalizingRelativeDateText(
        _ transcript: String
    ) -> String {
        var text = transcript
        let replacements: [(String, String)] = [
            (#"\bform\b"#, "from"),
            (#"\benxt\s+week\b"#, "next week"),
            (#"\bnetx\s+week\b"#, "next week"),
            (#"\bnxt\s+week\b"#, "next week"),
            (#"\bthrouh\b"#, "through"),
            (#"\bthrought\b"#, "through")
        ]
        for (pattern, replacement) in replacements {
            text = text.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return text
    }

    private static func relativePeriod(
        _ raw: String,
        now: Date,
        calendar: Calendar
    ) -> RelativePeriod? {
        let token = normalized(raw)
        let today = calendar.startOfDay(for: now)

        func addingDays(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: days, to: today)
                ?? today
        }

        switch token {
        case "now", "today", "tonight":
            return RelativePeriod(start: today, end: today)
        case "tomorrow":
            let date = addingDays(1)
            return RelativePeriod(start: date, end: date)
        case "day after tomorrow":
            let date = addingDays(2)
            return RelativePeriod(start: date, end: date)
        case "this week":
            return RelativePeriod(
                start: today,
                end: endOfWeek(containing: today, calendar: calendar)
            )
        case "next week":
            let start = startOfNextWeek(
                after: today,
                calendar: calendar
            )
            let end =
                calendar.date(byAdding: .day, value: 6, to: start)
                ?? start
            return RelativePeriod(start: start, end: end)
        case "this weekend":
            return weekend(
                containingOrUpcoming: today,
                calendar: calendar,
                offsetWeeks: 0
            )
        case "next weekend":
            return weekend(
                containingOrUpcoming: today,
                calendar: calendar,
                offsetWeeks: 1
            )
        default:
            return nil
        }
    }

    private static func startOfNextWeek(
        after date: Date,
        calendar: Calendar
    ) -> Date {
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: date
        )
        let thisWeekStart = calendar.date(from: components) ?? date
        return calendar.date(
            byAdding: .weekOfYear,
            value: 1,
            to: thisWeekStart
        )
            ?? calendar.date(byAdding: .day, value: 7, to: date)
            ?? date
    }

    private static func endOfWeek(
        containing date: Date,
        calendar: Calendar
    ) -> Date {
        let start = calendar.date(
            from: calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: date
            )
        ) ?? date
        return calendar.date(byAdding: .day, value: 6, to: start)
            ?? date
    }

    private static func weekend(
        containingOrUpcoming date: Date,
        calendar: Calendar,
        offsetWeeks: Int
    ) -> RelativePeriod {
        let weekday = calendar.component(.weekday, from: date)
        let daysToThisSaturday: Int
        switch weekday {
        case 1:
            daysToThisSaturday = -1
        case 7:
            daysToThisSaturday = 0
        default:
            daysToThisSaturday = 7 - weekday
        }
        let saturday =
            calendar.date(
                byAdding: .day,
                value: daysToThisSaturday + (offsetWeeks * 7),
                to: date
            ) ?? date
        let sunday =
            calendar.date(byAdding: .day, value: 1, to: saturday)
            ?? saturday
        return RelativePeriod(start: saturday, end: sunday)
    }

    private static func range(
        from start: Date,
        durationDays: Int
    ) -> TripDateRange {
        let calendar = tripCalendar()
        let days = max(durationDays, 1)
        let end =
            calendar.date(
                byAdding: .day,
                value: days - 1,
                to: calendar.startOfDay(for: start)
            ) ?? start
        return makeDateRange(start: start, end: end)
    }

    private static func makeDateRange(
        start: Date,
        end: Date
    ) -> TripDateRange {
        let calendar = tripCalendar()
        return TripDateRange(
            start: calendar.startOfDay(for: start),
            end: calendar.startOfDay(for: end),
            timeZoneIdentifier: TimeZone.current.identifier
        )
    }

    private static func durationDays(in range: TripDateRange) -> Int? {
        let calendar = tripCalendar()
        let start = calendar.startOfDay(for: range.start)
        let end = calendar.startOfDay(for: range.end)
        return calendar.dateComponents(
            [.day],
            from: start,
            to: end
        ).day.map { $0 + 1 }
    }

    private static func tripCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    private struct RelativePeriod {
        var start: Date
        var end: Date
    }

    private static func parseInterests(
        in transcript: String
    ) -> Set<TripInterest> {
        let mappings: [(TripInterest, [String])] = [
            (.adventure, ["adventure", "hiking"]),
            (.art, ["art", "gallery", "galleries"]),
            (.beaches, ["beach", "beaches"]),
            (.culture, ["culture", "cultural"]),
            (.family, ["family", "kids", "children"]),
            (.food, ["food", "cuisine", "restaurants"]),
            (.history, ["history", "historical"]),
            (.museums, ["museum", "museums"]),
            (.nature, ["nature", "wildlife", "outdoors"]),
            (.nightlife, ["nightlife", "clubs"]),
            (.relaxation, ["relax", "relaxation", "spa"]),
            (.shopping, ["shopping", "shops"]),
            (.sports, ["sports", "game"]),
            (.technology, ["technology", "tech"])
        ]
        return matchedValues(mappings, in: transcript)
    }

    private static func parseDietaryRequirements(
        in transcript: String
    ) -> Set<DietaryRequirement> {
        let mappings: [(DietaryRequirement, [String])] = [
            (.vegetarian, ["vegetarian"]),
            (.vegan, ["vegan"]),
            (.halal, ["halal"]),
            (.kosher, ["kosher"]),
            (.glutenFree, ["gluten free", "gluten-free"]),
            (.dairyFree, ["dairy free", "dairy-free"]),
            (.nutFree, ["nut free", "nut-free", "nut allergy"]),
            (
                .shellfishFree,
                ["shellfish free", "shellfish-free", "shellfish allergy"]
            )
        ]
        return matchedValues(mappings, in: transcript)
    }

    private static func parseAccessibilityRequirements(
        in transcript: String
    ) -> Set<AccessibilityRequirement> {
        let mappings: [(AccessibilityRequirement, [String])] = [
            (
                .wheelchairAccess,
                ["wheelchair", "wheelchair accessible"]
            ),
            (.stepFreeAccess, ["step free", "step-free"]),
            (
                .visualAssistance,
                ["visual assistance", "blind traveler"]
            ),
            (
                .hearingAssistance,
                ["hearing assistance", "deaf traveler"]
            ),
            (.serviceAnimal, ["service animal"]),
            (.reducedWalking, ["limited walking", "reduced walking"]),
            (.quietEnvironment, ["quiet environment", "sensory friendly"])
        ]
        return matchedValues(mappings, in: transcript)
    }

    private static func parseTravelPace(
        in transcript: String
    ) -> TravelPace {
        let text = normalized(transcript)
        if
            text.contains("relaxed pace")
            || text.contains("slow pace")
            || text.contains("take it easy")
        {
            return .relaxed
        }
        if
            text.contains("active pace")
            || text.contains("packed itinerary")
            || text.contains("see as much as possible")
        {
            return .active
        }
        return .balanced
    }

    private static func parseFlightPreferences(
        in transcript: String
    ) -> FlightPreferences {
        let text = normalized(transcript)
        let travelClass: TravelClass
        if text.contains("first class") {
            travelClass = .first
        } else if text.contains("business class") {
            travelClass = .business
        } else if text.contains("premium economy") {
            travelClass = .premiumEconomy
        } else {
            travelClass = .economy
        }

        let stops: StopPreference
        if text.contains("nonstop") || text.contains("direct flight") {
            stops = .nonstopOnly
        } else if
            text.contains("at most one stop")
            || text.contains("one stop maximum")
        {
            stops = .atMostOne
        } else {
            stops = .any
        }

        let departureWindow: TimeWindow?
        if text.contains("morning flight") {
            departureWindow = TimeWindow(
                startMinute: 5 * 60,
                endMinute: 12 * 60
            )
        } else if text.contains("afternoon flight") {
            departureWindow = TimeWindow(
                startMinute: 12 * 60,
                endMinute: 17 * 60
            )
        } else if
            text.contains("evening flight")
            || text.contains("night flight")
        {
            departureWindow = TimeWindow(
                startMinute: 17 * 60,
                endMinute: 24 * 60 - 1
            )
        } else {
            departureWindow = nil
        }

        return FlightPreferences(
            travelClass: travelClass,
            stopPreference: stops,
            checkedBagRequired:
                text.contains("checked bag")
                || text.contains("checked luggage"),
            refundablePreferred:
                text.contains("refundable flight")
                || text.contains("refundable fare"),
            departureTimeWindow: departureWindow
        )
    }

    private static func parseHotelPreferences(
        in transcript: String
    ) -> HotelPreferences {
        let text = normalized(transcript)
        var types: Set<LodgingType> = []
        if text.contains("hostel") {
            types.insert(.hostel)
        }
        if text.contains("resort") {
            types.insert(.resort)
        }
        if
            text.contains("vacation rental")
            || text.contains("holiday rental")
        {
            types.insert(.vacationRental)
        }
        if text.contains("apartment") {
            types.insert(.apartment)
        }
        if text.contains("hotel") {
            types.insert(.hotel)
        }
        if types.isEmpty {
            types = [.hotel]
        }

        let amenities = matchedValues(
            [
                (HotelAmenity.accessibleRoom, ["accessible room"]),
                (HotelAmenity.airportShuttle, ["airport shuttle"]),
                (HotelAmenity.breakfast, ["hotel breakfast", "breakfast included"]),
                (HotelAmenity.fitnessCenter, ["fitness center", "hotel gym"]),
                (HotelAmenity.kitchen, ["kitchen", "kitchenette"]),
                (HotelAmenity.laundry, ["laundry"]),
                (HotelAmenity.parking, ["parking"]),
                (HotelAmenity.pool, ["pool"]),
                (HotelAmenity.spa, ["hotel spa"]),
                (HotelAmenity.wifi, ["wifi", "wi-fi"])
            ],
            in: transcript
        )
        let starPattern =
            #"\b([1-5])\s*[- ]?\s*star\s+(?:hotel|stay|property)\b"#
        let minimumStars = firstCapture(
            starPattern,
            in: transcript
        ).flatMap(Int.init)

        return HotelPreferences(
            allowedTypes: types,
            minimumStarRating: minimumStars,
            requiredAmenities: amenities,
            maximumNightlyRate:
                parseMaximumNightlyRate(in: transcript),
            refundablePreferred:
                text.contains("refundable hotel")
                || text.contains("free cancellation")
        )
    }

    private static func parseMaximumNightlyRate(
        in transcript: String
    ) -> Money? {
        let pattern =
            #"\b(?:under|below|up to|maximum(?:\s+of)?)\s*(\$|€|£|¥)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(USD|EUR|GBP|JPY|CAD|AUD)?\s*(?:per night|nightly|a night)\b"#
        guard
            let values = captures(pattern, in: transcript),
            values.count >= 2,
            let amount = Decimal(
                string: values[1].replacingOccurrences(
                    of: ",",
                    with: ""
                )
            )
        else {
            return nil
        }
        return Money(
            amount: amount,
            currencyCode: currencyCode(
                symbol: values[0],
                word: values.count > 2 ? values[2] : ""
            )
        )
    }

    private static func matchedValues<Value: Hashable>(
        _ mappings: [(Value, [String])],
        in transcript: String
    ) -> Set<Value> {
        let text = normalized(transcript)
        return Set(
            mappings.compactMap { value, keywords in
                keywords.contains {
                    text.contains(normalized($0))
                } ? value : nil
            }
        )
    }

    private static func parseNumberPhrase(_ value: String) -> Int? {
        let cleaned = normalized(value)
            .replacingOccurrences(of: "-", with: " ")
        if let direct = Int(cleaned.replacingOccurrences(of: ",", with: "")) {
            return direct
        }

        let smallNumbers: [String: Int] = [
            "zero": 0, "a": 1, "an": 1, "one": 1, "two": 2, "three": 3,
            "four": 4, "five": 5, "six": 6, "seven": 7,
            "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
            "twelve": 12, "thirteen": 13, "fourteen": 14,
            "fifteen": 15, "sixteen": 16, "seventeen": 17,
            "eighteen": 18, "nineteen": 19, "twenty": 20,
            "thirty": 30, "forty": 40, "fifty": 50,
            "sixty": 60, "seventy": 70, "eighty": 80,
            "ninety": 90
        ]
        var total = 0
        var current = 0
        var recognized = false

        for word in cleaned.split(separator: " ").map(String.init) {
            if let number = smallNumbers[word] {
                current += number
                recognized = true
            } else if word == "hundred" {
                current = max(current, 1) * 100
                recognized = true
            } else if word == "thousand" {
                total += max(current, 1) * 1_000
                current = 0
                recognized = true
            } else if word == "million" {
                total += max(current, 1) * 1_000_000
                current = 0
                recognized = true
            } else if word != "and" {
                return nil
            }
        }

        return recognized ? total + current : nil
    }

    private static func currencyCode(
        symbol: String,
        word: String
    ) -> String {
        let normalizedWord = normalized(word)
        if symbol == "€" || normalizedWord.contains("eur") {
            return "EUR"
        }
        if symbol == "£" || normalizedWord.contains("gbp")
            || normalizedWord.contains("pound")
        {
            return "GBP"
        }
        if symbol == "¥" || normalizedWord.contains("jpy")
            || normalizedWord.contains("yen")
        {
            return "JPY"
        }
        if normalizedWord.contains("cad") {
            return "CAD"
        }
        if normalizedWord.contains("aud") {
            return "AUD"
        }
        return "USD"
    }

    private static func monthNumber(_ value: String) -> Int? {
        let key = String(normalized(value).prefix(3))
        return [
            "jan": 1,
            "feb": 2,
            "mar": 3,
            "apr": 4,
            "may": 5,
            "jun": 6,
            "jul": 7,
            "aug": 8,
            "sep": 9,
            "oct": 10,
            "nov": 11,
            "dec": 12
        ][key]
    }

    private static func cleanPlaceName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map { word in
                let lower = word.lowercased()
                if ["and", "of", "the"].contains(lower) {
                    return lower
                }
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func firstCapture(
        _ pattern: String,
        in text: String
    ) -> String? {
        captures(pattern, in: text)?.first
    }

    private static func captures(
        _ pattern: String,
        in text: String
    ) -> [String]? {
        guard
            let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            )
        else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = expression.firstMatch(
                in: text,
                range: range
            )
        else {
            return nil
        }

        return (1..<match.numberOfRanges).map { index in
            let captureRange = match.range(at: index)
            guard
                captureRange.location != NSNotFound,
                let range = Range(captureRange, in: text)
            else {
                return ""
            }
            return String(text[range])
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US")
            )
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
