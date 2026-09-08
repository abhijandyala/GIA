import Foundation

struct TransientPlanningResults: Sendable {
    var flightOffers: [FlightOffer] = []
    var hotelOffers: [HotelOffer] = []
    var places: [PlaceRecommendation] = []
    var events: [TimedEvent] = []
    var weather: [WeatherSnapshot] = []
    var routes: [TransportationLeg] = []
}

enum TransientTripAssembler {
    static func baseTrip(
        request: TripRequest,
        results: TransientPlanningResults = TransientPlanningResults(),
        lifecycleState: TripLifecycleState = .planning
    ) -> Trip {
        let organizer = Traveler(
            displayName: "You",
            initials: "YO",
            role: .organizer
        )
        return Trip(
            title: title(for: request),
            lifecycleState: lifecycleState,
            organizerTravelerID: organizer.id,
            request: request,
            travelers: [organizer],
            catalog: TripCatalog(
                flightOffers: results.flightOffers,
                hotelOffers: results.hotelOffers,
                places: results.places,
                timedEvents: results.events,
                weatherSnapshots: results.weather
            ),
            selections: TripSelections(
                flightOfferIDs:
                    selectedFlightID(in: results.flightOffers),
                hotelOfferIDs:
                    selectedHotelID(in: results.hotelOffers)
            ),
            itinerary: TripItinerary(
                days: itineraryDays(
                    request: request,
                    places: results.places,
                    events: results.events,
                    weather: results.weather
                ),
                transportationLegs: results.routes
            ),
            budget: TripBudget(totalLimit: request.totalBudget)
        )
    }

    static func finalizedTrip(
        request: TripRequest,
        results: TransientPlanningResults
    ) -> Trip {
        baseTrip(
            request: request,
            results: results,
            lifecycleState: .ready
        )
    }

    static func finalizedTrip(
        request: TripRequest,
        results: TransientPlanningResults,
        blueprint: TripPlanBlueprint
    ) -> Trip? {
        let criteria = TripGenerationCriteria(
            request: request,
            flightOffers: results.flightOffers,
            hotelOffers: results.hotelOffers,
            places: results.places,
            events: results.events,
            routes: results.routes,
            weather: results.weather
        )
        guard
            TripPlanBlueprintValidator.isValid(
                blueprint,
                criteria: criteria
            ),
            let days = itineraryDays(
                from: blueprint,
                request: request,
                results: results
            )
        else {
            return nil
        }

        var trip = baseTrip(
            request: request,
            results: results,
            lifecycleState: .ready
        )
        trip.title = blueprint.title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        trip.selections = TripSelections(
            flightOfferIDs: Set(
                blueprint.selectedFlightOfferIDs
            ),
            hotelOfferIDs: Set(
                blueprint.selectedHotelOfferIDs
            )
        )
        trip.itinerary = TripItinerary(
            days: days,
            transportationLegs: results.routes
        )
        return trip
    }

    private static func itineraryDays(
        from blueprint: TripPlanBlueprint,
        request: TripRequest,
        results: TransientPlanningResults
    ) -> [ItineraryDay]? {
        var mappedDays: [ItineraryDay] = []

        for day in blueprint.days {
            guard
                let date = date(
                    from: day.date,
                    timeZoneIdentifier:
                        day.timeZoneIdentifier
                )
            else {
                return nil
            }
            let items = day.items.compactMap {
                itineraryItem(
                    from: $0,
                    timeZoneIdentifier:
                        day.timeZoneIdentifier,
                    request: request,
                    results: results
                )
            }
            guard items.count == day.items.count else {
                return nil
            }
            mappedDays.append(
                ItineraryDay(
                    date: date,
                    timeZoneIdentifier:
                        day.timeZoneIdentifier,
                    items: items.sorted {
                        $0.start < $1.start
                    },
                    weatherSnapshotID:
                        matchingWeatherID(
                            for: date,
                            weather: results.weather,
                            calendar: calendar(
                                timeZoneIdentifier:
                                    day.timeZoneIdentifier
                            )
                        )
                )
            )
        }

        return mappedDays.sorted { $0.date < $1.date }
    }

    private static func itineraryItem(
        from planned: PlannedItineraryItem,
        timeZoneIdentifier: String,
        request: TripRequest,
        results: TransientPlanningResults
    ) -> ItineraryItem? {
        let notes = planned.rationale.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        switch planned.sourceKind {
        case .freeTime:
            guard planned.sourceIdentifier == nil else {
                return nil
            }
            return ItineraryItem(
                title: "Open group time",
                kind: .freeTime,
                status: .proposed,
                flexibility: .flexible,
                start: planned.start,
                end: planned.end,
                timeZoneIdentifier: timeZoneIdentifier,
                notes: notes
            )
        case .flight:
            guard
                let id = planned.sourceIdentifier,
                let offer = results.flightOffers.first(
                    where: { $0.id == id }
                )
            else {
                return nil
            }
            let firstSegment =
                offer.outboundSegments.first
                ?? offer.returnSegments.first
            let lastSegment =
                offer.returnSegments.last
                ?? offer.outboundSegments.last
            return ItineraryItem(
                title:
                    firstSegment.map {
                        "\($0.airlineName) flight"
                    }
                    ?? "Selected flight",
                subtitle:
                    lastSegment.map {
                        "Arrive \($0.destination.name)"
                    },
                kind: .flight,
                status: .proposed,
                flexibility: .fixed,
                start: planned.start,
                end: planned.end,
                timeZoneIdentifier: timeZoneIdentifier,
                location: lastSegment?.destination,
                reference: .flightOffer(id),
                estimatedCost: offer.totalPrice,
                notes: notes
            )
        case .hotel:
            guard
                let id = planned.sourceIdentifier,
                let offer = results.hotelOffers.first(
                    where: { $0.id == id }
                )
            else {
                return nil
            }
            return ItineraryItem(
                title: "Stay at \(offer.name)",
                subtitle: offer.roomDescription,
                kind: .hotelCheckIn,
                status: .proposed,
                flexibility: .fixed,
                start: planned.start,
                end: planned.end,
                timeZoneIdentifier: timeZoneIdentifier,
                location: offer.location,
                reference: .hotelOffer(id),
                estimatedCost: offer.totalPrice,
                notes: notes
            )
        case .place:
            guard
                let id = planned.sourceIdentifier,
                let place = results.places.first(
                    where: { $0.id == id }
                )
            else {
                return nil
            }
            let totalCost =
                place.estimatedCostPerTraveler.map {
                    Money(
                        amount:
                            $0.amount
                            * Decimal(
                                request.travelerCount ?? 1
                            ),
                        currencyCode: $0.currencyCode
                    )
                }
            return ItineraryItem(
                title: place.name,
                subtitle: place.summary,
                kind:
                    place.categories.contains(.restaurant)
                    || place.categories.contains(.cafe)
                    ? .meal
                    : .activity,
                status: .proposed,
                flexibility: .flexible,
                start: planned.start,
                end: planned.end,
                timeZoneIdentifier: timeZoneIdentifier,
                location: place.location,
                reference: .place(id),
                estimatedCost: totalCost,
                notes: notes
            )
        case .event:
            guard
                let id = planned.sourceIdentifier,
                let event = results.events.first(
                    where: { $0.id == id }
                )
            else {
                return nil
            }
            return ItineraryItem(
                title: event.title,
                subtitle: event.venueName ?? event.summary,
                kind: .activity,
                status: .proposed,
                flexibility: .fixed,
                start: planned.start,
                end: planned.end,
                timeZoneIdentifier: timeZoneIdentifier,
                location: event.location,
                reference: .timedEvent(id),
                notes: notes
            )
        case .route:
            guard
                let id = planned.sourceIdentifier,
                let route = results.routes.first(
                    where: { $0.id == id }
                )
            else {
                return nil
            }
            return ItineraryItem(
                title:
                    "\(route.mode.rawValue.capitalized) "
                    + "to \(route.destination.name)",
                subtitle:
                    "\(route.origin.name) → "
                    + route.destination.name,
                kind: .transportation,
                status: .proposed,
                flexibility: .fixed,
                start: planned.start,
                end: planned.end,
                timeZoneIdentifier: timeZoneIdentifier,
                location: route.destination,
                reference: .transportationLeg(id),
                estimatedCost: route.estimatedCost,
                notes: notes
            )
        }
    }

    private static func date(
        from dateOnly: String,
        timeZoneIdentifier: String
    ) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone =
            TimeZone(identifier: timeZoneIdentifier)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: dateOnly)
    }

    private static func calendar(
        timeZoneIdentifier: String
    ) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: timeZoneIdentifier)
            ?? .current
        return calendar
    }

    private static func itineraryDays(
        request: TripRequest,
        places: [PlaceRecommendation],
        events: [TimedEvent],
        weather: [WeatherSnapshot]
    ) -> [ItineraryDay] {
        let hasSchedulableEvent = events.contains {
            $0.status == .upcoming
                && $0.timeZoneIsResolved
                && $0.start != nil
        }
        guard !places.isEmpty || hasSchedulableEvent else {
            return []
        }
        guard let range = request.dateRange else { return [] }
        let timeZoneIdentifier =
            request.destinations.first?.timeZoneIdentifier
            ?? range.timeZoneIdentifier
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: timeZoneIdentifier) ?? .current
        let start = calendar.startOfDay(for: range.start)
        let end = calendar.startOfDay(for: range.end)
        let totalDays = min(
            max(
                calendar.dateComponents(
                    [.day],
                    from: start,
                    to: end
                ).day ?? 0,
                0
            ) + 1,
            14
        )
        var days = (0..<totalDays).compactMap { offset -> ItineraryDay? in
            guard
                let date = calendar.date(
                    byAdding: .day,
                    value: offset,
                    to: start
                )
            else {
                return nil
            }
            return ItineraryDay(
                date: date,
                timeZoneIdentifier: timeZoneIdentifier,
                weatherSnapshotID:
                    matchingWeatherID(
                        for: date,
                        weather: weather,
                        calendar: calendar
                    )
            )
        }

        for event in events
        where
            event.status == .upcoming
            && event.timeZoneIsResolved
            && event.start != nil
        {
            guard
                let start = event.start,
                let dayIndex = days.firstIndex(
                    where: {
                        calendar.isDate(
                            $0.date,
                            inSameDayAs: start
                        )
                    }
                )
            else {
                continue
            }
            let end =
                event.end
                ?? start.addingTimeInterval(7_200)
            days[dayIndex].items.append(
                ItineraryItem(
                    title: event.title,
                    subtitle: event.venueName,
                    kind: .activity,
                    status: .proposed,
                    flexibility: .fixed,
                    start: start,
                    end: end,
                    timeZoneIdentifier:
                        event.timeZoneIdentifier,
                    location: event.location,
                    reference: .timedEvent(event.id),
                    notes:
                        "Fixed-time sourced event. "
                        + "No booking has been made."
                )
            )
        }

        let rankedPlaces = places.sorted {
            if ($0.rating ?? 0) != ($1.rating ?? 0) {
                return ($0.rating ?? 0) > ($1.rating ?? 0)
            }
            return $0.name < $1.name
        }
        for (index, place) in
            rankedPlaces.prefix(max(totalDays * 2, 0)).enumerated()
        {
            guard !days.isEmpty else { break }
            let dayIndex = min(index / 2, days.count - 1)
            let preferredHour = index.isMultiple(of: 2) ? 10 : 14
            guard
                var itemStart = calendar.date(
                    bySettingHour: preferredHour,
                    minute: 0,
                    second: 0,
                    of: days[dayIndex].date
                )
            else {
                continue
            }
            let duration =
                place.estimatedDuration ?? 5_400
            var itemEnd = itemStart.addingTimeInterval(duration)
            if
                days[dayIndex].items.contains(
                    where: {
                        itemStart < $0.end && itemEnd > $0.start
                    }
                ),
                let shifted = calendar.date(
                    byAdding: .hour,
                    value: 3,
                    to: itemStart
                )
            {
                itemStart = shifted
                itemEnd = shifted.addingTimeInterval(duration)
            }
            let itemCost = place.estimatedCostPerTraveler.map {
                Money(
                    amount:
                        $0.amount
                        * Decimal(request.travelerCount ?? 1),
                    currencyCode: $0.currencyCode
                )
            }
            days[dayIndex].items.append(
                ItineraryItem(
                    title: place.name,
                    kind:
                        place.categories.contains(.restaurant)
                        || place.categories.contains(.cafe)
                        ? .meal
                        : .activity,
                    status: .proposed,
                    flexibility: .flexible,
                    start: itemStart,
                    end: itemEnd,
                    timeZoneIdentifier: timeZoneIdentifier,
                    location: place.location,
                    reference: .place(place.id),
                    estimatedCost: itemCost,
                    notes:
                        "Sourced recommendation. "
                        + "No reservation has been made."
                )
            )
        }

        for index in days.indices {
            days[index].items.sort { $0.start < $1.start }
        }
        return days
    }

    private static func matchingWeatherID(
        for date: Date,
        weather: [WeatherSnapshot],
        calendar: Calendar
    ) -> UUID? {
        weather.first {
            $0.periods.contains {
                calendar.isDate($0.start, inSameDayAs: date)
            }
        }?.id
    }

    private static func selectedFlightID(
        in offers: [FlightOffer]
    ) -> Set<UUID> {
        guard !offers.isEmpty else { return [] }
        let selected =
            offers.first {
                $0.badges.contains(.giaRecommended)
            }
            ?? offers.min {
                $0.totalPrice.currencyCode
                    == $1.totalPrice.currencyCode
                    ? $0.totalPrice.amount < $1.totalPrice.amount
                    : $0.totalDuration < $1.totalDuration
            }
        return selected.map { Set([$0.id]) } ?? []
    }

    private static func selectedHotelID(
        in offers: [HotelOffer]
    ) -> Set<UUID> {
        guard !offers.isEmpty else { return [] }
        let selected =
            offers.first {
                $0.badges.contains(.giaRecommended)
            }
            ?? offers.min {
                $0.totalPrice.currencyCode
                    == $1.totalPrice.currencyCode
                    ? $0.totalPrice.amount < $1.totalPrice.amount
                    : ($0.guestRating ?? 0) > ($1.guestRating ?? 0)
            }
        return selected.map { Set([$0.id]) } ?? []
    }

    private static func title(for request: TripRequest) -> String {
        let destination =
            request.destinations.first?.city
            ?? request.destinations.first?.name
            ?? "Trip"
        return "\(destination) Plan"
    }
}
