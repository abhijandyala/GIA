import Foundation
import Observation

enum TripOrchestrationState: String, Sendable {
    case idle
    case resolvingLocation
    case searching
    case assembling
    case ready
    case partiallyAvailable
    case failed
    case cancelled
}

enum TripPlanningFallbackReason: String, Sendable {
    case offline
    case gatewayNotConfigured
    case partialProviderFailure
    case serviceFailure
}

@MainActor
@Observable
final class TripPlanningOrchestrator {
    private(set) var state: TripOrchestrationState = .idle
    private(set) var previewTrip: Trip?
    private(set) var unavailableProviders: Set<TravelProvider> = []
    private(set) var lastErrorMessage: String?
    private(set) var fallbackReason: TripPlanningFallbackReason?
    private(set) var usedGroundedPlanner = false
    private(set) var plannerFallbackMessage: String?

    @ObservationIgnored
    private let service: (any TripPlanningServing)?
    @ObservationIgnored
    private let strictProviderFailures: Bool
    @ObservationIgnored
    private var planningTask: Task<Void, Never>?

    init(
        service: (any TripPlanningServing)?,
        strictProviderFailures: Bool? = nil
    ) {
        self.service = service
        self.strictProviderFailures =
            strictProviderFailures
            ?? Self.defaultStrictProviderFailures
    }

    private static var defaultStrictProviderFailures: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment[
            "GIA_DEBUG_STRICT_PROVIDER_FAILURES"
        ] == "1"
        #else
        false
        #endif
    }

    func start(
        request: TripRequest,
        session: TripPlanningSession,
        connectivity: GIAConnectivityState = .unknown
    ) {
        cancel()
        previewTrip = TransientTripAssembler.baseTrip(
            request: request
        )
        unavailableProviders = []
        lastErrorMessage = nil
        fallbackReason = nil
        usedGroundedPlanner = false
        plannerFallbackMessage = nil
        state = .resolvingLocation

        planningTask = Task {
            await run(
                request: request,
                session: session,
                connectivity: connectivity
            )
        }
    }

    func completeRoundTrip(
        outboundOffer: FlightOffer,
        request: TripRequest
    ) async throws -> [FlightOffer] {
        guard let service else {
            throw GatewayClientError.providerUnavailable(
                code: "gateway_not_configured",
                message: "Live flight search is unavailable."
            )
        }
        guard
            outboundOffer.returnSegments.isEmpty,
            outboundOffer.continuationToken != nil,
            let origin = request.origin,
            let destination = request.destinations.first,
            let range = request.dateRange,
            let travelers = request.travelerCount
        else {
            throw GatewayClientError.providerUnavailable(
                code: "round_trip_completion_unavailable",
                message:
                    "This flight cannot load return options."
            )
        }

        return try await service.completeRoundTrip(
            matching: RoundTripFlightCompletionCriteria(
                searchCriteria: FlightSearchCriteria(
                    origin: origin,
                    destination: destination,
                    departureDate: range.start,
                    returnDate: range.end,
                    adults: travelers,
                    children: 0,
                    currencyCode:
                        request.totalBudget?.currencyCode ?? "USD",
                    preferences: request.flightPreferences
                ),
                outboundOffer: outboundOffer
            )
        )
    }

    func cancel() {
        planningTask?.cancel()
        planningTask = nil
        if state != .idle {
            state = .cancelled
        }
    }

    func reset() {
        cancel()
        previewTrip = nil
        unavailableProviders = []
        lastErrorMessage = nil
        fallbackReason = nil
        usedGroundedPlanner = false
        plannerFallbackMessage = nil
        state = .idle
    }

    private func run(
        request originalRequest: TripRequest,
        session: TripPlanningSession,
        connectivity: GIAConnectivityState
    ) async {
        if connectivity == .offline {
            if strictProviderFailures {
                publishStrictFailure(
                    code: "offline",
                    message:
                        "Strict local testing: the device is offline.",
                    session: session
                )
                return
            }
            await markAllProvidersUnavailable(
                request: originalRequest,
                session: session,
                reason: .offline
            )
            return
        }
        guard let service else {
            if strictProviderFailures {
                publishStrictFailure(
                    code: "gateway_not_configured",
                    message:
                        "Strict local testing: the gateway is not configured.",
                    session: session
                )
                return
            }
            await markAllProvidersUnavailable(
                request: originalRequest,
                session: session,
                reason: .gatewayNotConfigured
            )
            return
        }

        do {
            var request = originalRequest
            try session.completeWorkstream(
                .understanding,
                message: "Request validated"
            )
            try session.beginWorkstream(
                .destination,
                providers: [.geoapify],
                message: "Resolving destination context"
            )
            do {
                let destination = try await service.resolveLocation(
                    matching: LocationResolutionCriteria(
                        query:
                            request.destinations.first?.name ?? "",
                        includeNearestAirport: true
                    )
                )
                try Task.checkCancellation()
                request.destinations = [destination]
                if var range = request.dateRange,
                   let zone = destination.timeZoneIdentifier {
                    range.timeZoneIdentifier = zone
                    request.dateRange = range
                }

                if let originName = request.origin?.name {
                    do {
                        request.origin = try await service.resolveLocation(
                            matching: LocationResolutionCriteria(
                                query: originName,
                                includeNearestAirport: true
                            )
                        )
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch let error as GatewayClientError
                    where error == .cancelled {
                        throw error
                    } catch {
                        if strictProviderFailures {
                            throw error
                        }
                        request.origin = nil
                    }
                }
                try Task.checkCancellation()
                try session.completeWorkstream(
                    .destination,
                    resultCount: 1,
                    providers: [.geoapify],
                    message: "Destination resolved"
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as GatewayClientError
            where error == .cancelled {
                throw error
            } catch {
                if strictProviderFailures {
                    throw error
                }
                unavailableProviders.insert(.geoapify)
                try? session.markWorkstreamUnavailable(
                    .destination,
                    providers: [.geoapify],
                    message:
                        "Using the destination name without map context"
                )
            }
            try session.replaceRequestDuringValidation(request)
            try session.beginSearch()
            state = .searching
            previewTrip = TransientTripAssembler.baseTrip(
                request: request
            )

            var results = TransientPlanningResults()
            try await searchProviders(
                request: request,
                service: service,
                session: session,
                results: &results
            )
            try Task.checkCancellation()

            try session.beginComparison()
            try session.beginItineraryBuild()
            state = .assembling
            try session.beginWorkstream(
                .schedule,
                providers: [.openAI],
                message: "Building a grounded itinerary"
            )

            var blueprint: TripPlanBlueprint?
            if results.hasPlanningSources {
                let criteria = TripGenerationCriteria(
                    request: request,
                    flightOffers: Array(
                        results.flightOffers.prefix(8)
                    ),
                    hotelOffers: Array(
                        results.hotelOffers.prefix(8)
                    ),
                    places: Array(results.places.prefix(20)),
                    events: Array(results.events.prefix(10)),
                    routes: [],
                    weather: Array(results.weather.prefix(3))
                )
                do {
                    let generated = try await service.generatePlan(
                        matching: criteria
                    )
                    try Task.checkCancellation()
                    guard
                        TransientTripAssembler.finalizedTrip(
                            request: request,
                            results: results,
                            blueprint: generated
                        ) != nil
                    else {
                        throw GatewayClientError.providerUnavailable(
                            code: "invalid_plan_blueprint",
                            message:
                                "The generated plan could not be applied."
                        )
                    }
                    blueprint = generated
                    usedGroundedPlanner = true
                } catch is CancellationError {
                    throw CancellationError()
                } catch let error as GatewayClientError
                where error == .cancelled {
                    throw error
                } catch {
                    if strictProviderFailures {
                        throw error
                    }
                    unavailableProviders.insert(.openAI)
                    plannerFallbackMessage =
                        "GIA used the deterministic sourced itinerary "
                        + "because trip intelligence was unavailable."
                }
            }

            previewTrip =
                blueprint.flatMap {
                    TransientTripAssembler.finalizedTrip(
                        request: request,
                        results: results,
                        blueprint: $0
                    )
                }
                ?? TransientTripAssembler.baseTrip(
                    request: request,
                    results: results
                )

            results.routes = try await routes(
                for: previewTrip,
                service: service,
                session: session,
                currencyCode:
                    request.totalBudget?.currencyCode ?? "USD"
            )
            try Task.checkCancellation()
            let assembled =
                blueprint.flatMap {
                    TransientTripAssembler.finalizedTrip(
                        request: request,
                        results: results,
                        blueprint: $0
                    )
                }
                ?? TransientTripAssembler.finalizedTrip(
                    request: request,
                    results: results
                )
            previewTrip = assembled
            try session.completeWorkstream(
                .schedule,
                resultCount: assembled.itinerary.days.count,
                providers:
                    usedGroundedPlanner ? [.openAI] : [.gia],
                message:
                    usedGroundedPlanner
                    ? "Grounded itinerary assembled"
                    : "Deterministic sourced itinerary assembled"
            )
            if request.totalBudget != nil {
                try session.completeWorkstream(
                    .budget,
                    message: "Budget boundary applied"
                )
            }
            try session.beginPresentation()
            try session.complete(with: assembled)
            if unavailableProviders.isEmpty {
                state = .ready
            } else {
                state = .partiallyAvailable
                fallbackReason = .partialProviderFailure
                lastErrorMessage =
                    plannerFallbackMessage
                    ?? (
                        "Some live sources were unavailable. "
                        + "Available results are shown below."
                    )
            }
            planningTask = nil
        } catch is CancellationError {
            state = .cancelled
        } catch let error as GatewayClientError
        where error == .cancelled {
            state = .cancelled
        } catch {
            let failure = strictFailureDescription(for: error)
            publishStrictFailure(
                code: failure.code,
                message: failure.message,
                session: session
            )
        }
    }

    private func searchProviders(
        request: TripRequest,
        service: any TripPlanningServing,
        session: TripPlanningSession,
        results: inout TransientPlanningResults
    ) async throws {
        guard
            let destination = request.destinations.first,
            let range = request.dateRange,
            let travelers = request.travelerCount
        else {
            throw GatewayClientError.providerUnavailable(
                code: "incomplete_request",
                message: "The request is incomplete."
            )
        }

        let currency =
            request.totalBudget?.currencyCode ?? "USD"
        var canSearchFlights =
            request.origin?.iataCode != nil
            && request.origin?.timeZoneIdentifier != nil
            && destination.iataCode != nil
            && destination.timeZoneIdentifier != nil
            && travelers <= 9

        if canSearchFlights {
            try session.beginWorkstream(
                .flights,
                providers: [.serpApi],
                message: "Comparing live fares"
            )
        } else {
            canSearchFlights = false
            try session.markWorkstreamUnavailable(
                .flights,
                providers: [.serpApi],
                message:
                    request.origin == nil
                    ? "Add an origin to compare flights"
                    : "A flight airport could not be resolved"
            )
            unavailableProviders.insert(.serpApi)
        }
        try session.beginWorkstream(
            .stay,
            providers: [.serpApi],
            message: "Evaluating live stays"
        )
        try session.beginWorkstream(
            .experiences,
            providers: [.geoapify, .serpApi],
            message: "Finding places and timed events"
        )
        let canSearchWeather =
            destination.coordinate != nil
            && destination.timeZoneIdentifier != nil
        if canSearchWeather {
            try session.beginWorkstream(
                .weather,
                providers: [.weatherAPI],
                message: "Checking forecast and alerts"
            )
        } else {
            try session.markWorkstreamUnavailable(
                .weather,
                providers: [.weatherAPI],
                message: "Weather needs resolved coordinates"
            )
            unavailableProviders.insert(.weatherAPI)
        }

        let strictMode = strictProviderFailures
        var strictProviderError: GatewayClientError?
        await withTaskGroup(of: ProviderOutput.self) { group in
            if canSearchFlights, let origin = request.origin {
                group.addTask {
                    do {
                        return .flights(
                            try await service.searchFlights(
                                matching: FlightSearchCriteria(
                                    origin: origin,
                                    destination: destination,
                                    departureDate: range.start,
                                    returnDate: range.end,
                                    adults: travelers,
                                    children: 0,
                                    currencyCode: currency,
                                    preferences:
                                        request.flightPreferences
                                )
                            )
                        )
                    } catch let error as GatewayClientError {
                        return .flightFailure(error)
                    } catch {
                        return .flightFailure(.transportFailure)
                    }
                }
            }
            group.addTask {
                do {
                    return .hotels(
                        try await service.searchHotels(
                            matching: HotelSearchCriteria(
                                destination: destination,
                                checkInDate: range.start,
                                checkOutDate: range.end,
                                adults: travelers,
                                rooms: max(
                                    Int(
                                        ceil(
                                            Double(travelers) / 2
                                        )
                                    ),
                                    1
                                ),
                                currencyCode: currency,
                                preferences:
                                    request.hotelPreferences
                            )
                        )
                    )
                } catch let error as GatewayClientError {
                    return .hotelFailure(error)
                } catch {
                    return .hotelFailure(.transportFailure)
                }
            }
            group.addTask {
                if strictMode {
                    do {
                        async let places = service.searchPlaces(
                            matching: PlaceSearchCriteria(
                                destination: destination,
                                categories:
                                    Self.placeCategories(for: request),
                                interests: request.interests,
                                dietaryRequirements:
                                    request.dietaryRequirements,
                                accessibilityRequirements:
                                    request.accessibilityRequirements,
                                radiusMeters: 15_000,
                                limit: 20
                            )
                        )
                        async let events = service.searchEvents(
                            matching: EventSearchCriteria(
                                destination: destination,
                                dateRange: range,
                                query: nil,
                                interests: request.interests,
                                limit: 10
                            )
                        )
                        let values = try await (places, events)
                        return .experiences(
                            values.0,
                            values.1,
                            nil
                        )
                    } catch let error as GatewayClientError {
                        return .experiences([], [], error)
                    } catch {
                        return .experiences(
                            [],
                            [],
                            .transportFailure
                        )
                    }
                }
                async let places = try? service.searchPlaces(
                    matching: PlaceSearchCriteria(
                        destination: destination,
                        categories: Self.placeCategories(for: request),
                        interests: request.interests,
                        dietaryRequirements:
                            request.dietaryRequirements,
                        accessibilityRequirements:
                            request.accessibilityRequirements,
                        radiusMeters: 15_000,
                        limit: 20
                    )
                )
                async let events = try? service.searchEvents(
                    matching: EventSearchCriteria(
                        destination: destination,
                        dateRange: range,
                        query: nil,
                        interests: request.interests,
                        limit: 10
                    )
                )
                let values = await (places, events)
                return .experiences(
                    values.0 ?? [],
                    values.1 ?? [],
                    values.0 == nil && values.1 == nil
                        ? .transportFailure
                        : nil
                )
            }
            if canSearchWeather {
                group.addTask {
                    do {
                        return .weather(
                            try await service.weather(
                                matching: WeatherSearchCriteria(
                                    location: destination,
                                    dateRange: range,
                                    includeAlerts: true
                                )
                            )
                        )
                    } catch let error as GatewayClientError {
                        return .weatherFailure(error)
                    } catch {
                        return .weatherFailure(.transportFailure)
                    }
                }
            }

            for await output in group {
                if Task.isCancelled { break }
                switch output {
                case .flights(let offers):
                    results.flightOffers = offers
                    try? session.completeWorkstream(
                        .flights,
                        resultCount: offers.count,
                        providers: [.serpApi],
                        message: offers.isEmpty
                            ? "No matching fares found"
                            : "Live fares received"
                    )
                case .flightFailure(let error):
                    strictProviderError =
                        strictProviderError ?? error
                    unavailableProviders.insert(.serpApi)
                    try? session.markWorkstreamUnavailable(
                        .flights,
                        providers: [.serpApi],
                        message: "Flight search is unavailable"
                    )
                case .hotels(let offers):
                    results.hotelOffers = offers
                    try? session.completeWorkstream(
                        .stay,
                        resultCount: offers.count,
                        providers: [.serpApi],
                        message: offers.isEmpty
                            ? "No matching stays found"
                            : "Live stays received"
                    )
                case .hotelFailure(let error):
                    strictProviderError =
                        strictProviderError ?? error
                    unavailableProviders.insert(.serpApi)
                    try? session.markWorkstreamUnavailable(
                        .stay,
                        providers: [.serpApi],
                        message: "Hotel search is unavailable"
                    )
                case .experiences(
                    let places,
                    let events,
                    let failure
                ):
                    results.places = places
                    results.events = events
                    if let failure {
                        strictProviderError =
                            strictProviderError ?? failure
                        unavailableProviders.formUnion(
                            [.geoapify, .serpApi]
                        )
                        try? session.markWorkstreamUnavailable(
                            .experiences,
                            providers: [.geoapify, .serpApi],
                            message:
                                "Place and event search is unavailable"
                        )
                    } else {
                        let providers = Set(
                            places.map { $0.provenance.provider }
                            + events.map { $0.provenance.provider }
                        )
                        try? session.completeWorkstream(
                            .experiences,
                            resultCount:
                                places.count + events.count,
                            providers: providers,
                            message:
                                places.isEmpty && events.isEmpty
                                ? "No matching experiences found"
                                : "Places and events received"
                        )
                    }
                case .weather(let snapshots):
                    results.weather = snapshots
                    try? session.completeWorkstream(
                        .weather,
                        resultCount: snapshots.count,
                        providers: [.weatherAPI],
                        message: snapshots.isEmpty
                            ? "Forecast is outside the live window"
                            : "Forecast and alerts received"
                    )
                case .weatherFailure(let error):
                    strictProviderError =
                        strictProviderError ?? error
                    unavailableProviders.insert(.weatherAPI)
                    try? session.markWorkstreamUnavailable(
                        .weather,
                        providers: [.weatherAPI],
                        message: "Weather is unavailable"
                    )
                }
                previewTrip = TransientTripAssembler.baseTrip(
                    request: request,
                    results: results
                )
            }
        }
        if strictMode, let strictProviderError {
            throw strictProviderError
        }
    }

    private func routes(
        for trip: Trip?,
        service: any TripPlanningServing,
        session: TripPlanningSession,
        currencyCode: String
    ) async throws -> [TransportationLeg] {
        guard let trip else { return [] }
        let pairs = trip.itinerary.days.flatMap { day in
            Array(
                zip(
                    day.chronologicallySortedItems,
                    day.chronologicallySortedItems.dropFirst()
                )
            )
        }.prefix(8)
        guard !pairs.isEmpty else {
            try session.completeWorkstream(
                .routes,
                resultCount: 0,
                message: "No routes are needed yet"
            )
            return []
        }
        try session.beginWorkstream(
            .routes,
            providers: [.geoapify],
            message: "Connecting itinerary locations"
        )
        var collected: [TransportationLeg] = []
        for (item, next) in pairs {
            try Task.checkCancellation()
            guard
                let origin = item.location,
                let destination = next.location,
                origin.coordinate != nil,
                destination.coordinate != nil
            else {
                continue
            }
            do {
                let planned = try await service.planRoutes(
                    matching: RoutePlanningCriteria(
                        origin: origin,
                        destination: destination,
                        modes: [.walking, .transit],
                        departure: item.end,
                        currencyCode: currencyCode
                    )
                )
                collected += planned
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as GatewayClientError
            where error == .cancelled {
                throw error
            } catch {
                if strictProviderFailures {
                    throw error
                }
            }
        }
        if collected.isEmpty {
            if strictProviderFailures {
                throw GatewayClientError.providerUnavailable(
                    code: "route_search_empty",
                    message:
                        "Route search returned no sourced routes."
                )
            }
            unavailableProviders.insert(.geoapify)
            try? session.markWorkstreamUnavailable(
                .routes,
                providers: [.geoapify],
                message: "No sourced routes were available"
            )
        } else {
            try session.completeWorkstream(
                .routes,
                resultCount: collected.count,
                providers: [.geoapify],
                message: "Transportation routes received"
            )
        }
        return collected
    }

    private func publishStrictFailure(
        code: String,
        message: String,
        session: TripPlanningSession
    ) {
        state = .failed
        fallbackReason = .serviceFailure
        lastErrorMessage = message
        try? session.fail(
            code: code,
            userMessage: message,
            isRecoverable: true
        )
        planningTask = nil
    }

    private func strictFailureDescription(
        for error: Error
    ) -> (code: String, message: String) {
        guard let error = error as? GatewayClientError else {
            return (
                "live_planning_failed",
                "Strict local testing: live planning failed."
            )
        }
        switch error {
        case .providerUnavailable(let code, let message):
            return (
                code,
                "Strict local testing: \(message)"
            )
        case .timedOut:
            return (
                "provider_timeout",
                "Strict local testing: a provider timed out."
            )
        case .rateLimited:
            return (
                "provider_rate_limited",
                "Strict local testing: a provider rate limit was reached."
            )
        case .unauthorized, .forbidden:
            return (
                "gateway_authorization_failed",
                "Strict local testing: gateway authorization failed."
            )
        case .invalidBaseURL:
            return (
                "invalid_gateway_url",
                "Strict local testing: the gateway URL is invalid."
            )
        case .decodingFailed, .invalidResponse:
            return (
                "invalid_provider_response",
                "Strict local testing: a provider response was invalid."
            )
        case .encodingFailed:
            return (
                "invalid_provider_request",
                "Strict local testing: a provider request was invalid."
            )
        case .serverFailure, .transportFailure:
            return (
                "provider_transport_failed",
                "Strict local testing: a provider could not be reached."
            )
        case .cancelled:
            return (
                "provider_cancelled",
                "Strict local testing: provider work was cancelled."
            )
        }
    }

    private func markAllProvidersUnavailable(
        request: TripRequest,
        session: TripPlanningSession,
        reason: TripPlanningFallbackReason
    ) async {
        do {
            try session.beginSearch()
            for workstream in [
                PlanningWorkstream.flights,
                .stay,
                .experiences,
                .weather,
                .routes
            ] {
                try? session.markWorkstreamUnavailable(
                    workstream,
                    message:
                        reason == .offline
                        ? "Reconnect to load live results"
                        : "Connect the local gateway to load live results"
                )
            }
            unavailableProviders = [
                .serpApi,
                .geoapify,
                .weatherAPI
            ]
            state = .partiallyAvailable
            fallbackReason = reason
            lastErrorMessage =
                reason == .offline
                ? "You appear to be offline. "
                    + "Your request remains in memory."
                : "Live travel services are not connected. "
                    + "Your request remains in memory."
            try session.markPartiallyAvailable(
                unavailableProviders: unavailableProviders
            )
            previewTrip = TransientTripAssembler.baseTrip(
                request: request
            )
        } catch {
            state = .failed
            fallbackReason = .serviceFailure
            lastErrorMessage =
                "Planning could not start. Your request remains in memory."
        }
        planningTask = nil
    }

    private static func placeCategories(
        for request: TripRequest
    ) -> Set<PlaceCategory> {
        var categories: Set<PlaceCategory> = [
            .restaurant,
            .attraction,
            .museum,
            .park
        ]
        if request.interests.contains(.food) {
            categories.formUnion([.restaurant, .cafe])
        }
        if request.interests.contains(.nightlife) {
            categories.insert(.nightlife)
        }
        if request.interests.contains(.shopping) {
            categories.insert(.shopping)
        }
        if request.interests.contains(.sports) {
            categories.insert(.sports)
        }
        return categories
    }
}

enum PlanTranslationLanguage:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            "English"
        case .spanish:
            "Spanish"
        case .french:
            "French"
        case .german:
            "German"
        case .italian:
            "Italian"
        case .japanese:
            "Japanese"
        }
    }
}

@MainActor
@Observable
final class PlanTranslationCoordinator {
    private(set) var targetLanguage: PlanTranslationLanguage
    private(set) var failureMessage: String?

    var isAvailable: Bool {
        service != nil
    }

    @ObservationIgnored
    private let service: (any TranslationProviding)?
    @ObservationIgnored
    private var cache:
        [PlanTranslationCacheKey: TranslatedText] = [:]
    @ObservationIgnored
    private var activeRequests: Set<PlanTranslationCacheKey> = []

    private static let preferenceKey =
        "gia.plan.translationLanguage"

    init(service: (any TranslationProviding)?) {
        self.service = service
        let stored = UserDefaults.standard.string(
            forKey: Self.preferenceKey
        )
        targetLanguage =
            stored.flatMap(PlanTranslationLanguage.init(rawValue:))
            ?? .english
    }

    func select(_ language: PlanTranslationLanguage) {
        targetLanguage = language
        failureMessage = nil
        UserDefaults.standard.set(
            language.rawValue,
            forKey: Self.preferenceKey
        )
    }

    func translation(
        for originalText: String,
        contentKind: TranslationContentKind,
        protectedTerms: [String]
    ) async -> TranslatedText? {
        let trimmed = originalText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard
            targetLanguage != .english,
            !trimmed.isEmpty,
            let service
        else {
            return nil
        }

        let terms = Array(
            Set(
                protectedTerms
                    .map {
                        $0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }
                    .filter { !$0.isEmpty }
            )
        ).sorted()
        let key = PlanTranslationCacheKey(
            text: trimmed,
            targetLanguageCode: targetLanguage.rawValue,
            contentKind: contentKind.rawValue,
            protectedTerms: terms
        )
        if let cached = cache[key] {
            return cached
        }
        guard !activeRequests.contains(key) else {
            return nil
        }

        activeRequests.insert(key)
        defer {
            activeRequests.remove(key)
        }

        do {
            let translated = try await service.translate(
                matching: TranslationCriteria(
                    text: trimmed,
                    sourceLanguageCode: nil,
                    targetLanguageCode: targetLanguage.rawValue,
                    contentKind: contentKind,
                    protectedTerms: terms
                )
            )
            guard
                translated.originalText == trimmed,
                translated.targetLanguageCode.lowercased()
                    == targetLanguage.rawValue,
                !translated.translatedText
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
            else {
                failureMessage =
                    "Translation returned an invalid response."
                return nil
            }

            cache[key] = translated
            failureMessage = nil
            return translated
        } catch is CancellationError {
            return nil
        } catch let error as GatewayClientError
        where error == .cancelled {
            return nil
        } catch {
            failureMessage =
                "Translation is unavailable. Original text is shown."
            return nil
        }
    }
}

private struct PlanTranslationCacheKey: Hashable, Sendable {
    var text: String
    var targetLanguageCode: String
    var contentKind: String
    var protectedTerms: [String]
}

private extension TransientPlanningResults {
    var hasPlanningSources: Bool {
        !flightOffers.isEmpty
            || !hotelOffers.isEmpty
            || !places.isEmpty
            || !events.isEmpty
            || !weather.isEmpty
    }
}

private enum ProviderOutput: Sendable {
    case flights([FlightOffer])
    case flightFailure(GatewayClientError)
    case hotels([HotelOffer])
    case hotelFailure(GatewayClientError)
    case experiences(
        [PlaceRecommendation],
        [TimedEvent],
        GatewayClientError?
    )
    case weather([WeatherSnapshot])
    case weatherFailure(GatewayClientError)
}
