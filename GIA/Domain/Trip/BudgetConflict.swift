import Foundation

struct CurrencyConversionRate:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: UUID
    var sourceCurrencyCode: String
    var destinationCurrencyCode: String
    var rate: Decimal
    var retrievedAt: Date
    var expiresAt: Date?
    var provenance: DataProvenance

    init(
        id: UUID = UUID(),
        sourceCurrencyCode: String,
        destinationCurrencyCode: String,
        rate: Decimal,
        retrievedAt: Date,
        expiresAt: Date? = nil,
        provenance: DataProvenance
    ) {
        self.id = id
        self.sourceCurrencyCode =
            sourceCurrencyCode.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).uppercased()
        self.destinationCurrencyCode =
            destinationCurrencyCode.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).uppercased()
        self.rate = rate
        self.retrievedAt = retrievedAt
        self.expiresAt = expiresAt
        self.provenance = provenance
    }
}

struct TripBudgetCategorySummary:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    var id: BudgetCategory { category }
    var category: BudgetCategory
    var limit: Money?
    var estimatedSpend: Money
    var confirmedSpend: Money
    var unknownCostCount: Int
    var conversionTimestamps: [Date]

    var plannedSpend: Money {
        Money(
            amount: estimatedSpend.amount + confirmedSpend.amount,
            currencyCode: estimatedSpend.currencyCode
        )
    }

    var remaining: Money? {
        guard let limit else { return nil }
        return Money(
            amount: limit.amount - plannedSpend.amount,
            currencyCode: limit.currencyCode
        )
    }

    var isOverLimit: Bool {
        guard let remaining else { return false }
        return remaining.amount < 0
    }
}

struct TripBudgetSummary: Codable, Hashable, Sendable {
    var currencyCode: String
    var totalLimit: Money?
    var estimatedSpend: Money
    var confirmedSpend: Money
    var emergencyReserve: Money
    var remainingAfterReserve: Money?
    var categories: [TripBudgetCategorySummary]
    var unconvertedCurrencyCodes: Set<String>
    var unknownCostCount: Int
    var conversionTimestamps: [Date]

    var plannedSpend: Money {
        Money(
            amount:
                estimatedSpend.amount
                + confirmedSpend.amount
                + emergencyReserve.amount,
            currencyCode: currencyCode
        )
    }

    var isOverLimit: Bool {
        guard let remainingAfterReserve else { return false }
        return remainingAfterReserve.amount < 0
    }
}

enum TripConflictKind: String, Codable, CaseIterable, Sendable {
    case accessibility
    case budgetCategoryOverflow
    case budgetOverflow
    case closedVenue
    case currencyConversionMissing
    case dietary
    case duplicateActivity
    case excessiveDailyTravel
    case insufficientTravelTime
    case missingReservation
    case timeOverlap
    case weather
}

enum TripConflictSeverity: Int, Codable, CaseIterable, Sendable {
    case advisory = 0
    case warning = 1
    case critical = 2
}

struct TripConflict: Codable, Hashable, Identifiable, Sendable {
    let id: String
    var kind: TripConflictKind
    var severity: TripConflictSeverity
    var title: String
    var explanation: String
    var recommendation: String
    var relatedItemIDs: [UUID]
    var dayID: UUID?

    init(
        id: String,
        kind: TripConflictKind,
        severity: TripConflictSeverity,
        title: String,
        explanation: String,
        recommendation: String,
        relatedItemIDs: [UUID] = [],
        dayID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.title = title
        self.explanation = explanation
        self.recommendation = recommendation
        self.relatedItemIDs = relatedItemIDs
        self.dayID = dayID
    }
}

struct TripBudgetConflictAnalysis:
    Codable,
    Hashable,
    Sendable
{
    var budget: TripBudgetSummary
    var conflicts: [TripConflict]
    var analyzedAt: Date

    var criticalCount: Int {
        conflicts.count { $0.severity == .critical }
    }

    var warningCount: Int {
        conflicts.count { $0.severity == .warning }
    }
}
