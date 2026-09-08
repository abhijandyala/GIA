import Foundation

struct FlightOptionPresentation: Identifiable {
    let offer: FlightOffer

    var id: UUID { offer.id }

    var airlineName: String {
        let names = Set(
            offer.outboundSegments.map(\.airlineName)
        )
        if names.count == 1 {
            return names.first ?? "Airline unavailable"
        }
        return names.isEmpty
            ? "Airline unavailable"
            : "Multiple airlines"
    }

    var originCode: String {
        offer.outboundSegments.first?.origin.iataCode
            ?? "—"
    }

    var destinationCode: String {
        offer.outboundSegments.last?.destination.iataCode
            ?? "—"
    }

    var departureTime: String {
        guard let segment = offer.outboundSegments.first else {
            return "—"
        }
        return localTime(
            rawText: segment.departureLocalTimeText,
            date: segment.departure,
            timeZoneIdentifier:
                segment.departureTimeZoneIdentifier
        )
    }

    var arrivalTime: String {
        guard let segment = offer.outboundSegments.last else {
            return "—"
        }
        return localTime(
            rawText: segment.arrivalLocalTimeText,
            date: segment.arrival,
            timeZoneIdentifier:
                segment.arrivalTimeZoneIdentifier
        )
    }

    var departureDate: String {
        guard let segment = offer.outboundSegments.first else {
            return "Date unavailable"
        }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = TimeZone(
            identifier: segment.departureTimeZoneIdentifier
        )
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter.string(from: segment.departure)
    }

    var totalPrice: String {
        money(offer.totalPrice)
    }

    var duration: String {
        durationText(offer.totalDuration)
    }

    var stopDescription: String {
        let outboundStops = max(
            offer.outboundSegments.count - 1,
            0
        )
        let outbound = stopText(outboundStops)
        guard !offer.returnSegments.isEmpty else {
            return outbound
        }
        let returnStops = max(
            offer.returnSegments.count - 1,
            0
        )
        return "\(outbound) out · \(stopText(returnStops)) back"
    }

    private func stopText(_ stops: Int) -> String {
        switch stops {
        case 0:
            "Nonstop"
        case 1:
            "1 stop"
        default:
            "\(stops) stops"
        }
    }

    var baggageDescription: String {
        if
            let rawDescription = offer.baggage?.rawDescription,
            !rawDescription.isEmpty
        {
            return rawDescription
        }

        var parts: [String] = []
        if let carryOn = offer.baggage?.carryOnBags, carryOn > 0 {
            parts.append(
                carryOn == 1
                    ? "1 carry-on"
                    : "\(carryOn) carry-ons"
            )
        }
        if let checked = offer.baggage?.checkedBags, checked > 0 {
            parts.append(
                checked == 1
                    ? "1 checked bag"
                    : "\(checked) checked bags"
            )
        }
        return parts.isEmpty ? "Baggage not supplied" : parts.joined(
            separator: " · "
        )
    }

    var emissionsDescription: String {
        guard let grams = offer.carbonEmissionsGrams else {
            return "Emissions unavailable"
        }
        let kilograms = Double(grams) / 1_000
        return "\(Int(kilograms.rounded())) kg CO₂e"
    }

    var priceInsightDescription: String? {
        guard let insight = offer.priceInsight else { return nil }
        switch insight.level {
        case .low:
            return "Lower than typical"
        case .typical:
            return "Typical price"
        case .high:
            return "Higher than typical"
        case .unknown:
            return nil
        }
    }

    var priceInsightSymbol: String {
        switch offer.priceInsight?.level {
        case .low:
            "arrow.down.right"
        case .high:
            "arrow.up.right"
        case .typical, .unknown, .none:
            "equal"
        }
    }

    var primaryBadge: String? {
        let priority: [(OfferBadge, String)] = [
            (.giaRecommended, "GIA RECOMMENDED"),
            (.lowestPrice, "LOWEST PRICE"),
            (.fastest, "FASTEST"),
            (.fewestStops, "FEWEST STOPS"),
            (.lowerEmissions, "LOWER EMISSIONS"),
            (.flexible, "FLEXIBLE")
        ]
        return priority.first {
            offer.badges.contains($0.0)
        }?.1
    }

    var sourceLabel: String {
        switch offer.provenance.origin {
        case .live:
            "LIVE"
        case .cached:
            "CACHED"
        case .demo:
            "DEMO"
        case .userEntered:
            "USER"
        }
    }

    var returnStatus: String? {
        if offer.returnSegments.isEmpty {
            return "Return flight selection pending"
        }
        return nil
    }

    var hasResolvedTimeZones: Bool {
        (
            offer.outboundSegments
            + offer.returnSegments
        ).allSatisfy {
            $0.departureTimeZoneIsResolved
                && $0.arrivalTimeZoneIsResolved
        }
    }

    var accessibilitySummary: String {
        [
            airlineName,
            "\(originCode) to \(destinationCode)",
            "departing \(departureTime)",
            "arriving \(arrivalTime)",
            duration,
            stopDescription,
            totalPrice,
            sourceLabel
        ].joined(separator: ", ")
    }

    private func localTime(
        rawText: String?,
        date: Date,
        timeZoneIdentifier: String
    ) -> String {
        if
            let rawText,
            let time = rawText.split(separator: " ").last
        {
            return String(time)
        }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone =
            TimeZone(identifier: timeZoneIdentifier)
            ?? .current
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func money(_ value: Money) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = value.currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(
            from: NSDecimalNumber(decimal: value.amount)
        ) ?? "\(value.amount) \(value.currencyCode)"
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(Int(duration / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return "\(minutes)m"
        }
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }
}

enum FlightPresentationBuilder {
    static func sortedOffers(
        _ offers: [FlightOffer],
        selectedIDs: Set<UUID>
    ) -> [FlightOptionPresentation] {
        offers
            .map(FlightOptionPresentation.init)
            .sorted { left, right in
                let leftRank = rank(
                    left.offer,
                    selectedIDs: selectedIDs
                )
                let rightRank = rank(
                    right.offer,
                    selectedIDs: selectedIDs
                )
                if leftRank != rightRank {
                    return leftRank < rightRank
                }
                if
                    left.offer.totalPrice.currencyCode
                    == right.offer.totalPrice.currencyCode,
                    left.offer.totalPrice.amount
                    != right.offer.totalPrice.amount
                {
                    return left.offer.totalPrice.amount
                        < right.offer.totalPrice.amount
                }
                return left.offer.totalDuration
                    < right.offer.totalDuration
            }
    }

    private static func rank(
        _ offer: FlightOffer,
        selectedIDs: Set<UUID>
    ) -> Int {
        if selectedIDs.contains(offer.id) {
            return 0
        }
        if offer.badges.contains(.giaRecommended) {
            return 1
        }
        if offer.badges.contains(.lowestPrice) {
            return 2
        }
        if offer.badges.contains(.fastest) {
            return 3
        }
        return 4
    }
}
