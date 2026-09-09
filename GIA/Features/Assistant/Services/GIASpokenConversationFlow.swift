import Foundation

enum GIAConversationIngestResult: Equatable, Sendable {
    case keepListening
    case askRequired(TripClarificationField)
    case askOptionalPreferences
    case readyToSearch
    case failed
}

@MainActor
final class GIASpokenConversationFlow {
    let session: TripPlanningSession
    private(set) var clarificationTurn: GIAClarificationTurn?

    init() {
        self.session = TripPlanningSession()
    }

    init(session: TripPlanningSession) {
        self.session = session
    }

    func startListening(
        source: TripActivationSource = .debug
    ) throws {
        try session.beginListening(source: source)
        try session.beginTranscribing()
    }

    func ingestInitial(
        _ transcript: String,
        now: Date = Date()
    ) -> GIAConversationIngestResult {
        let spoken = travelTranscript(from: transcript)
        let interpretation = TripRequestInterpreter.interpret(
            transcript: spoken,
            now: now
        )
        do {
            try session.beginValidation(request: interpretation.request)
            if interpretation.requiresClarification {
                try session.requestClarification(
                    for: interpretation.clarificationFields
                )
                guard
                    let field =
                        TripRequestInterpreter.preferredClarificationField(
                            in: interpretation.issues
                        )
                else {
                    return .failed
                }
                clarificationTurn = .required(field)
                return .askRequired(field)
            }
            try session.requestClarification(for: [.preferences])
            clarificationTurn = .optionalPreferences
            return .askOptionalPreferences
        } catch {
            return .failed
        }
    }

    func ingestClarification(
        _ transcript: String,
        now: Date = Date()
    ) -> GIAConversationIngestResult {
        guard
            let turn = clarificationTurn,
            let currentRequest = session.currentRequest
        else {
            return .failed
        }

        switch turn {
        case .optionalPreferences:
            if TripRequestInterpreter.isConversationCompletion(transcript) {
                return finishSearch(with: currentRequest, now: now)
            }
            if case .updated(let request, _) =
                TripRequestInterpreter.interpretFollowUp(
                    transcript: transcript,
                    applyingTo: currentRequest,
                    now: now
                )
            {
                return continueClarification(with: request, now: now)
            }
            return .askOptionalPreferences
        case .required(let field):
            guard
                let updated =
                    TripRequestInterpreter.interpretClarificationAnswer(
                        transcript,
                        for: field,
                        applyingTo: currentRequest,
                        now: now
                    )
            else {
                return .askRequired(field)
            }
            return continueClarification(with: updated, now: now)
        }
    }

    func runVoiceScript(
        destinationUtterance: String,
        dateUtterance: String,
        travelerUtterance: String,
        wrapUpUtterance: String = "that's it",
        now: Date = Date(timeIntervalSince1970: 1_788_000_000)
    ) throws -> TripRequest {
        try startListening()
        let first = ingestInitial(destinationUtterance, now: now)
        guard case .askRequired(.dates) = first else {
            throw GIASpokenConversationFlowError.unexpectedTurn(first)
        }

        var next = ingestClarification(dateUtterance, now: now)
        if case .askRequired(.dates) = next {
            throw GIASpokenConversationFlowError.unexpectedTurn(next)
        }
        if case .askRequired(.travelers) = next {
            next = ingestClarification(travelerUtterance, now: now)
        }

        switch next {
        case .askOptionalPreferences:
            let finished = ingestClarification(wrapUpUtterance, now: now)
            guard case .readyToSearch = finished else {
                throw GIASpokenConversationFlowError.unexpectedTurn(finished)
            }
        case .readyToSearch:
            break
        default:
            throw GIASpokenConversationFlowError.unexpectedTurn(next)
        }

        guard let request = session.currentRequest else {
            throw GIASpokenConversationFlowError.missingRequest
        }
        let leftover = TripRequestInterpreter.validate(request, now: now)
        guard leftover.isEmpty else {
            throw GIASpokenConversationFlowError.incompleteRequest
        }
        return request
    }

    private func continueClarification(
        with request: TripRequest,
        now: Date
    ) -> GIAConversationIngestResult {
        do {
            try session.beginValidation(request: request)
            let issues = TripRequestInterpreter.validate(request, now: now)
            if let field = TripRequestInterpreter.preferredClarificationField(
                in: issues
            ) {
                try session.requestClarification(
                    for: Set(issues.map(\.field))
                )
                clarificationTurn = .required(field)
                return .askRequired(field)
            }
            try session.requestClarification(for: [.preferences])
            clarificationTurn = .optionalPreferences
            return .askOptionalPreferences
        } catch {
            return .failed
        }
    }

    private func finishSearch(
        with request: TripRequest,
        now: Date
    ) -> GIAConversationIngestResult {
        do {
            try session.beginValidation(request: request)
            let issues = TripRequestInterpreter.validate(request, now: now)
            if let field = TripRequestInterpreter.preferredClarificationField(
                in: issues
            ) {
                try session.requestClarification(
                    for: Set(issues.map(\.field))
                )
                clarificationTurn = .required(field)
                return .askRequired(field)
            }
            clarificationTurn = nil
            return .readyToSearch
        } catch {
            return .failed
        }
    }

    private func travelTranscript(from spoken: String) -> String {
        if
            VoiceRecognitionRules.looksLikeBarePlace(spoken),
            TripRequestInterpreter.interpret(
                transcript: spoken
            ).request.destinations.isEmpty
        {
            return "trip to \(spoken)"
        }
        return spoken
    }
}

enum GIASpokenConversationFlowError: Error, Equatable {
    case unexpectedTurn(GIAConversationIngestResult)
    case missingRequest
    case incompleteRequest
}
