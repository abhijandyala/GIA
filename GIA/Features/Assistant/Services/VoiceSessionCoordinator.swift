import AVFAudio
import Foundation
import Observation
import Speech

enum VoiceSessionMode: String, Sendable {
    case stopped
    case wakePhrase
    case requestTranscription
    case bargeIn
}

enum VoiceSessionFailure: String, Sendable {
    case permissionDenied
    case recognitionUnavailable
    case noSpeechDetected
    case recognitionInterrupted

    var userMessage: String {
        switch self {
        case .permissionDenied:
            "Microphone and speech access are required."
        case .recognitionUnavailable:
            "Speech recognition is temporarily unavailable."
        case .noSpeechDetected:
            "I did not hear a travel request."
        case .recognitionInterrupted:
            "The request could not be transcribed."
        }
    }
}

enum VoicePermissionState: String, Sendable {
    case notDetermined
    case requesting
    case authorized
    case denied
}

@MainActor
@Observable
final class VoiceSessionCoordinator {
    private(set) var mode: VoiceSessionMode = .stopped
    private(set) var level: CGFloat = 0
    private(set) var isUserSpeaking = false
    private(set) var liveTranscript = ""
    private(set) var completedTranscript: String?
    private(set) var detectedWakePhrase: String?
    private(set) var wakeDetectionSequence = 0
    private(set) var transcriptionSequence = 0
    private(set) var bargeInSequence = 0
    private(set) var failureSequence = 0
    private(set) var lastFailure: VoiceSessionFailure?
    private(set) var permissionDenied = false
    private(set) var recognitionUnavailable = false
    private(set) var permissionState:
        VoicePermissionState = .notDetermined
    private(set) var usesOnDeviceRecognition = false
    private(set) var recognitionRestartCount = 0

    @ObservationIgnored
    private let audioEngine = AVAudioEngine()
    @ObservationIgnored
    private let speechRecognizer = SFSpeechRecognizer(
        locale: Locale(identifier: "en_US")
    )
    @ObservationIgnored
    private var recognitionRequest:
        SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored
    private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored
    private var restartTask: Task<Void, Never>?
    @ObservationIgnored
    private var dynamicsTask: Task<Void, Never>?
    @ObservationIgnored
    private var desiredMode: VoiceSessionMode = .stopped
    @ObservationIgnored
    private var sessionGeneration = 0
    @ObservationIgnored
    private var isTapInstalled = false
    @ObservationIgnored
    private var noiseFloorDecibels: Float = -48
    @ObservationIgnored
    private var targetLevel: CGFloat = 0
    @ObservationIgnored
    private var lastMeasurementTime: TimeInterval = 0
    @ObservationIgnored
    private var sessionStartedAt: TimeInterval = 0
    @ObservationIgnored
    private var lastTranscriptUpdateAt: TimeInterval = 0
    @ObservationIgnored
    private var lastVoiceActivityAt: TimeInterval = 0
    @ObservationIgnored
    private var hasDetectedSpeech = false
    @ObservationIgnored
    private var isPostWakeCapture = false
    @ObservationIgnored
    private var recognitionEpoch = 0
    @ObservationIgnored
    private var bargeInArmedAt: TimeInterval = 0
    @ObservationIgnored
    private var bargeInVoiceStartedAt: TimeInterval = 0
    @ObservationIgnored
    private var prefersOnDeviceRecognition = true
    @ObservationIgnored
    private var hasRetriedWithoutOnDeviceRecognition = false
    @ObservationIgnored
    private var isVoiceProcessingEnabled = false
    @ObservationIgnored
    private let speechDetector = SpeechActivityDetector()
    @ObservationIgnored
    private var isSpeechUtteranceActive = false
    @ObservationIgnored
    private var speechSilenceDuration: TimeInterval = 0
    @ObservationIgnored
    private var isStartingSession = false
    @ObservationIgnored
    private var isFinalizingRequest = false
    @ObservationIgnored
    private var finalizeTimeoutTask: Task<Void, Never>?
    @ObservationIgnored
    nonisolated(unsafe) private var isRecognitionAudioOpen = true

    func startWakePhraseListening() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment[
            "GIA_AUTORUN_PLAN_HANDOFF_TRANSCRIPT"
        ] != nil
            || ProcessInfo.processInfo.environment[
                "GIA_DEBUG_INJECT_TRANSCRIPT"
            ] != nil
        {
            return
        }
        #endif

        clearRecognitionOutput()
        resetRecognitionPreference()
        await start(mode: .wakePhrase)
    }

    func startRequestTranscription() async {
        recognitionUnavailable = false
        clearRecognitionOutput()
        resetRecognitionPreference()
        await start(mode: .requestTranscription)
    }

    func startBargeInListening() async {
        resetRecognitionPreference()
        await start(mode: .bargeIn)
    }

    func pauseForSpeechPlayback() {
        stop()
    }

    #if DEBUG
    /// Publishes text through the same observable completion event consumed
    /// after live speech recognition finishes. Simulator automation therefore
    /// exercises the real conversation path without opening the microphone.
    func injectCompletedTranscript(_ transcript: String) {
        let normalized = VoiceRecognitionRules
            .strippingWakePhrasePrefix(from: transcript)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        stop()
        liveTranscript = normalized
        completedTranscript = normalized
        lastFailure = nil
        transcriptionSequence &+= 1
    }
    #endif

    func stop() {
        desiredMode = .stopped
        sessionGeneration &+= 1
        restartTask?.cancel()
        restartTask = nil
        finalizeTimeoutTask?.cancel()
        finalizeTimeoutTask = nil
        isFinalizingRequest = false
        isRecognitionAudioOpen = false
        tearDownRecognitionSession()
    }

    private func start(mode requestedMode: VoiceSessionMode) async {
        if
            requestedMode == desiredMode,
            (
                isStartingSession
                    || (
                        mode == requestedMode
                        && audioEngine.isRunning
                        && isTapInstalled
                    )
            )
        {
            return
        }

        desiredMode = requestedMode
        sessionGeneration &+= 1
        let generation = sessionGeneration
        isStartingSession = true
        defer { isStartingSession = false }

        restartTask?.cancel()
        restartTask = nil
        finalizeTimeoutTask?.cancel()
        finalizeTimeoutTask = nil
        isFinalizingRequest = false
        tearDownRecognitionSession(deactivateAudio: false)
        permissionState = .requesting

        let microphoneAuthorized =
            await AVAudioApplication.requestRecordPermission()
        guard
            desiredMode == requestedMode,
            sessionGeneration == generation
        else {
            return
        }
        guard microphoneAuthorized else {
            permissionState = .denied
            permissionDenied = true
            recognitionUnavailable = false
            if requestedMode == .requestTranscription {
                publishFailure(.permissionDenied)
            }
            return
        }

        if requestedMode != .bargeIn {
            let speechAuthorization =
                await requestSpeechAuthorization()
            guard
                desiredMode == requestedMode,
                sessionGeneration == generation
            else {
                return
            }

            guard
                speechAuthorization == .authorized
            else {
                permissionState = .denied
                permissionDenied = true
                recognitionUnavailable = false
                if requestedMode == .requestTranscription {
                    publishFailure(.permissionDenied)
                }
                return
            }

            let recognizerReady =
                await waitUntilSpeechRecognizerAvailable(
                    generation: generation
                )
            guard
                desiredMode == requestedMode,
                sessionGeneration == generation
            else {
                return
            }
            guard
                recognizerReady,
                let speechRecognizer,
                speechRecognizer.isAvailable
            else {
                if
                    requestedMode == .requestTranscription,
                    recognitionRestartCount < 2
                {
                    scheduleRecognitionRestart(
                        mode: requestedMode,
                        generation: generation
                    )
                } else if requestedMode == .requestTranscription {
                    recognitionUnavailable = true
                    publishFailure(.recognitionUnavailable)
                }
                return
            }
        }

        permissionState = .authorized
        permissionDenied = false
        recognitionUnavailable = false

        do {
            try Self.configureConversationAudioSession()
            await Task.yield()

            let inputNode = audioEngine.inputNode
            #if !targetEnvironment(simulator)
            try? inputNode.setVoiceProcessingEnabled(false)
            isVoiceProcessingEnabled = false
            #endif
            if isTapInstalled {
                inputNode.removeTap(onBus: 0)
                isTapInstalled = false
            }
            enableVoiceProcessingIfPossible()

            guard
                sessionGeneration == generation,
                desiredMode == requestedMode
            else {
                return
            }

            if
                requestedMode != .bargeIn,
                let speechRecognizer
            {
                let request = makeRecognitionRequest(
                    for: requestedMode,
                    recognizer: speechRecognizer
                )
                recognitionRequest = request
                attachRecognitionTask(
                    for: request,
                    generation: generation
                )
            }

            speechDetector.reset()
            isSpeechUtteranceActive = false
            speechSilenceDuration = 0
            isRecognitionAudioOpen = true
            inputNode.installTap(
                onBus: 0,
                bufferSize: 4_096,
                format: nil
            ) { [weak self] buffer, _ in
                guard let self else { return }
                let decision = self.speechDetector.consume(buffer)
                if self.isRecognitionAudioOpen {
                    self.recognitionRequest?.append(
                        Self.boostedRecognitionBuffer(buffer)
                    )
                }

                Task { @MainActor [weak self] in
                    guard
                        let self,
                        self.sessionGeneration == generation
                    else {
                        return
                    }
                    self.consume(speech: decision)
                }
            }
            isTapInstalled = true

            audioEngine.prepare()
            try audioEngine.start()

            let now = ProcessInfo.processInfo.systemUptime
            sessionStartedAt = now
            lastMeasurementTime = now
            lastTranscriptUpdateAt = now
            lastVoiceActivityAt = now
            bargeInArmedAt =
                requestedMode == .bargeIn
                ? now + VoiceSessionTiming.bargeInGracePeriod
                : 0
            bargeInVoiceStartedAt = 0
            noiseFloorDecibels = -48
            targetLevel = 0
            level = 0
            hasDetectedSpeech = false
            isPostWakeCapture = false
            isSpeechUtteranceActive = false
            speechSilenceDuration = 0
            self.mode = requestedMode
            recognitionRestartCount = 0
            startDynamicsLoop(generation: generation)
        } catch {
            if
                requestedMode == .requestTranscription,
                recognitionRestartCount < 2
            {
                #if os(iOS)
                try? AVAudioSession.sharedInstance().setActive(
                    false,
                    options: .notifyOthersOnDeactivation
                )
                #endif
                scheduleRecognitionRestart(
                    mode: requestedMode,
                    generation: generation
                )
            } else if requestedMode == .requestTranscription {
                recognitionUnavailable = true
                publishFailure(.recognitionInterrupted)
            } else if requestedMode == .wakePhrase {
                scheduleWakeRestart(generation: generation)
            }
        }
    }

    private func makeRecognitionRequest(
        for mode: VoiceSessionMode,
        recognizer _: SFSpeechRecognizer
    ) -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint =
            mode == .wakePhrase ? .search : .dictation
        request.addsPunctuation = false
        request.requiresOnDeviceRecognition = false
        usesOnDeviceRecognition = false

        if mode == .wakePhrase {
            request.contextualStrings =
                VoiceRecognitionRules.wakeContextualStrings
        } else {
            request.contextualStrings =
                VoiceRecognitionRules.wakeContextualStrings
                + [
                    "itinerary",
                    "round trip",
                    "nonstop",
                    "hotel",
                    "restaurant"
                ]
        }

        return request
    }

    private func attachRecognitionTask(
        for request: SFSpeechAudioBufferRecognitionRequest,
        generation: Int
    ) {
        guard let speechRecognizer else { return }
        recognitionEpoch &+= 1
        let epoch = recognitionEpoch
        recognitionTask = speechRecognizer.recognitionTask(
            with: request
        ) { [weak self] result, error in
            let transcript =
                result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true

            Task { @MainActor [weak self] in
                guard
                    let self,
                    self.sessionGeneration == generation,
                    self.recognitionEpoch == epoch,
                    self.desiredMode != .stopped
                else {
                    return
                }

                self.consume(
                    transcript: transcript,
                    mode: self.desiredMode
                )

                if isFinal {
                    self.recognitionDidFinish(
                        mode: self.desiredMode
                    )
                } else if error != nil {
                    self.recognitionDidFail(
                        mode: self.desiredMode
                    )
                }
            }
        }
    }

    private func rotateRecognitionToKeepListening(generation: Int) {
        guard
            desiredMode == .wakePhrase
                || desiredMode == .requestTranscription,
            sessionGeneration == generation,
            let speechRecognizer,
            speechRecognizer.isAvailable
        else {
            if desiredMode == .wakePhrase {
                scheduleWakeRestart(generation: generation)
            }
            return
        }

        let previousRequest = recognitionRequest
        recognitionTask?.cancel()
        recognitionTask = nil
        let request = makeRecognitionRequest(
            for: desiredMode,
            recognizer: speechRecognizer
        )
        recognitionRequest = request
        previousRequest?.endAudio()
        attachRecognitionTask(
            for: request,
            generation: generation
        )
    }

    private func consume(
        transcript: String?,
        mode: VoiceSessionMode
    ) {
        guard let transcript else { return }

        switch mode {
        case .wakePhrase:
            guard VoiceRecognitionRules.containsWakePhrase(transcript) else {
                return
            }

            let remainder =
                VoiceRecognitionRules.spokenRequestAfterWake(
                    from: transcript
                )
            detectedWakePhrase = transcript
            promoteWakeToRequestCapture(remainder: remainder)
            wakeDetectionSequence &+= 1
        case .requestTranscription:
            let trimmed = transcript.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !trimmed.isEmpty else { return }

            let merged = VoiceRecognitionRules.mergingTranscript(
                existing: liveTranscript,
                incoming: trimmed
            )
            let contentChanged =
                VoiceRecognitionRules.hasNewSpokenContent(
                    previous: liveTranscript,
                    incoming: merged
                )
            liveTranscript = merged
            if contentChanged {
                lastTranscriptUpdateAt =
                    ProcessInfo.processInfo.systemUptime
            }
            hasDetectedSpeech = true
        case .stopped, .bargeIn:
            break
        }
    }

    private func consume(speech decision: SpeechGateDecision) {
        lastMeasurementTime = ProcessInfo.processInfo.systemUptime
        isSpeechUtteranceActive = decision.isUtteranceActive
        isUserSpeaking = decision.isUtteranceActive
        speechSilenceDuration = decision.silenceDuration

        let decibels = decision.speechBandDecibels
        let distanceFromFloor = decibels - noiseFloorDecibels
        if distanceFromFloor < 0 {
            noiseFloorDecibels += distanceFromFloor * 0.18
        } else if distanceFromFloor < 14 {
            noiseFloorDecibels += distanceFromFloor * 0.012
        }

        let voiceThreshold = noiseFloorDecibels + 4.5
        let fullScaleThreshold = noiseFloorDecibels + 36
        let linearLevel = min(
            max(
                (decibels - voiceThreshold)
                    / (fullScaleThreshold - voiceThreshold),
                0
            ),
            1
        )
        let rawLevel = CGFloat(pow(linearLevel, 0.68))
        if
            mode == .bargeIn,
            lastMeasurementTime >= bargeInArmedAt,
            decision.isUtteranceActive
        {
            if bargeInVoiceStartedAt == 0 {
                bargeInVoiceStartedAt = lastMeasurementTime
            } else if
                lastMeasurementTime - bargeInVoiceStartedAt
                    >= VoiceSessionTiming.bargeInHoldDuration
            {
                publishBargeIn()
                return
            }
        } else if mode == .bargeIn {
            bargeInVoiceStartedAt = 0
        }
        if decision.isUtteranceActive {
            lastVoiceActivityAt = lastMeasurementTime
        }
        let transcriptInactivity =
            ProcessInfo.processInfo.systemUptime
            - lastTranscriptUpdateAt
        targetLevel =
            mode == .requestTranscription
            && decision.isUtteranceActive
            && VoiceRecognitionRules.shouldVisualizeMicrophoneLevel(
                hasTranscript: !liveTranscript.isEmpty,
                transcriptInactivity: transcriptInactivity
            )
            ? rawLevel
            : 0
    }

    private func startDynamicsLoop(generation: Int) {
        dynamicsTask?.cancel()
        dynamicsTask = Task { [weak self] in
            var previousFrameTime =
                ProcessInfo.processInfo.systemUptime

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_666_667)
                guard
                    let self,
                    self.sessionGeneration == generation
                else {
                    return
                }

                let currentTime =
                    ProcessInfo.processInfo.systemUptime
                let deltaTime = min(
                    max(currentTime - previousFrameTime, 1.0 / 240.0),
                    1.0 / 15.0
                )
                previousFrameTime = currentTime

                if currentTime - self.lastMeasurementTime > 0.16 {
                    self.targetLevel = 0
                }

                let timeConstant: Double =
                    self.targetLevel > self.level ? 0.085 : 0.28
                let coefficient =
                    1 - exp(-deltaTime / timeConstant)
                let nextLevel =
                    self.level
                    + (
                        (self.targetLevel - self.level)
                        * CGFloat(coefficient)
                    )
                self.level = nextLevel < 0.006 ? 0 : nextLevel

                self.evaluateRequestCompletion(at: currentTime)
            }
        }
    }

    private func evaluateRequestCompletion(at currentTime: TimeInterval) {
        guard
            mode == .requestTranscription,
            !isFinalizingRequest
        else {
            return
        }

        let elapsed = currentTime - sessionStartedAt
        if
            isPostWakeCapture,
            liveTranscript.isEmpty,
            elapsed >= VoiceSessionTiming.wakeOnlyHandoffSilence,
            !isSpeechUtteranceActive,
            speechSilenceDuration
                >= VoiceSessionTiming.endOfSpeechSilence
        {
            finishWakeOnlyHandoff()
            return
        }

        if
            usesOnDeviceRecognition,
            liveTranscript.isEmpty,
            elapsed >= 1.2
        {
            _ = retryWithoutOnDeviceRecognitionIfPossible(
                mode: .requestTranscription
            )
        }

        let decision = VoiceRecognitionRules.requestCompletionDecision(
            hasDetectedSpeech: hasDetectedSpeech,
            hasTranscript: !liveTranscript.isEmpty,
            elapsed: elapsed,
            silenceDuration: endOfSpeechSilence(at: currentTime),
            transcript: liveTranscript,
            isSpeaking: isSpeechUtteranceActive,
            transcriptStableFor:
                currentTime - lastTranscriptUpdateAt
        )

        switch decision {
        case .continueListening:
            break
        case .complete:
            beginFinalizeRequest()
        case .noSpeech:
            publishFailure(.noSpeechDetected)
        }
    }

    private func recognitionDidFinish(mode: VoiceSessionMode) {
        switch mode {
        case .wakePhrase:
            rotateRecognitionToKeepListening(
                generation: sessionGeneration
            )
        case .requestTranscription:
            if isFinalizingRequest {
                if !isRecognitionAudioOpen {
                    publishCompletedTranscript()
                }
                return
            }
            let currentTime = ProcessInfo.processInfo.systemUptime
                let decision =
                    VoiceRecognitionRules.requestCompletionDecision(
                        hasDetectedSpeech: hasDetectedSpeech,
                        hasTranscript: !liveTranscript.isEmpty,
                        elapsed: currentTime - sessionStartedAt,
                        silenceDuration: endOfSpeechSilence(at: currentTime),
                        transcript: liveTranscript,
                        isSpeaking: isSpeechUtteranceActive,
                        transcriptStableFor:
                            currentTime - lastTranscriptUpdateAt
                    )
            switch decision {
            case .complete:
                beginFinalizeRequest()
            case .noSpeech:
                publishFailure(.noSpeechDetected)
            case .continueListening:
                rotateRecognitionToKeepListening(
                    generation: sessionGeneration
                )
            }
        case .stopped, .bargeIn:
            break
        }
    }

    private func recognitionDidFail(mode: VoiceSessionMode) {
        switch mode {
        case .wakePhrase:
            if retryWithoutOnDeviceRecognitionIfPossible(
                mode: mode
            ) {
                return
            }
            scheduleWakeRestart(generation: sessionGeneration)
        case .requestTranscription:
            if liveTranscript.isEmpty {
                if retryWithoutOnDeviceRecognitionIfPossible(
                    mode: mode
                ) {
                    return
                }
                publishFailure(.recognitionInterrupted)
            } else {
                recognitionDidFinish(mode: mode)
            }
        case .stopped, .bargeIn:
            break
        }
    }

    private func endOfSpeechSilence(
        at _: TimeInterval
    ) -> TimeInterval {
        if isSpeechUtteranceActive {
            return 0
        }
        return speechSilenceDuration
    }

    private func beginFinalizeRequest() {
        guard
            desiredMode == .requestTranscription,
            !isFinalizingRequest
        else {
            return
        }

        isFinalizingRequest = true
        finalizeTimeoutTask?.cancel()
        let generation = sessionGeneration
        finalizeTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(
                    VoiceSessionTiming.trailingAudioDuration
                        * 1_000_000_000
                )
            )
            guard
                !Task.isCancelled,
                let self,
                self.sessionGeneration == generation,
                self.isFinalizingRequest
            else {
                return
            }

            self.isRecognitionAudioOpen = false
            self.recognitionRequest?.endAudio()

            try? await Task.sleep(
                nanoseconds: UInt64(
                    VoiceSessionTiming.finalResultWait * 1_000_000_000
                )
            )
            guard
                !Task.isCancelled,
                self.sessionGeneration == generation,
                self.isFinalizingRequest
            else {
                return
            }
            self.publishCompletedTranscript()
        }
    }

    private func publishCompletedTranscript() {
        guard desiredMode == .requestTranscription else { return }
        isFinalizingRequest = false
        finalizeTimeoutTask?.cancel()
        finalizeTimeoutTask = nil

        let transcript =
            VoiceRecognitionRules.strippingWakePhrasePrefix(
                from: liveTranscript
            )
        guard !transcript.isEmpty else {
            if isPostWakeCapture {
                finishWakeOnlyHandoff()
            } else {
                publishFailure(.noSpeechDetected)
            }
            return
        }

        completedTranscript = transcript
        transcriptionSequence &+= 1
        isPostWakeCapture = false
        stop()
    }

    private func finishWakeOnlyHandoff() {
        guard desiredMode == .requestTranscription else { return }
        completedTranscript = ""
        transcriptionSequence &+= 1
        isPostWakeCapture = false
        stop()
    }

    private func promoteWakeToRequestCapture(remainder: String) {
        let now = ProcessInfo.processInfo.systemUptime
        desiredMode = .requestTranscription
        mode = .requestTranscription
        sessionStartedAt = now
        lastTranscriptUpdateAt = now
        lastVoiceActivityAt = now
        liveTranscript = remainder
        hasDetectedSpeech = !remainder.isEmpty
        isPostWakeCapture = true
    }

    private func publishBargeIn() {
        bargeInSequence &+= 1
        stop()
    }

    private func publishFailure(_ failure: VoiceSessionFailure) {
        lastFailure = failure
        failureSequence &+= 1
        stop()
    }

    private func waitUntilSpeechRecognizerAvailable(
        generation: Int
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(2.4)
        while Date() < deadline {
            guard
                desiredMode != .stopped,
                sessionGeneration == generation
            else {
                return false
            }
            if speechRecognizer?.isAvailable == true {
                return true
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        return speechRecognizer?.isAvailable == true
    }

    private func scheduleWakeRestart(generation: Int) {
        scheduleRecognitionRestart(
            mode: .wakePhrase,
            generation: generation
        )
    }

    private func scheduleRecognitionRestart(
        mode: VoiceSessionMode,
        generation: Int
    ) {
        guard
            desiredMode == mode,
            sessionGeneration == generation
        else {
            return
        }

        sessionGeneration &+= 1
        recognitionRestartCount &+= 1
        tearDownRecognitionSession()
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: VoiceSessionTiming.recognitionRestartDelay
            )
            guard
                !Task.isCancelled,
                let self,
                self.desiredMode == mode
            else {
                return
            }

            await self.start(mode: mode)
        }
    }

    private func retryWithoutOnDeviceRecognitionIfPossible(
        mode: VoiceSessionMode
    ) -> Bool {
        guard
            usesOnDeviceRecognition,
            !hasRetriedWithoutOnDeviceRecognition
        else {
            return false
        }
        hasRetriedWithoutOnDeviceRecognition = true
        prefersOnDeviceRecognition = false
        scheduleRecognitionRestart(
            mode: mode,
            generation: sessionGeneration
        )
        return true
    }

    private func resetRecognitionPreference() {
        prefersOnDeviceRecognition = true
        hasRetriedWithoutOnDeviceRecognition = false
    }

    private func tearDownRecognitionSession(
        deactivateAudio: Bool = true
    ) {
        mode = .stopped
        dynamicsTask?.cancel()
        dynamicsTask = nil
        finalizeTimeoutTask?.cancel()
        finalizeTimeoutTask = nil
        isFinalizingRequest = false
        isRecognitionAudioOpen = false

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        disableVoiceProcessingIfNeeded()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        speechDetector.reset()
        isSpeechUtteranceActive = false
        isUserSpeaking = false
        speechSilenceDuration = 0
        targetLevel = 0
        level = 0

        guard deactivateAudio else { return }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func clearRecognitionOutput() {
        liveTranscript = ""
        completedTranscript = nil
        detectedWakePhrase = nil
        lastFailure = nil
    }

    private func requestSpeechAuthorization() async
        -> SFSpeechRecognizerAuthorizationStatus
    {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func enableVoiceProcessingIfPossible() {
        #if targetEnvironment(simulator)
        isVoiceProcessingEnabled = false
        #else
        guard !isVoiceProcessingEnabled else { return }
        let inputNode = audioEngine.inputNode
        do {
            try inputNode.setVoiceProcessingEnabled(true)
            isVoiceProcessingEnabled = true
            configureVoiceProcessingOptions(on: inputNode)
        } catch {
            isVoiceProcessingEnabled = false
        }
        #endif
    }

    private func configureVoiceProcessingOptions(
        on inputNode: AVAudioInputNode
    ) {
        inputNode.isVoiceProcessingAGCEnabled = true
        inputNode.isVoiceProcessingBypassed = false
        if #available(iOS 17.0, *) {
            inputNode.voiceProcessingOtherAudioDuckingConfiguration =
                AVAudioVoiceProcessingOtherAudioDuckingConfiguration(
                    enableAdvancedDucking: true,
                    duckingLevel: .mid
                )
        }
    }

    private func disableVoiceProcessingIfNeeded() {
        guard isVoiceProcessingEnabled else { return }
        try? audioEngine.inputNode.setVoiceProcessingEnabled(false)
        isVoiceProcessingEnabled = false
    }

    nonisolated private static func configureConversationAudioSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        #if targetEnvironment(simulator)
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [
                .defaultToSpeaker,
                .mixWithOthers
            ]
        )
        #else
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [
                .defaultToSpeaker,
                .duckOthers,
                .allowBluetoothHFP
            ]
        )
        try session.setPreferredIOBufferDuration(0.02)
        #endif
        try session.setActive(true)
        if session.isInputGainSettable {
            try? session.setInputGain(1)
        }
        #endif
    }

    nonisolated private static func boostedRecognitionBuffer(
        _ buffer: AVAudioPCMBuffer
    ) -> AVAudioPCMBuffer {
        guard
            let copy = AVAudioPCMBuffer(
                pcmFormat: buffer.format,
                frameCapacity: buffer.frameLength
            )
        else {
            return buffer
        }
        copy.frameLength = buffer.frameLength
        guard
            let source = buffer.floatChannelData,
            let destination = copy.floatChannelData
        else {
            return buffer
        }

        let frames = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        var peak: Float = 0.000_1
        for channel in 0..<channels {
            let samples = source[channel]
            for index in 0..<frames {
                peak = max(peak, abs(samples[index]))
            }
        }

        let targetPeak: Float = 0.30
        let gain: Float
        if peak < 0.003 {
            gain = 3.5
        } else {
            gain = min(12, max(1.35, targetPeak / peak))
        }
        let limit: Float = 0.94
        for channel in 0..<channels {
            let input = source[channel]
            let output = destination[channel]
            for index in 0..<frames {
                output[index] = max(
                    -limit,
                    min(limit, input[index] * gain)
                )
            }
        }
        return copy
    }
}
