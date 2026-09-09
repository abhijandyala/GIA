import SwiftUI

struct PlanScreen: View {
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
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var selectedMetric:
        PlanContextMetric.Kind?
    @State private var bookingReview: BookingReviewSubject?
    @State private var completingFlightOfferID: UUID?
    @State private var flightCompletionMessage: String?
    @State private var isCancelConfirmationPresented = false

    var body: some View {
        ZStack {
            GIAColor.canvas
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    GIAColor.primaryText.opacity(0.055),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.02),
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()

            if let request = tripPlanningSession.currentRequest {
                PlanWorkspaceView(
                    request: request,
                    phase: tripPlanningSession.phase,
                    trip: displayedTrip,
                    progress: tripPlanningSession.progress,
                    failureMessage:
                        tripPlanningSession.failure?.userMessage,
                    orchestrationState:
                        planningOrchestrator.state,
                    orchestrationError:
                        planningOrchestrator.lastErrorMessage,
                    fallbackReason:
                        planningOrchestrator.fallbackReason,
                    budgetConflictAnalysis:
                        tripPlanningSession.budgetConflictAnalysis,
                    onSelectMetric: {
                        selectedMetric = $0
                    },
                    onSelectFlight: selectFlight,
                    completingFlightOfferID:
                        completingFlightOfferID,
                    flightCompletionMessage:
                        flightCompletionMessage,
                    onSelectHotel: selectHotel,
                    onMoveItineraryItem: moveItineraryItem,
                    onToggleItineraryItemLock:
                        toggleItineraryItemLock,
                    onNewRequest: startNewRequest,
                    onRetry: retryPlanning,
                    onContinueConversation: {
                        appState.requestMapFollowUp()
                        appState.select(.map)
                    },
                    onCancel: {
                        isCancelConfirmationPresented = true
                    }
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(
                            with: .scale(
                                scale: 1.035,
                                anchor: .top
                            )
                        )
                )
            } else {
                PlanUnavailableState(
                    message:
                        tripPlanningSession.failure?.userMessage
                        ?? "Talk with G.I.A. on Map to start a trip.",
                    onReturnToMap: {
                        appState.select(.map)
                    }
                )
            }
        }
            .accessibilityIdentifier("plan.screen")
            .onAppear {
                configureDebugBookingIfRequested()
                configureDebugBudgetConflictIfRequested()
                configureDebugTimelineIfRequested()
                configureDebugHotelResultsIfRequested()
                configureDebugFlightResultsIfRequested()
                configureDebugProgressIfRequested()
                openDebugCorrectionIfRequested()
                scheduleDebugCancellationIfRequested()
                runDebugSpeechIfRequested()
            }
            .onChange(of: planningOrchestrator.state) { _, state in
                narratePlanningState(state)
            }
            .sheet(item: $selectedMetric) { field in
                if let request = tripPlanningSession.currentRequest {
                    TripRequestCorrectionSheet(
                        field: field,
                        request: request,
                        onSave: applyCorrection
                    )
                }
            }
            .sheet(item: $bookingReview) { subject in
                if
                    let trip = tripPlanningSession.currentTrip,
                    let presentation =
                        BookingReviewBuilder.presentation(
                            for: subject,
                            in: trip
                        )
                {
                    let mode =
                        BookingReviewBuilder.confirmationMode(
                            for: presentation
                        )
                    BookingConfirmationSheet(
                        presentation: presentation,
                        mode: mode,
                        onConfirm: {
                            confirmBooking(
                                subject,
                                mode: mode
                            )
                        }
                    )
                }
            }
            .confirmationDialog(
                "Cancel this planning request?",
                isPresented: $isCancelConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Cancel Request", role: .destructive) {
                    cancelPlanning()
                }

                Button("Keep Planning", role: .cancel) { }
            } message: {
                Text(
                    "The captured request will be cleared. "
                    + "No provider booking has been made."
                )
            }
    }

    private func applyCorrection(_ request: TripRequest) {
        do {
            try tripPlanningSession.replaceRequestDuringValidation(
                request
            )

            let issues = TripRequestInterpreter.validate(request)
            if !issues.isEmpty {
                try tripPlanningSession.requestClarification(
                    for: Set(issues.map(\.field))
                )
            } else {
                planningOrchestrator.start(
                    request: request,
                    session: tripPlanningSession,
                    connectivity: connectivityMonitor.state
                )
            }
        } catch {
            return
        }
    }

    private func openDebugCorrectionIfRequested() {
        #if DEBUG
        guard
            let rawField = ProcessInfo.processInfo.environment[
                "GIA_AUTOPEN_CORRECTION_FIELD"
            ],
            let field = PlanContextMetric.Kind(rawValue: rawField)
        else {
            return
        }

        selectedMetric = field
        #endif
    }

    private func configureDebugProgressIfRequested() {
        #if DEBUG
        guard
            ProcessInfo.processInfo.environment[
                "GIA_DEBUG_PROGRESS_FIXTURE"
            ] == "1",
            tripPlanningSession.phase == .validating,
            let request = tripPlanningSession.currentRequest,
            TripRequestInterpreter.validate(request).isEmpty
        else {
            return
        }

        try? tripPlanningSession.beginSearch()
        try? tripPlanningSession.beginWorkstream(
            .flights,
            providers: [.serpApi],
            message: "Comparing live fares"
        )
        try? tripPlanningSession.completeWorkstream(
            .stay,
            resultCount: 18,
            providers: [.serpApi],
            message: "Sourced hotel options"
        )
        try? tripPlanningSession.beginWorkstream(
            .experiences,
            providers: [.geoapify, .serpApi],
            message: "Discovering relevant places"
        )
        try? tripPlanningSession.completeWorkstream(
            .weather,
            resultCount: 1,
            providers: [.weatherAPI],
            message: "Forecast received"
        )
        #endif
    }

    private func configureDebugBookingIfRequested() {
        #if DEBUG
        guard
            let category = ProcessInfo.processInfo.environment[
                "GIA_DEBUG_BOOKING_REVIEW"
            ],
            tripPlanningSession.phase == .validating,
            let request = tripPlanningSession.currentRequest
        else {
            return
        }

        let trip: Trip
        let subject: BookingReviewSubject
        if category == "hotel" {
            trip = HotelDebugFixtures.comparisonTrip(
                preserving: request
            )
            guard let id = trip.selections.hotelOfferIDs.first else {
                return
            }
            subject = .hotel(id)
        } else {
            trip = PlanDebugFixtures.flightComparisonTrip(
                preserving: request
            )
            guard let id = trip.selections.flightOfferIDs.first else {
                return
            }
            subject = .flight(id)
        }

        try? tripPlanningSession.replaceRequestDuringValidation(
            trip.request
        )
        try? tripPlanningSession.beginSearch()
        try? tripPlanningSession.beginComparison()
        try? tripPlanningSession.beginItineraryBuild()
        try? tripPlanningSession.beginPresentation()
        try? tripPlanningSession.complete(with: trip)
        bookingReview = subject
        #endif
    }

    private func configureDebugFlightResultsIfRequested() {
        #if DEBUG
        guard
            ProcessInfo.processInfo.environment[
                "GIA_DEBUG_FLIGHT_RESULTS_FIXTURE"
            ] == "1",
            tripPlanningSession.phase == .validating,
            let request = tripPlanningSession.currentRequest
        else {
            return
        }

        let trip = PlanDebugFixtures.flightComparisonTrip(
            preserving: request
        )
        try? tripPlanningSession.replaceRequestDuringValidation(
            trip.request
        )
        try? tripPlanningSession.beginSearch()
        try? tripPlanningSession.beginComparison()
        try? tripPlanningSession.beginItineraryBuild()
        try? tripPlanningSession.beginPresentation()
        try? tripPlanningSession.complete(with: trip)
        #endif
    }

    private func configureDebugHotelResultsIfRequested() {
        #if DEBUG
        guard
            ProcessInfo.processInfo.environment[
                "GIA_DEBUG_HOTEL_RESULTS_FIXTURE"
            ] == "1",
            tripPlanningSession.phase == .validating,
            let request = tripPlanningSession.currentRequest
        else {
            return
        }

        let trip = HotelDebugFixtures.comparisonTrip(
            preserving: request
        )
        try? tripPlanningSession.replaceRequestDuringValidation(
            trip.request
        )
        try? tripPlanningSession.beginSearch()
        try? tripPlanningSession.beginComparison()
        try? tripPlanningSession.beginItineraryBuild()
        try? tripPlanningSession.beginPresentation()
        try? tripPlanningSession.complete(with: trip)
        #endif
    }

    private func configureDebugTimelineIfRequested() {
        #if DEBUG
        guard
            ProcessInfo.processInfo.environment[
                "GIA_DEBUG_TIMELINE_FIXTURE"
            ] == "1",
            tripPlanningSession.phase == .validating,
            let request = tripPlanningSession.currentRequest
        else {
            return
        }

        let trip = TimelineDebugFixtures.itineraryTrip(
            preserving: request
        )
        try? tripPlanningSession.replaceRequestDuringValidation(
            trip.request
        )
        try? tripPlanningSession.beginSearch()
        try? tripPlanningSession.beginComparison()
        try? tripPlanningSession.beginItineraryBuild()
        try? tripPlanningSession.beginPresentation()
        try? tripPlanningSession.complete(with: trip)
        #endif
    }

    private func configureDebugBudgetConflictIfRequested() {
        #if DEBUG
        guard
            ProcessInfo.processInfo.environment[
                "GIA_DEBUG_BUDGET_CONFLICT_FIXTURE"
            ] == "1",
            tripPlanningSession.phase == .validating,
            let request = tripPlanningSession.currentRequest
        else {
            return
        }

        let trip = BudgetConflictDebugFixtures.analysisTrip(
            preserving: request
        )
        try? tripPlanningSession.replaceRequestDuringValidation(
            trip.request
        )
        try? tripPlanningSession.beginSearch()
        try? tripPlanningSession.beginComparison()
        try? tripPlanningSession.beginItineraryBuild()
        try? tripPlanningSession.beginPresentation()
        try? tripPlanningSession.complete(with: trip)
        #endif
    }

    private func scheduleDebugCancellationIfRequested() {
        #if DEBUG
        guard
            ProcessInfo.processInfo.environment[
                "GIA_DEBUG_AUTOCANCEL_PLAN"
            ] == "1"
        else {
            return
        }

        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            cancelPlanning()
        }
        #endif
    }

    private func runDebugSpeechIfRequested() {
        #if DEBUG
        guard
            ProcessInfo.processInfo.environment[
                "GIA_DEBUG_SPEECH_RESPONSE"
            ] == "1"
        else {
            return
        }

        Task {
            _ = await responseCoordinator.speak(.planReady)
        }
        #endif
    }

    private func cancelPlanning() {
        planningOrchestrator.cancel()
        do {
            try tripPlanningSession.cancel()
        } catch {
            return
        }

        withAnimation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .easeInOut(duration: 0.24)
        ) {
            appState.select(.map)
        }
    }

    private func startNewRequest() {
        completingFlightOfferID = nil
        flightCompletionMessage = nil
        planningOrchestrator.reset()
        responseCoordinator.stop()
        judgeDemoController.reset()
        tripPlanningSession.clearCurrentTrip()
        appState.setAssistantReplyMode(nil)
        withAnimation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .easeOut(duration: 0.2)
        ) {
            appState.select(.map)
        }
    }

    private func retryPlanning() {
        guard let request = tripPlanningSession.currentRequest else {
            return
        }
        completingFlightOfferID = nil
        flightCompletionMessage = nil
        planningOrchestrator.reset()
        tripPlanningSession.resetForNewRequest()
        do {
            try tripPlanningSession.beginListening(source: .manual)
            try tripPlanningSession.beginTranscribing()
            try tripPlanningSession.beginValidation(request: request)
            planningOrchestrator.start(
                request: request,
                session: tripPlanningSession,
                connectivity: connectivityMonitor.state
            )
        } catch {
            return
        }
    }

    private var displayedTrip: Trip? {
        switch planningOrchestrator.state {
        case .resolvingLocation, .searching, .assembling:
            planningOrchestrator.previewTrip
        default:
            tripPlanningSession.currentTrip
                ?? planningOrchestrator.previewTrip
        }
    }

    private func narratePlanningState(
        _ state: TripOrchestrationState
    ) {
        guard responseCoordinator.state == .idle else {
            return
        }
        let phrase: GIAResponsePhrase?
        switch state {
        case .searching:
            phrase = .searching
        case .assembling:
            phrase = .assembling
        case .ready:
            phrase = .planReady
        default:
            phrase = nil
        }
        guard let phrase else { return }
        Task {
            if appState.assistantReplyMode == .typing {
                responseCoordinator.presentText(
                    GIAConversationFallback.response(for: phrase)
                )
            } else {
                _ = await responseCoordinator.speak(phrase)
            }
        }
    }

    private func selectFlight(_ offerID: UUID) {
        guard
            completingFlightOfferID == nil,
            let trip = tripPlanningSession.currentTrip,
            let offer = trip.catalog.flightOffers.first(
                where: { $0.id == offerID }
            )
        else {
            return
        }
        let isIncompleteRoundTrip =
            trip.request.dateRange != nil
            && offer.returnSegments.isEmpty
            && offer.continuationToken != nil
        guard isIncompleteRoundTrip else {
            do {
                try tripPlanningSession.selectFlightOffer(offerID)
                bookingReview = .flight(offerID)
            } catch {
                return
            }
            return
        }

        completingFlightOfferID = offerID
        flightCompletionMessage = nil
        Task {
            do {
                let completed =
                    try await planningOrchestrator
                        .completeRoundTrip(
                            outboundOffer: offer,
                            request: trip.request
                        )
                guard !Task.isCancelled else { return }
                let selectedID =
                    try tripPlanningSession
                        .replaceOutboundFlightOffer(
                            offerID,
                            with: completed
                        )
                bookingReview = .flight(selectedID)
            } catch is CancellationError {
                return
            } catch {
                flightCompletionMessage =
                    "Return options could not be loaded. "
                    + "No flight was selected."
            }
            completingFlightOfferID = nil
        }
    }

    private func selectHotel(_ offerID: UUID) {
        do {
            try tripPlanningSession.selectHotelOffer(offerID)
            bookingReview = .hotel(offerID)
        } catch {
            return
        }
    }

    private func confirmBooking(
        _ subject: BookingReviewSubject,
        mode: BookingConfirmationMode
    ) -> Result<BookingRecord, BookingConfirmationError> {
        do {
            let record: BookingRecord
            switch subject {
            case .flight(let id):
                record = try tripPlanningSession.confirmFlightOffer(
                    id,
                    mode: mode
                )
            case .hotel(let id):
                record = try tripPlanningSession.confirmHotelOffer(
                    id,
                    mode: mode
                )
            }
            return .success(record)
        } catch let error as BookingConfirmationError {
            return .failure(error)
        } catch {
            return .failure(.noCurrentTrip)
        }
    }

    private func moveItineraryItem(
        _ itemID: UUID,
        start: Date,
        end: Date
    ) -> Bool {
        do {
            try tripPlanningSession.moveItineraryItem(
                itemID,
                toStart: start,
                end: end
            )
            return true
        } catch {
            return false
        }
    }

    private func toggleItineraryItemLock(_ itemID: UUID) {
        try? tripPlanningSession.toggleItineraryItemLock(itemID)
    }
}

private struct PlanUnavailableState: View {
    let message: String
    let onReturnToMap: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No trip yet", systemImage: "map")
        } description: {
            Text(message)
        } actions: {
            Button("Talk with G.I.A.", action: onReturnToMap)
                .buttonStyle(.borderedProminent)
                .tint(GIAColor.primaryText)
                .foregroundStyle(GIAColor.canvas)
                .frame(minHeight: 44)
        }
        .foregroundStyle(GIAColor.secondaryText)
        .accessibilityHint(
            "Returns to Map so you can talk with G.I.A."
        )
    }
}

struct PlanLanguageMenu: View {
    @Environment(PlanTranslationCoordinator.self)
    private var translationCoordinator

    var body: some View {
        Menu {
            ForEach(PlanTranslationLanguage.allCases) { language in
                Button {
                    translationCoordinator.select(language)
                } label: {
                    if
                        language
                            == translationCoordinator.targetLanguage
                    {
                        Label(
                            language.displayName,
                            systemImage: "checkmark"
                        )
                    } else {
                        Text(language.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "globe")

                Text(
                    translationCoordinator
                        .targetLanguage
                        .displayName
                )
                .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(
                translationCoordinator.failureMessage == nil
                    ? GIAColor.secondaryText
                    : GIAColor.warningAccent
            )
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background {
                Capsule(style: .continuous)
                    .fill(GIAColor.primaryText.opacity(0.05))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(GIAColor.subtleStroke, lineWidth: 0.7)
            }
        }
        .disabled(!translationCoordinator.isAvailable)
        .accessibilityLabel("Plan language")
        .accessibilityValue(
            translationCoordinator.targetLanguage.displayName
        )
        .accessibilityHint(
            translationCoordinator.isAvailable
                ? "Changes translated Plan descriptions"
                : "Translation is unavailable"
        )
    }
}

struct TranslatedPlanText: View {
    @Environment(PlanTranslationCoordinator.self)
    private var translationCoordinator

    let originalText: String
    let contentKind: TranslationContentKind
    let protectedTerms: [String]

    @State private var translated: TranslatedText?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(translated?.translatedText ?? originalText)
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if translated?.isMachineTranslated == true {
                Text("MACHINE TRANSLATED · GOOGLE")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(
                        GIAColor.intelligenceAccent.opacity(0.78)
                    )
            } else if
                translationCoordinator.targetLanguage != .english,
                let failure = translationCoordinator.failureMessage
            {
                Label(
                    failure,
                    systemImage: "exclamationmark.circle"
                )
                .font(.caption2)
                .foregroundStyle(GIAColor.warningAccent)
            }
        }
        .task(id: taskIdentifier) {
            translated = nil
            translated = await translationCoordinator.translation(
                for: originalText,
                contentKind: contentKind,
                protectedTerms: protectedTerms
            )
        }
        .accessibilityElement(children: .combine)
    }

    private var taskIdentifier: TranslationDisplayTaskID {
        TranslationDisplayTaskID(
            text: originalText,
            targetLanguageCode:
                translationCoordinator.targetLanguage.rawValue,
            contentKind: contentKind.rawValue,
            protectedTerms: protectedTerms
        )
    }
}

private struct TranslationDisplayTaskID: Hashable {
    var text: String
    var targetLanguageCode: String
    var contentKind: String
    var protectedTerms: [String]
}

private struct PlanWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(GIAResponseCoordinator.self)
    private var responseCoordinator
    @Environment(JudgeDemoController.self)
    private var judgeDemoController
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let request: TripRequest
    let phase: TripPlanningPhase
    let trip: Trip?
    let progress: TripPlanningProgress
    let failureMessage: String?
    let orchestrationState: TripOrchestrationState
    let orchestrationError: String?
    let fallbackReason: TripPlanningFallbackReason?
    let budgetConflictAnalysis: TripBudgetConflictAnalysis?
    let onSelectMetric: (PlanContextMetric.Kind) -> Void
    let onSelectFlight: (UUID) -> Void
    let completingFlightOfferID: UUID?
    let flightCompletionMessage: String?
    let onSelectHotel: (UUID) -> Void
    let onMoveItineraryItem:
        (UUID, Date, Date) -> Bool
    let onToggleItineraryItemLock: (UUID) -> Void
    let onNewRequest: () -> Void
    let onRetry: () -> Void
    let onContinueConversation: () -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let edge = GIASpacing.screenEdge(
                for: geometry.size.width
            )

            ScrollViewReader { scrollProxy in
                VStack(spacing: 0) {
                    PlanHeaderView(
                        request: request,
                        phase: phase,
                        statusText: compactStatusMessage,
                        isProcessing: isOrchestrationActive,
                        canCancel: canCancelPlanning,
                        jumpAnchors: jumpAnchors,
                        showsAskGIA: shouldOfferMapFollowUp,
                        isWaitingForAnswer:
                            phase == .needsClarification,
                        onSelectMetric: onSelectMetric,
                        onJump: { anchor in
                            withAnimation(jumpAnimation) {
                                scrollProxy.scrollTo(
                                    anchor.rawValue,
                                    anchor: .top
                                )
                            }
                        },
                        onNewRequest: onNewRequest,
                        onCancel: onCancel,
                        onAskGIA: onContinueConversation
                    )
                    .padding(.horizontal, edge)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                    ScrollView {
                        LazyVStack(spacing: 18) {
                            if judgeDemoController.isActive {
                                JudgeDemoStatusBanner(
                                    status:
                                        judgeDemoController.statusLabel
                                )
                            }

                            if showsResponseBanner {
                                GIASpeechStatusBanner(
                                    state: responseCoordinator.state,
                                    text: responseCoordinator.visibleText,
                                    failureMessage:
                                        responseCoordinator.failureMessage,
                                    onDismiss: {
                                        responseCoordinator.stop()
                                    }
                                )
                                .task(id: responseCoordinator.state) {
                                    guard
                                        responseCoordinator.state
                                            == .generating
                                    else {
                                        return
                                    }
                                    try? await Task.sleep(
                                        nanoseconds: 4_250_000_000
                                    )
                                    guard !Task.isCancelled else {
                                        return
                                    }
                                    responseCoordinator
                                        .cancelPendingResponse()
                                }
                            }

                            if let orchestrationError {
                                OrchestrationAvailabilityNotice(
                                    state: orchestrationState,
                                    message: orchestrationError,
                                    reason: fallbackReason,
                                    onRetry: onRetry
                                )
                                .id("orchestration-availability")
                            }

                            if
                                let trip,
                                !trip.itinerary.days.isEmpty
                            {
                                SpatialItineraryTimeline(
                                    trip: trip,
                                    onMove: onMoveItineraryItem,
                                    onToggleLock:
                                        onToggleItineraryItemLock
                                )
                                .id("itinerary-timeline")
                            }

                            if
                                let trip,
                                !trip.catalog.flightOffers.isEmpty
                            {
                                FlightComparisonSection(
                                    offers: trip.catalog.flightOffers,
                                    selectedIDs:
                                        trip.selections.flightOfferIDs,
                                    bookings: trip.bookings,
                                    completingOfferID:
                                        completingFlightOfferID,
                                    completionMessage:
                                        flightCompletionMessage,
                                    onSelect: onSelectFlight
                                )
                                .id("flight-comparison")
                            }

                            if
                                let trip,
                                !trip.catalog.hotelOffers.isEmpty
                            {
                                HotelComparisonSection(
                                    offers: trip.catalog.hotelOffers,
                                    selectedIDs:
                                        trip.selections.hotelOfferIDs,
                                    bookings: trip.bookings,
                                    onSelect: onSelectHotel
                                )
                                .id("hotel-comparison")
                            }

                            if let budgetConflictAnalysis {
                                BudgetConflictSection(
                                    analysis: budgetConflictAnalysis
                                )
                                .id("budget-conflict")
                            }
                        }
                        .padding(.horizontal, edge)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
                .task {
                    #if DEBUG
                    let environment = ProcessInfo.processInfo.environment
                    let target =
                        environment["GIA_DEBUG_SCROLL_TO_FLIGHTS"] == "1"
                        ? "flight-comparison"
                        : environment["GIA_DEBUG_SCROLL_TO_HOTELS"] == "1"
                            ? "hotel-comparison"
                            : environment[
                                "GIA_DEBUG_SCROLL_TO_AVAILABILITY"
                            ] == "1"
                                ? "orchestration-availability"
                            : environment[
                                "GIA_DEBUG_SCROLL_TO_TIMELINE"
                            ] == "1"
                                ? "itinerary-timeline"
                            : environment[
                                "GIA_DEBUG_SCROLL_TO_BUDGET_CONFLICT"
                            ] == "1"
                                ? "budget-conflict"
                            : nil
                    if let target {
                        try? await Task.sleep(
                            nanoseconds: 900_000_000
                        )
                        withAnimation(.easeInOut(duration: 0.35)) {
                            scrollProxy.scrollTo(
                                target,
                                anchor: .top
                            )
                        }
                    }
                    #endif
                }
            }
        }
    }

    private var jumpAnchors: [PlanJumpAnchor] {
        var anchors: [PlanJumpAnchor] = []
        if let trip, !trip.itinerary.days.isEmpty {
            anchors.append(.days)
        }
        if let trip, !trip.catalog.flightOffers.isEmpty {
            anchors.append(.flights)
        }
        if let trip, !trip.catalog.hotelOffers.isEmpty {
            anchors.append(.stay)
        }
        if budgetConflictAnalysis != nil {
            anchors.append(.budget)
        }
        return anchors
    }

    private var canCancelPlanning: Bool {
        switch phase {
        case
            .validating,
            .needsClarification,
            .searching,
            .comparing,
            .buildingItinerary,
            .presenting:
            true
        default:
            false
        }
    }

    private var jumpAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.01)
            : .easeInOut(duration: 0.28)
    }

    private var isOrchestrationActive: Bool {
        switch orchestrationState {
        case .resolvingLocation, .searching, .assembling:
            true
        default:
            false
        }
    }

    private var showsResponseBanner: Bool {
        guard !responseCoordinator.visibleText.isEmpty else {
            return false
        }
        if responseCoordinator.state != .idle {
            return true
        }
        return appState.assistantReplyMode == .typing
    }

    private var compactStatusMessage: String? {
        if
            orchestrationState == .failed || phase == .failed,
            let failureMessage
        {
            return failureMessage
        }
        if
            let activeMessage = progress.activeItem?.statusMessage,
            !activeMessage.isEmpty
        {
            return activeMessage
        }
        return PlanPhasePresentation.workspaceStatus(
            phase: phase,
            orchestration: orchestrationState,
            failureMessage: failureMessage
        )
    }

    private var shouldOfferMapFollowUp: Bool {
        switch phase {
        case
            .needsClarification,
            .searching,
            .comparing,
            .buildingItinerary,
            .presenting,
            .ready,
            .partiallyAvailable:
            true
        default:
            false
        }
    }
}

private struct OrchestrationAvailabilityNotice: View {
    let state: TripOrchestrationState
    let message: String
    let reason: TripPlanningFallbackReason?
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(
                systemName:
                    state == .failed
                    ? "exclamationmark.triangle"
                    : "wifi.slash"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(GIAColor.warningAccent)
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    reason == .offline
                        ? "Offline"
                        : state == .failed
                        ? "Planning paused"
                        : "Some results are missing"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(GIAColor.warningAccent)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(GIAColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    "No options, prices, or progress counts "
                    + "have been fabricated."
                )
                .font(.caption2)
                .foregroundStyle(GIAColor.secondaryText)

                Button(action: onRetry) {
                    Label(
                        "Try again",
                        systemImage: "arrow.clockwise"
                    )
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(GIAColor.intelligenceAccent)
                .accessibilityHint(
                    "Retries the in-memory provider searches"
                )
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .planSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}

private struct ConversationalClarificationNotice: View {
    var phase: TripPlanningPhase = .needsClarification
    let onContinue: () -> Void

    @Environment(AppState.self) private var appState

    private var isWaitingForAnswer: Bool {
        phase == .needsClarification
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            GIAPlanningIndicator(isActive: true)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 7) {
                Text(
                    isWaitingForAnswer
                        ? "CONTINUE WITH GIA"
                        : "ADD OR CHANGE"
                )
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(GIAColor.intelligenceAccent)

                Text(
                    isWaitingForAnswer
                        ? "GIA is waiting for your answer on Map."
                        : "Go back to Map to add, change, or remove something."
                )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)

                Text(
                    isWaitingForAnswer
                        ? "Answer naturally. There is no form to complete."
                        : "Map opens the same typed conversation so you can update this trip."
                )
                .font(.caption)
                .foregroundStyle(GIAColor.secondaryText)

                Button(action: onContinue) {
                    Label(
                        isWaitingForAnswer
                            ? "CONTINUE CONVERSATION"
                            : "ADD OR CHANGE ON MAP",
                        systemImage:
                            appState.assistantReplyMode == .speaking
                            ? "waveform"
                            : appState.assistantReplyMode == .typing
                                ? "keyboard"
                                : "waveform"
                    )
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(GIAColor.intelligenceAccent)
                .accessibilityIdentifier("plan.addOrChange")
            }

            Spacer(minLength: 0)
        }
        .padding(17)
        .planSurface(cornerRadius: 22)
        .accessibilityElement(children: .contain)
    }
}

private struct ClarificationConversationCard: View {
    let prompts: [PlanClarificationPrompt]
    let onSelectMetric: (PlanContextMetric.Kind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(
                            GIAColor.intelligenceAccent.opacity(0.42),
                            lineWidth: 1
                        )
                    Text("GIΛ")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.8)
                        .foregroundStyle(
                            GIAColor.intelligenceAccent
                        )
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 5) {
                    Text("ONE MORE DETAIL")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(
                            GIAColor.intelligenceAccent
                        )

                    Text(
                        prompts.count == 1
                            ? "I only need this before we continue."
                            : "I need these details before we continue."
                    )
                    .font(.headline.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)

                    Text(
                        "Keep everything else. There is no need "
                        + "to repeat your request."
                    )
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
                }
            }

            VStack(spacing: 9) {
                ForEach(prompts) { prompt in
                    if let metric = prompt.editableMetric {
                        Button {
                            onSelectMetric(metric)
                        } label: {
                            clarificationRow(
                                prompt,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(prompt.title). \(prompt.question)"
                        )
                        .accessibilityHint(
                            "Opens an editor for this detail"
                        )
                    } else {
                        clarificationRow(
                            prompt,
                            showsChevron: false
                        )
                    }
                }
            }
        }
        .padding(18)
        .planSurface(cornerRadius: 22)
    }

    private func clarificationRow(
        _ prompt: PlanClarificationPrompt,
        showsChevron: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(
                systemName:
                    prompt.severity == .invalid
                    ? "exclamationmark"
                    : "plus"
            )
            .font(.caption2.weight(.bold))
            .foregroundStyle(
                prompt.severity == .invalid
                    ? GIAColor.warningAccent
                    : GIAColor.intelligenceAccent
            )
            .frame(width: 28, height: 28)
            .background {
                Circle().fill(
                    (
                        prompt.severity == .invalid
                        ? GIAColor.warningAccent
                        : GIAColor.intelligenceAccent
                    ).opacity(0.09)
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(prompt.title.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(GIAColor.secondaryText)

                Text(prompt.question)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 5)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(GIAColor.secondaryText)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GIAColor.primaryText.opacity(0.035))
        }
        .contentShape(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

private struct TransientPlanStatus: View {
    let phase: TripPlanningPhase
    let failureMessage: String?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.10))
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accent)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(GIAColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("NOT SAVED · CURRENT SESSION ONLY")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(GIAColor.intelligenceAccent)
                    .padding(.top, 3)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .planSurface(cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch phase {
        case .needsClarification:
            "A few details are missing"
        case .failed:
            "Request needs attention"
        default:
            "Request captured"
        }
    }

    private var detail: String {
        switch phase {
        case .needsClarification:
            "Review the highlighted request fields above. "
                + "You can correct one detail without starting over."
        case .failed:
            failureMessage
                ?? "Return to Map and try the request again."
        default:
            "Your request is available in memory. Live travel results "
                + "are not connected in this UI-focused build."
        }
    }

    private var symbol: String {
        switch phase {
        case .needsClarification:
            "questionmark"
        case .failed:
            "exclamationmark"
        default:
            "checkmark"
        }
    }

    private var accent: Color {
        phase == .failed
            ? GIAColor.warningAccent
            : GIAColor.intelligenceAccent
    }
}

private struct JudgeDemoStatusBanner: View {
    let status: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.checkered")
                .font(.caption.weight(.medium))
                .foregroundStyle(GIAColor.intelligenceAccent)

            Text("Judge-safe Tokyo demo. No live booking.")
                .font(.caption)
                .foregroundStyle(GIAColor.primaryText)
                .lineLimit(2)

            Spacer(minLength: 8)

            Text("Demo")
                .font(.caption.weight(.bold))
                .foregroundStyle(GIAColor.canvas)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background {
                    Capsule(style: .continuous)
                        .fill(GIAColor.intelligenceAccent)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .planSurface(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Judge-safe Tokyo demo. \(status). No live booking."
        )
    }
}

private struct GIASpeechStatusBanner: View {
    let state: GIAResponseState
    let text: String
    let failureMessage: String?
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        HStack(spacing: 13) {
            Image(
                systemName:
                    state == .failed
                    ? "speaker.slash"
                    : state == .idle
                        ? "text.bubble"
                        : "waveform"
            )
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(
                state == .failed
                    ? GIAColor.warningAccent
                    : GIAColor.intelligenceAccent
            )
            .symbolEffect(
                .variableColor.iterative,
                isActive: state == .playing && !reduceMotion
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(
                    state == .failed
                        ? "Voice unavailable"
                        : state == .playing
                            ? "G.I.A. speaking"
                            : state == .generating
                                ? "G.I.A. is preparing"
                                : "G.I.A."
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(GIAColor.secondaryText)

                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)

                if let failureMessage {
                    Text(failureMessage)
                        .font(.caption2)
                        .foregroundStyle(GIAColor.secondaryText)
                }
            }

            Spacer()

            if state == .failed {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GIAColor.secondaryText)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss voice message")
            }
        }
        .padding(16)
        .planSurface(cornerRadius: 18)
        .accessibilityElement(children: .contain)
        .accessibilityHidden(state == .playing)
    }
}

struct PlanScreen_Previews: PreviewProvider {
    static var previews: some View {
        PlanWorkspaceView(
            request: TripRequest(
                rawTranscript:
                    "Plan seven days in Lisbon for four travelers "
                    + "under six thousand dollars."
            ),
            phase: .validating,
            trip: nil,
            progress: TripPlanningProgress(),
            failureMessage: nil,
            orchestrationState: .idle,
            orchestrationError: nil,
            fallbackReason: nil,
            budgetConflictAnalysis: nil,
            onSelectMetric: { _ in },
            onSelectFlight: { _ in },
            completingFlightOfferID: nil,
            flightCompletionMessage: nil,
            onSelectHotel: { _ in },
            onMoveItineraryItem: { _, _, _ in false },
            onToggleItineraryItemLock: { _ in },
            onNewRequest: { },
            onRetry: { },
            onContinueConversation: { },
            onCancel: { }
        )
            .background(GIAColor.canvas)
            .environment(AppState())
            .environment(GIAResponseCoordinator())
            .environment(JudgeDemoController())
            .environment(TripPlanningOrchestrator(service: nil))
            .environment(PlanTranslationCoordinator(service: nil))
            .environment(GIAConnectivityMonitor())
            .preferredColorScheme(.dark)
    }
}
