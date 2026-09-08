import SwiftUI

private enum GIAClarificationTurn: Equatable {
    case required(TripClarificationField)
    case optionalPreferences
}

struct MapScreen: View {
    let isActive: Bool

    @Environment(AppState.self) private var appState
    @Environment(TripPlanningSession.self)
    private var tripPlanningSession
    @Environment(GIAResponseCoordinator.self)
    private var responseCoordinator
    @Environment(JudgeDemoController.self)
    private var judgeDemoController
    @Environment(TripPlanningOrchestrator.self)
    private var planningOrchestrator
    @Environment(GIAConnectivityMonitor.self)
    private var connectivityMonitor
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = MapViewModel()
    @State private var earthSceneController = EarthSceneController()
    @State private var voiceSession = VoiceSessionCoordinator()
    @State private var isVoiceDiscVisible = false
    @State private var voiceDiscRevealProgress: CGFloat = 0
    @State private var planHandoffProgress: CGFloat = 0
    @State private var isPlanHandoffPending = false
    @State private var activationTask: Task<Void, Never>?
    @State private var speechTask: Task<Void, Never>?
    @State private var responseDeadlineTask: Task<Void, Never>?
    @State private var clarificationFallbackTask: Task<Void, Never>?
    @State private var initialGreetingFallbackTask: Task<Void, Never>?
    @State private var goodbyeFallbackTask: Task<Void, Never>?
    @State private var demoFallbackTask: Task<Void, Never>?
    @State private var isReplyModePickerPresented = false
    @State private var typedReplyMode: GIATypedReplyMode?
    @State private var preferredTypedReplyMode: GIATypedReplyMode?
    @State private var typedMessages: [GIATypedChatMessage] = []
    @State private var isTypedComposerBusy = false
    @State private var speakingDraft = ""
    @State private var pendingTypedUtterance = ""
    @State private var isFollowUpRequest = false
    @State private var followUpReturnPhase: TripPlanningPhase?
    @State private var clarificationTurn: GIAClarificationTurn?
    @State private var clarificationPromptText = ""
    @State private var greetingSequence = 0
    @State private var isEndingConversation = false
    @State private var clarificationRetryCount = 0
    @State private var presenceCheckCount = 0
    @State private var isLettingUserFinish = false
    @State private var accumulatedSpokenRequest = ""
    @State private var conversationMemory = GIAConversationMemory()
    @State private var listeningMutedUntil: TimeInterval = 0
    @State private var isLowPowerModeEnabled =
        ProcessInfo.processInfo.isLowPowerModeEnabled

    init(isActive: Bool = true) {
        self.isActive = isActive
    }

    var body: some View {
        MapStage {
            ZStack {
                ProceduralStarfieldView(isActive: isActive)

                GIAIdleMark(
                    isActive:
                        isActive && !isReturningToWorld,
                    isAssistantActive:
                        isAssistantActive || isReturningToWorld,
                    onActivate: toggleAssistant
                )
                .offset(y: 15)
                .opacity(isVoiceDiscVisible ? 0 : 1)
                .allowsHitTesting(!isVoiceDiscVisible)
                .zIndex(0)

                EarthSceneView(
                    controller: earthSceneController,
                    isActive: isActive && !isVoiceDiscVisible,
                    isAnimating:
                        GIAQualityPolicy.shouldRunContinuousAnimation(
                            isVisible:
                                isActive && !isVoiceDiscVisible,
                            reduceMotion: reduceMotion
                        ),
                    preferredFramesPerSecond:
                        GIAQualityPolicy.preferredEarthFrameRate(
                            lowPowerMode: isLowPowerModeEnabled,
                            standardFrameRate:
                                EarthRenderingConfiguration
                                    .preferredFramesPerSecond
                        ),
                    isGlobeVisible: !isVoiceDiscVisible
                )
                .opacity(isVoiceDiscVisible ? 0 : 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .zIndex(1)
            }
        } chrome: {
            MapTopChrome(
                locationContext: viewModel.locationContext,
                isMenuExpanded: appState.isMenuPresented,
                onMenuTap: toggleMenu
            )
        } assistant: {
            ZStack {
                if isVoiceDiscVisible {
                    GIAActiveVoiceDisc(
                        microphoneLevel: displayedMicrophoneLevel,
                        revealProgress: voiceDiscRevealProgress,
                        transcript: displayedTranscript,
                        statusText: assistantStatusText,
                        presentationState:
                            assistantPresentationState,
                        isSpeechPlaybackActive:
                            responseCoordinator.isPlaying,
                        isAnimationActive: isActive,
                        isAssistantTranscript:
                            isDisplayingAssistantCopy
                    )
                    .scaleEffect(
                        1 - (planHandoffProgress * 0.81)
                    )
                    .offset(y: planHandoffProgress * -390)
                    .opacity(
                        Double(
                            1 - (planHandoffProgress * 0.08)
                        )
                    )
                    .allowsHitTesting(false)
                }
            }
        } overlay: {
            ZStack {
                if appState.isMenuPresented {
                    EmptyMenuOverlay(
                        onDismiss: dismissMenu,
                        isJudgeDemoActive:
                            judgeDemoController.isActive,
                        onStartJudgeDemo: startJudgeDemo,
                        onResetJudgeDemo: resetJudgeDemo
                    )
                    .transition(.opacity)
                }

                if isReplyModePickerPresented {
                    GIAReplyModePicker(
                        onSelect: beginTypedConversation,
                        onCancel: {
                            isReplyModePickerPresented = false
                            startWakePhraseListeningIfPossible()
                        }
                    )
                    .transition(.opacity)
                }

                if typedReplyMode == .typing {
                    GIATypedChatOverlay(
                        messages: typedMessages,
                        isBusy: isTypedComposerBusy,
                        title: isFollowUpRequest
                            ? "ADD / CHANGE"
                            : "TYPE",
                        subtitle: isFollowUpRequest
                            ? "Update this trip"
                            : "GIA types back",
                        suggestions: typedQuickReplies,
                        composerPlaceholder: isFollowUpRequest
                            ? "Add, change, or remove"
                            : "Tell GIA the trip",
                        onSend: sendTypedMessage,
                        onClose: closeTypedConversation,
                        onSwitchMode: switchTypedReplyMode,
                        draft: $speakingDraft
                    )
                    .transition(.opacity)
                }

                if
                    typedReplyMode != .typing,
                    !isReplyModePickerPresented
                {
                    VStack(alignment: .leading, spacing: 0) {
                        if let voiceFailureMessage {
                            VoiceAccessBanner(
                                message: voiceFailureMessage,
                                onRetry:
                                    voiceSession.permissionDenied
                                    ? nil
                                    : retryVoice,
                                onOpenSettings:
                                    voiceSession.permissionDenied
                                    ? openSettings
                                    : nil
                            )
                            .padding(.horizontal, 22)
                            .padding(.bottom, 10)
                        }

                        typedConversationControls
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottom
                    )
                    .padding(
                        .bottom,
                        typedReplyMode == .speaking ? 16 : 12
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
            .environment(viewModel)
            .accessibilityIdentifier("map.screen")
            .animation(
                reduceMotion ? nil : GIAMotion.quick,
                value: isReplyModePickerPresented
            )
            .animation(
                reduceMotion ? nil : GIAMotion.quick,
                value: typedReplyMode
            )
            .onChange(of: appState.selectedTab) { _, tab in
                switch tab {
                case .plan:
                    rememberTypedReplyMode()
                    if !isLiveAssistantConversation {
                        dismissTypedOverlaysKeepingPreference()
                    }
                case .group:
                    rememberTypedReplyMode()
                case .map:
                    planHandoffProgress = 0
                    restoreVoiceDiscAfterTabReturn()
                    if appState.consumePendingMapFollowUp() {
                        Task { @MainActor in
                            startMapFollowUpConversation()
                        }
                    }
                }
            }
            .onChange(of: isActive, initial: true) { _, isMapActive in
                viewModel.setEarthActive(isMapActive)
                if isMapActive {
                    restoreVoiceDiscAfterTabReturn()
                }
            }
            .onChange(of: responseCoordinator.visibleText) { _, text in
                if !text.isEmpty {
                    pendingTypedUtterance = ""
                }
            }
            .onChange(of: voiceSession.level) { _, level in
                guard isAssistantActive else { return }
                earthSceneController.setSpeechIntensity(Float(level))
            }
            .onChange(
                of: responseCoordinator.playbackLevel
            ) { _, level in
                guard isAssistantActive else { return }
                earthSceneController.setSpeechIntensity(Float(level))
            }
            .onChange(
                of: voiceSession.wakeDetectionSequence
            ) { _, detectionSequence in
                guard
                    detectionSequence > 0,
                    appState.applicationActivity == .active,
                    !isVoiceCaptureInProgress,
                    !isReturningToWorld,
                    !isReplyModePickerPresented
                else {
                    return
                }

                if usesTypedInput {
                    closeTypedConversation()
                }

                let followsExistingPlan =
                    tripPlanningSession.currentRequest != nil
                    && tripPlanningSession.phase != .idle
                    && tripPlanningSession.phase != .cancelled
                    && tripPlanningSession.phase != .returning
                if followsExistingPlan && !appState.isMapSelected {
                    withAnimation(
                        reduceMotion
                            ? .linear(duration: 0.01)
                            : .easeInOut(duration: 0.24)
                    ) {
                        appState.select(.map)
                    }
                }
                activateAssistant(
                    source: .wakePhrase,
                    asFollowUp: followsExistingPlan,
                    continuingWakeCapture:
                        voiceSession.mode == .requestTranscription
                        && !VoiceRecognitionRules.spokenRequestAfterWake(
                            from: voiceSession.liveTranscript
                        )
                        .isEmpty
                )
            }
            .onChange(
                of: voiceSession.transcriptionSequence
            ) { _, transcriptionSequence in
                guard
                    transcriptionSequence > 0,
                    !isHearingOwnPlayback,
                    let transcript = voiceSession.completedTranscript
                else {
                    return
                }

                let trimmed = transcript.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                if trimmed.isEmpty {
                    Task { await keepListeningQuietly() }
                    return
                }

                if tripPlanningSession.phase == .listening {
                    try? tripPlanningSession.beginTranscribing()
                }
                guard tripPlanningSession.phase == .transcribing else {
                    return
                }

                if clarificationTurn != nil {
                    handleClarificationTranscript(transcript)
                    return
                }

                if VoiceRecognitionRules.isStopCommand(transcript) {
                    handleStopCommand()
                    return
                }

                if isFollowUpRequest {
                    handleFollowUpTranscript(transcript)
                    return
                }

                accumulatedSpokenRequest =
                    VoiceRecognitionRules.appendingSpokenRequest(
                        existing: accumulatedSpokenRequest,
                        incoming: trimmed
                    )
                submitOrContinueInitialRequest(
                    accumulatedSpokenRequest
                )
            }
            .onChange(
                of: voiceSession.failureSequence
            ) { _, failureSequence in
                guard
                    failureSequence > 0,
                    !isHearingOwnPlayback,
                    let failure = voiceSession.lastFailure
                else {
                    return
                }

                let isWaitingForUser =
                    tripPlanningSession.phase == .transcribing
                    || tripPlanningSession.phase == .listening
                guard isWaitingForUser else {
                    return
                }

                if
                    failure == .noSpeechDetected,
                    clarificationTurn == nil,
                    !isFollowUpRequest,
                    !accumulatedSpokenRequest.isEmpty
                {
                    submitInitialSpokenRequest(
                        accumulatedSpokenRequest,
                        forceComplete: true
                    )
                    return
                }

                if
                    failure == .noSpeechDetected,
                    case .optionalPreferences = clarificationTurn,
                    let request = tripPlanningSession.currentRequest
                {
                    finishClarificationConversation(with: request)
                    return
                }

                if failure == .noSpeechDetected {
                    Task { await keepListeningQuietly() }
                    return
                }
            }
            .onChange(of: isActive, initial: true) { _, mapIsActive in
                if
                    mapIsActive,
                    tripPlanningSession.phase == .cancelled
                {
                    returnAssistantToWorld()
                } else if
                    mapIsActive,
                    tripPlanningSession.phase == .transcribing,
                    !usesTypedInput
                {
                    Task {
                        await voiceSession.startRequestTranscription()
                    }
                } else if mapIsActive, !isReturningToWorld {
                    startWakePhraseListeningIfPossible()
                } else if !mapIsActive {
                    invalidatePlanHandoff()
                    if appState.applicationActivity != .active {
                        cancelBackgroundWork()
                    } else if shouldArmWakePhrase {
                        startWakePhraseListeningIfPossible()
                    } else {
                        voiceSession.stop()
                    }
                }
            }
            .onChange(of: tripPlanningSession.phase) { _, _ in
                if shouldArmWakePhrase {
                    startWakePhraseListeningIfPossible()
                }
            }
            .onChange(of: appState.applicationActivity) { _, activity in
                if activity == .active {
                    if
                        let turn = clarificationTurn,
                        tripPlanningSession.phase == .needsClarification
                    {
                        switch turn {
                        case .required(let field):
                            beginClarificationConversation(for: field)
                        case .optionalPreferences:
                            beginOptionalPreferenceConversation()
                        }
                    } else {
                        startWakePhraseListeningIfPossible()
                    }
                } else {
                    cancelBackgroundWork()
                }
            }
            .onChange(
                of: voiceSession.bargeInSequence
            ) { _, bargeInSequence in
                guard bargeInSequence > 0 else { return }
                handleBargeIn()
            }
            .onChange(of: responseCoordinator.state) { _, state in
                switch state {
                case .generating, .playing:
                    voiceSession.pauseForSpeechPlayback()
                case .idle, .failed:
                    if shouldArmWakePhrase {
                        startWakePhraseListeningIfPossible()
                    }
                }
            }
            .onAppear(perform: runDebugVoiceDemoIfRequested)
            .onReceive(
                NotificationCenter.default.publisher(
                    for:
                        UIApplication
                        .didReceiveMemoryWarningNotification
                )
            ) { _ in
                earthSceneController.handleMemoryPressure(
                    isActive: isActive
                )
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for:
                        Notification.Name
                        .NSProcessInfoPowerStateDidChange
                )
            ) { _ in
                isLowPowerModeEnabled =
                    ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .sensoryFeedback(
                .impact(weight: .light),
                trigger:
                    reduceMotion ? false : isAssistantActive
            )
    }

    private var isAssistantActive: Bool {
        tripPlanningSession.isAssistantPresented
    }

    private var usesTypedInput: Bool {
        typedReplyMode != nil
    }

    private var usesTypedReplies: Bool {
        typedReplyMode == .typing
    }

    private var hasActiveTripRequest: Bool {
        tripPlanningSession.currentRequest != nil
            && tripPlanningSession.phase != .idle
            && tripPlanningSession.phase != .cancelled
            && tripPlanningSession.phase != .returning
    }

    private var shouldTreatSessionAsFollowUp: Bool {
        guard hasActiveTripRequest else { return false }
        switch tripPlanningSession.phase {
        case
            .searching,
            .comparing,
            .buildingItinerary,
            .presenting,
            .ready,
            .partiallyAvailable,
            .failed:
            return true
        default:
            return false
        }
    }

    private var typedQuickReplies: [String] {
        if case .optionalPreferences = clarificationTurn {
            return ["That's it", "Plan it"]
        }
        return []
    }

    private var isReturningToWorld: Bool {
        tripPlanningSession.isReturning
    }

    private var isHearingOwnPlayback: Bool {
        responseCoordinator.state == .generating
            || responseCoordinator.state == .playing
            || ProcessInfo.processInfo.systemUptime < listeningMutedUntil
    }

    private var assistantPresentationState:
        GIAAssistantPresentationState
    {
        GIAAssistantPresentationState.resolve(
            phase: tripPlanningSession.phase,
            responseState: responseCoordinator.state,
            permissionDenied: voiceSession.permissionDenied,
            recognitionUnavailable:
                voiceSession.recognitionUnavailable
        )
    }

    private var voiceFailureMessage: String? {
        if
            tripPlanningSession.phase == .failed,
            let failure = tripPlanningSession.failure
        {
            return failure.userMessage
        }
        if
            responseCoordinator.state == .failed,
            let failure = responseCoordinator.failureMessage
        {
            return failure
        }
        if voiceSession.permissionDenied {
            return
                "Voice access is off. Enable it in Settings, "
                + "or type your request."
        }
        if voiceSession.recognitionUnavailable {
            return
                "Speech recognition is unavailable. "
                + "You can still type your request."
        }
        return nil
    }

    private func toggleMenu() {
        withAnimation(menuAnimation) {
            appState.toggleMenu()
        }
    }

    private func dismissMenu() {
        withAnimation(menuAnimation) {
            appState.dismissMenu()
        }
    }

    private var typedConversationControls: some View {
        Group {
            if typedReplyMode == .speaking {
                VStack(spacing: 8) {
                    Text("TYPE HERE")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.8)
                        .foregroundStyle(GIAColor.intelligenceAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 6)

                    GIATypedComposerBar(
                        draft: $speakingDraft,
                        isBusy: isTypedComposerBusy,
                        placeholder: isFollowUpRequest
                            ? "Add, change, or remove"
                            : "Type here, GIA will speak",
                        style: .spotlight,
                        onSend: sendTypedMessage
                    )
                    HStack(spacing: 10) {
                        Button(action: switchTypedReplyMode) {
                            Text("CHAT")
                                .font(.caption2.weight(.semibold))
                                .tracking(1.2)
                                .foregroundStyle(
                                    GIAColor.intelligenceAccent
                                )
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(GIAColor.menuSurface)
                                }
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(
                                            GIAColor.subtleStroke,
                                            lineWidth: 0.8
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            GIATypedReplyMode.speaking
                                .switchControlAccessibilityLabel
                        )
                        .accessibilityIdentifier(
                            "map.typedSpeak.switchToTyping"
                        )

                        Button(action: closeTypedConversation) {
                            Text("CLOSE")
                                .font(.caption2.weight(.semibold))
                                .tracking(1.2)
                                .foregroundStyle(GIAColor.primaryText)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(GIAColor.menuSurface)
                                }
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(
                                            GIAColor.subtleStroke,
                                            lineWidth: 0.8
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close typed conversation")
                    }
                }
                .padding(.horizontal, 18)
            } else if typedReplyMode != .typing {
                Button {
                    if let mode = preferredTypedReplyMode {
                        beginTypedConversation(mode)
                    } else {
                        presentReplyModePicker()
                    }
                } label: {
                    Label(
                        hasActiveTripRequest
                            ? "ADD / CHANGE"
                            : "TYPE",
                        systemImage: hasActiveTripRequest
                            ? "plus.forwardslash.minus"
                            : "keyboard"
                    )
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(GIAColor.primaryText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background {
                        Capsule(style: .continuous)
                            .fill(GIAColor.menuSurface)
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                GIAColor.subtleStroke,
                                lineWidth: 0.8
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    hasActiveTripRequest
                        ? "Add or change this trip"
                        : "Type a travel request"
                )
                .accessibilityIdentifier("map.typeButton")
                .padding(.horizontal, 18)
            }
        }
    }

    private var isLiveAssistantConversation: Bool {
        switch tripPlanningSession.phase {
        case
            .wakePhraseDetected,
            .listening,
            .transcribing,
            .validating,
            .needsClarification:
            true
        default:
            responseCoordinator.state == .generating
                || responseCoordinator.state == .playing
        }
    }

    private func restoreVoiceDiscAfterTabReturn() {
        guard isAssistantActive, !isReturningToWorld else {
            if typedReplyMode != .typing {
                isVoiceDiscVisible = false
                voiceDiscRevealProgress = 0
            }
            return
        }

        if typedReplyMode == .typing {
            isVoiceDiscVisible = false
            voiceDiscRevealProgress = 0
            return
        }

        isVoiceDiscVisible = true
        voiceDiscRevealProgress = 1
        earthSceneController.setFocusedPresentation(
            true,
            animated: false
        )
    }

    private func presentReplyModePicker() {
        dismissMenu()
        voiceSession.stop()
        isReplyModePickerPresented = true
    }

    private func rememberTypedReplyMode() {
        if let typedReplyMode {
            preferredTypedReplyMode = typedReplyMode
            appState.setAssistantReplyMode(typedReplyMode)
        }
    }

    private func dismissTypedOverlaysKeepingPreference() {
        typedReplyMode = nil
        typedMessages = []
        isTypedComposerBusy = false
        speakingDraft = ""
        pendingTypedUtterance = ""
        isReplyModePickerPresented = false
    }

    private func startMapFollowUpConversation() {
        if let mode = preferredTypedReplyMode ?? appState.assistantReplyMode {
            beginTypedConversation(mode)
        } else {
            presentReplyModePicker()
        }
    }

    private func beginTypedConversation(_ mode: GIATypedReplyMode) {
        dismissMenu()
        isReplyModePickerPresented = false
        preferredTypedReplyMode = mode
        appState.setAssistantReplyMode(mode)
        typedReplyMode = mode
        isTypedComposerBusy = false
        speakingDraft = ""
        voiceSession.stop()

        if isAssistantActive {
            if
                typedMessages.isEmpty,
                let seed = responseCoordinator.lastResponse?.displayText
                    ?? (
                        clarificationPromptText.isEmpty
                            ? nil
                            : clarificationPromptText
                    )
            {
                appendTypedMessage(role: .gia, text: seed)
            }
            if shouldTreatSessionAsFollowUp && !isFollowUpRequest {
                typedMessages = []
                activateAssistant(source: .manual, asFollowUp: true)
                return
            }
            if mode == .typing {
                isVoiceDiscVisible = false
                voiceDiscRevealProgress = 0
            }
            return
        }

        typedMessages = []
        activateAssistant(
            source: .manual,
            asFollowUp: shouldTreatSessionAsFollowUp
        )
    }

    private func switchTypedReplyMode() {
        guard let current = typedReplyMode else { return }
        let mode = current.opposite
        preferredTypedReplyMode = mode
        appState.setAssistantReplyMode(mode)
        voiceSession.stop()

        if mode == .typing {
            responseCoordinator.stop(clearVisibleText: false)
            isVoiceDiscVisible = false
            voiceDiscRevealProgress = 0
            if let seed = latestAssistantCopy {
                appendTypedMessage(role: .gia, text: seed)
            }
        } else if isAssistantActive {
            if let seed = latestAssistantCopy {
                let previous = responseCoordinator.lastResponse
                responseCoordinator.presentText(
                    GIAConversationResponse(
                        spokenText: seed,
                        displayText: seed,
                        intent:
                            previous?.intent
                            ?? .clarificationNeeded,
                        shouldContinueListening:
                            previous?.shouldContinueListening
                            ?? true
                    )
                )
            }
            presentSpeakingDisc()
        }

        typedReplyMode = mode
    }

    private var latestAssistantCopy: String? {
        if
            let last = typedMessages.last(where: { $0.role == .gia }),
            !last.text.isEmpty
        {
            return last.text
        }
        if !responseCoordinator.visibleText.isEmpty {
            return responseCoordinator.visibleText
        }
        if
            let display = responseCoordinator.lastResponse?.displayText,
            !display.isEmpty
        {
            return display
        }
        if !clarificationPromptText.isEmpty {
            return clarificationPromptText
        }
        return nil
    }

    private func presentSpeakingDisc() {
        if reduceMotion {
            earthSceneController.setFocusedPresentation(
                true,
                animated: false
            )
            earthSceneController.setActiveWithoutMotion(true)
            isVoiceDiscVisible = true
            voiceDiscRevealProgress = 1
        } else {
            earthSceneController.setFocusedPresentation(
                true,
                animated: true
            )
            startFocusedActivation()
        }
    }

    private func closeTypedConversation() {
        isReplyModePickerPresented = false
        speakingDraft = ""
        pendingTypedUtterance = ""
        isTypedComposerBusy = false
        typedMessages = []
        typedReplyMode = nil
        if isFollowUpRequest {
            finishFollowUpWithoutChanges(
                phrase: .noChanges,
                announce: false,
                navigateToPlan: false
            )
        } else if isAssistantActive {
            returnAssistantToWorld()
        } else {
            startWakePhraseListeningIfPossible()
        }
    }

    private func sendTypedMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty, !isTypedComposerBusy else { return }
        speakingDraft = ""
        pendingTypedUtterance = trimmed
        clarificationPromptText = ""
        speechTask?.cancel()
        responseCoordinator.stop(clearVisibleText: true)
        isTypedComposerBusy = usesTypedReplies
        appendTypedMessage(role: .user, text: trimmed)
        if
            let turn = clarificationTurn,
            let request = tripPlanningSession.currentRequest
        {
            speechTask = Task {
                await resolveClarificationReply(
                    trimmed,
                    turn: turn,
                    currentRequest: request
                )
                guard !Task.isCancelled else { return }
                completeTypedTurn()
            }
            if !usesTypedReplies {
                completeTypedTurn()
            }
            return
        }
        if
            isFollowUpRequest,
            let request = tripPlanningSession.currentRequest
        {
            speechTask = Task {
                await resolveFollowUpReply(
                    trimmed,
                    currentRequest: request
                )
                guard !Task.isCancelled else { return }
                completeTypedTurn()
            }
            if !usesTypedReplies {
                completeTypedTurn()
            }
            return
        }
        submitInitialSpokenRequest(trimmed, forceComplete: true)
        if !usesTypedReplies {
            completeTypedTurn()
        }
    }

    private func deliverGeneratedReply(
        to context: GIAConversationContext,
        fallback: GIAConversationResponse? = nil
    ) async {
        if usesTypedReplies {
            if
                let response = await responseCoordinator.compose(
                    to: context,
                    fallback: fallback
                )
            {
                appendTypedMessage(
                    role: .gia,
                    text: response.displayText
                )
            }
            return
        }
        _ = await responseCoordinator.respond(
            to: context,
            fallback: fallback
        )
        appendTypedMessage(
            role: .gia,
            text: responseCoordinator.lastResponse?.displayText
        )
    }

    private func deliverPhrase(_ phrase: GIAResponsePhrase) async {
        await deliverCannedReply(
            GIAConversationFallback.response(for: phrase),
            cachedPhrase: phrase
        )
    }

    private func deliverCannedReply(
        _ response: GIAConversationResponse,
        cachedPhrase: GIAResponsePhrase? = nil
    ) async {
        if usesTypedReplies {
            responseCoordinator.presentText(response)
            appendTypedMessage(role: .gia, text: response.displayText)
            return
        }
        if let cachedPhrase {
            _ = await responseCoordinator.speak(cachedPhrase)
        } else {
            _ = await responseCoordinator.speak(response)
        }
        appendTypedMessage(role: .gia, text: response.displayText)
    }

    private func appendTypedMessage(
        role: GIATypedChatRole,
        text: String?
    ) {
        let trimmed = text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard usesTypedInput, !trimmed.isEmpty else { return }
        if
            typedMessages.last?.role == role,
            typedMessages.last?.text == trimmed
        {
            return
        }
        typedMessages.append(
            GIATypedChatMessage(role: role, text: trimmed)
        )
    }

    private func completeTypedTurn() {
        isTypedComposerBusy = false
        speakingDraft = ""
    }

    private func openSettings() {
        guard
            let url = URL(
                string: UIApplication.openSettingsURLString
            )
        else {
            return
        }
        openURL(url)
    }

    private func retryVoice() {
        if tripPlanningSession.phase == .failed {
            tripPlanningSession.clearCurrentTrip()
            activateAssistant(source: .manual)
        } else {
            Task {
                await voiceSession.startWakePhraseListening()
            }
        }
    }

    private func cancelBackgroundWork() {
        activationTask?.cancel()
        invalidatePlanHandoff()
        speechTask?.cancel()
        responseDeadlineTask?.cancel()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        demoFallbackTask?.cancel()
        planningOrchestrator.cancel()
        responseCoordinator.stop()
        isPlanHandoffPending = false
    }

    private func toggleAssistant() {
        if isAssistantActive {
            if isFollowUpRequest {
                voiceSession.stop()
                responseCoordinator.stop()
                finishFollowUpWithoutChanges(phrase: .noChanges)
            } else {
                returnAssistantToWorld()
            }
        } else if !isReturningToWorld {
            activateAssistant(
                source: .manual,
                asFollowUp:
                    tripPlanningSession.currentRequest != nil
                    && tripPlanningSession.phase != .idle
                    && tripPlanningSession.phase != .cancelled
                    && tripPlanningSession.phase != .returning
            )
        }
    }

    private func activateAssistant(
        source: TripActivationSource,
        asFollowUp: Bool = false,
        continuingWakeCapture: Bool = false
    ) {
        activationTask?.cancel()
        invalidatePlanHandoff()
        speechTask?.cancel()
        responseDeadlineTask?.cancel()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        demoFallbackTask?.cancel()
        let keepMicrophone =
            continuingWakeCapture
            || voiceSession.mode == .requestTranscription
        responseCoordinator.stop(deactivateAudio: !keepMicrophone)
        planHandoffProgress = 0
        isPlanHandoffPending = false

        if tripPlanningSession.phase != .idle && !asFollowUp {
            guard tripPlanningSession.phase.isTerminal else {
                return
            }
            tripPlanningSession.resetForNewRequest()
        }
        if !asFollowUp {
            planningOrchestrator.reset()
            followUpReturnPhase = nil
        } else {
            followUpReturnPhase = tripPlanningSession.phase
            switch planningOrchestrator.state {
            case .resolvingLocation, .searching, .assembling:
                planningOrchestrator.cancel()
            default:
                break
            }
        }
        isFollowUpRequest = asFollowUp
        if typedReplyMode == nil {
            appState.setAssistantReplyMode(nil)
        }
        if !asFollowUp {
            conversationMemory.reset()
        }
        presenceCheckCount = 0
        isLettingUserFinish = false
        accumulatedSpokenRequest =
            continuingWakeCapture
            || voiceSession.mode == .requestTranscription
            ? VoiceRecognitionRules.spokenRequestAfterWake(
                from: voiceSession.liveTranscript
            )
            : ""

        do {
            if source == .wakePhrase {
                try tripPlanningSession.registerWakePhrase()
            }
            try tripPlanningSession.beginListening(source: source)
        } catch {
            return
        }

        if !keepMicrophone {
            voiceSession.stop()
        }
        isVoiceDiscVisible = false
        voiceDiscRevealProgress = 0

        if asFollowUp {
            if !keepMicrophone {
                startFollowUpPrompt()
            }
        } else if
            !accumulatedSpokenRequest.isEmpty,
            VoiceRecognitionRules.hasTravelIntent(
                accumulatedSpokenRequest
            ),
            !VoiceRecognitionRules.looksIncomplete(
                accumulatedSpokenRequest
            )
        {
            submitInitialSpokenRequest(accumulatedSpokenRequest)
        } else if keepMicrophone {
            try? tripPlanningSession.beginTranscribing()
            if accumulatedSpokenRequest.isEmpty {
                startInitialGreeting()
            }
        } else {
            startInitialGreeting()
        }

        if typedReplyMode == .typing {
            isVoiceDiscVisible = false
            voiceDiscRevealProgress = 0
        } else if reduceMotion {
            earthSceneController.setFocusedPresentation(
                true,
                animated: false
            )
            earthSceneController.setActiveWithoutMotion(true)
            isVoiceDiscVisible = true
            voiceDiscRevealProgress = 1
        } else {
            earthSceneController.setFocusedPresentation(
                true,
                animated: true
            )
            startFocusedActivation()
        }
    }

    private func returnAssistantToWorld() {
        activationTask?.cancel()
        invalidatePlanHandoff()
        speechTask?.cancel()
        responseDeadlineTask?.cancel()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        planningOrchestrator.cancel()
        responseCoordinator.stop()
        clarificationTurn = nil
        clarificationPromptText = ""
        accumulatedSpokenRequest = ""
        conversationMemory.reset()
        typedReplyMode = nil
        typedMessages = []
        isTypedComposerBusy = false
        speakingDraft = ""
        pendingTypedUtterance = ""
        isReplyModePickerPresented = false
        planHandoffProgress = 0
        isPlanHandoffPending = false

        do {
            try tripPlanningSession.beginReturning()
        } catch {
            return
        }

        voiceSession.stop()

        if reduceMotion {
            earthSceneController.setFocusedPresentation(
                false,
                animated: false
            )
            voiceDiscRevealProgress = 0
            isVoiceDiscVisible = false
            earthSceneController.setActiveWithoutMotion(false)
            try? tripPlanningSession.finishReturning()
            startWakePhraseListeningIfPossible()
        } else {
            earthSceneController.returnToWorld()
            scheduleVoiceDiscReturn()
        }
    }

    private func startFocusedActivation() {
        isVoiceDiscVisible = true
        earthSceneController.activate()
        withAnimation(voiceTransitionAnimation) {
            voiceDiscRevealProgress = 1
        }
    }

    private func scheduleVoiceDiscReturn() {
        withAnimation(voiceReturnAnimation) {
            voiceDiscRevealProgress = 0
        }

        activationTask = Task {
            let worldZoomDelay =
                EarthRenderingConfiguration.transformationDuration
                * EarthRenderingConfiguration.worldZoomDelayFactor
            try? await Task.sleep(
                nanoseconds: UInt64(
                    worldZoomDelay * 1_000_000_000
                )
            )
            guard
                !Task.isCancelled,
                isReturningToWorld
            else {
                return
            }

            isVoiceDiscVisible = false

            let zoomSettleDelay = UInt64(
                (
                    EarthRenderingConfiguration.worldPresentationDuration
                    + 0.06
                ) * 1_000_000_000
            )
            try? await Task.sleep(
                nanoseconds: zoomSettleDelay
            )
            guard
                !Task.isCancelled,
                isReturningToWorld
            else {
                return
            }

            try? tripPlanningSession.finishReturning()
            startWakePhraseListeningIfPossible()
        }
    }

    private func startWakePhraseListeningIfPossible() {
        #if DEBUG
        if ProcessInfo.processInfo.environment[
            "GIA_AUTORUN_PLAN_HANDOFF_TRANSCRIPT"
        ] != nil
            || ProcessInfo.processInfo.environment[
                "GIA_DEBUG_JUDGE_DEMO"
            ] == "1"
            || ProcessInfo.processInfo.environment[
                "GIA_DEBUG_TEXT_REQUEST"
            ] == "1"
            || ProcessInfo.processInfo.environment[
                "GIA_DEBUG_SKIP_WAKE"
            ] == "1"
        {
            return
        }
        #endif

        guard
            shouldArmWakePhrase,
            !isVoiceCaptureInProgress,
            !isReturningToWorld,
            !usesTypedInput,
            !isReplyModePickerPresented,
            responseCoordinator.state != .generating,
            responseCoordinator.state != .playing
        else {
            return
        }

        Task {
            await voiceSession.startWakePhraseListening()
        }
    }

    private var shouldArmWakePhrase: Bool {
        guard
            appState.applicationActivity == .active,
            clarificationTurn == nil,
            !isEndingConversation,
            !usesTypedInput,
            !isReplyModePickerPresented
        else {
            return false
        }
        switch tripPlanningSession.phase {
        case
            .wakePhraseDetected,
            .listening,
            .transcribing,
            .returning,
            .cancelled:
            return false
        default:
            return true
        }
    }

    private var isVoiceCaptureInProgress: Bool {
        switch tripPlanningSession.phase {
        case .wakePhraseDetected, .listening, .transcribing:
            true
        default:
            false
        }
    }

    private func schedulePlanHandoff() {
        guard
            isActive,
            canPresentPlanHandoff,
            tripPlanningSession.currentRequest != nil
        else {
            return
        }
        isPlanHandoffPending = true

        if reduceMotion {
            isPlanHandoffPending = false
            withAnimation(.easeOut(duration: 0.16)) {
                appState.select(.plan)
            }
            return
        }

        withAnimation(planHandoffAnimation) {
            planHandoffProgress = 1
            isPlanHandoffPending = false
            appState.select(.plan)
        }
    }

    private func invalidatePlanHandoff() {
        isPlanHandoffPending = false
    }

    private func beginSpokenHandoff(
        _ context: GIAConversationContext
    ) {
        voiceSession.pauseForSpeechPlayback()
        speechTask?.cancel()
        responseDeadlineTask?.cancel()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        let shouldRevealTypedHandoff = usesTypedInput
        speechTask = Task {
            await deliverGeneratedReply(to: context)
            rememberAssistantReply(
                from: tripPlanningSession.currentRequest
            )
            completeTypedTurn()
            if shouldRevealTypedHandoff {
                if usesTypedReplies {
                    try? await Task.sleep(nanoseconds: 420_000_000)
                }
                guard !Task.isCancelled else { return }
                presentTypedPlanHandoff()
            }
        }
        responseDeadlineTask = Task {
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled else { return }
            responseCoordinator.cancelPendingResponse()
        }
        if !shouldRevealTypedHandoff {
            schedulePlanHandoff()
        }
    }

    private func presentTypedPlanHandoff() {
        rememberTypedReplyMode()
        dismissTypedOverlaysKeepingPreference()
        clarificationTurn = nil
        clarificationPromptText = ""
        isFollowUpRequest = false
        planHandoffProgress = 0
        isVoiceDiscVisible = true
        voiceDiscRevealProgress = 1
        if reduceMotion {
            earthSceneController.setFocusedPresentation(
                true,
                animated: false
            )
            earthSceneController.setActiveWithoutMotion(true)
        } else {
            earthSceneController.setFocusedPresentation(
                true,
                animated: false
            )
        }
        schedulePlanHandoff()
    }

    private func startFollowUpPrompt() {
        voiceSession.pauseForSpeechPlayback()
        speechTask?.cancel()
        speechTask = Task {
            if let request = tripPlanningSession.currentRequest {
                let fallback = GIAConversationFallback.response(
                    for: .followUpPrompt
                )
                conversationMemory.markAsked("follow-up")
                await deliverGeneratedReply(
                    to: conversationContext(
                        for: TripRequestInterpretation(
                            request: request,
                            issues: []
                        ),
                        intent: .clarificationNeeded,
                        extraFacts: [
                            "Ask what they want to add, change, or remove."
                        ]
                    ),
                    fallback: fallback
                )
                rememberAssistantReply(from: request)
            } else {
                await deliverPhrase(.followUpPrompt)
            }
            completeTypedTurn()
            guard
                !Task.isCancelled,
                isFollowUpRequest,
                tripPlanningSession.phase == .listening,
                !usesTypedInput
            else {
                return
            }
            do {
                try tripPlanningSession.beginTranscribing()
            } catch {
                return
            }
            await waitForPlaybackEchoToSettle()
            guard !Task.isCancelled else { return }
            await voiceSession.startRequestTranscription()
        }
    }

    private func startInitialGreeting() {
        guard
            !isFollowUpRequest,
            clarificationTurn == nil,
            VoiceRecognitionRules.spokenRequestAfterWake(
                from: voiceSession.liveTranscript
            ).isEmpty,
            accumulatedSpokenRequest.isEmpty
        else {
            if usesTypedInput {
                return
            }
            Task { await beginInitialRequestTranscription() }
            return
        }

        voiceSession.pauseForSpeechPlayback()
        let greetings: [GIAResponsePhrase] = [
            .greetingTrip,
            .greetingDestination,
            .greetingPlan
        ]
        let greeting =
            greetings[greetingSequence % greetings.count]
        greetingSequence &+= 1

        speechTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        speechTask = Task {
            await deliverPhrase(greeting)
            if usesTypedInput {
                return
            }
            await resumeListeningAfterPlayback()
        }
        initialGreetingFallbackTask = Task {
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard
                !Task.isCancelled,
                !usesTypedInput,
                tripPlanningSession.phase == .listening
                    || tripPlanningSession.phase == .transcribing,
                !isFollowUpRequest
            else {
                return
            }
            responseCoordinator.stop(clearVisibleText: false)
            await resumeListeningAfterPlayback()
        }
    }

    private func resumeListeningAfterPlayback() async {
        initialGreetingFallbackTask?.cancel()
        await waitForPlaybackEchoToSettle()
        guard !Task.isCancelled else { return }
        await beginInitialRequestTranscription()
    }

    private func waitForPlaybackEchoToSettle() async {
        listeningMutedUntil =
            ProcessInfo.processInfo.systemUptime
            + VoiceSessionTiming.playbackEchoSettle
        try? await Task.sleep(
            nanoseconds: UInt64(
                VoiceSessionTiming.playbackEchoSettle * 1_000_000_000
            )
        )
    }

    private func handleChatterWhileListening() {
        Task { await keepListeningQuietly() }
    }

    private func keepListeningQuietly() async {
        if let turn = clarificationTurn {
            if tripPlanningSession.phase == .needsClarification {
                await beginClarificationTranscription(expectedTurn: turn)
            } else {
                if tripPlanningSession.phase == .listening {
                    try? tripPlanningSession.beginTranscribing()
                }
                await voiceSession.startRequestTranscription()
            }
            return
        }
        if isFollowUpRequest {
            if tripPlanningSession.phase == .listening {
                try? tripPlanningSession.beginTranscribing()
            }
            await voiceSession.startRequestTranscription()
            return
        }
        await continueInitialRequestListening()
    }

    private func beginInitialRequestTranscription() async {
        initialGreetingFallbackTask?.cancel()
        guard
            !usesTypedInput,
            tripPlanningSession.phase == .listening
                || tripPlanningSession.phase == .transcribing,
            !isFollowUpRequest,
            clarificationTurn == nil
        else {
            return
        }
        if tripPlanningSession.phase == .listening {
            do {
                try tripPlanningSession.beginTranscribing()
            } catch {
                return
            }
        }
        await voiceSession.startRequestTranscription()
        if voiceSession.mode != .requestTranscription {
            try? await Task.sleep(nanoseconds: 250_000_000)
            await voiceSession.startRequestTranscription()
        }
    }

    private func continueInitialRequestListening() async {
        if tripPlanningSession.phase == .listening {
            await beginInitialRequestTranscription()
            return
        }
        if tripPlanningSession.phase == .transcribing {
            await voiceSession.startRequestTranscription()
        }
    }

    private func submitOrContinueInitialRequest(
        _ request: String
    ) {
        guard !request.isEmpty else {
            Task { await continueInitialRequestListening() }
            return
        }
        if isLikelyOwnSpeech(request) {
            Task { await continueInitialRequestListening() }
            return
        }
        if VoiceRecognitionRules.isAssistantChatter(request) {
            accumulatedSpokenRequest = ""
            handleChatterWhileListening()
            return
        }
        if VoiceRecognitionRules.looksIncomplete(request) {
            Task { await continueInitialRequestListening() }
            return
        }
        if !utteranceHasTravelIntent(request) {
            accumulatedSpokenRequest = ""
            handleChatterWhileListening()
            return
        }
        submitInitialSpokenRequest(request)
    }

    private func submitInitialSpokenRequest(
        _ request: String,
        forceComplete: Bool = false
    ) {
        let spoken = request.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !spoken.isEmpty else {
            if usesTypedInput {
                completeTypedTurn()
                return
            }
            Task { await continueInitialRequestListening() }
            return
        }
        if
            !forceComplete,
            VoiceRecognitionRules.looksIncomplete(spoken)
        {
            if usesTypedInput {
                completeTypedTurn()
                return
            }
            Task { await continueInitialRequestListening() }
            return
        }
        if isLikelyOwnSpeech(spoken) {
            if usesTypedInput {
                completeTypedTurn()
                return
            }
            Task { await continueInitialRequestListening() }
            return
        }
        if VoiceRecognitionRules.isAssistantChatter(spoken) {
            accumulatedSpokenRequest = ""
            if usesTypedInput {
                Task {
                    await deliverPhrase(.keepGoing)
                    completeTypedTurn()
                }
                return
            }
            handleChatterWhileListening()
            return
        }
        if !utteranceHasTravelIntent(spoken) {
            accumulatedSpokenRequest = ""
            if usesTypedInput {
                Task {
                    await deliverPhrase(.whatDoYouMean)
                    completeTypedTurn()
                }
                return
            }
            if forceComplete {
                handleChatterWhileListening()
            } else {
                Task { await continueInitialRequestListening() }
            }
            return
        }

        if tripPlanningSession.phase == .listening {
            try? tripPlanningSession.beginTranscribing()
        }
        guard
            tripPlanningSession.phase == .transcribing
                || tripPlanningSession.phase == .validating
        else {
            if usesTypedInput {
                completeTypedTurn()
            }
            return
        }

        let interpretation = TripRequestInterpreter.interpret(
            transcript: travelTranscript(from: spoken)
        )
        accumulatedSpokenRequest = ""
        try? tripPlanningSession.beginValidation(
            request: interpretation.request
        )
        if interpretation.requiresClarification {
            try? tripPlanningSession.requestClarification(
                for: interpretation.clarificationFields
            )
            continueClarification(
                with: interpretation.request,
                userUtterance: spoken
            )
            return
        }
        if usesTypedInput {
            finishClarificationConversation(
                with: interpretation.request
            )
            return
        }
        try? tripPlanningSession.requestClarification(
            for: [.preferences]
        )
        beginOptionalPreferenceConversation(
            userUtterance: spoken
        )
    }

    private func utteranceHasTravelIntent(
        _ spoken: String
    ) -> Bool {
        if VoiceRecognitionRules.hasTravelIntent(spoken) {
            return true
        }
        let interpretation = TripRequestInterpreter.interpret(
            transcript: travelTranscript(from: spoken)
        )
        return
            interpretation.request.destinations.isEmpty == false
            || interpretation.request.origin != nil
            || interpretation.request.dateRange != nil
            || interpretation.request.durationDays != nil
            || interpretation.request.travelerCount != nil
    }

    private func travelTranscript(
        from spoken: String
    ) -> String {
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

    private func isLikelyOwnSpeech(_ transcript: String) -> Bool {
        let candidates =
            [
                responseCoordinator.lastResponse?.spokenText,
                responseCoordinator.visibleText
            ]
            .compactMap { $0 }
            + [
                GIAResponsePhrase.greetingTrip.text,
                GIAResponsePhrase.greetingDestination.text,
                GIAResponsePhrase.greetingPlan.text,
                GIAResponsePhrase.stillListening.text
            ]
        return candidates.contains {
            VoiceRecognitionRules.isPlaybackEcho(
                transcript,
                spokenText: $0
            )
        }
    }

    private func handleStopCommand() {
        let preservesPlan = tripPlanningSession.currentTrip != nil
        voiceSession.stop()
        planningOrchestrator.cancel()
        speechTask?.cancel()
        responseDeadlineTask?.cancel()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        responseCoordinator.stop()
        clarificationTurn = nil
        clarificationPromptText = ""
        accumulatedSpokenRequest = ""
        if !preservesPlan {
            conversationMemory.reset()
        }
        typedReplyMode = nil
        typedMessages = []
        isTypedComposerBusy = false
        speakingDraft = ""
        pendingTypedUtterance = ""
        isReplyModePickerPresented = false
        isFollowUpRequest = false
        followUpReturnPhase = nil
        isEndingConversation = true

        do {
            if preservesPlan {
                try tripPlanningSession.resumeAfterFollowUp(
                    returningTo: .ready
                )
            } else {
                try tripPlanningSession.beginReturning()
            }
        } catch {
            isEndingConversation = false
            return
        }

        speechTask = Task {
            await deliverPhrase(.goodbye)
            completeTypedTurn()
            completeStopCommand(preservingPlan: preservesPlan)
        }
        goodbyeFallbackTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled, isEndingConversation else {
                return
            }
            responseCoordinator.stop(clearVisibleText: false)
            completeStopCommand(preservingPlan: preservesPlan)
        }
    }

    private func completeStopCommand(preservingPlan: Bool) {
        guard isEndingConversation else { return }
        goodbyeFallbackTask?.cancel()
        isEndingConversation = false

        if preservingPlan {
            withAnimation(
                reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 0.24)
            ) {
                appState.select(.plan)
            }
            startWakePhraseListeningIfPossible()
            return
        }

        try? tripPlanningSession.finishReturning()
        planHandoffProgress = 0
        voiceDiscRevealProgress = 0
        isVoiceDiscVisible = false
        earthSceneController.setFocusedPresentation(
            false,
            animated: !reduceMotion
        )
        earthSceneController.setActiveWithoutMotion(false)
        startWakePhraseListeningIfPossible()
    }

    private func handleFollowUpTranscript(_ transcript: String) {
        guard let currentRequest = tripPlanningSession.currentRequest else {
            isFollowUpRequest = false
            return
        }
        voiceSession.pauseForSpeechPlayback()
        rememberUserUtterance(transcript)
        if case .cancelled =
            TripRequestInterpreter.interpretFollowUp(
                transcript: transcript,
                applyingTo: currentRequest
            )
        {
            finishFollowUpWithoutChanges(
                phrase: .noChanges,
                transcript: transcript
            )
            return
        }

        speechTask?.cancel()
        speechTask = Task {
            await resolveFollowUpReply(
                transcript,
                currentRequest: currentRequest
            )
        }
    }

    private func resolveFollowUpReply(
        _ transcript: String,
        currentRequest: TripRequest
    ) async {
        switch TripRequestInterpreter.interpretFollowUp(
            transcript: transcript,
            applyingTo: currentRequest
        ) {
        case .cancelled:
            finishFollowUpWithoutChanges(
                phrase: .noChanges,
                transcript: transcript
            )
            return
        case .updated(let request, _):
            applyFollowUpUpdate(request)
            return
        case .unsupported:
            break
        }

        if
            let reply = await interpretedReply(
                utterance: transcript,
                askedField: "followUp",
                request: currentRequest,
                timeoutNanoseconds: usesTypedInput
                    ? 2_400_000_000
                    : 1_200_000_000
            )
        {
            if !reply.isUnderstood {
                await askWhatTheUserMeant(
                    spokenText: reply.spokenText,
                    turn: nil,
                    isFollowUp: true
                )
                return
            }
            if reply.hasUsablePatch {
                applyFollowUpUpdate(
                    TripRequestInterpreter.applying(
                        reply,
                        to: currentRequest
                    )
                )
                return
            }
        }

        await askWhatTheUserMeant(
            spokenText: nil,
            turn: nil,
            isFollowUp: true
        )
    }

    private func applyFollowUpUpdate(_ request: TripRequest) {
        do {
            try tripPlanningSession.beginValidation(
                request: request
            )
            let issues = TripRequestInterpreter.validate(request)
            if !issues.isEmpty {
                try tripPlanningSession.requestClarification(
                    for: Set(issues.map(\.field))
                )
                isFollowUpRequest = false
                followUpReturnPhase = nil
                if
                    usesTypedInput,
                    let field = nextClarificationField(in: issues)
                {
                    beginClarificationConversation(for: field)
                    completeTypedTurn()
                    return
                }
            }
        } catch {
            finishFollowUpWithoutChanges(
                phrase: .changeNotUnderstood
            )
            return
        }

        isFollowUpRequest = false
        followUpReturnPhase = nil
        let shouldRevealTypedHandoff = usesTypedInput
        speechTask = Task {
            await deliverPhrase(.updateCaptured)
            completeTypedTurn()
            if shouldRevealTypedHandoff {
                if usesTypedReplies {
                    try? await Task.sleep(nanoseconds: 420_000_000)
                }
                guard !Task.isCancelled else { return }
                presentTypedPlanHandoff()
            }
        }
        if !TripRequestInterpreter.validate(request).isEmpty {
            if !shouldRevealTypedHandoff {
                schedulePlanHandoff()
            }
            return
        }
        planningOrchestrator.start(
            request: request,
            session: tripPlanningSession,
            connectivity: connectivityMonitor.state
        )
        if !shouldRevealTypedHandoff {
            schedulePlanHandoff()
        }
    }

    private func finishFollowUpWithoutChanges(
        phrase: GIAResponsePhrase,
        transcript _: String? = nil,
        announce: Bool = true,
        navigateToPlan: Bool = true
    ) {
        let returnPhase = followUpReturnPhase ?? .ready
        var requestToRestart: TripRequest?
        if
            returnPhase == .ready
            || returnPhase == .partiallyAvailable
        {
            do {
                try tripPlanningSession.resumeAfterFollowUp(
                    returningTo: returnPhase
                )
            } catch {
                return
            }
        } else if let request = tripPlanningSession.currentRequest {
            do {
                try tripPlanningSession.beginValidation(
                    request: request
                )
                let issues = TripRequestInterpreter.validate(request)
                if issues.isEmpty {
                    requestToRestart = request
                } else {
                    try tripPlanningSession.requestClarification(
                        for: Set(issues.map(\.field))
                    )
                }
            } catch {
                return
            }
        }
        isFollowUpRequest = false
        followUpReturnPhase = nil
        speechTask?.cancel()
        if announce {
            speechTask = Task {
                await deliverPhrase(phrase)
                completeTypedTurn()
            }
        } else {
            completeTypedTurn()
        }
        if let requestToRestart {
            planningOrchestrator.start(
                request: requestToRestart,
                session: tripPlanningSession,
                connectivity: connectivityMonitor.state
            )
        }
        if navigateToPlan {
            withAnimation(
                reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 0.24)
            ) {
                appState.select(.plan)
            }
        } else {
            startWakePhraseListeningIfPossible()
        }
    }

    private func beginClarificationConversation(
        for field: TripClarificationField,
        retrying: Bool = false,
        userUtterance: String? = nil
    ) {
        if !retrying {
            clarificationRetryCount = 0
            presenceCheckCount = 0
        }
        clarificationTurn = .required(field)
        voiceSession.pauseForSpeechPlayback()
        let request = tripPlanningSession.currentRequest
        let resolvedRequest = request ?? TripRequest()
        let fallback = GIAConversationFallback.response(
            for: GIAConversationIntent.clarificationNeeded
        )
        let context = conversationContext(
            for: TripRequestInterpretation(
                request: resolvedRequest,
                issues: TripRequestInterpreter.validate(
                    resolvedRequest
                )
            ),
            transcript: userUtterance,
            intent: .clarificationNeeded,
            extraFacts: clarificationFacts(
                for: field,
                retrying: retrying
            )
        )
        rememberUserUtterance(userUtterance)
        conversationMemory.markAsked(
            askedFieldName(for: .required(field))
        )
        speechTask?.cancel()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        speechTask = Task {
            await deliverGeneratedReply(
                to: context,
                fallback: fallback
            )
            rememberAssistantReply(from: resolvedRequest)
            clarificationPromptText =
                responseCoordinator.lastResponse?.displayText
                ?? fallback.displayText
            clarificationFallbackTask?.cancel()
            completeTypedTurn()
            await beginClarificationTranscription(
                expectedTurn: .required(field)
            )
        }
        scheduleClarificationSpeechFallback(
            expectedTurn: .required(field)
        )
    }

    private func beginOptionalPreferenceConversation(
        retrying: Bool = false,
        userUtterance: String? = nil
    ) {
        if !retrying {
            clarificationRetryCount = 0
            presenceCheckCount = 0
        }
        clarificationTurn = .optionalPreferences
        voiceSession.pauseForSpeechPlayback()
        let request = tripPlanningSession.currentRequest
        let omitted = request.map {
            TripRequestInterpreter.omittedOptionalExamples(for: $0)
        } ?? []
        let fallback = GIAConversationFallback.response(
            for: GIAConversationIntent.clarificationNeeded
        )
        speechTask?.cancel()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        speechTask = Task {
            var extraFacts = [
                "Ask if they want to add anything else or say that's it."
            ]
            if retrying {
                extraFacts = [
                    "Retry: ask again if they want to add anything, "
                        + "or say that's it. No compliment."
                ]
            } else if !omitted.isEmpty {
                extraFacts.append(
                    "Still missing: "
                        + omitted.joined(separator: ", ")
                        + "."
                )
            }
            let context = conversationContext(
                for: TripRequestInterpretation(
                    request: request ?? TripRequest(),
                    issues: []
                ),
                transcript: userUtterance,
                intent: .clarificationNeeded,
                extraFacts: extraFacts
            )
            rememberUserUtterance(userUtterance)
            conversationMemory.markAsked("preferences")
            await deliverGeneratedReply(
                to: context,
                fallback: fallback
            )
            rememberAssistantReply(from: request)
            clarificationPromptText =
                responseCoordinator.lastResponse?.displayText
                ?? fallback.displayText
            clarificationFallbackTask?.cancel()
            completeTypedTurn()
            await beginClarificationTranscription(
                expectedTurn: .optionalPreferences
            )
        }
        scheduleClarificationSpeechFallback(
            expectedTurn: .optionalPreferences
        )
    }

    private func resumeListeningAfterPresenceCheck() async {
        if
            let turn = clarificationTurn,
            tripPlanningSession.phase == .needsClarification
        {
            await beginClarificationTranscription(expectedTurn: turn)
            return
        }
        if tripPlanningSession.phase == .transcribing {
            await waitForPlaybackEchoToSettle()
            guard !Task.isCancelled else { return }
            await voiceSession.startRequestTranscription()
            return
        }
        if
            tripPlanningSession.phase == .listening,
            isFollowUpRequest
        {
            do {
                try tripPlanningSession.beginTranscribing()
            } catch {
                await voiceSession.startRequestTranscription()
                return
            }
            await voiceSession.startRequestTranscription()
            return
        }
        if
            tripPlanningSession.phase == .listening,
            !isFollowUpRequest,
            clarificationTurn == nil
        {
            await beginInitialRequestTranscription()
            return
        }
        if
            tripPlanningSession.phase == .needsClarification,
            let turn = clarificationTurn
        {
            await beginClarificationTranscription(expectedTurn: turn)
        }
    }

    private func handleBargeIn() {
        guard
            isAssistantActive,
            !isEndingConversation,
            !isLettingUserFinish,
            !isReturningToWorld
        else {
            return
        }

        invalidatePlanHandoff()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        responseDeadlineTask?.cancel()
        speechTask?.cancel()
        responseCoordinator.stop(clearVisibleText: false)
        switch planningOrchestrator.state {
        case .resolvingLocation, .searching, .assembling:
            planningOrchestrator.cancel()
        default:
            break
        }

        Task {
            await resumeListeningAfterPresenceCheck()
        }
    }

    private func scheduleClarificationSpeechFallback(
        expectedTurn: GIAClarificationTurn
    ) {
        guard !usesTypedInput else { return }
        clarificationFallbackTask = Task {
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard
                !Task.isCancelled,
                clarificationTurn == expectedTurn,
                tripPlanningSession.phase == .needsClarification
            else {
                return
            }
            responseCoordinator.stop(clearVisibleText: false)
            await beginClarificationTranscription(
                expectedTurn: expectedTurn
            )
        }
    }

    private func beginClarificationTranscription(
        expectedTurn: GIAClarificationTurn
    ) async {
        guard !usesTypedInput else { return }
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        await waitForPlaybackEchoToSettle()
        guard
            !Task.isCancelled,
            clarificationTurn == expectedTurn,
            tripPlanningSession.phase == .needsClarification
        else {
            return
        }
        do {
            try tripPlanningSession.beginListening()
            try tripPlanningSession.beginTranscribing()
        } catch {
            return
        }
        await voiceSession.startRequestTranscription()
    }

    private func handleClarificationTranscript(
        _ transcript: String
    ) {
        guard
            let turn = clarificationTurn,
            let currentRequest = tripPlanningSession.currentRequest
        else {
            return
        }
        if
            SpeechEndpointRules.looksCutOff(transcript),
            VoiceRecognitionRules.spokenRequestAfterWake(
                from: transcript
            ).isEmpty
        {
            Task { await keepListeningQuietly() }
            return
        }

        voiceSession.pauseForSpeechPlayback()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        speechTask?.cancel()
        speechTask = Task {
            await resolveClarificationReply(
                transcript,
                turn: turn,
                currentRequest: currentRequest
            )
        }
    }

    private func resolveClarificationReply(
        _ transcript: String,
        turn: GIAClarificationTurn,
        currentRequest: TripRequest
    ) async {
        rememberUserUtterance(transcript)
        switch turn {
        case .optionalPreferences:
            if TripRequestInterpreter.isConversationCompletion(
                transcript
            ) {
                finishClarificationConversation(
                    with: currentRequest
                )
                return
            }
            if case .cancelled =
                TripRequestInterpreter.interpretFollowUp(
                    transcript: transcript,
                    applyingTo: currentRequest
                )
            {
                finishClarificationConversation(
                    with: currentRequest
                )
                return
            }
        case .required:
            break
        }

        switch turn {
        case .required(let field):
            if
                let updated =
                    TripRequestInterpreter
                    .interpretClarificationAnswer(
                        transcript,
                        for: field,
                        applyingTo: currentRequest
                    )
            {
                clarificationRetryCount = 0
                presenceCheckCount = 0
                continueClarification(
                    with: updated,
                    userUtterance: transcript
                )
                return
            }
        case .optionalPreferences:
            if case .updated(let request, _) =
                TripRequestInterpreter.interpretFollowUp(
                    transcript: transcript,
                    applyingTo: currentRequest
                )
            {
                continueClarification(
                    with: request,
                    userUtterance: transcript
                )
                return
            }
        }

        await resolveUnparsedClarificationReply(
            transcript,
            turn: turn,
            currentRequest: currentRequest
        )
    }

    private func resolveUnparsedClarificationReply(
        _ transcript: String,
        turn: GIAClarificationTurn,
        currentRequest: TripRequest
    ) async {
        let interpretTimeout: UInt64 =
            usesTypedInput ? 2_400_000_000 : 1_200_000_000
        let interpretTask = Task {
            await interpretedReply(
                utterance: transcript,
                askedField: askedFieldName(for: turn),
                request: currentRequest,
                timeoutNanoseconds: interpretTimeout
            )
        }
        let raced = await raceInterpretation(
            interpretTask,
            timeoutNanoseconds: usesTypedInput
                ? 2_400_000_000
                : 450_000_000
        )

        switch raced {
        case .completed(let reply):
            await applyRemoteClarificationReply(
                reply,
                turn: turn,
                currentRequest: currentRequest,
                transcript: transcript
            )
        case .timedOut:
            interpretTask.cancel()
            continueClarification(
                with: currentRequest,
                userUtterance: transcript
            )
        }
    }

    private func applyRemoteClarificationReply(
        _ reply: TripReplyInterpretation?,
        turn: GIAClarificationTurn,
        currentRequest: TripRequest,
        transcript: String
    ) async {
        guard let reply else {
            continueClarification(
                with: currentRequest,
                userUtterance: transcript
            )
            return
        }
        if !reply.isUnderstood {
            await askWhatTheUserMeant(
                spokenText: reply.spokenText,
                turn: turn,
                isFollowUp: false
            )
            return
        }
        if reply.hasUsablePatch {
            clarificationRetryCount = 0
            presenceCheckCount = 0
            continueClarification(
                with: TripRequestInterpreter.applying(
                    reply,
                    to: currentRequest
                ),
                userUtterance: transcript
            )
            return
        }
        continueClarification(
            with: currentRequest,
            userUtterance: transcript
        )
    }

    private enum InterpretationRace: Sendable {
        case completed(TripReplyInterpretation?)
        case timedOut
    }

    private func raceInterpretation(
        _ task: Task<TripReplyInterpretation?, Never>,
        timeoutNanoseconds: UInt64
    ) async -> InterpretationRace {
        await withTaskGroup(of: InterpretationRace.self) { group in
            group.addTask {
                .completed(await task.value)
            }
            group.addTask {
                try? await Task.sleep(
                    nanoseconds: timeoutNanoseconds
                )
                return .timedOut
            }
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            return first
        }
    }

    private func interpretedReply(
        utterance: String,
        askedField: String,
        request: TripRequest,
        timeoutNanoseconds: UInt64 = 900_000_000
    ) async -> TripReplyInterpretation? {
        await responseCoordinator.interpretSpokenReply(
            replyInterpretationRequest(
                utterance: utterance,
                askedField: askedField,
                request: request
            ),
            timeoutNanoseconds: timeoutNanoseconds
        )
    }

    private func askWhatTheUserMeant(
        spokenText: String?,
        turn: GIAClarificationTurn?,
        isFollowUp: Bool
    ) async {
        let trimmed = spokenText?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        let spoken =
            trimmed.isEmpty
            ? GIAResponsePhrase.whatDoYouMean.text
            : trimmed
        if let turn {
            clarificationTurn = turn
        }
        clarificationPromptText = spoken
        conversationMemory.remember(speaker: "GIA", text: spoken)
        let response = GIAConversationResponse(
            spokenText: spoken,
            displayText: spoken,
            intent: .clarificationNeeded,
            shouldContinueListening: true
        )
        guard !Task.isCancelled else { return }
        await deliverCannedReply(response)
        completeTypedTurn()
        if usesTypedInput {
            return
        }
        if let turn {
            await beginClarificationTranscription(
                expectedTurn: turn
            )
        } else if isFollowUp {
            await resumeFollowUpListening()
        }
    }

    private func resumeFollowUpListening() async {
        if usesTypedInput { return }
        await waitForPlaybackEchoToSettle()
        guard !Task.isCancelled, isFollowUpRequest else { return }
        if tripPlanningSession.phase == .listening {
            try? tripPlanningSession.beginTranscribing()
        } else if
            tripPlanningSession.phase != .transcribing
        {
            try? tripPlanningSession.beginListening()
            try? tripPlanningSession.beginTranscribing()
        }
        await voiceSession.startRequestTranscription()
    }

    private func askedFieldName(
        for turn: GIAClarificationTurn
    ) -> String {
        switch turn {
        case .required(let field):
            field.rawValue
        case .optionalPreferences:
            "preferences"
        }
    }

    private func rememberUserUtterance(_ text: String?) {
        conversationMemory.remember(speaker: "User", text: text)
    }

    private func rememberAssistantReply(from request: TripRequest?) {
        let spoken =
            responseCoordinator.lastResponse?.spokenText
            ?? responseCoordinator.visibleText
        conversationMemory.remember(speaker: "GIA", text: spoken)
        conversationMemory.markDestinationComplimented(
            GIAHumanReplyComposer.spokenDestination(in: request)
        )
    }

    private func replyInterpretationRequest(
        utterance: String,
        askedField: String,
        request: TripRequest
    ) -> TripReplyInterpretationRequest {
        let context = conversationContext(
            for: TripRequestInterpretation(
                request: request,
                issues: TripRequestInterpreter.validate(request)
            ),
            transcript: utterance
        )
        return TripReplyInterpretationRequest(
            utterance: String(utterance.prefix(500)),
            askedField: askedField,
            today: isoDateString(from: Date()),
            requestSummary: context.requestSummary,
            knownFacts: context.groundedFacts
        )
    }

    private func isoDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func continueClarification(
        with request: TripRequest,
        userUtterance: String? = nil
    ) {
        do {
            try tripPlanningSession.beginValidation(request: request)
            let issues = TripRequestInterpreter.validate(request)
            if let field = nextClarificationField(in: issues) {
                try tripPlanningSession.requestClarification(
                    for: Set(issues.map(\.field))
                )
                beginClarificationConversation(
                    for: field,
                    userUtterance: userUtterance
                )
            } else if usesTypedInput {
                finishClarificationConversation(with: request)
            } else {
                try tripPlanningSession.requestClarification(
                    for: [.preferences]
                )
                beginOptionalPreferenceConversation(
                    userUtterance: userUtterance
                )
            }
        } catch {
            return
        }
    }

    private func repeatClarification(
        request: TripRequest,
        field: TripClarificationField
    ) {
        guard clarificationRetryCount < 1 else {
            try? tripPlanningSession.fail(
                code: "clarification_not_heard",
                userMessage:
                    "I still need that detail. Say GIA when you're ready.",
                isRecoverable: true
            )
            clarificationTurn = nil
            clarificationPromptText = ""
            return
        }
        clarificationRetryCount += 1
        do {
            try tripPlanningSession.beginValidation(request: request)
            try tripPlanningSession.requestClarification(for: [field])
        } catch {
            return
        }
        beginClarificationConversation(
            for: field,
            retrying: true
        )
    }

    private func repeatOptionalPreferenceQuestion(
        request: TripRequest
    ) {
        guard clarificationRetryCount < 1 else {
            finishClarificationConversation(with: request)
            return
        }
        clarificationRetryCount += 1
        do {
            try tripPlanningSession.beginValidation(request: request)
            try tripPlanningSession.requestClarification(
                for: [.preferences]
            )
        } catch {
            return
        }
        beginOptionalPreferenceConversation(retrying: true)
    }

    private func finishClarificationConversation(
        with request: TripRequest
    ) {
        do {
            try tripPlanningSession.beginValidation(request: request)
        } catch {
            return
        }
        let issues = TripRequestInterpreter.validate(request)
        if let field = nextClarificationField(in: issues) {
            do {
                try tripPlanningSession.requestClarification(
                    for: Set(issues.map(\.field))
                )
            } catch {
                return
            }
            beginClarificationConversation(
                for: field,
                retrying: true
            )
            return
        }

        let interpretation = TripRequestInterpretation(
            request: request,
            issues: []
        )
        beginSpokenHandoff(
            conversationContext(
                for: interpretation,
                extraFacts: [
                    "Confirm briefly that you have what you need. "
                        + "Do not ask another question."
                ]
            )
        )
        planningOrchestrator.start(
            request: request,
            session: tripPlanningSession,
            connectivity: connectivityMonitor.state
        )
    }

    private func nextClarificationField(
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

    private func conversationContext(
        for interpretation: TripRequestInterpretation,
        transcript: String? = nil,
        intent: GIAConversationIntent? = nil,
        extraFacts: [String] = []
    ) -> GIAConversationContext {
        let request = interpretation.request
        let resolvedIntent =
            intent
            ?? (
                interpretation.requiresClarification
                ? .clarificationNeeded
                : .requestCaptured
            )
        var facts: [String] = []
        if
            let transcript,
            !transcript.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        {
            facts.append("User said: \(transcript)")
        }
        facts.append(
            contentsOf: conversationMemory.turnFacts(
                userUtterance: transcript
            )
        )
        let destinationName =
            GIAHumanReplyComposer.spokenDestination(in: request)
        if let destinationName {
            facts.append("Destination: \(destinationName)")
        }
        if let complimentFact = conversationMemory.destinationComplimentFact(
            destination: destinationName
        ) {
            facts.append(complimentFact)
        }
        facts.append(contentsOf: extraFacts)
        if let travelers = request.travelerCount {
            facts.append("Travelers: \(travelers)")
        }
        if let budget = request.totalBudget {
            facts.append(
                "Budget: \(budget.amount) \(budget.currencyCode)"
            )
        }
        let datesFact: String?
        if let range = request.dateRange {
            let fact =
                "Dates: "
                + spokenTripDate(range.start)
                + " through "
                + spokenTripDate(range.end)
            facts.append(fact)
            datesFact = fact
        } else {
            datesFact = nil
        }
        facts += interpretation.issues.map {
            "Missing or invalid: \($0.message)"
        }

        var summaryParts: [String] = []
        if let destinationName {
            summaryParts.append("Destination: \(destinationName)")
        }
        if let travelers = request.travelerCount {
            summaryParts.append("Travelers: \(travelers)")
        }
        if let datesFact {
            summaryParts.append(datesFact)
        }
        if let ask = extraFacts.first(where: { $0.hasPrefix("Ask next:") }) {
            summaryParts.append(ask)
        }

        return GIAConversationContext(
            intent: resolvedIntent,
            requestSummary:
                summaryParts.isEmpty
                ? "A group travel request was captured."
                : summaryParts.joined(separator: ". "),
            groundedFacts: facts
        )
    }

    private func spokenTripDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .month(.wide)
                .day(.defaultDigits)
                .locale(Locale(identifier: "en_US"))
        )
    }

    private func clarificationFacts(
        for field: TripClarificationField,
        retrying: Bool
    ) -> [String] {
        let question: String
        switch field {
        case .destination:
            question = "Ask next: where they want to go."
        case .dates:
            question = "Ask next: travel dates."
        case .travelers:
            question = "Ask next: how many people are traveling."
        case .budget:
            question = "Ask next: the budget they want to stay under."
        case .origin:
            question = "Ask next: where they are leaving from."
        case .dietaryRequirements:
            question = "Ask next: any dietary needs."
        case .accessibility:
            question = "Ask next: any accessibility needs."
        case .preferences:
            question = "Ask next: anything else to account for."
        }
        if retrying {
            return [
                question,
                "Retry: ask the missing detail again. No compliment."
            ]
        }
        return [question]
    }

    private func submitTextRequest(_ text: String) {
        activationTask?.cancel()
        invalidatePlanHandoff()
        speechTask?.cancel()
        responseDeadlineTask?.cancel()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        demoFallbackTask?.cancel()
        responseCoordinator.stop()
        voiceSession.stop()
        clarificationTurn = nil
        clarificationPromptText = ""

        if
            (
                tripPlanningSession.phase == .ready
                || tripPlanningSession.phase == .partiallyAvailable
            ),
            tripPlanningSession.currentRequest != nil
        {
            followUpReturnPhase = tripPlanningSession.phase
            isFollowUpRequest = true
            do {
                try tripPlanningSession.beginListening(source: .manual)
                try tripPlanningSession.beginTranscribing()
            } catch {
                isFollowUpRequest = false
                followUpReturnPhase = nil
                return
            }
            handleFollowUpTranscript(text)
            return
        }

        judgeDemoController.reset()
        planningOrchestrator.reset()
        tripPlanningSession.clearCurrentTrip()
        conversationMemory.reset()

        let interpretation = TripRequestInterpreter.interpret(
            transcript: text
        )
        do {
            try tripPlanningSession.beginListening(source: .manual)
            try tripPlanningSession.beginTranscribing()
            try tripPlanningSession.beginValidation(
                request: interpretation.request
            )
            if interpretation.requiresClarification {
                try tripPlanningSession.requestClarification(
                    for: interpretation.clarificationFields
                )
            }
        } catch {
            return
        }
        if !interpretation.requiresClarification {
            planningOrchestrator.start(
                request: interpretation.request,
                session: tripPlanningSession,
                connectivity: connectivityMonitor.state
            )
        }

        earthSceneController.setFocusedPresentation(
            true,
            animated: !reduceMotion
        )
        earthSceneController.setActiveWithoutMotion(true)
        isVoiceDiscVisible = true
        voiceDiscRevealProgress = 1
        if
            interpretation.requiresClarification,
            let field = nextClarificationField(
                in: interpretation.issues
            )
        {
            beginClarificationConversation(
                for: field,
                userUtterance: text
            )
            return
        }
        schedulePlanHandoff()
    }

    private func startJudgeDemo() {
        dismissMenu()
        demoFallbackTask?.cancel()
        speechTask?.cancel()
        responseDeadlineTask?.cancel()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        responseCoordinator.stop()
        voiceSession.stop()
        planningOrchestrator.reset()
        tripPlanningSession.clearCurrentTrip()
        conversationMemory.reset()

        let trip = JudgeDemoTripFactory.makeTrip()
        do {
            try tripPlanningSession.beginListening(source: .debug)
            try tripPlanningSession.beginTranscribing()
            try tripPlanningSession.beginValidation(
                request: trip.request
            )
        } catch {
            return
        }

        judgeDemoController.activate(reason: .manual)
        isVoiceDiscVisible = true
        voiceDiscRevealProgress = 1
        earthSceneController.setFocusedPresentation(
            true,
            animated: !reduceMotion
        )
        earthSceneController.setActiveWithoutMotion(true)
        schedulePlanHandoff()

        demoFallbackTask = Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            completeDemoTrip(trip)
        }
    }

    private func completeDemoTrip(_ trip: Trip) {
        do {
            if tripPlanningSession.phase == .validating {
                try tripPlanningSession.replaceRequestDuringValidation(
                    trip.request
                )
                try tripPlanningSession.beginSearch()
            }
            if tripPlanningSession.phase == .searching {
                try tripPlanningSession.beginComparison()
            }
            if tripPlanningSession.phase == .comparing {
                try tripPlanningSession.beginItineraryBuild()
            }
            if tripPlanningSession.phase == .buildingItinerary {
                try tripPlanningSession.beginPresentation()
            }
            if tripPlanningSession.phase == .presenting {
                try tripPlanningSession.complete(with: trip)
            }
        } catch {
            return
        }
    }

    private func resetJudgeDemo() {
        dismissMenu()
        demoFallbackTask?.cancel()
        activationTask?.cancel()
        invalidatePlanHandoff()
        speechTask?.cancel()
        responseDeadlineTask?.cancel()
        clarificationFallbackTask?.cancel()
        initialGreetingFallbackTask?.cancel()
        goodbyeFallbackTask?.cancel()
        responseCoordinator.stop()
        voiceSession.stop()
        judgeDemoController.reset()
        clarificationTurn = nil
        clarificationPromptText = ""
        conversationMemory.reset()
        typedReplyMode = nil
        preferredTypedReplyMode = nil
        appState.setAssistantReplyMode(nil)
        typedMessages = []
        isTypedComposerBusy = false
        speakingDraft = ""
        isReplyModePickerPresented = false
        planningOrchestrator.reset()
        tripPlanningSession.clearCurrentTrip()
        planHandoffProgress = 0
        isPlanHandoffPending = false
        voiceDiscRevealProgress = 0
        isVoiceDiscVisible = false
        earthSceneController.setFocusedPresentation(
            false,
            animated: false
        )
        earthSceneController.setActiveWithoutMotion(false)
        withAnimation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .easeOut(duration: 0.2)
        ) {
            appState.select(.map)
        }
        startWakePhraseListeningIfPossible()
    }

    private var planHandoffAnimation: Animation {
        .timingCurve(
            0.32,
            0,
            0.18,
            1,
            duration: 0.58
        )
    }

    private var canPresentPlanHandoff: Bool {
        return switch tripPlanningSession.phase {
        case
            .validating,
            .needsClarification,
            .searching,
            .comparing,
            .buildingItinerary,
            .presenting,
            .partiallyAvailable,
            .ready:
            true
        default:
            false
        }
    }

    private var voiceTransitionAnimation: Animation {
        .linear(
            duration:
                EarthRenderingConfiguration
                    .transformationDuration
        )
    }

    private var voiceReturnAnimation: Animation {
        .linear(
            duration:
                EarthRenderingConfiguration.transformationDuration
                * EarthRenderingConfiguration.worldZoomDelayFactor
        )
    }

    private var displayedMicrophoneLevel: CGFloat {
        #if DEBUG
        if
            let rawLevel = ProcessInfo.processInfo.environment[
                "GIA_MIC_LEVEL"
            ],
            let level = Double(rawLevel)
        {
            return min(max(CGFloat(level), 0), 1)
        }
        #endif

        return max(
            voiceSession.level,
            responseCoordinator.playbackLevel
        )
    }

    private var displayedTranscript: String {
        discTranscript.text
    }

    private var isDisplayingAssistantCopy: Bool {
        discTranscript.isAssistantCopy
    }

    private var discTranscript: (text: String, isAssistantCopy: Bool) {
        switch responseCoordinator.state {
        case .generating:
            if
                responseCoordinator.visibleText.isEmpty,
                !pendingTypedUtterance.isEmpty
            {
                return (pendingTypedUtterance, false)
            }
            return (
                responseCoordinator.visibleText,
                !responseCoordinator.visibleText.isEmpty
            )
        case .playing, .failed:
            return (
                responseCoordinator.visibleText,
                !responseCoordinator.visibleText.isEmpty
            )
        case .idle:
            if
                !responseCoordinator.visibleText.isEmpty,
                voiceSession.liveTranscript.isEmpty
            {
                return (responseCoordinator.visibleText, true)
            }
        }

        if
            clarificationTurn != nil,
            voiceSession.liveTranscript.isEmpty,
            !clarificationPromptText.isEmpty
        {
            return (clarificationPromptText, true)
        }

        #if DEBUG
        if
            let transcript = ProcessInfo.processInfo.environment[
                "GIA_AUTORUN_PLAN_HANDOFF_TRANSCRIPT"
            ],
            !transcript.isEmpty
        {
            return (transcript, false)
        }

        if
            let transcript = ProcessInfo.processInfo.environment[
                "GIA_TRANSCRIPT"
            ],
            !transcript.isEmpty
        {
            return (transcript, false)
        }
        #endif

        if clarificationTurn != nil {
            return (voiceSession.liveTranscript, false)
        }

        return (
            VoiceRecognitionRules.appendingSpokenRequest(
                existing: accumulatedSpokenRequest,
                incoming: voiceSession.liveTranscript
            ),
            false
        )
    }

    private var assistantStatusText: String {
        assistantPresentationState.statusText
    }

    private func runDebugVoiceDemoIfRequested() {
        #if DEBUG
        if ProcessInfo.processInfo.environment[
            "GIA_DEBUG_GREETING"
        ] == "1" {
            Task {
                try? await Task.sleep(nanoseconds: 180_000_000)
                activateAssistant(source: .debug)
            }
            return
        }

        if
            let followUp = ProcessInfo.processInfo.environment[
                "GIA_DEBUG_FOLLOW_UP_TRANSCRIPT"
            ],
            !followUp.isEmpty
        {
            runDebugFollowUp(followUp)
            return
        }

        if ProcessInfo.processInfo.environment[
            "GIA_DEBUG_TEXT_REQUEST"
        ] == "1" {
            Task {
                try? await Task.sleep(nanoseconds: 180_000_000)
                isReplyModePickerPresented = true
            }
            return
        }

        if ProcessInfo.processInfo.environment[
            "GIA_DEBUG_JUDGE_DEMO"
        ] == "1" {
            Task {
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard
                    judgeDemoController.state == .inactive,
                    tripPlanningSession.currentTrip == nil
                else {
                    return
                }
                startJudgeDemo()
            }
            return
        }

        if
            let transcript = ProcessInfo.processInfo.environment[
                "GIA_AUTORUN_PLAN_HANDOFF_TRANSCRIPT"
            ],
            !transcript.isEmpty
        {
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard
                    appState.applicationActivity == .active
                else {
                    return
                }
                runDebugPlanHandoff(transcript)
            }
            return
        }

        if
            let rawReveal = ProcessInfo.processInfo.environment[
                "GIA_DISC_REVEAL_PROGRESS"
            ],
            let reveal = Double(rawReveal)
        {
            let normalizedReveal = min(
                max(CGFloat(reveal), 0),
                1
            )
            if normalizedReveal > 0 {
                if tripPlanningSession.phase != .idle {
                    tripPlanningSession.resetForNewRequest()
                }
                try? tripPlanningSession.beginListening(
                    source: .debug
                )
            } else if tripPlanningSession.phase != .idle {
                tripPlanningSession.resetForNewRequest()
            }
            earthSceneController.setFocusedPresentation(
                normalizedReveal > 0,
                animated: false
            )
            isVoiceDiscVisible = normalizedReveal > 0
            voiceDiscRevealProgress = normalizedReveal
            return
        }

        guard
            !isAssistantActive,
            ProcessInfo.processInfo.environment[
                "GIA_AUTORUN_VOICE_DEMO"
            ] == "1"
        else {
            return
        }

        toggleAssistant()

        if
            let rawDelay = ProcessInfo.processInfo.environment[
                "GIA_AUTORETURN_DELAY"
            ],
            let delay = Double(rawDelay),
            delay > 0
        {
            Task {
                try? await Task.sleep(
                    nanoseconds: UInt64(delay * 1_000_000_000)
                )
                guard isAssistantActive else { return }
                toggleAssistant()
            }
        }
        #endif
    }

    #if DEBUG
    private func runDebugPlanHandoff(_ transcript: String) {
        if tripPlanningSession.phase != .idle {
            tripPlanningSession.resetForNewRequest()
        }
        try? tripPlanningSession.beginListening(source: .debug)
        try? tripPlanningSession.beginTranscribing()
        let interpretation = TripRequestInterpreter.interpret(
            transcript: transcript
        )
        try? tripPlanningSession.beginValidation(
            request: interpretation.request
        )
        if interpretation.requiresClarification {
            try? tripPlanningSession.requestClarification(
                for: interpretation.clarificationFields
            )
        }
        earthSceneController.setFocusedPresentation(
            true,
            animated: false
        )
        earthSceneController.setActiveWithoutMotion(true)
        isVoiceDiscVisible = true
        voiceDiscRevealProgress = 1
        if
            interpretation.requiresClarification,
            let field = nextClarificationField(
                in: interpretation.issues
            )
        {
            beginClarificationConversation(
                for: field,
                userUtterance: transcript
            )
            return
        }
        if ProcessInfo.processInfo.environment[
            "GIA_DEBUG_CONVERSATION_HANDOFF"
        ] == "1" {
            beginSpokenHandoff(
                conversationContext(
                    for: interpretation,
                    transcript: transcript,
                    extraFacts: [
                        "Confirm briefly that you have what you need. "
                            + "Do not ask another question."
                    ]
                )
            )
        } else {
            schedulePlanHandoff()
        }
        planningOrchestrator.start(
            request: interpretation.request,
            session: tripPlanningSession,
            connectivity: connectivityMonitor.state
        )
    }

    private func runDebugFollowUp(_ followUp: String) {
        let interpretation = TripRequestInterpreter.interpret(
            transcript:
                "Plan a trip from Atlanta to Lisbon for two "
                + "travelers under $4000 from May 10 to May 14, 2027."
        )
        let trip = TimelineDebugFixtures.itineraryTrip(
            preserving: interpretation.request
        )
        do {
            try tripPlanningSession.beginListening(source: .debug)
            try tripPlanningSession.beginTranscribing()
            try tripPlanningSession.beginValidation(
                request: interpretation.request
            )
            try tripPlanningSession.beginSearch()
            try tripPlanningSession.beginComparison()
            try tripPlanningSession.beginItineraryBuild()
            try tripPlanningSession.beginPresentation()
            try tripPlanningSession.complete(with: trip)
        } catch {
            return
        }
        appState.select(.plan)

        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.linear(duration: 0.01)) {
                appState.select(.map)
            }
            activateAssistant(source: .manual, asFollowUp: true)
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard tripPlanningSession.phase == .transcribing else {
                return
            }
            voiceSession.stop()
            handleFollowUpTranscript(followUp)
        }
    }
    #endif

    private var menuAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : GIAMotion.quick
    }
}

private struct VoiceAccessBanner: View {
    let message: String
    let onRetry: (() -> Void)?
    let onOpenSettings: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "mic.slash")
                .font(.caption.weight(.medium))
                .foregroundStyle(GIAColor.warningAccent)
                .frame(width: 24, height: 24)

            Text(message)
                .font(.caption)
                .foregroundStyle(GIAColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            if let onRetry {
                Button("TRY AGAIN", action: onRetry)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(GIAColor.intelligenceAccent)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
            }

            if let onOpenSettings {
                Button("SETTINGS", action: onOpenSettings)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(GIAColor.warningAccent)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open G.I.A. settings")
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GIAColor.menuSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    GIAColor.warningAccent.opacity(0.30),
                    lineWidth: 0.8
                )
        }
        .accessibilityElement(children: .contain)
    }
}

struct MapScreen_Previews: PreviewProvider {
    static var previews: some View {
        MapScreen()
            .environment(AppState())
            .environment(TripPlanningSession())
            .environment(GIAResponseCoordinator())
            .environment(JudgeDemoController())
            .environment(TripPlanningOrchestrator(service: nil))
            .environment(GIAConnectivityMonitor())
            .preferredColorScheme(.dark)
    }
}
