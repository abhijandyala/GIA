import AVFAudio
import Foundation
import Observation

enum GIAResponsePhrase: String, CaseIterable, Sendable {
    case requestCaptured
    case clarificationNeeded
    case betterFlightFound
    case planReady
    case timingConflict
    case followUpPrompt
    case updateCaptured
    case noChanges
    case changeNotUnderstood
    case searching
    case assembling
    case greetingTrip
    case greetingDestination
    case greetingPlan
    case goodbye
    case keepGoing
    case stillListening
    case whatDoYouMean
    case okay
    case gotIt
    case nice

    var text: String {
        switch self {
        case .requestCaptured:
            "Okay, I've got it."
        case .clarificationNeeded:
            "I need one more detail."
        case .betterFlightFound:
            "I found a better flight option."
        case .planReady:
            "Your plan is ready."
        case .timingConflict:
            "That change creates a timing conflict."
        case .followUpPrompt:
            "What would you like me to add, change, or remove?"
        case .updateCaptured:
            "Got it. I'm updating your plan now."
        case .noChanges:
            "Okay. I didn't change anything."
        case .changeNotUnderstood:
            "I didn't catch a change. Try add, change, remove, or cancel."
        case .searching:
            "I'm checking live flights, stays, and things to do."
        case .assembling:
            "Okay, I'm fitting the strongest options into your schedule."
        case .greetingTrip:
            "What's up? What trip are we planning?"
        case .greetingDestination:
            "Hey, how are you doing? Where are we thinking of going?"
        case .greetingPlan:
            "I'm here. What's the plan?"
        case .goodbye:
            "See you later."
        case .keepGoing:
            "Oh, sorry, keep going."
        case .stillListening:
            "I'm here. Just tell me the trip."
        case .whatDoYouMean:
            "What do you mean?"
        case .okay:
            "Okay."
        case .gotIt:
            "Got it."
        case .nice:
            "Nice."
        }
    }
}

enum GIAConversationBackchannel {
    static let phrases: [GIAResponsePhrase] = [.okay, .gotIt, .nice]

    static func phrase(for utterance: String) -> GIAResponsePhrase {
        let sum = utterance.unicodeScalars.reduce(into: 0) { total, scalar in
            total = total &+ Int(scalar.value)
        }
        return phrases[abs(sum) % phrases.count]
    }
}

enum GIAConversationFallback {
    static func response(
        for intent: GIAConversationIntent
    ) -> GIAConversationResponse {
        switch intent {
        case .requestCaptured:
            GIAConversationResponse(
                spokenText: "Okay. I've got it.",
                displayText: "Your request is captured.",
                intent: intent,
                shouldContinueListening: false
            )
        case .clarificationNeeded:
            GIAConversationResponse(
                spokenText:
                    "Okay. I just need one more detail.",
                displayText:
                    "I need one more detail before continuing.",
                intent: intent,
                shouldContinueListening: true
            )
        case .resultsReady:
            GIAConversationResponse(
                spokenText:
                    "Okay. Your plan is ready to review.",
                displayText: "Your plan is ready to review.",
                intent: intent,
                shouldContinueListening: false
            )
        case .timingConflict:
            GIAConversationResponse(
                spokenText:
                    "That change creates a timing conflict.",
                displayText:
                    "That change creates a timing conflict.",
                intent: intent,
                shouldContinueListening: false
            )
        case .providerUnavailable:
            GIAConversationResponse(
                spokenText:
                    "I couldn't reach live travel services, "
                    + "but your request is still here.",
                displayText:
                    "Live travel services are unavailable. "
                    + "Your request remains in this session.",
                intent: intent,
                shouldContinueListening: false
            )
        }
    }

    static func response(
        for phrase: GIAResponsePhrase
    ) -> GIAConversationResponse {
        switch phrase {
        case .requestCaptured:
            response(
                for: GIAConversationIntent.requestCaptured
            )
        case .clarificationNeeded:
            response(
                for: GIAConversationIntent.clarificationNeeded
            )
        case .betterFlightFound:
            GIAConversationResponse(
                spokenText:
                    "I found a better flight option.",
                displayText:
                    "I found a better flight option.",
                intent: .resultsReady,
                shouldContinueListening: false
            )
        case .planReady:
            response(for: GIAConversationIntent.resultsReady)
        case .timingConflict:
            response(for: GIAConversationIntent.timingConflict)
        case .followUpPrompt:
            GIAConversationResponse(
                spokenText: phrase.text,
                displayText:
                    "What would you like to add, change, or remove?",
                intent: .clarificationNeeded,
                shouldContinueListening: true
            )
        case .updateCaptured:
            GIAConversationResponse(
                spokenText: phrase.text,
                displayText: "Updating your plan.",
                intent: .requestCaptured,
                shouldContinueListening: false
            )
        case .noChanges:
            GIAConversationResponse(
                spokenText: phrase.text,
                displayText: "No changes were made.",
                intent: .requestCaptured,
                shouldContinueListening: false
            )
        case .changeNotUnderstood:
            GIAConversationResponse(
                spokenText: phrase.text,
                displayText:
                    "Try add, change, remove, or cancel.",
                intent: .clarificationNeeded,
                shouldContinueListening: true
            )
        case .searching, .assembling:
            GIAConversationResponse(
                spokenText: phrase.text,
                displayText: phrase.text,
                intent: .requestCaptured,
                shouldContinueListening: false
            )
        case
            .greetingTrip,
            .greetingDestination,
            .greetingPlan:
            GIAConversationResponse(
                spokenText: phrase.text,
                displayText: phrase.text,
                intent: .clarificationNeeded,
                shouldContinueListening: true
            )
        case .goodbye:
            GIAConversationResponse(
                spokenText: phrase.text,
                displayText: phrase.text,
                intent: .requestCaptured,
                shouldContinueListening: false
            )
        case .keepGoing, .stillListening, .whatDoYouMean:
            GIAConversationResponse(
                spokenText: phrase.text,
                displayText: phrase.text,
                intent: .clarificationNeeded,
                shouldContinueListening: true
            )
        case .okay, .gotIt, .nice:
            GIAConversationResponse(
                spokenText: phrase.text,
                displayText: phrase.text,
                intent: .clarificationNeeded,
                shouldContinueListening: true
            )
        }
    }
}

enum GIAResponseState: String, Sendable {
    case idle
    case generating
    case playing
    case failed
}

enum GIASpeechPlaybackSource: String, Sendable {
    case none
    case elevenLabs
    case systemFallback
}

@MainActor
@Observable
final class GIAResponseCoordinator:
    NSObject,
    AVAudioPlayerDelegate,
    AVSpeechSynthesizerDelegate
{
    private(set) var state: GIAResponseState = .idle
    private(set) var visibleText = ""
    private(set) var playbackLevel: CGFloat = 0
    private(set) var failureMessage: String?
    private(set) var lastResponse: GIAConversationResponse?
    private(set) var usedFallbackResponse = false
    private(set) var preservesListening = false
    private(set) var speechPlaybackSource: GIASpeechPlaybackSource = .none
    private(set) var isHoldingConversationTurn = false

    var isPlaying: Bool {
        state == .playing
    }

    @ObservationIgnored
    private let speechGenerator: (any SpeechGenerating)?
    @ObservationIgnored
    private let responseGenerator: (any AssistantResponding)?
    @ObservationIgnored
    private let replyInterpreter: (any TripReplyInterpreting)?
    @ObservationIgnored
    private let allowsSystemVoiceFallback: Bool
    @ObservationIgnored
    private let allowsCannedReplyFallback: Bool
    @ObservationIgnored
    private var audioPlayer: AVAudioPlayer?
    @ObservationIgnored
    private let speechSynthesizer = AVSpeechSynthesizer()
    @ObservationIgnored
    private var playbackContinuation:
        CheckedContinuation<Bool, Never>?
    @ObservationIgnored
    private var meteringTask: Task<Void, Never>?
    @ObservationIgnored
    private var localSpeechMeteringTask: Task<Void, Never>?
    @ObservationIgnored
    private var localSpeechGeneration: Int?
    @ObservationIgnored
    private var generation = 0
    @ObservationIgnored
    private var phraseCache: [GIAResponsePhrase: GeneratedSpeech] = [:]
    @ObservationIgnored
    private var clearsVisibleTextOnFinish = true
    @ObservationIgnored
    private var isPlayingBackchannel = false

    override convenience init() {
        let service = GIAAssistantServiceFactory.make()
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let speechGenerator: (any SpeechGenerating)? =
            environment["GIA_DEBUG_DISABLE_SPEECH"] == "1"
            ? nil
            : service
        let strictProviderFailures =
            environment["GIA_DEBUG_STRICT_PROVIDER_FAILURES"] == "1"
        self.init(
            speechGenerator: speechGenerator,
            responseGenerator: service,
            replyInterpreter: service,
            allowsSystemVoiceFallback:
                !strictProviderFailures
                && environment["GIA_DEBUG_DISABLE_SPEECH"] != "1",
            allowsCannedReplyFallback: !strictProviderFailures
        )
        #else
        self.init(
            speechGenerator: service,
            responseGenerator: service,
            replyInterpreter: service
        )
        #endif
    }

    init(
        speechGenerator: (any SpeechGenerating)?,
        responseGenerator: (any AssistantResponding)? = nil,
        replyInterpreter: (any TripReplyInterpreting)? = nil,
        allowsSystemVoiceFallback: Bool = true,
        allowsCannedReplyFallback: Bool = true
    ) {
        self.speechGenerator = speechGenerator
        self.responseGenerator = responseGenerator
        self.replyInterpreter = replyInterpreter
        self.allowsSystemVoiceFallback = allowsSystemVoiceFallback
        self.allowsCannedReplyFallback = allowsCannedReplyFallback
        super.init()
        speechSynthesizer.delegate = self
    }

    func interpretSpokenReply(
        _ request: TripReplyInterpretationRequest,
        timeoutNanoseconds: UInt64 = 900_000_000
    ) async -> TripReplyInterpretation? {
        guard let replyInterpreter else { return nil }
        return await firstResult(
            timeoutNanoseconds: timeoutNanoseconds
        ) {
            if Task.isCancelled {
                return nil
            }
            return try? await replyInterpreter.interpretReply(
                matching: request
            )
        }
    }

    func compose(
        to context: GIAConversationContext,
        fallback: GIAConversationResponse? = nil
    ) async -> GIAConversationResponse? {
        guard
            let prepared = await prepareConversationReply(
                to: context,
                fallback: fallback
            )
        else {
            return nil
        }
        state = .idle
        return prepared.response
    }

    func presentText(_ response: GIAConversationResponse) {
        stop(clearVisibleText: false)
        generation &+= 1
        lastResponse = response
        visibleText = response.displayText
        failureMessage = nil
        state = .idle
        usedFallbackResponse = true
        isHoldingConversationTurn = false
        isPlayingBackchannel = false
    }

    func beginHeldTurn() {
        audioPlayer?.stop()
        audioPlayer = nil
        localSpeechGeneration = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
        playbackContinuation?.resume(returning: false)
        playbackContinuation = nil
        isHoldingConversationTurn = true
        isPlayingBackchannel = false
        failureMessage = nil
        state = .generating
        speechPlaybackSource = .none
    }

    func playBackchannel(_ phrase: GIAResponsePhrase) async {
        isPlayingBackchannel = true
        isHoldingConversationTurn = true
        failureMessage = nil
        if state != .playing {
            state = .generating
        }
        guard speechGenerator != nil else {
            isPlayingBackchannel = false
            state = .generating
            return
        }
        let keptText = visibleText
        let keptResponse = lastResponse
        _ = await generateAndPlay(
            response: GIAConversationFallback.response(for: phrase),
            cachedPhrase: phrase,
            generation: generation,
            preservesListening: true,
            updatesVisibleText: false
        )
        visibleText = keptText
        lastResponse = keptResponse
        usedFallbackResponse = false
        isPlayingBackchannel = false
        if isHoldingConversationTurn, state != .playing {
            state = .generating
        }
    }

    func prefetchBackchannelAudio() async {
        guard let speechGenerator else { return }
        for phrase in GIAConversationBackchannel.phrases {
            if phraseCache[phrase] != nil {
                continue
            }
            if
                let speech = await generatedSpeech(
                    from: speechGenerator,
                    text: phrase.text
                )
            {
                phraseCache[phrase] = speech
            }
        }
    }

    func respond(
        to context: GIAConversationContext,
        fallback: GIAConversationResponse? = nil
    ) async -> Bool {
        guard
            let prepared = await prepareConversationReply(
                to: context,
                fallback: fallback
            )
        else {
            return false
        }
        await waitForBackchannelIfNeeded()
        isHoldingConversationTurn = true
        let played = await generateAndPlay(
            response: prepared.response,
            cachedPhrase: nil,
            generation: prepared.generation
        )
        isHoldingConversationTurn = false
        return played
    }

    private struct PreparedConversationReply {
        var response: GIAConversationResponse
        var generation: Int
    }

    private func prepareConversationReply(
        to context: GIAConversationContext,
        fallback: GIAConversationResponse?
    ) async -> PreparedConversationReply? {
        if isHoldingConversationTurn || isPlayingBackchannel {
            failureMessage = nil
            state = .generating
        } else {
            stop(clearVisibleText: true)
        }
        let currentGeneration = generation
        let fallbackResponse =
            fallback
            ?? GIAConversationFallback.response(
                for: context.intent
            )
        failureMessage = nil
        state = .generating
        usedFallbackResponse = true

        var response = fallbackResponse
        if let responseGenerator {
            switch await generatedResponse(
                from: responseGenerator,
                context: context
            ) {
            case .success(let generated)
                where Self.isValid(generated, for: context):
                response = generated
                usedFallbackResponse = false
            case .success:
                if allowsCannedReplyFallback {
                    break
                }
                publishFailure(
                    "Assistant reply was rejected. Check the gateway log."
                )
                return nil
            case .failure(let message):
                if allowsCannedReplyFallback {
                    break
                }
                publishFailure(message)
                return nil
            case nil:
                if allowsCannedReplyFallback {
                    break
                }
                publishFailure(
                    "Assistant reply timed out. Check the gateway."
                )
                return nil
            }
        } else if !allowsCannedReplyFallback {
            publishFailure(
                "Assistant replies are disabled in this build."
            )
            return nil
        }
        guard
            generation == currentGeneration,
            !Task.isCancelled
        else {
            return nil
        }
        lastResponse = response
        visibleText = response.displayText
        return PreparedConversationReply(
            response: response,
            generation: currentGeneration
        )
    }

    func speak(
        _ phrase: GIAResponsePhrase,
        preservesListening: Bool = false
    ) async -> Bool {
        self.preservesListening = preservesListening
        stop(
            clearVisibleText: false,
            deactivateAudio: !preservesListening
        )
        self.preservesListening = preservesListening
        generation &+= 1
        let currentGeneration = generation
        let response = GIAConversationFallback.response(
            for: phrase
        )
        visibleText = response.displayText
        lastResponse = response
        failureMessage = nil
        state = .generating
        usedFallbackResponse = true
        return await generateAndPlay(
            response: response,
            cachedPhrase: phrase,
            generation: currentGeneration,
            preservesListening: preservesListening
        )
    }

    func speak(
        _ response: GIAConversationResponse,
        preservesListening: Bool = false
    ) async -> Bool {
        self.preservesListening = preservesListening
        stop(
            clearVisibleText: false,
            deactivateAudio: !preservesListening
        )
        self.preservesListening = preservesListening
        generation &+= 1
        let currentGeneration = generation
        visibleText = response.displayText
        lastResponse = response
        failureMessage = nil
        state = .generating
        usedFallbackResponse = true
        return await generateAndPlay(
            response: response,
            cachedPhrase: nil,
            generation: currentGeneration,
            preservesListening: preservesListening
        )
    }

    private func generateAndPlay(
        response: GIAConversationResponse,
        cachedPhrase: GIAResponsePhrase?,
        generation currentGeneration: Int,
        preservesListening: Bool = false,
        updatesVisibleText: Bool = true
    ) async -> Bool {
        speechPlaybackSource = .none
        guard let speechGenerator else {
            return await playSystemVoiceFallback(
                response.spokenText,
                generation: currentGeneration,
                overlapping: preservesListening
            )
        }

        let texts: [String]
        if cachedPhrase != nil {
            texts = Self.speechRequestTexts(for: response.spokenText)
        } else {
            texts = GIAConversationCopy.spokenPlaybackSegments(
                for: response.spokenText
            )
        }
        guard !texts.isEmpty else {
            return await playSystemVoiceFallback(
                response.spokenText,
                generation: currentGeneration,
                overlapping: preservesListening
            )
        }

        if
            let cachedPhrase,
            let cached = phraseCache[cachedPhrase]
        {
            let played = await playGeneratedSpeech(
                cached,
                generation: currentGeneration,
                preservesListening: preservesListening,
                clearVisibleTextOnSuccess: false
            )
            if played {
                return true
            }
            guard generation == currentGeneration else {
                return false
            }
            return await playSystemVoiceFallback(
                response.spokenText,
                generation: currentGeneration,
                overlapping: preservesListening
            )
        }

        var playedAny = false
        var pendingSpeech: GeneratedSpeech?
        if texts.count > 1 {
            let restText = texts[1]
            pendingSpeech = nil
            async let restGeneration = generatedSpeech(
                from: speechGenerator,
                text: restText
            )
            guard
                let firstSpeech = await generatedSpeech(
                    from: speechGenerator,
                    text: texts[0]
                )
            else {
                return await playSystemVoiceFallback(
                    response.spokenText,
                    generation: currentGeneration,
                    overlapping: preservesListening
                )
            }
            isHoldingConversationTurn = updatesVisibleText
            let playedFirst = await playGeneratedSpeech(
                firstSpeech,
                generation: currentGeneration,
                preservesListening: true,
                clearVisibleTextOnSuccess: false
            )
            pendingSpeech = await restGeneration
            if playedFirst {
                playedAny = true
                if generation == currentGeneration {
                    state = .generating
                }
            }
            if
                let rest = pendingSpeech,
                generation == currentGeneration,
                !Task.isCancelled
            {
                if updatesVisibleText {
                    isHoldingConversationTurn = false
                }
                let playedRest = await playGeneratedSpeech(
                    rest,
                    generation: currentGeneration,
                    preservesListening: preservesListening,
                    clearVisibleTextOnSuccess: false
                )
                playedAny = playedAny || playedRest
            }
            return playedAny
        }
        for (index, speechText) in texts.enumerated() {
            guard generation == currentGeneration, !Task.isCancelled else {
                return playedAny
            }
            let isLast = index == texts.count - 1
            if updatesVisibleText {
                isHoldingConversationTurn = !isLast
            }
            guard
                let generated = await generatedSpeech(
                    from: speechGenerator,
                    text: speechText
                )
            else {
                if playedAny {
                    continue
                }
                return await playSystemVoiceFallback(
                    response.spokenText,
                    generation: currentGeneration,
                    overlapping: preservesListening
                )
            }
            if let cachedPhrase {
                phraseCache[cachedPhrase] = generated
            }
            let played = await playGeneratedSpeech(
                generated,
                generation: currentGeneration,
                preservesListening: preservesListening || !isLast,
                clearVisibleTextOnSuccess: false
            )
            if played {
                playedAny = true
            } else if !playedAny {
                return await playSystemVoiceFallback(
                    response.spokenText,
                    generation: currentGeneration,
                    overlapping: preservesListening
                )
            }
            if !isLast, generation == currentGeneration {
                state = .generating
            }
        }
        return playedAny
    }

    private func waitForBackchannelIfNeeded() async {
        while isPlayingBackchannel, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    static func speechRequestTexts(for text: String) -> [String] {
        GIAConversationCopy.spokenPlaybackSegments(for: text)
    }

    private func playGeneratedSpeech(
        _ speech: GeneratedSpeech,
        generation currentGeneration: Int,
        preservesListening: Bool,
        clearVisibleTextOnSuccess: Bool,
        overlappingAudioSession: Bool? = nil
    ) async -> Bool {
        guard
            generation == currentGeneration,
            !Task.isCancelled
        else {
            return false
        }
        guard
            speech.contentType
                .lowercased()
                .hasPrefix("audio/mpeg"),
            !speech.audioData.isEmpty
        else {
            return false
        }

        do {
            try configureAudioSession(
                overlapping:
                    overlappingAudioSession ?? preservesListening
            )
            let player = try AVAudioPlayer(data: speech.audioData)
            player.delegate = self
            player.isMeteringEnabled = true
            player.volume = 1
            player.prepareToPlay()
            audioPlayer = player
            clearsVisibleTextOnFinish = clearVisibleTextOnSuccess

            return await withCheckedContinuation { continuation in
                playbackContinuation = continuation
                guard player.play() else {
                    finishPlayback(success: false)
                    return
                }
                speechPlaybackSource = .elevenLabs
                state = .playing
                startMetering(generation: currentGeneration)
            }
        } catch {
            return false
        }
    }

    func stop(
        clearVisibleText: Bool = true,
        deactivateAudio: Bool = true
    ) {
        generation &+= 1
        audioPlayer?.stop()
        audioPlayer = nil
        localSpeechGeneration = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
        meteringTask?.cancel()
        meteringTask = nil
        localSpeechMeteringTask?.cancel()
        localSpeechMeteringTask = nil
        playbackLevel = 0
        state = .idle
        failureMessage = nil
        isHoldingConversationTurn = false
        isPlayingBackchannel = false
        if clearVisibleText {
            visibleText = ""
        }
        playbackContinuation?.resume(returning: false)
        playbackContinuation = nil
        if deactivateAudio {
            preservesListening = false
            deactivateAudioSession()
        }
    }

    func purgeCachedAudio() {
        phraseCache.removeAll(keepingCapacity: false)
    }

    func cancelPendingResponse(
        message: String =
            "G.I.A. voice is taking too long. The response is shown."
    ) {
        guard state == .generating else { return }
        generation &+= 1
        audioPlayer?.stop()
        audioPlayer = nil
        localSpeechGeneration = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
        meteringTask?.cancel()
        meteringTask = nil
        localSpeechMeteringTask?.cancel()
        localSpeechMeteringTask = nil
        playbackLevel = 0
        state = .failed
        failureMessage = message
        playbackContinuation?.resume(returning: false)
        playbackContinuation = nil
        deactivateAudioSession()
    }

    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            guard self?.audioPlayer === player else { return }
            self?.finishPlayback(success: flag)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard self?.audioPlayer === player else { return }
            self?.finishPlayback(success: false)
        }
    }

    private static func isValid(
        _ response: GIAConversationResponse,
        for context: GIAConversationContext
    ) -> Bool {
        let spoken = response.spokenText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let display = response.displayText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return
            response.intent == context.intent
            && !spoken.isEmpty
            && spoken.count <= 240
            && !display.isEmpty
            && display.count <= 300
            && response.shouldContinueListening
                == (
                    context.intent == .clarificationNeeded
                )
    }

    private enum LiveReplyOutcome: Sendable {
        case success(GIAConversationResponse)
        case failure(String)
    }

    private func generatedResponse(
        from generator: any AssistantResponding,
        context: GIAConversationContext
    ) async -> LiveReplyOutcome? {
        await firstResult(
            timeoutNanoseconds: 8_000_000_000
        ) {
            if Task.isCancelled {
                return nil
            }
            do {
                let response = try await generator.generateResponse(
                    matching: context
                )
                return .success(response)
            } catch let error as GatewayClientError {
                return .failure(Self.message(for: error))
            } catch {
                return .failure(error.localizedDescription)
            }
        }
    }

    nonisolated private static func message(
        for error: GatewayClientError
    ) -> String {
        switch error {
        case .providerUnavailable(let code, let message):
            "\(code). \(message)"
        case .timedOut:
            "Assistant reply timed out."
        case .transportFailure:
            "Could not reach the G.I.A. gateway."
        case .unauthorized, .forbidden:
            "Gateway authorization failed."
        case .rateLimited:
            "The assistant is busy. Try again shortly."
        case .serverFailure:
            "The gateway returned a server failure."
        case .decodingFailed:
            "The assistant reply could not be read."
        case .cancelled:
            "Assistant reply was cancelled."
        case .invalidBaseURL, .invalidResponse, .encodingFailed:
            "Assistant reply failed."
        }
    }

    private func generatedSpeech(
        from generator: any SpeechGenerating,
        text: String
    ) async -> GeneratedSpeech? {
        await firstResult(
            timeoutNanoseconds: 8_000_000_000
        ) {
            if Task.isCancelled {
                return nil
            }
            return
                try? await generator.generateSpeech(
                    matching: SpeechGenerationCriteria(
                        text: GIAConversationCopy.spoken(text),
                        voiceIdentifier: nil,
                        outputFormat: "mp3_44100_128"
                    )
                )
        }
    }

    private func firstResult<Value: Sendable>(
        timeoutNanoseconds: UInt64,
        operation:
            @escaping @Sendable () async -> Value?
    ) async -> Value? {
        await withCheckedContinuation { continuation in
            let gate = OneShotContinuationGate<Value>(
                continuation: continuation
            )
            let operationTask = Task.detached(
                priority: .userInitiated
            ) {
                let value = await operation()
                await gate.resolve(value)
            }
            Task.detached(priority: .userInitiated) {
                try? await Task.sleep(
                    nanoseconds: timeoutNanoseconds
                )
                operationTask.cancel()
                await gate.resolve(nil)
            }
        }
    }

    private func configureAudioSession(
        overlapping: Bool = false
    ) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        if overlapping {
            try session.setActive(true)
            return
        }
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [
                .defaultToSpeaker,
                .duckOthers,
                .allowBluetoothHFP
            ]
        )
        try session.setActive(true)
        #endif
    }

    private func startMetering(generation: Int) {
        meteringTask?.cancel()
        meteringTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_333_333)
                guard
                    let self,
                    self.generation == generation,
                    let player = self.audioPlayer,
                    player.isPlaying
                else {
                    return
                }

                player.updateMeters()
                let decibels = player.averagePower(forChannel: 0)
                let linear = CGFloat(
                    pow(10, Double(decibels) / 20)
                )
                let target = min(
                    max(pow(linear, 0.58) * 1.35, 0),
                    1
                )
                self.playbackLevel +=
                    (target - self.playbackLevel) * 0.42
            }
        }
    }

    private func playSystemVoiceFallback(
        _ text: String,
        generation currentGeneration: Int,
        overlapping: Bool = false
    ) async -> Bool {
        guard
            generation == currentGeneration,
            !Task.isCancelled,
            !text.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        else {
            return false
        }
        guard allowsSystemVoiceFallback else {
            publishFailure(
                "G.I.A. voice is unavailable. The response is shown."
            )
            return false
        }

        do {
            try configureAudioSession(overlapping: overlapping)
        } catch {
            publishFailure(
                "G.I.A. voice could not play. The response is shown."
            )
            return false
        }

        let utterance = AVSpeechUtterance(
            string: GIAConversationCopy.spoken(text)
        )
        utterance.voice =
            AVSpeechSynthesisVoice.speechVoices().first {
                $0.language == "en-US"
                    && $0.quality == .enhanced
            }
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.02
        utterance.volume = 1
        utterance.preUtteranceDelay = 0.04
        clearsVisibleTextOnFinish = false
        speechPlaybackSource = .systemFallback
        state = .playing
        localSpeechGeneration = currentGeneration
        startLocalSpeechMetering(generation: currentGeneration)

        return await withCheckedContinuation { continuation in
            playbackContinuation = continuation
            speechSynthesizer.speak(utterance)
        }
    }

    private func startLocalSpeechMetering(generation: Int) {
        localSpeechMeteringTask?.cancel()
        localSpeechMeteringTask = Task { [weak self] in
            var phase = 0.0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 45_000_000)
                guard
                    let self,
                    self.generation == generation,
                    self.speechSynthesizer.isSpeaking
                else {
                    return
                }
                phase += 0.72
                let voiceEnvelope =
                    0.20
                    + (abs(sin(phase)) * 0.34)
                    + (abs(sin(phase * 0.43)) * 0.16)
                self.playbackLevel = min(voiceEnvelope, 0.78)
            }
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard
                self?.speechSynthesizer === synthesizer,
                self?.localSpeechGeneration != nil
            else {
                return
            }
            self?.finishPlayback(success: true)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard
                self?.speechSynthesizer === synthesizer,
                self?.localSpeechGeneration != nil
            else {
                return
            }
            self?.finishPlayback(success: false)
        }
    }

    private func finishPlayback(success: Bool) {
        audioPlayer = nil
        localSpeechGeneration = nil
        meteringTask?.cancel()
        meteringTask = nil
        localSpeechMeteringTask?.cancel()
        localSpeechMeteringTask = nil
        playbackLevel = 0
        if success {
            failureMessage = nil
            if clearsVisibleTextOnFinish {
                visibleText = ""
            }
            if isHoldingConversationTurn {
                state = .generating
                playbackContinuation?.resume(returning: success)
                playbackContinuation = nil
                return
            }
            // Conversational prompts stay visible while the microphone is
            // re-armed, but playback must leave PLAYING and release the
            // audio session so request capture can start.
            state = .idle
            preservesListening = false
            deactivateAudioSession()
        } else {
            state = .failed
            failureMessage =
                "G.I.A. voice could not finish. The response is shown."
        }
        clearsVisibleTextOnFinish = true
        playbackContinuation?.resume(returning: success)
        playbackContinuation = nil
    }

    #if DEBUG
    func simulateSuccessfulPlaybackCompletionForTesting(
        visibleText text: String,
        clearsVisibleText: Bool
    ) {
        stop()
        visibleText = text
        state = .playing
        clearsVisibleTextOnFinish = clearsVisibleText
        finishPlayback(success: true)
    }
    #endif

    private func publishFailure(_ message: String) {
        state = .failed
        playbackLevel = 0
        failureMessage = message
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        #endif
    }
}

private actor OneShotContinuationGate<Value: Sendable> {
    private var continuation:
        CheckedContinuation<Value?, Never>?

    init(
        continuation: CheckedContinuation<Value?, Never>
    ) {
        self.continuation = continuation
    }

    func resolve(_ value: Value?) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: value)
    }
}

enum GIAAssistantServiceFactory {
    static func make() -> GatewayTravelService? {
        let environment = ProcessInfo.processInfo.environment
        #if DEBUG
        if environment["GIA_DEBUG_DISABLE_GATEWAY"] == "1" {
            return nil
        }
        let rawURL =
            environment["GIA_GATEWAY_BASE_URL"]
            ?? Bundle.main.object(
                forInfoDictionaryKey: "GIAGatewayBaseURL"
            ) as? String
            ?? "http://127.0.0.1:8787"
        #else
        guard
            let rawURL =
                environment["GIA_GATEWAY_BASE_URL"]
                ?? Bundle.main.object(
                    forInfoDictionaryKey: "GIAGatewayBaseURL"
                ) as? String
        else {
            return nil
        }
        #endif
        guard
            let baseURL = URL(string: rawURL),
            !rawURL.isEmpty
        else {
            return nil
        }

        let authorizationProvider:
            any GatewayAuthorizationProviding
        #if DEBUG
        authorizationProvider =
            DebugEnvironmentGatewayAuthorizationProvider()
        #else
        authorizationProvider =
            AnonymousGatewayAuthorizationProvider()
        #endif

        let client = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: baseURL,
                requestTimeout: 12,
                retryPolicy: GatewayRetryPolicy(
                    maximumAttempts: 2,
                    baseDelay: 0.25,
                    maximumDelay: 0.75
                ),
                authorizationProvider: authorizationProvider
            )
        )
        return GatewayTravelService(client: client)
    }
}
