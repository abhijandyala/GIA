import Foundation

enum PlanModuleKind: String, CaseIterable, Identifiable {
    case flights
    case stay
    case experiences
    case routes
    case weather

    var id: Self { self }

    var title: String {
        switch self {
        case .flights:
            "Flights"
        case .stay:
            "Stay"
        case .experiences:
            "Experiences"
        case .routes:
            "Routes"
        case .weather:
            "Weather"
        }
    }

    var symbolName: String {
        switch self {
        case .flights:
            "airplane"
        case .stay:
            "bed.double.fill"
        case .experiences:
            "sparkles"
        case .routes:
            "location.north.line.fill"
        case .weather:
            "cloud.sun.fill"
        }
    }
}

enum PlanModuleStatus: Equatable {
    case queued
    case active(String)
    case ready(String)
    case unavailable
    case cancelled

    var label: String {
        switch self {
        case .queued:
            "Queued"
        case .active(let label), .ready(let label):
            label
        case .unavailable:
            "Unavailable"
        case .cancelled:
            "Cancelled"
        }
    }

    var isActive: Bool {
        if case .active = self {
            return true
        }
        return false
    }

    var isReady: Bool {
        if case .ready = self {
            return true
        }
        return false
    }
}

struct PlanContextMetric: Identifiable {
    enum Kind: String, Identifiable {
        case destination
        case dates
        case travelers
        case budget

        var id: Self { self }
    }

    let kind: Kind
    let title: String
    let value: String
    let isResolved: Bool

    var id: Kind { kind }
}

struct PlanClarificationPrompt: Identifiable {
    let field: TripClarificationField
    let title: String
    let question: String
    let severity: RequestValidationSeverity
    let editableMetric: PlanContextMetric.Kind?

    var id: String {
        "\(field.rawValue):\(severity.rawValue)"
    }
}

enum PlanClarificationBuilder {
    static func prompts(
        for request: TripRequest,
        now: Date = Date()
    ) -> [PlanClarificationPrompt] {
        TripRequestInterpreter.validate(request, now: now).map {
            issue in
            PlanClarificationPrompt(
                field: issue.field,
                title: title(for: issue.field),
                question: issue.message,
                severity: issue.severity,
                editableMetric: metric(for: issue.field)
            )
        }
    }

    private static func title(
        for field: TripClarificationField
    ) -> String {
        switch field {
        case .destination:
            "Destination"
        case .dates:
            "Travel dates"
        case .travelers:
            "Travelers"
        case .budget:
            "Trip budget"
        case .origin:
            "Origin"
        case .preferences:
            "Preferences"
        case .dietaryRequirements:
            "Dietary needs"
        case .accessibility:
            "Accessibility"
        }
    }

    private static func metric(
        for field: TripClarificationField
    ) -> PlanContextMetric.Kind? {
        switch field {
        case .destination:
            .destination
        case .dates:
            .dates
        case .travelers:
            .travelers
        case .budget:
            .budget
        case
            .origin,
            .preferences,
            .dietaryRequirements,
            .accessibility:
            nil
        }
    }
}

enum PlanJumpAnchor: String, CaseIterable, Identifiable {
    case days = "itinerary-timeline"
    case flights = "flight-comparison"
    case stay = "hotel-comparison"
    case budget = "budget-conflict"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days:
            "Days"
        case .flights:
            "Flights"
        case .stay:
            "Stay"
        case .budget:
            "Budget"
        }
    }
}

enum PlanPhasePresentation {
    static func title(for phase: TripPlanningPhase) -> String {
        switch phase {
        case .validating:
            "Understanding your trip"
        case .needsClarification:
            "One more detail"
        case .searching:
            "Finding travel options"
        case .comparing:
            "Comparing options"
        case .buildingItinerary:
            "Building your days"
        case .presenting:
            "Putting the plan together"
        case .partiallyAvailable:
            "Some results are missing"
        case .ready:
            "Your plan"
        case .failed:
            "Planning paused"
        case .cancelled:
            "Request cancelled"
        default:
            "Listening"
        }
    }

    static func workspaceStatus(
        phase: TripPlanningPhase,
        orchestration: TripOrchestrationState,
        failureMessage: String?
    ) -> String? {
        switch orchestration {
        case .resolvingLocation:
            return "Finding the destination"
        case .searching:
            return "Finding travel options"
        case .assembling:
            return "Building your days"
        case .partiallyAvailable:
            return "Some results are missing"
        case .failed:
            return failureMessage ?? "Planning paused"
        case .ready, .idle, .cancelled:
            break
        }

        switch phase {
        case .ready, .cancelled, .idle:
            return nil
        case .failed:
            return failureMessage ?? title(for: phase)
        default:
            return title(for: phase)
        }
    }

    static func detail(for phase: TripPlanningPhase) -> String {
        switch phase {
        case .validating:
            "Checking destinations, dates, travelers, and budget"
        case .needsClarification:
            "Waiting for a missing trip detail"
        case .searching:
            "Finding live travel options"
        case .comparing:
            "Balancing time, quality, and cost"
        case .buildingItinerary:
            "Connecting every part of the trip"
        case .presenting:
            "Assembling the shared itinerary"
        case .partiallyAvailable:
            "Some providers are temporarily unavailable"
        case .ready:
            "Your shared plan is ready"
        case .failed:
            "The request can be retried"
        case .cancelled:
            "No changes were made"
        default:
            "Capturing your travel request"
        }
    }

    static func isActive(_ phase: TripPlanningPhase) -> Bool {
        switch phase {
        case .ready, .failed, .cancelled, .idle:
            false
        default:
            true
        }
    }
}

enum PlanPresentationBuilder {
    static func contextMetrics(
        for request: TripRequest
    ) -> [PlanContextMetric] {
        [
            PlanContextMetric(
                kind: .destination,
                title: "Destination",
                value:
                    request.destinations.first?.name
                    ?? "Resolving",
                isResolved: !request.destinations.isEmpty
            ),
            PlanContextMetric(
                kind: .dates,
                title: "Dates",
                value: formattedDates(
                    request.dateRange,
                    durationDays: request.durationDays
                ),
                isResolved: request.dateRange != nil
            ),
            PlanContextMetric(
                kind: .travelers,
                title: "Travelers",
                value: formattedTravelers(request.travelerCount),
                isResolved: request.travelerCount != nil
            ),
            PlanContextMetric(
                kind: .budget,
                title: "Budget",
                value: formattedBudget(request.totalBudget),
                isResolved: true
            )
        ]
    }

    static func moduleStatus(
        for kind: PlanModuleKind,
        progress: TripPlanningProgress,
        trip: Trip?
    ) -> PlanModuleStatus {
        if hasResult(for: kind, trip: trip) {
            return .ready("Ready")
        }

        let item = progress.item(for: kind.workstream)
        switch item.status {
        case .queued, .waitingForInput:
            return .queued
        case .active:
            return .active(item.statusMessage ?? "Active")
        case .complete:
            if let count = item.resultCount {
                return .ready(
                    count == 1 ? "1 found" : "\(count) found"
                )
            }
            return .ready("Ready")
        case .unavailable:
            return .unavailable
        case .cancelled:
            return .cancelled
        }
    }

    private static func hasResult(
        for kind: PlanModuleKind,
        trip: Trip?
    ) -> Bool {
        guard let trip else { return false }

        return switch kind {
        case .flights:
            !trip.catalog.flightOffers.isEmpty
        case .stay:
            !trip.catalog.hotelOffers.isEmpty
        case .experiences:
            !trip.catalog.places.isEmpty
                || !trip.catalog.timedEvents.isEmpty
        case .routes:
            !trip.itinerary.transportationLegs.isEmpty
        case .weather:
            !trip.catalog.weatherSnapshots.isEmpty
        }
    }

    private static func formattedDates(
        _ range: TripDateRange?,
        durationDays: Int?
    ) -> String {
        guard let range else {
            if let durationDays {
                return "\(durationDays) days. Choose dates"
            }
            return "Resolving"
        }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = range.timeZone ?? .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        let start = formatter.string(from: range.start)
        let end = formatter.string(from: range.end)
        return "\(start) to \(end)"
    }

    private static func formattedTravelers(
        _ count: Int?
    ) -> String {
        guard let count else { return "Resolving" }
        return count == 1 ? "1 person" : "\(count) people"
    }

    private static func formattedBudget(_ budget: Money?) -> String {
        guard let budget else { return "No limit set" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = budget.currencyCode
        formatter.maximumFractionDigits = 0

        return formatter.string(
            from: budget.amount as NSDecimalNumber
        ) ?? "\(budget.amount) \(budget.currencyCode)"
    }
}

private extension PlanModuleKind {
    var workstream: PlanningWorkstream {
        switch self {
        case .flights:
            .flights
        case .stay:
            .stay
        case .experiences:
            .experiences
        case .routes:
            .routes
        case .weather:
            .weather
        }
    }
}
