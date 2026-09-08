import SwiftUI

struct BudgetConflictSection: View {
    let analysis: TripBudgetConflictAnalysis

    private var budget: TripBudgetSummary {
        analysis.budget
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader
            budgetOverview
            categoryLedger
            conflictLedger
            evidenceFooter
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BUDGET / CONFLICT CORE")
                    .font(.caption2.weight(.semibold))
                    .tracking(2.1)
                    .foregroundStyle(
                        GIAColor.primaryText.opacity(0.48)
                    )

                Text("Deterministic trip analysis")
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
            }

            Spacer()

            Label(
                analysis.conflicts.isEmpty
                    ? "CLEAR"
                    : "\(analysis.conflicts.count) FLAGS",
                systemImage:
                    analysis.conflicts.isEmpty
                    ? "checkmark.circle"
                    : "exclamationmark.triangle"
            )
            .font(.system(size: 9, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(
                analysis.conflicts.isEmpty
                    ? GIAColor.confirmedAccent
                    : GIAColor.warningAccent
            )
        }
    }

    private var budgetOverview: some View {
        HStack(spacing: 20) {
            budgetRing

            VStack(alignment: .leading, spacing: 13) {
                metric(
                    label: "PLANNED",
                    value: money(budget.plannedSpend),
                    detail:
                        budget.confirmedSpend.amount > 0
                        ? "\(money(budget.confirmedSpend)) confirmed"
                        : "Sourced estimates"
                )

                metric(
                    label:
                        budget.isOverLimit
                        ? "OVER LIMIT"
                        : "AVAILABLE",
                    value: budget.remainingAfterReserve.map {
                        money(
                            Money(
                                amount: max($0.amount, 0),
                                currencyCode: $0.currencyCode
                            )
                        )
                    } ?? "No limit",
                    detail:
                        budget.emergencyReserve.amount > 0
                        ? "\(money(budget.emergencyReserve)) protected"
                        : "No reserve allocated"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .planSurface(cornerRadius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(budgetAccessibilitySummary)
    }

    private var budgetRing: some View {
        let progress = budgetProgress
        let ringColor =
            budget.isOverLimit
            ? GIAColor.warningAccent
            : GIAColor.intelligenceAccent

        return ZStack {
            Circle()
                .stroke(
                    GIAColor.primaryText.opacity(0.08),
                    lineWidth: 8
                )

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(
                        lineWidth: 8,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(0.32), radius: 8)

            VStack(spacing: 2) {
                Text(budgetPercentText)
                    .font(.title3.monospacedDigit().weight(.medium))
                    .foregroundStyle(GIAColor.primaryText)

                Text("ALLOCATED")
                    .font(.system(size: 7, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(GIAColor.secondaryText)
            }
        }
        .frame(width: 112, height: 112)
        .accessibilityHidden(true)
    }

    private var categoryLedger: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CATEGORY LEDGER")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(GIAColor.secondaryText)

                Spacer()

                if budget.unknownCostCount > 0 {
                    Text("\(budget.unknownCostCount) COSTS UNKNOWN")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.9)
                        .foregroundStyle(GIAColor.warningAccent)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            Divider()
                .overlay(GIAColor.subtleStroke)

            ForEach(Array(budget.categories.enumerated()), id: \.element.id) {
                index,
                category in
                BudgetCategoryRow(summary: category)

                if index < budget.categories.count - 1 {
                    Divider()
                        .overlay(GIAColor.subtleStroke)
                        .padding(.leading, 52)
                }
            }
        }
        .planSurface(cornerRadius: 22)
    }

    @ViewBuilder
    private var conflictLedger: some View {
        if analysis.conflicts.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(GIAColor.confirmedAccent)

                VStack(alignment: .leading, spacing: 3) {
                    Text("No deterministic conflicts")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)

                    Text(
                        "Current times, costs, routes, preferences, "
                        + "weather, and reservations pass known rules."
                    )
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
                }
            }
            .padding(18)
            .planSurface(cornerRadius: 20)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("CONFLICT LEDGER")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(GIAColor.secondaryText)

                    Spacer()

                    if analysis.criticalCount > 0 {
                        Text("\(analysis.criticalCount) CRITICAL")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.9)
                            .foregroundStyle(GIAColor.warningAccent)
                    }
                }

                ForEach(analysis.conflicts) {
                    TripConflictCard(conflict: $0)
                }
            }
        }
    }

    private var evidenceFooter: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(
                "Calculated locally — GPT does not set totals",
                systemImage: "function"
            )

            if let latest = budget.conversionTimestamps.last {
                let latestText = latest.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
                Label(
                    "Latest exchange rate \(latestText)",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
        }
        .font(.caption2)
        .foregroundStyle(GIAColor.secondaryText.opacity(0.78))
        .padding(.horizontal, 4)
    }

    private func metric(
        label: String,
        value: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(GIAColor.secondaryText)

            Text(value)
                .font(.title3.monospacedDigit().weight(.medium))
                .foregroundStyle(GIAColor.primaryText)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(GIAColor.secondaryText)
        }
    }

    private var budgetProgress: CGFloat {
        guard
            let limit = budget.totalLimit,
            limit.amount > 0
        else { return 0 }
        let value = NSDecimalNumber(
            decimal: budget.plannedSpend.amount / limit.amount
        ).doubleValue
        return CGFloat(min(max(value, 0), 1))
    }

    private var budgetPercentText: String {
        guard
            let limit = budget.totalLimit,
            limit.amount > 0
        else { return "—" }
        let ratio = NSDecimalNumber(
            decimal: budget.plannedSpend.amount / limit.amount
        ).doubleValue
        return "\(Int((ratio * 100).rounded()))%"
    }

    private var budgetAccessibilitySummary: String {
        var parts = [
            "Planned spend \(money(budget.plannedSpend))"
        ]
        if let remaining = budget.remainingAfterReserve {
            if remaining.amount < 0 {
                let overage = money(
                    Money(
                        amount: -remaining.amount,
                        currencyCode: remaining.currencyCode
                    )
                )
                parts.append("Over budget by \(overage)")
            } else {
                parts.append(
                    "\(money(remaining)) available after reserve"
                )
            }
        }
        return parts.joined(separator: ", ")
    }

    private func money(_ value: Money) -> String {
        BudgetConflictFormatting.money(value)
    }
}

private struct BudgetCategoryRow: View {
    let summary: TripBudgetCategorySummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(rowColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)

                    if summary.unknownCostCount > 0 {
                        Text("\(summary.unknownCostCount) unknown")
                            .font(.caption2)
                            .foregroundStyle(GIAColor.warningAccent)
                    }

                    Spacer()

                    Text(spendAndLimit)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(
                            summary.isOverLimit
                                ? GIAColor.warningAccent
                                : GIAColor.secondaryText
                        )
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(GIAColor.primaryText.opacity(0.07))

                        Capsule()
                            .fill(rowColor)
                            .frame(
                                width:
                                    geometry.size.width
                                    * progress
                            )
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch summary.category {
        case .activities:
            "Activities"
        case .emergencyReserve:
            "Emergency reserve"
        case .flights:
            "Flights"
        case .food:
            "Food"
        case .lodging:
            "Lodging"
        case .transportation:
            "Local transportation"
        case .uncategorized:
            "Uncategorized"
        }
    }

    private var iconName: String {
        switch summary.category {
        case .activities:
            "ticket"
        case .emergencyReserve:
            "shield"
        case .flights:
            "airplane"
        case .food:
            "fork.knife"
        case .lodging:
            "bed.double"
        case .transportation:
            "tram"
        case .uncategorized:
            "square.grid.2x2"
        }
    }

    private var spendAndLimit: String {
        let spend = BudgetConflictFormatting.money(
            summary.plannedSpend
        )
        guard let limit = summary.limit else {
            return "\(spend) / open"
        }
        return "\(spend) / \(BudgetConflictFormatting.money(limit))"
    }

    private var progress: CGFloat {
        guard
            let limit = summary.limit,
            limit.amount > 0
        else {
            return summary.plannedSpend.amount > 0 ? 1 : 0
        }
        let value = NSDecimalNumber(
            decimal: summary.plannedSpend.amount / limit.amount
        ).doubleValue
        return CGFloat(min(max(value, 0), 1))
    }

    private var rowColor: Color {
        if summary.isOverLimit {
            return GIAColor.warningAccent
        }
        if summary.category == .emergencyReserve {
            return GIAColor.confirmedAccent
        }
        return GIAColor.intelligenceAccent
    }
}

private struct TripConflictCard: View {
    let conflict: TripConflict

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conflict.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GIAColor.primaryText)

                    Spacer(minLength: 8)

                    Text(severityLabel)
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.9)
                        .foregroundStyle(accent)
                }

                Text(conflict.explanation)
                    .font(.caption)
                    .foregroundStyle(GIAColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Label(
                    conflict.recommendation,
                    systemImage: "arrow.turn.down.right"
                )
                .font(.caption2)
                .foregroundStyle(
                    GIAColor.primaryText.opacity(0.78)
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GIAColor.planSurface.opacity(0.94))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.24), lineWidth: 0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(severityLabel), \(conflict.title). "
            + "\(conflict.explanation) "
            + "\(conflict.recommendation)"
        )
    }

    private var severityLabel: String {
        switch conflict.severity {
        case .advisory:
            "ADVISORY"
        case .warning:
            "REVIEW"
        case .critical:
            "CRITICAL"
        }
    }

    private var accent: Color {
        switch conflict.severity {
        case .advisory:
            GIAColor.intelligenceAccent
        case .warning, .critical:
            GIAColor.warningAccent
        }
    }

    private var iconName: String {
        switch conflict.kind {
        case .accessibility:
            "accessibility"
        case .budgetCategoryOverflow, .budgetOverflow:
            "creditcard.trianglebadge.exclamationmark"
        case .closedVenue:
            "door.left.hand.closed"
        case .currencyConversionMissing:
            "coloncurrencysign.arrow.circlepath"
        case .dietary:
            "fork.knife"
        case .duplicateActivity:
            "square.on.square"
        case .excessiveDailyTravel:
            "figure.walk.motion"
        case .insufficientTravelTime:
            "clock.badge.exclamationmark"
        case .missingReservation:
            "ticket"
        case .timeOverlap:
            "calendar.badge.exclamationmark"
        case .weather:
            "cloud.bolt.rain"
        }
    }
}

private enum BudgetConflictFormatting {
    static func money(_ value: Money) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = value.currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(
            from: NSDecimalNumber(decimal: value.amount)
        ) ?? "\(value.amount) \(value.currencyCode)"
    }
}
