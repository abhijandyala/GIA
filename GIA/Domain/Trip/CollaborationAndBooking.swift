import Foundation

enum DecisionRule: String, Codable, CaseIterable, Sendable {
    case organizer
    case majority
    case unanimous
}

enum DecisionState: String, Codable, CaseIterable, Sendable {
    case proposed
    case voting
    case approved
    case rejected
    case tied
    case needsRevision
}

enum VoteChoice: String, Codable, CaseIterable, Sendable {
    case approve
    case reject
    case abstain
}

enum DecisionSubject: Codable, Hashable, Sendable {
    case destination(UUID)
    case dateRange
    case flightOffer(UUID)
    case hotelOffer(UUID)
    case place(UUID)
    case itineraryItem(UUID)
    case budget
}

struct TripVote: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var travelerID: UUID
    var choice: VoteChoice
    var comment: String?
    var submittedAt: Date

    init(
        id: UUID = UUID(),
        travelerID: UUID,
        choice: VoteChoice,
        comment: String? = nil,
        submittedAt: Date = Date()
    ) {
        self.id = id
        self.travelerID = travelerID
        self.choice = choice
        self.comment = comment
        self.submittedAt = submittedAt
    }
}

struct GroupDecision: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var subject: DecisionSubject
    var rule: DecisionRule
    var state: DecisionState
    var votes: [TripVote]
    var proposedByTravelerID: UUID
    var proposedAt: Date
    var resolvedAt: Date?
    var eligibleTravelerIDs: Set<UUID>?
    var supersedesDecisionID: UUID?
    var revisionNumber: Int?

    init(
        id: UUID = UUID(),
        title: String,
        subject: DecisionSubject,
        rule: DecisionRule,
        state: DecisionState = .proposed,
        votes: [TripVote] = [],
        proposedByTravelerID: UUID,
        proposedAt: Date = Date(),
        resolvedAt: Date? = nil,
        eligibleTravelerIDs: Set<UUID>? = nil,
        supersedesDecisionID: UUID? = nil,
        revisionNumber: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.rule = rule
        self.state = state
        self.votes = votes
        self.proposedByTravelerID = proposedByTravelerID
        self.proposedAt = proposedAt
        self.resolvedAt = resolvedAt
        self.eligibleTravelerIDs = eligibleTravelerIDs
        self.supersedesDecisionID = supersedesDecisionID
        self.revisionNumber = revisionNumber
    }
}

enum BudgetCategory: String, Codable, CaseIterable, Sendable {
    case activities
    case emergencyReserve
    case flights
    case food
    case lodging
    case transportation
    case uncategorized
}

struct BudgetAllocation: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var category: BudgetCategory
    var limit: Money
    var estimatedSpend: Money
    var confirmedSpend: Money

    init(
        id: UUID = UUID(),
        category: BudgetCategory,
        limit: Money,
        estimatedSpend: Money,
        confirmedSpend: Money
    ) {
        self.id = id
        self.category = category
        self.limit = limit
        self.estimatedSpend = estimatedSpend
        self.confirmedSpend = confirmedSpend
    }
}

struct TripBudget: Codable, Hashable, Sendable {
    var totalLimit: Money?
    var allocations: [BudgetAllocation]
    var currencyConversionRates: [CurrencyConversionRate]

    init(
        totalLimit: Money? = nil,
        allocations: [BudgetAllocation] = [],
        currencyConversionRates: [CurrencyConversionRate] = []
    ) {
        self.totalLimit = totalLimit
        self.allocations = allocations
        self.currencyConversionRates = currencyConversionRates
    }

    private enum CodingKeys: String, CodingKey {
        case totalLimit
        case allocations
        case currencyConversionRates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        totalLimit = try container.decodeIfPresent(
            Money.self,
            forKey: .totalLimit
        )
        allocations = try container.decodeIfPresent(
            [BudgetAllocation].self,
            forKey: .allocations
        ) ?? []
        currencyConversionRates = try container.decodeIfPresent(
            [CurrencyConversionRate].self,
            forKey: .currencyConversionRates
        ) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )
        try container.encodeIfPresent(
            totalLimit,
            forKey: .totalLimit
        )
        try container.encode(allocations, forKey: .allocations)
        try container.encode(
            currencyConversionRates,
            forKey: .currencyConversionRates
        )
    }
}

enum BookingCategory: String, Codable, CaseIterable, Sendable {
    case activity
    case flight
    case hotel
    case restaurant
    case transportation
}

enum BookingMode: String, Codable, CaseIterable, Sendable {
    case demo
    case externalCheckout
    case providerConfirmed
}

enum BookingStatus: String, Codable, CaseIterable, Sendable {
    case suggested
    case selected
    case demoConfirmed
    case externalCheckoutRequired
    case processing
    case confirmed
    case modificationRequested
    case cancelled
    case failed
}

enum BookingConfirmationMode: String, Codable, Sendable {
    case fblaDemo
    case externalProvider
}

struct BookingRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var category: BookingCategory
    var mode: BookingMode
    var status: BookingStatus
    var itemIdentifier: UUID
    var providerName: String
    var providerConfirmationCode: String?
    var amount: Money?
    var checkoutURL: URL?
    var receiptURL: URL?
    var createdAt: Date
    var updatedAt: Date
    var provenance: DataProvenance

    init(
        id: UUID = UUID(),
        category: BookingCategory,
        mode: BookingMode,
        status: BookingStatus,
        itemIdentifier: UUID,
        providerName: String,
        providerConfirmationCode: String? = nil,
        amount: Money? = nil,
        checkoutURL: URL? = nil,
        receiptURL: URL? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        provenance: DataProvenance
    ) {
        self.id = id
        self.category = category
        self.mode = mode
        self.status = status
        self.itemIdentifier = itemIdentifier
        self.providerName = providerName
        self.providerConfirmationCode =
            providerConfirmationCode
        self.amount = amount
        self.checkoutURL = checkoutURL
        self.receiptURL = receiptURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.provenance = provenance
    }
}
