import Foundation

enum BookingReviewSubject: Hashable, Identifiable {
    case flight(UUID)
    case hotel(UUID)

    var id: String {
        switch self {
        case .flight(let id):
            "flight-\(id)"
        case .hotel(let id):
            "hotel-\(id)"
        }
    }
}

struct BookingReviewPresentation: Identifiable {
    let subject: BookingReviewSubject
    let title: String
    let subtitle: String
    let categoryLabel: String
    let price: Money
    let providerName: String
    let cancellationSummary: String
    let checkoutURL: URL?
    let sourceOrigin: DataOrigin
    let sourceRetrievedAt: Date
    let existingBookingRecord: BookingRecord?

    var id: String { subject.id }
}

enum BookingReviewBuilder {
    static func presentation(
        for subject: BookingReviewSubject,
        in trip: Trip
    ) -> BookingReviewPresentation? {
        switch subject {
        case .flight(let id):
            guard
                let offer = trip.catalog.flightOffers.first(
                    where: { $0.id == id }
                )
            else { return nil }
            let flight = FlightOptionPresentation(offer: offer)
            let cancellationSummary: String
            switch offer.refundable {
            case true:
                cancellationSummary =
                    "Provider reports this fare as refundable."
            case false:
                cancellationSummary =
                    "Provider reports this fare as nonrefundable."
            case nil:
                cancellationSummary =
                    "Refund and change terms were not supplied."
            }
            return BookingReviewPresentation(
                subject: subject,
                title: flight.airlineName,
                subtitle:
                    "\(flight.originCode) → "
                    + "\(flight.destinationCode) · "
                    + flight.departureDate,
                categoryLabel: "Flight",
                price: offer.totalPrice,
                providerName: providerName(offer.provenance),
                cancellationSummary: cancellationSummary,
                checkoutURL: offer.bookingURL,
                sourceOrigin: offer.provenance.origin,
                sourceRetrievedAt: offer.provenance.retrievedAt,
                existingBookingRecord: trip.bookings.first {
                    $0.category == .flight
                        && $0.itemIdentifier == offer.id
                        && $0.status != .cancelled
                }
            )
        case .hotel(let id):
            guard
                let offer = trip.catalog.hotelOffers.first(
                    where: { $0.id == id }
                )
            else { return nil }
            let hotel = HotelOptionPresentation(offer: offer)
            return BookingReviewPresentation(
                subject: subject,
                title: offer.name,
                subtitle: hotel.locationLabel,
                categoryLabel: "Stay",
                price: offer.totalPrice,
                providerName: providerName(offer.provenance),
                cancellationSummary:
                    offer.cancellationPolicy?.summary
                    ?? "Cancellation terms were not supplied.",
                checkoutURL: offer.bookingURL,
                sourceOrigin: offer.provenance.origin,
                sourceRetrievedAt: offer.provenance.retrievedAt,
                existingBookingRecord: trip.bookings.first {
                    $0.category == .hotel
                        && $0.itemIdentifier == offer.id
                        && $0.status != .cancelled
                }
            )
        }
    }

    static func confirmationMode(
        for presentation: BookingReviewPresentation,
        environment: [String: String] =
            ProcessInfo.processInfo.environment
    ) -> BookingConfirmationMode {
        if
            environment["GIA_FBLA_DEMO_MODE"] == "1"
            || presentation.sourceOrigin == .demo
        {
            return .fblaDemo
        }
        return .externalProvider
    }

    static func money(_ value: Money) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = value.currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(
            from: NSDecimalNumber(decimal: value.amount)
        ) ?? "\(value.amount) \(value.currencyCode)"
    }

    private static func providerName(
        _ provenance: DataProvenance
    ) -> String {
        switch provenance.provider {
        case .serpApi:
            "SerpApi / Google Travel"
        case .user:
            "User supplied"
        case .gia:
            "GIA"
        default:
            provenance.provider.rawValue
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }
}

extension BookingConfirmationError {
    var userMessage: String {
        switch self {
        case .invalidPhase:
            "This selection cannot be continued right now."
        case .noCurrentTrip:
            "The trip is no longer available."
        case .unknownFlightOffer, .unknownHotelOffer:
            "This option is no longer in the sourced results."
        case .missingProviderCheckout:
            "The provider did not supply a checkout link."
        case .providerConfirmedBookingExists:
            "A provider-confirmed booking already exists. "
                + "Use the provider's modification flow."
        }
    }
}
