import Foundation

enum PlanningWorkstream: String, Codable, CaseIterable, Identifiable, Sendable {
    case understanding
    case destination
    case flights
    case stay
    case experiences
    case weather
    case routes
    case schedule
    case budget

    var id: Self { self }
}

enum PlanningWorkStatus: String, Codable, Sendable {
    case queued
    case waitingForInput
    case active
    case complete
    case unavailable
    case cancelled
}

struct PlanningWorkItem: Codable, Hashable, Identifiable, Sendable {
    var workstream: PlanningWorkstream
    var status: PlanningWorkStatus
    var resultCount: Int?
    var providers: Set<TravelProvider>
    var statusMessage: String?
    var startedAt: Date?
    var completedAt: Date?

    var id: PlanningWorkstream { workstream }
}

struct TripPlanningProgress: Codable, Hashable, Sendable {
    private(set) var items: [PlanningWorkItem]
    private(set) var startedAt: Date?
    private(set) var updatedAt: Date?

    init() {
        items = PlanningWorkstream.allCases.map {
            PlanningWorkItem(
                workstream: $0,
                status: .queued,
                resultCount: nil,
                providers: [],
                statusMessage: nil,
                startedAt: nil,
                completedAt: nil
            )
        }
    }

    func item(for workstream: PlanningWorkstream)
        -> PlanningWorkItem
    {
        items.first { $0.workstream == workstream }
            ?? PlanningWorkItem(
                workstream: workstream,
                status: .queued,
                resultCount: nil,
                providers: [],
                statusMessage: nil,
                startedAt: nil,
                completedAt: nil
            )
    }

    var activeItem: PlanningWorkItem? {
        items.first { $0.status == .active }
    }

    var completedCount: Int {
        items.filter { $0.status == .complete }.count
    }

    var hasStartedProviderWork: Bool {
        items.contains {
            $0.workstream.isProviderWork
                && $0.status != .queued
        }
    }

    mutating func begin(
        _ workstream: PlanningWorkstream,
        providers: Set<TravelProvider> = [],
        message: String? = nil,
        at date: Date = Date()
    ) {
        update(workstream) { item in
            item.status = .active
            item.resultCount = nil
            item.providers = providers
            item.statusMessage = message
            item.startedAt = item.startedAt ?? date
            item.completedAt = nil
        }
        startedAt = startedAt ?? date
        updatedAt = date
    }

    mutating func waitForInput(
        _ workstream: PlanningWorkstream,
        message: String?,
        at date: Date = Date()
    ) {
        update(workstream) { item in
            item.status = .waitingForInput
            item.statusMessage = message
            item.completedAt = nil
        }
        startedAt = startedAt ?? date
        updatedAt = date
    }

    mutating func complete(
        _ workstream: PlanningWorkstream,
        resultCount: Int? = nil,
        providers: Set<TravelProvider> = [],
        message: String? = nil,
        at date: Date = Date()
    ) {
        update(workstream) { item in
            item.status = .complete
            item.resultCount = resultCount
            item.providers.formUnion(providers)
            item.statusMessage = message
            item.startedAt = item.startedAt ?? date
            item.completedAt = date
        }
        startedAt = startedAt ?? date
        updatedAt = date
    }

    mutating func markUnavailable(
        _ workstream: PlanningWorkstream,
        providers: Set<TravelProvider> = [],
        message: String?,
        at date: Date = Date()
    ) {
        update(workstream) { item in
            item.status = .unavailable
            item.resultCount = nil
            item.providers.formUnion(providers)
            item.statusMessage = message
            item.startedAt = item.startedAt ?? date
            item.completedAt = date
        }
        startedAt = startedAt ?? date
        updatedAt = date
    }

    mutating func cancelOpenWork(at date: Date = Date()) {
        for index in items.indices
        where
            items[index].status == .queued
            || items[index].status == .active
            || items[index].status == .waitingForInput
        {
            items[index].status = .cancelled
            items[index].completedAt = date
        }
        updatedAt = date
    }

    private mutating func update(
        _ workstream: PlanningWorkstream,
        mutation: (inout PlanningWorkItem) -> Void
    ) {
        guard
            let index = items.firstIndex(
                where: { $0.workstream == workstream }
            )
        else {
            return
        }
        mutation(&items[index])
    }
}

extension PlanningWorkstream {
    var isProviderWork: Bool {
        switch self {
        case .flights, .stay, .experiences, .weather, .routes:
            true
        case .understanding, .destination, .schedule, .budget:
            false
        }
    }
}

enum TripPlanningProgressError: Error, Equatable {
    case invalidPhase(
        phase: TripPlanningPhase,
        workstream: PlanningWorkstream
    )
    case invalidResultCount(Int)
}
