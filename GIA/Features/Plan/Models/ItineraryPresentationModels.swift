import Foundation

struct ItineraryItemPresentation: Identifiable {
    let item: ItineraryItem

    var id: UUID { item.id }

    var timeRange: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone =
            TimeZone(identifier: item.timeZoneIdentifier)
            ?? .current
        formatter.timeStyle = .short
        return "\(formatter.string(from: item.start))–"
            + formatter.string(from: item.end)
    }

    var locationText: String? {
        item.location?.name
    }

    var costText: String? {
        guard let cost = item.estimatedCost else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = cost.currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(
            from: NSDecimalNumber(decimal: cost.amount)
        )
    }

    var iconName: String {
        switch item.kind {
        case .activity:
            "sparkles"
        case .arrival:
            "arrow.down.circle"
        case .departure:
            "arrow.up.circle"
        case .flight:
            "airplane"
        case .freeTime:
            "circle.dotted"
        case .hotelCheckIn:
            "bed.double.fill"
        case .hotelCheckOut:
            "rectangle.portrait.and.arrow.right"
        case .meal:
            "fork.knife"
        case .meeting:
            "person.2"
        case .transportation:
            "location.north.line.fill"
        }
    }

    var flexibilityLabel: String {
        switch item.flexibility {
        case .fixed:
            "FIXED"
        case .flexible:
            "FLEXIBLE"
        case .lockedByUser:
            "LOCKED"
        }
    }

    var canMove: Bool {
        item.flexibility == .flexible
    }

    var canToggleLock: Bool {
        item.flexibility != .fixed
    }

    var accessibilitySummary: String {
        [
            item.title,
            timeRange,
            locationText,
            flexibilityLabel,
            costText
        ].compactMap { $0 }.joined(separator: ", ")
    }
}

struct TimelineDayPresentation: Identifiable {
    let day: ItineraryDay
    let weather: WeatherSnapshot?

    var id: UUID { day.id }

    var shortTitle: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone =
            TimeZone(identifier: day.timeZoneIdentifier)
            ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEE d")
        return formatter.string(from: day.date)
    }

    var fullTitle: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone =
            TimeZone(identifier: day.timeZoneIdentifier)
            ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        return formatter.string(from: day.date)
    }

    var weatherSummary: String? {
        guard let period = weather?.periods.first else {
            return nil
        }
        var parts = [period.providerDescription]
        if let temperature = period.temperatureCelsius {
            parts.append("\(Int(temperature.rounded()))°C")
        }
        return parts.joined(separator: " · ")
    }

    var items: [ItineraryItemPresentation] {
        day.chronologicallySortedItems.map(
            ItineraryItemPresentation.init
        )
    }
}

struct TimelineTransportPresentation: Identifiable {
    let route: TransportationLeg

    var id: UUID { route.id }

    var durationText: String {
        let minutes = max(Int(route.duration / 60), 1)
        return minutes < 60
            ? "\(minutes) min"
            : "\(minutes / 60)h \(minutes % 60)m"
    }

    var modeText: String {
        switch route.mode {
        case .airplane:
            "Flight"
        case .bicycle:
            "Bicycle"
        case .bus:
            "Bus"
        case .car:
            "Drive"
        case .ferry:
            "Ferry"
        case .rideshare:
            "Rideshare"
        case .subway:
            "Subway"
        case .train:
            "Train"
        case .transit:
            "Transit"
        case .walking:
            "Walk"
        }
    }

    var confidenceText: String {
        switch route.confidence {
        case .live:
            "Live"
        case .scheduled:
            "Scheduled"
        case .estimated:
            "Estimated"
        case .approximated:
            "Approximate"
        }
    }
}

enum ItineraryPresentationBuilder {
    static func days(for trip: Trip) -> [TimelineDayPresentation] {
        trip.itinerary.chronologicallySortedDays.map { day in
            TimelineDayPresentation(
                day: day,
                weather: trip.catalog.weatherSnapshots.first {
                    $0.id == day.weatherSnapshotID
                }
            )
        }
    }

    static func route(
        from item: ItineraryItem,
        to nextItem: ItineraryItem,
        in trip: Trip
    ) -> TimelineTransportPresentation? {
        guard
            let origin = item.location,
            let destination = nextItem.location
        else {
            return nil
        }

        return trip.itinerary.transportationLegs.first {
            locationsMatch($0.origin, origin)
                && locationsMatch($0.destination, destination)
        }.map {
            TimelineTransportPresentation(route: $0)
        }
    }

    private static func locationsMatch(
        _ left: TravelLocation,
        _ right: TravelLocation
    ) -> Bool {
        if let leftCoordinate = left.coordinate,
           let rightCoordinate = right.coordinate {
            return abs(
                leftCoordinate.latitude - rightCoordinate.latitude
            ) < 0.000_1
                && abs(
                    leftCoordinate.longitude - rightCoordinate.longitude
                ) < 0.000_1
        }

        return left.name.compare(
            right.name,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) == .orderedSame
    }
}
