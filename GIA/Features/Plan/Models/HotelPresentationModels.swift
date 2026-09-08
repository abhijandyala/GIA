import Foundation

struct HotelOptionPresentation: Identifiable {
    let offer: HotelOffer

    var id: UUID { offer.id }

    var locationLabel: String {
        let components = [
            offer.location.city,
            offer.location.country
        ].compactMap { $0 }.filter { !$0.isEmpty }
        return components.isEmpty
            ? offer.location.name
            : components.joined(separator: ", ")
    }

    var ratingText: String {
        guard
            let rating = offer.guestRating,
            let scale = offer.guestRatingScale
        else {
            return "Rating unavailable"
        }
        return "\(decimal(rating, maximumDigits: 1))/"
            + "\(decimal(scale, maximumDigits: 0))"
    }

    var reviewText: String {
        guard let count = offer.reviewCount else {
            return "Reviews unavailable"
        }
        return count == 1 ? "1 review" : "\(count) reviews"
    }

    var nightlyPrice: String {
        offer.nightlyPrice.map(money) ?? "Nightly unavailable"
    }

    var totalPrice: String {
        money(offer.totalPrice)
    }

    var taxDescription: String {
        switch offer.taxesAndFeesIncluded {
        case true:
            "Taxes and fees included"
        case false:
            "Taxes and fees not included"
        case nil:
            "Tax and fee total not confirmed"
        }
    }

    var cancellationDescription: String {
        offer.cancellationPolicy?.summary
            ?? "Cancellation terms unavailable"
    }

    var amenityTitles: [String] {
        offer.amenities.map(amenityTitle).sorted()
    }

    var primaryBadge: String? {
        let priority: [(OfferBadge, String)] = [
            (.giaRecommended, "GIA RECOMMENDED"),
            (.lowestPrice, "LOWEST TOTAL"),
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

    var starDescription: String {
        guard let rating = offer.starRating else {
            return "Class unavailable"
        }
        return "\(rating)-star"
    }

    var lodgingType: String {
        switch offer.lodgingType {
        case .hotel:
            "Hotel"
        case .hostel:
            "Hostel"
        case .resort:
            "Resort"
        case .vacationRental:
            "Vacation rental"
        case .apartment:
            "Apartment"
        }
    }

    var checkTimeDescription: String {
        let checkIn = offer.checkInTime ?? "Not supplied"
        let checkOut = offer.checkOutTime ?? "Not supplied"
        return "Check-in \(checkIn) · Check-out \(checkOut)"
    }

    var accessibilitySummary: String {
        [
            offer.name,
            locationLabel,
            ratingText,
            reviewText,
            "\(nightlyPrice) nightly",
            "\(totalPrice) total",
            taxDescription,
            cancellationDescription,
            sourceLabel
        ].joined(separator: ", ")
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

    private func decimal(
        _ value: Double,
        maximumDigits: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumDigits
        return formatter.string(from: NSNumber(value: value))
            ?? String(value)
    }

    private func amenityTitle(_ amenity: HotelAmenity) -> String {
        switch amenity {
        case .accessibleRoom:
            "Accessible room"
        case .airportShuttle:
            "Airport shuttle"
        case .breakfast:
            "Breakfast"
        case .fitnessCenter:
            "Fitness"
        case .kitchen:
            "Kitchen"
        case .laundry:
            "Laundry"
        case .parking:
            "Parking"
        case .pool:
            "Pool"
        case .spa:
            "Spa"
        case .wifi:
            "Wi-Fi"
        }
    }
}

enum HotelPresentationBuilder {
    static func sortedOffers(
        _ offers: [HotelOffer],
        selectedIDs: Set<UUID>
    ) -> [HotelOptionPresentation] {
        offers
            .map(HotelOptionPresentation.init)
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
                return (left.offer.guestRating ?? 0)
                    > (right.offer.guestRating ?? 0)
            }
    }

    private static func rank(
        _ offer: HotelOffer,
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
        if offer.badges.contains(.flexible) {
            return 3
        }
        return 4
    }
}
