import Foundation

enum TripBudgetConflictEngine {
    static func analyze(
        trip: Trip,
        at analyzedAt: Date? = nil
    ) -> TripBudgetConflictAnalysis {
        let analysisDate = analyzedAt ?? trip.updatedAt
        let currencyCode = analysisCurrency(for: trip)
        var accumulators: [BudgetCategory: SpendAccumulator] = [:]
        var unconvertedCurrencies: Set<String> = []
        var usedBookingIDs: Set<UUID> = []

        func add(
            _ money: Money?,
            category: BudgetCategory,
            confirmed: Bool = false,
            unknownWhenMissing: Bool = false
        ) {
            guard let money else {
                if unknownWhenMissing {
                    accumulators[category, default: SpendAccumulator()]
                        .unknownCostCount += 1
                }
                return
            }
            guard
                let converted = convert(
                    money,
                    to: currencyCode,
                    rates: trip.budget.currencyConversionRates,
                    at: analysisDate
                )
            else {
                unconvertedCurrencies.insert(money.currencyCode)
                accumulators[category, default: SpendAccumulator()]
                    .unknownCostCount += 1
                return
            }

            if confirmed {
                accumulators[category, default: SpendAccumulator()]
                    .confirmed += converted.amount
            } else {
                accumulators[category, default: SpendAccumulator()]
                    .estimated += converted.amount
            }
            if let timestamp = converted.timestamp {
                accumulators[category, default: SpendAccumulator()]
                    .conversionTimestamps.insert(timestamp)
            }
        }

        let bookingsByItem = Dictionary(
            grouping: trip.bookings.filter {
                $0.status != .cancelled && $0.status != .failed
            },
            by: \.itemIdentifier
        )

        for offerID in trip.selections.flightOfferIDs {
            guard
                let offer = trip.catalog.flightOffers.first(
                    where: { $0.id == offerID }
                )
            else { continue }
            if
                !addBookingSpend(
                    bookingsByItem[offerID],
                    category: .flights,
                    usedBookingIDs: &usedBookingIDs,
                    add: add
                )
            {
                add(offer.totalPrice, category: .flights)
            }
        }

        for offerID in trip.selections.hotelOfferIDs {
            guard
                let offer = trip.catalog.hotelOffers.first(
                    where: { $0.id == offerID }
                )
            else { continue }
            if
                !addBookingSpend(
                    bookingsByItem[offerID],
                    category: .lodging,
                    usedBookingIDs: &usedBookingIDs,
                    add: add
                )
            {
                add(offer.totalPrice, category: .lodging)
            }
        }

        for item in trip.itinerary.days.flatMap(\.items)
        where item.status != .cancelled {
            let category = budgetCategory(for: item)
            let linkedBookings =
                bookingsByItem[item.id]
                ?? referenceIdentifier(item.reference).flatMap {
                    bookingsByItem[$0]
                }
            if
                !addBookingSpend(
                    linkedBookings,
                    category: category,
                    usedBookingIDs: &usedBookingIDs,
                    add: add
                )
            {
                let sourceCostIsCounted = sourceCostAlreadyCounted(
                    for: item.reference,
                    selections: trip.selections
                )
                if !sourceCostIsCounted {
                    add(
                        item.estimatedCost,
                        category: category,
                        unknownWhenMissing: itemKindCanCost(item.kind)
                    )
                }
            }
        }

        for leg in trip.itinerary.transportationLegs {
            if
                !addBookingSpend(
                    bookingsByItem[leg.id],
                    category: .transportation,
                    usedBookingIDs: &usedBookingIDs,
                    add: add
                )
            {
                add(
                    leg.estimatedCost,
                    category: .transportation,
                    unknownWhenMissing: false
                )
            }
        }

        for booking in trip.bookings
        where
            !usedBookingIDs.contains(booking.id)
            && booking.status != .cancelled
            && booking.status != .failed
        {
            add(
                booking.amount,
                category: budgetCategory(for: booking.category),
                confirmed: booking.status == .confirmed,
                unknownWhenMissing: true
            )
        }

        let limits = categoryLimits(
            trip: trip,
            currencyCode: currencyCode,
            analyzedAt: analysisDate,
            unconvertedCurrencies: &unconvertedCurrencies
        )
        let reserveAmount =
            limits[.emergencyReserve]?.amount ?? 0
        let categories = BudgetCategory.allCases
            .filter { $0 != .uncategorized }
            .map { category in
                let accumulator =
                    accumulators[category] ?? SpendAccumulator()
                return TripBudgetCategorySummary(
                    category: category,
                    limit: limits[category],
                    estimatedSpend: Money(
                        amount:
                            category == .emergencyReserve
                            ? 0
                            : accumulator.estimated,
                        currencyCode: currencyCode
                    ),
                    confirmedSpend: Money(
                        amount: accumulator.confirmed,
                        currencyCode: currencyCode
                    ),
                    unknownCostCount: accumulator.unknownCostCount,
                    conversionTimestamps:
                        accumulator.conversionTimestamps.sorted()
                )
            }
        let estimatedTotal = categories.reduce(Decimal.zero) {
            $0 + $1.estimatedSpend.amount
        }
        let confirmedTotal = categories.reduce(Decimal.zero) {
            $0 + $1.confirmedSpend.amount
        }
        let totalLimit = convertedTotalLimit(
            trip: trip,
            currencyCode: currencyCode,
            analyzedAt: analysisDate,
            unconvertedCurrencies: &unconvertedCurrencies
        )
        let remaining = totalLimit.map {
            Money(
                amount:
                    $0.amount
                    - estimatedTotal
                    - confirmedTotal
                    - reserveAmount,
                currencyCode: currencyCode
            )
        }
        let budget = TripBudgetSummary(
            currencyCode: currencyCode,
            totalLimit: totalLimit,
            estimatedSpend: Money(
                amount: estimatedTotal,
                currencyCode: currencyCode
            ),
            confirmedSpend: Money(
                amount: confirmedTotal,
                currencyCode: currencyCode
            ),
            emergencyReserve: Money(
                amount: reserveAmount,
                currencyCode: currencyCode
            ),
            remainingAfterReserve: remaining,
            categories: categories,
            unconvertedCurrencyCodes: unconvertedCurrencies,
            unknownCostCount: categories.reduce(0) {
                $0 + $1.unknownCostCount
            },
            conversionTimestamps: categories
                .flatMap(\.conversionTimestamps)
                .uniqued()
                .sorted()
        )

        var conflicts = detectScheduleConflicts(in: trip)
        conflicts += detectPreferenceConflicts(in: trip)
        conflicts += detectWeatherConflicts(in: trip)
        conflicts += detectReservationConflicts(in: trip)
        conflicts += budgetConflicts(budget)
        conflicts.sort {
            if $0.severity != $1.severity {
                return $0.severity.rawValue > $1.severity.rawValue
            }
            if $0.kind != $1.kind {
                return $0.kind.rawValue < $1.kind.rawValue
            }
            return $0.id < $1.id
        }

        return TripBudgetConflictAnalysis(
            budget: budget,
            conflicts: conflicts,
            analyzedAt: analysisDate
        )
    }

    private static func detectScheduleConflicts(
        in trip: Trip
    ) -> [TripConflict] {
        var conflicts: [TripConflict] = []

        for day in trip.itinerary.chronologicallySortedDays {
            let items = day.chronologicallySortedItems.filter {
                $0.status != .cancelled
            }
            for index in items.indices {
                let item = items[index]
                if index > items.startIndex {
                    let previous = items[index - 1]
                    if item.start < previous.end {
                        conflicts.append(
                            TripConflict(
                                id:
                                    "overlap-\(previous.id)-\(item.id)",
                                kind: .timeOverlap,
                                severity: .critical,
                                title: "Schedule overlap",
                                explanation:
                                    "\(previous.title) and \(item.title) "
                                    + "occupy the same time window.",
                                recommendation:
                                    "Move a flexible item or choose a "
                                    + "different time.",
                                relatedItemIDs: [
                                    previous.id,
                                    item.id
                                ],
                                dayID: day.id
                            )
                        )
                    } else if
                        let route = matchingRoute(
                            from: previous,
                            to: item,
                            in: trip
                        )
                    {
                        let available =
                            item.start.timeIntervalSince(previous.end)
                        let required =
                            route.duration + route.bufferDuration
                        if available < required {
                            let shortfall = max(
                                Int(ceil((required - available) / 60)),
                                1
                            )
                            conflicts.append(
                                TripConflict(
                                    id:
                                        "travel-\(previous.id)-\(item.id)",
                                    kind: .insufficientTravelTime,
                                    severity: .critical,
                                    title: "Travel window is too short",
                                    explanation:
                                        "\(shortfall) more minutes are "
                                        + "needed between "
                                        + "\(previous.title) and "
                                        + "\(item.title), including the "
                                        + "route buffer.",
                                    recommendation:
                                        "Move the later item or use a "
                                        + "faster sourced route.",
                                    relatedItemIDs: [
                                        previous.id,
                                        item.id
                                    ],
                                    dayID: day.id
                                )
                            )
                        }
                    }
                }
            }

            let duplicateGroups = Dictionary(
                grouping: items.filter {
                    $0.kind == .activity
                        || $0.kind == .meeting
                },
                by: { normalized($0.title) }
            )
            for (signature, duplicates) in duplicateGroups
            where !signature.isEmpty && duplicates.count > 1 {
                conflicts.append(
                    TripConflict(
                        id: "duplicate-\(day.id)-\(signature)",
                        kind: .duplicateActivity,
                        severity: .warning,
                        title: "Duplicate activity",
                        explanation:
                            "\(duplicates[0].title) appears "
                            + "\(duplicates.count) times on this day.",
                        recommendation:
                            "Remove a duplicate or replace it with a "
                            + "different group activity.",
                        relatedItemIDs: duplicates.map(\.id),
                        dayID: day.id
                    )
                )
            }

            let routes = adjacentRoutes(for: items, in: trip)
            let travelMinutes = Int(
                routes.reduce(0) { $0 + $1.duration } / 60
            )
            let threshold = dailyTravelThreshold(
                for: trip.request.preferredPace
            )
            if travelMinutes > threshold {
                conflicts.append(
                    TripConflict(
                        id: "daily-travel-\(day.id)",
                        kind: .excessiveDailyTravel,
                        severity: .warning,
                        title: "High daily travel",
                        explanation:
                            "This day includes \(travelMinutes) minutes "
                            + "of travel; the "
                            + "\(trip.request.preferredPace.rawValue) "
                            + "pace threshold is \(threshold) minutes.",
                        recommendation:
                            "Group nearby stops or move one activity to "
                            + "another day.",
                        relatedItemIDs: items.map(\.id),
                        dayID: day.id
                    )
                )
            }
        }

        return conflicts
    }

    private static func detectPreferenceConflicts(
        in trip: Trip
    ) -> [TripConflict] {
        var conflicts: [TripConflict] = []
        let requestedDietary = trip.request.dietaryRequirements.union(
            trip.travelers.flatMap {
                $0.preferences.dietaryRequirements
            }
        )
        let requestedAccessibility =
            trip.request.accessibilityRequirements.union(
                trip.travelers.flatMap {
                    $0.preferences.accessibilityRequirements
                }
            )

        for day in trip.itinerary.days {
            for item in day.items where item.status != .cancelled {
                guard
                    case .place(let placeID) = item.reference,
                    let place = trip.catalog.places.first(
                        where: { $0.id == placeID }
                    )
                else { continue }

                if
                    item.kind == .meal,
                    !requestedDietary.isEmpty
                {
                    let missing = requestedDietary.subtracting(
                        place.dietaryOptions
                    )
                    if !missing.isEmpty {
                        conflicts.append(
                            TripConflict(
                                id: "dietary-\(item.id)",
                                kind: .dietary,
                                severity: .warning,
                                title: "Dietary fit not verified",
                                explanation:
                                    "\(place.name) does not have sourced "
                                    + "support for "
                                    + labels(missing) + ".",
                                recommendation:
                                    "Confirm with the venue or choose a "
                                    + "verified alternative.",
                                relatedItemIDs: [item.id],
                                dayID: day.id
                            )
                        )
                    }
                }

                if !requestedAccessibility.isEmpty {
                    let missing = requestedAccessibility.subtracting(
                        place.accessibilityFeatures
                    )
                    if !missing.isEmpty {
                        conflicts.append(
                            TripConflict(
                                id: "accessibility-\(item.id)",
                                kind: .accessibility,
                                severity: .warning,
                                title: "Accessibility not verified",
                                explanation:
                                    "\(place.name) lacks sourced evidence "
                                    + "for " + labels(missing) + ".",
                                recommendation:
                                    "Verify directly before finalizing "
                                    + "this stop.",
                                relatedItemIDs: [item.id],
                                dayID: day.id
                            )
                        )
                    }
                }

                if isExplicitlyClosed(place, during: item) {
                    conflicts.append(
                        TripConflict(
                            id: "closed-\(item.id)",
                            kind: .closedVenue,
                            severity: .critical,
                            title: "Venue is closed",
                            explanation:
                                "Sourced opening hours mark \(place.name) "
                                + "closed on the scheduled day.",
                            recommendation:
                                "Choose another day or replace the venue.",
                            relatedItemIDs: [item.id],
                            dayID: day.id
                        )
                    )
                }
            }
        }
        return conflicts
    }

    private static func detectWeatherConflicts(
        in trip: Trip
    ) -> [TripConflict] {
        var conflicts: [TripConflict] = []
        for day in trip.itinerary.days {
            guard
                let snapshot = trip.catalog.weatherSnapshots.first(
                    where: { $0.id == day.weatherSnapshotID }
                )
            else { continue }

            for item in day.items
            where item.status != .cancelled
                && isWeatherSensitive(item, in: trip) {
                let dangerousPeriods = snapshot.periods.filter {
                    $0.start < item.end
                        && $0.end > item.start
                        && isDisruptive($0)
                }
                let activeAlerts = snapshot.alerts.filter {
                    ($0.severity == .severe
                        || $0.severity == .extreme)
                        && ($0.effectiveAt ?? item.start) < item.end
                        && ($0.expiresAt ?? item.end) > item.start
                }
                guard
                    let period = dangerousPeriods.first
                        ?? snapshot.periods.first(
                            where: { isDisruptive($0) }
                        ),
                    !dangerousPeriods.isEmpty || !activeAlerts.isEmpty
                else { continue }

                conflicts.append(
                    TripConflict(
                        id: "weather-\(item.id)",
                        kind: .weather,
                        severity:
                            activeAlerts.isEmpty ? .warning : .critical,
                        title: "Weather conflicts with this stop",
                        explanation:
                            "\(item.title) is weather-sensitive, while "
                            + "the sourced forecast reports "
                            + "\(period.providerDescription).",
                        recommendation:
                            "Move it to a safer window or use an indoor "
                            + "alternative.",
                        relatedItemIDs: [item.id],
                        dayID: day.id
                    )
                )
            }
        }
        return conflicts
    }

    private static func detectReservationConflicts(
        in trip: Trip
    ) -> [TripConflict] {
        var conflicts: [TripConflict] = []
        let confirmedItemIDs = Set(
            trip.bookings.filter {
                $0.status == .confirmed
            }.map(\.itemIdentifier)
        )

        for selectedID in trip.selections.flightOfferIDs
        where !confirmedItemIDs.contains(selectedID) {
            conflicts.append(
                TripConflict(
                    id: "reservation-flight-\(selectedID)",
                    kind: .missingReservation,
                    severity: .warning,
                    title: "Selected flight is not booked",
                    explanation:
                        "The chosen flight has no provider-confirmed "
                        + "booking record.",
                    recommendation:
                        "Continue to the provider before relying on it.",
                    relatedItemIDs: [selectedID]
                )
            )
        }
        for selectedID in trip.selections.hotelOfferIDs
        where !confirmedItemIDs.contains(selectedID) {
            conflicts.append(
                TripConflict(
                    id: "reservation-hotel-\(selectedID)",
                    kind: .missingReservation,
                    severity: .warning,
                    title: "Selected stay is not booked",
                    explanation:
                        "The chosen property has no provider-confirmed "
                        + "booking record.",
                    recommendation:
                        "Continue to the provider before relying on it.",
                    relatedItemIDs: [selectedID]
                )
            )
        }

        for day in trip.itinerary.days {
            for item in day.items
            where item.status != .cancelled
            {
                let requiresReservation: Bool
                let sourceIdentifier: UUID?
                switch item.reference {
                case .timedEvent(let eventID):
                    sourceIdentifier = eventID
                    requiresReservation =
                        trip.catalog.timedEvents.first {
                            $0.id == eventID
                        }?.schedulingTraits.contains {
                            $0 == .ticketRequired
                                || $0 == .reservationAvailable
                        } ?? false
                case .place(let placeID):
                    sourceIdentifier = placeID
                    requiresReservation =
                        trip.catalog.places.first {
                            $0.id == placeID
                        }?.reservationRequired == true
                default:
                    sourceIdentifier = nil
                    requiresReservation = false
                }
                let isConfirmed =
                    confirmedItemIDs.contains(item.id)
                    || sourceIdentifier.map {
                        confirmedItemIDs.contains($0)
                    } == true
                if requiresReservation && !isConfirmed {
                    conflicts.append(
                        TripConflict(
                            id: "reservation-item-\(item.id)",
                            kind: .missingReservation,
                            severity: .warning,
                            title: "Reservation still required",
                            explanation:
                                "\(item.title) is selected, but no "
                                + "provider-confirmed reservation exists.",
                            recommendation:
                                "Open the source link and complete the "
                                + "reservation.",
                            relatedItemIDs: [item.id],
                            dayID: day.id
                        )
                    )
                }
            }
        }
        return conflicts
    }

    private static func budgetConflicts(
        _ budget: TripBudgetSummary
    ) -> [TripConflict] {
        var conflicts: [TripConflict] = []
        if
            budget.isOverLimit,
            let remaining = budget.remainingAfterReserve
        {
            conflicts.append(
                TripConflict(
                    id: "budget-total",
                    kind: .budgetOverflow,
                    severity: .critical,
                    title: "Trip exceeds the budget",
                    explanation:
                        "The plan is "
                        + amountText(-remaining.amount)
                        + " \(budget.currencyCode) over the total after "
                        + "protecting the emergency reserve.",
                    recommendation:
                        "Replace a high-cost option or reduce a category."
                )
            )
        }
        for category in budget.categories where category.isOverLimit {
            guard let remaining = category.remaining else { continue }
            conflicts.append(
                TripConflict(
                    id: "budget-\(category.category.rawValue)",
                    kind: .budgetCategoryOverflow,
                    severity: .warning,
                    title:
                        "\(categoryTitle(category.category)) is over plan",
                    explanation:
                        "This category exceeds its allocation by "
                        + amountText(-remaining.amount)
                        + " \(budget.currencyCode).",
                    recommendation:
                        "Replace an item in this category or approve a "
                        + "budget reallocation."
                )
            )
        }
        if !budget.unconvertedCurrencyCodes.isEmpty {
            conflicts.append(
                TripConflict(
                    id: "currency-conversion",
                    kind: .currencyConversionMissing,
                    severity: .warning,
                    title: "Currency conversion is incomplete",
                    explanation:
                        "No timestamped rate is available for "
                        + budget.unconvertedCurrencyCodes.sorted()
                            .joined(separator: ", ")
                        + " to \(budget.currencyCode).",
                    recommendation:
                        "Refresh exchange rates before trusting the total."
                )
            )
        }
        return conflicts
    }

    private static func addBookingSpend(
        _ bookings: [BookingRecord]?,
        category: BudgetCategory,
        usedBookingIDs: inout Set<UUID>,
        add: (Money?, BudgetCategory, Bool, Bool) -> Void
    ) -> Bool {
        guard let booking = bookings?.first else { return false }
        usedBookingIDs.insert(booking.id)
        add(
            booking.amount,
            category,
            booking.status == .confirmed,
            true
        )
        return true
    }

    private static func analysisCurrency(for trip: Trip) -> String {
        if let code = trip.budget.totalLimit?.currencyCode {
            return code
        }
        if let code = trip.request.totalBudget?.currencyCode {
            return code
        }
        if let code = trip.budget.allocations.first?.limit.currencyCode {
            return code
        }
        if
            let code = trip.itinerary.days
                .flatMap(\.items)
                .compactMap(\.estimatedCost)
                .first?.currencyCode
        {
            return code
        }
        return Locale.current.currency?.identifier ?? "USD"
    }

    private static func categoryLimits(
        trip: Trip,
        currencyCode: String,
        analyzedAt: Date,
        unconvertedCurrencies: inout Set<String>
    ) -> [BudgetCategory: Money] {
        var limits: [BudgetCategory: Decimal] = [:]
        for allocation in trip.budget.allocations {
            guard
                let converted = convert(
                    allocation.limit,
                    to: currencyCode,
                    rates: trip.budget.currencyConversionRates,
                    at: analyzedAt
                )
            else {
                unconvertedCurrencies.insert(
                    allocation.limit.currencyCode
                )
                continue
            }
            limits[allocation.category, default: 0] += converted.amount
        }
        return limits.mapValues {
            Money(amount: $0, currencyCode: currencyCode)
        }
    }

    private static func convertedTotalLimit(
        trip: Trip,
        currencyCode: String,
        analyzedAt: Date,
        unconvertedCurrencies: inout Set<String>
    ) -> Money? {
        guard
            let limit =
                trip.budget.totalLimit ?? trip.request.totalBudget
        else { return nil }
        guard
            let converted = convert(
                limit,
                to: currencyCode,
                rates: trip.budget.currencyConversionRates,
                at: analyzedAt
            )
        else {
            unconvertedCurrencies.insert(limit.currencyCode)
            return nil
        }
        return Money(
            amount: converted.amount,
            currencyCode: currencyCode
        )
    }

    private static func convert(
        _ money: Money,
        to destinationCode: String,
        rates: [CurrencyConversionRate],
        at date: Date
    ) -> ConvertedAmount? {
        if money.currencyCode == destinationCode {
            return ConvertedAmount(
                amount: money.amount,
                timestamp: nil
            )
        }
        let candidates = rates.filter {
            ($0.expiresAt == nil || $0.expiresAt! > date)
                && $0.rate > 0
                && (
                    (
                        $0.sourceCurrencyCode == money.currencyCode
                        && $0.destinationCurrencyCode
                            == destinationCode
                    )
                    || (
                        $0.destinationCurrencyCode
                            == money.currencyCode
                        && $0.sourceCurrencyCode == destinationCode
                    )
                )
        }.sorted { $0.retrievedAt > $1.retrievedAt }
        guard let rate = candidates.first else { return nil }
        let amount: Decimal
        if rate.sourceCurrencyCode == money.currencyCode {
            amount = money.amount * rate.rate
        } else {
            amount = money.amount / rate.rate
        }
        return ConvertedAmount(
            amount: amount,
            timestamp: rate.retrievedAt
        )
    }

    private static func sourceCostAlreadyCounted(
        for reference: ItineraryReference,
        selections: TripSelections
    ) -> Bool {
        switch reference {
        case .flightOffer(let id):
            selections.flightOfferIDs.contains(id)
        case .hotelOffer(let id):
            selections.hotelOfferIDs.contains(id)
        case .transportationLeg:
            true
        default:
            false
        }
    }

    private static func referenceIdentifier(
        _ reference: ItineraryReference
    ) -> UUID? {
        switch reference {
        case
            .flightOffer(let id),
            .hotelOffer(let id),
            .place(let id),
            .timedEvent(let id),
            .transportationLeg(let id):
            id
        case .userCreated:
            nil
        }
    }

    private static func budgetCategory(
        for item: ItineraryItem
    ) -> BudgetCategory {
        switch item.kind {
        case .flight, .arrival, .departure:
            .flights
        case .hotelCheckIn, .hotelCheckOut:
            .lodging
        case .meal:
            .food
        case .activity, .meeting:
            .activities
        case .transportation:
            .transportation
        case .freeTime:
            .uncategorized
        }
    }

    private static func budgetCategory(
        for category: BookingCategory
    ) -> BudgetCategory {
        switch category {
        case .activity:
            .activities
        case .flight:
            .flights
        case .hotel:
            .lodging
        case .restaurant:
            .food
        case .transportation:
            .transportation
        }
    }

    private static func itemKindCanCost(
        _ kind: ItineraryItemKind
    ) -> Bool {
        switch kind {
        case
            .activity,
            .flight,
            .hotelCheckIn,
            .meal,
            .meeting,
            .transportation:
            true
        case
            .arrival,
            .departure,
            .freeTime,
            .hotelCheckOut:
            false
        }
    }

    private static func matchingRoute(
        from item: ItineraryItem,
        to nextItem: ItineraryItem,
        in trip: Trip
    ) -> TransportationLeg? {
        guard
            let origin = item.location,
            let destination = nextItem.location
        else { return nil }
        return trip.itinerary.transportationLegs.first {
            locationsMatch($0.origin, origin)
                && locationsMatch($0.destination, destination)
        }
    }

    private static func adjacentRoutes(
        for items: [ItineraryItem],
        in trip: Trip
    ) -> [TransportationLeg] {
        guard items.count > 1 else { return [] }
        return zip(items, items.dropFirst()).compactMap {
            matchingRoute(from: $0.0, to: $0.1, in: trip)
        }
    }

    private static func locationsMatch(
        _ left: TravelLocation,
        _ right: TravelLocation
    ) -> Bool {
        if
            let leftCoordinate = left.coordinate,
            let rightCoordinate = right.coordinate
        {
            return
                abs(
                    leftCoordinate.latitude
                    - rightCoordinate.latitude
                ) < 0.000_1
                && abs(
                    leftCoordinate.longitude
                    - rightCoordinate.longitude
                ) < 0.000_1
        }
        return normalized(left.name) == normalized(right.name)
    }

    private static func isExplicitlyClosed(
        _ place: PlaceRecommendation,
        during item: ItineraryItem
    ) -> Bool {
        guard let hours = place.openingHours else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone =
            TimeZone(identifier: item.timeZoneIdentifier) ?? .current
        formatter.dateFormat = "EEEE"
        let weekday = normalized(formatter.string(from: item.start))
        return hours.rawText.contains { line in
            let value = normalized(line)
            return value.hasPrefix(weekday)
                && value.contains("closed")
        }
    }

    private static func isWeatherSensitive(
        _ item: ItineraryItem,
        in trip: Trip
    ) -> Bool {
        switch item.reference {
        case .timedEvent(let id):
            guard
                let event = trip.catalog.timedEvents.first(
                    where: { $0.id == id }
                )
            else { return false }
            return event.schedulingTraits.contains(.outdoor)
                || event.schedulingTraits.contains(.weatherDependent)
        case .place(let id):
            return trip.catalog.places.first {
                $0.id == id
            }?.indoor == false
        default:
            return false
        }
    }

    private static func isDisruptive(
        _ period: WeatherPeriod
    ) -> Bool {
        switch period.condition {
        case .storm, .snow:
            return true
        case .rain:
            return (period.precipitationProbability ?? 1) >= 0.6
        case .wind:
            return (period.windKilometersPerHour ?? 0) >= 40
        default:
            return
                (period.precipitationProbability ?? 0) >= 0.75
                || (period.windKilometersPerHour ?? 0) >= 50
        }
    }

    private static func dailyTravelThreshold(
        for pace: TravelPace
    ) -> Int {
        switch pace {
        case .relaxed:
            90
        case .balanced:
            150
        case .active:
            210
        }
    }

    private static func labels<T: RawRepresentable>(
        _ values: Set<T>
    ) -> String where T.RawValue == String {
        values.map {
            $0.rawValue
                .replacingOccurrences(
                    of: "([a-z])([A-Z])",
                    with: "$1 $2",
                    options: .regularExpression
                )
                .lowercased()
        }.sorted().joined(separator: ", ")
    }

    private static func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        .lowercased()
        .filter(\.isLetter)
    }

    private static func amountText(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }

    private static func categoryTitle(
        _ category: BudgetCategory
    ) -> String {
        switch category {
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
            "Transportation"
        case .uncategorized:
            "Uncategorized"
        }
    }
}

private struct SpendAccumulator {
    var estimated: Decimal = 0
    var confirmed: Decimal = 0
    var unknownCostCount = 0
    var conversionTimestamps: Set<Date> = []
}

private struct ConvertedAmount {
    var amount: Decimal
    var timestamp: Date?
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
