import Foundation

enum JudgeDemoTripFactory {
    static let tripID = UUID(
        uuidString: "47000000-0000-0000-0000-000000000028"
    )!

    static func makeTrip(retrievedAt: Date = Date()) -> Trip {
        let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo")!
        let origin = location(
            "Hartsfield–Jackson Atlanta International Airport",
            city: "Atlanta",
            country: "United States",
            countryCode: "US",
            iataCode: "ATL",
            latitude: 33.6407,
            longitude: -84.4277,
            timeZone: "America/New_York"
        )
        let haneda = location(
            "Tokyo Haneda Airport",
            city: "Tokyo",
            country: "Japan",
            countryCode: "JP",
            iataCode: "HND",
            latitude: 35.5494,
            longitude: 139.7798
        )
        let hotelLocation = location(
            "Shibuya Stream Hotel",
            city: "Tokyo",
            country: "Japan",
            countryCode: "JP",
            latitude: 35.6573,
            longitude: 139.7030
        )
        let teamLabLocation = location(
            "teamLab Planets",
            city: "Tokyo",
            country: "Japan",
            countryCode: "JP",
            latitude: 35.6491,
            longitude: 139.7898
        )
        let restaurantLocation = location(
            "T's Tantan",
            city: "Tokyo",
            country: "Japan",
            countryCode: "JP",
            latitude: 35.6812,
            longitude: 139.7671
        )
        let museumLocation = location(
            "Tokyo National Museum",
            city: "Tokyo",
            country: "Japan",
            countryCode: "JP",
            latitude: 35.7188,
            longitude: 139.7765
        )
        let templeLocation = location(
            "Sensō-ji",
            city: "Tokyo",
            country: "Japan",
            countryCode: "JP",
            latitude: 35.7148,
            longitude: 139.7967
        )
        let cruiseLocation = location(
            "Sumida River Pier",
            city: "Tokyo",
            country: "Japan",
            countryCode: "JP",
            latitude: 35.7107,
            longitude: 139.7982
        )
        let startDay = date(
            year: 2027,
            month: 4,
            day: 3,
            hour: 0,
            timeZone: tokyoTimeZone
        )
        let secondDay = date(
            year: 2027,
            month: 4,
            day: 4,
            hour: 0,
            timeZone: tokyoTimeZone
        )
        let endDay = date(
            year: 2027,
            month: 4,
            day: 10,
            hour: 0,
            timeZone: tokyoTimeZone
        )
        let travelProvenance = provenance(
            provider: .serpApi,
            identifier: "judge-demo-travel",
            retrievedAt: retrievedAt,
            sourceURL: "https://www.google.com/travel"
        )
        let placeProvenance = provenance(
            provider: .geoapify,
            identifier: "judge-demo-places",
            retrievedAt: retrievedAt,
            sourceURL: "https://www.geoapify.com"
        )

        let flights = flightOffers(
            origin: origin,
            destination: haneda,
            startDay: startDay,
            endDay: endDay,
            provenance: travelProvenance
        )
        let hotels = hotelOffers(
            primaryLocation: hotelLocation,
            provenance: travelProvenance
        )
        let teamLab = PlaceRecommendation(
            providerPlaceIdentifier: "demo-teamlab",
            name: teamLabLocation.name,
            location: teamLabLocation,
            categories: [.museum, .attraction],
            summary: "Immersive digital art installation.",
            rating: 4.6,
            reviewCount: 42_000,
            priceLevel: 3,
            estimatedCostPerTraveler: money(42),
            estimatedDuration: 7_200,
            openingHours: OpeningHours(
                rawText: ["Saturday: 9:00 AM–10:00 PM"],
                isOpenAtRetrieval: nil
            ),
            accessibilityFeatures: [.wheelchairAccess],
            indoor: true,
            reservationRequired: true,
            provenance: placeProvenance
        )
        let restaurant = PlaceRecommendation(
            providerPlaceIdentifier: "demo-ts-tantan",
            name: restaurantLocation.name,
            location: restaurantLocation,
            categories: [.restaurant],
            summary: "Vegan Japanese ramen near Tokyo Station.",
            rating: 4.5,
            reviewCount: 2_800,
            priceLevel: 2,
            estimatedCostPerTraveler: money(24),
            estimatedDuration: 4_500,
            openingHours: OpeningHours(
                rawText: ["Saturday: 10:00 AM–10:00 PM"],
                isOpenAtRetrieval: nil
            ),
            dietaryOptions: [.vegan, .vegetarian, .dairyFree],
            accessibilityFeatures: [.wheelchairAccess],
            indoor: true,
            reservationRequired: false,
            provenance: placeProvenance
        )
        let museum = PlaceRecommendation(
            providerPlaceIdentifier: "demo-tokyo-museum",
            name: museumLocation.name,
            location: museumLocation,
            categories: [.museum],
            summary: "Japanese art and archaeology collections.",
            rating: 4.6,
            reviewCount: 25_000,
            priceLevel: 1,
            estimatedCostPerTraveler: money(7),
            estimatedDuration: 7_200,
            openingHours: OpeningHours(
                rawText: ["Saturday: 9:30 AM–5:00 PM"],
                isOpenAtRetrieval: nil
            ),
            accessibilityFeatures: [
                .wheelchairAccess,
                .stepFreeAccess
            ],
            indoor: true,
            provenance: placeProvenance
        )
        let temple = PlaceRecommendation(
            providerPlaceIdentifier: "demo-sensoji",
            name: templeLocation.name,
            location: templeLocation,
            categories: [.landmark, .attraction],
            summary: "Historic Buddhist temple in Asakusa.",
            rating: 4.5,
            reviewCount: 78_000,
            estimatedCostPerTraveler: money(0),
            estimatedDuration: 5_400,
            openingHours: OpeningHours(
                rawText: ["Sunday: Open 24 hours"],
                isOpenAtRetrieval: nil
            ),
            accessibilityFeatures: [.wheelchairAccess],
            indoor: false,
            provenance: placeProvenance
        )
        let cruiseStart = date(
            year: 2027,
            month: 4,
            day: 4,
            hour: 19,
            timeZone: tokyoTimeZone
        )
        let cruise = TimedEvent(
            providerEventIdentifier: "demo-sumida-cruise",
            title: "Sumida River Night Cruise",
            summary: "Reserved evening city-light cruise.",
            venueName: cruiseLocation.name,
            location: cruiseLocation,
            start: cruiseStart,
            end: cruiseStart.addingTimeInterval(5_400),
            rawDateText: "Sun, Apr 4, 7:00 PM–8:30 PM",
            timeZoneIdentifier: tokyoTimeZone.identifier,
            timeZoneIsResolved: true,
            status: .upcoming,
            schedulingTraits: [
                .fixedTime,
                .ticketRequired,
                .outdoor,
                .weatherDependent
            ],
            sourceURL: URL(string: "https://www.google.com/search?q=tokyo+events"),
            ticketURLs: [
                URL(string: "https://www.google.com/search?q=sumida+river+cruise")!
            ],
            provenance: provenance(
                provider: .serpApi,
                identifier: "judge-demo-event",
                retrievedAt: retrievedAt,
                sourceURL: "https://www.google.com/search?q=tokyo+events"
            )
        )
        let weatherOne = weather(
            id: UUID(),
            location: hotelLocation,
            day: startDay,
            description: "Clear and mild",
            condition: .clear,
            temperature: 18,
            rain: 0.12,
            retrievedAt: retrievedAt
        )
        let weatherTwo = weather(
            id: UUID(),
            location: hotelLocation,
            day: secondDay,
            description: "Light afternoon rain",
            condition: .rain,
            temperature: 16,
            rain: 0.62,
            retrievedAt: retrievedAt
        )

        let dayOneItems = [
            item(
                teamLab.name,
                kind: .activity,
                day: startDay,
                hour: 10,
                minutes: 120,
                location: teamLabLocation,
                reference: .place(teamLab.id),
                cost: 42,
                fixed: true
            ),
            item(
                restaurant.name,
                kind: .meal,
                day: startDay,
                hour: 13,
                minutes: 75,
                location: restaurantLocation,
                reference: .place(restaurant.id),
                cost: 24
            ),
            item(
                museum.name,
                kind: .activity,
                day: startDay,
                hour: 15,
                minutes: 120,
                location: museumLocation,
                reference: .place(museum.id),
                cost: 7
            )
        ]
        let dayTwoItems = [
            item(
                temple.name,
                kind: .activity,
                day: secondDay,
                hour: 9,
                minutes: 90,
                location: templeLocation,
                reference: .place(temple.id),
                cost: 0
            ),
            ItineraryItem(
                title: cruise.title,
                kind: .activity,
                status: .selected,
                flexibility: .fixed,
                start: cruiseStart,
                end: cruiseStart.addingTimeInterval(5_400),
                timeZoneIdentifier: tokyoTimeZone.identifier,
                location: cruiseLocation,
                reference: .timedEvent(cruise.id),
                estimatedCost: money(55),
                notes:
                    "Demo selection only. External ticket purchase "
                    + "is still required."
            )
        ]
        let itinerary = TripItinerary(
            days: [
                ItineraryDay(
                    date: startDay,
                    timeZoneIdentifier: tokyoTimeZone.identifier,
                    items: dayOneItems,
                    weatherSnapshotID: weatherOne.id
                ),
                ItineraryDay(
                    date: secondDay,
                    timeZoneIdentifier: tokyoTimeZone.identifier,
                    items: dayTwoItems,
                    weatherSnapshotID: weatherTwo.id
                )
            ],
            transportationLegs: [
                route(
                    from: teamLabLocation,
                    to: restaurantLocation,
                    mode: .transit,
                    minutes: 28,
                    cost: 4,
                    retrievedAt: retrievedAt
                ),
                route(
                    from: restaurantLocation,
                    to: museumLocation,
                    mode: .transit,
                    minutes: 22,
                    cost: 3,
                    retrievedAt: retrievedAt
                ),
                route(
                    from: templeLocation,
                    to: cruiseLocation,
                    mode: .walking,
                    minutes: 8,
                    cost: 0,
                    retrievedAt: retrievedAt
                )
            ]
        )
        let request = TripRequest(
            origin: origin,
            destinations: [haneda],
            dateRange: TripDateRange(
                start: startDay,
                end: endDay,
                timeZoneIdentifier: tokyoTimeZone.identifier
            ),
            durationDays: 8,
            travelerCount: 4,
            totalBudget: money(6_000),
            interests: [.art, .culture, .food, .technology],
            dietaryRequirements: [.vegetarian],
            accessibilityRequirements: [.reducedWalking],
            preferredPace: .balanced
        )
        let travelers = makeTravelers(
            range: request.dateRange!,
            joinedAt: retrievedAt
        )
        let organizer = travelers[0]
        let eligibleIDs = Set(travelers.map(\.id))
        let decisions = [
            GroupDecision(
                title: "Approve Shibuya Stream Hotel",
                subject: .hotelOffer(hotels[0].id),
                rule: .majority,
                state: .approved,
                votes: [
                    vote(travelers[0], .approve, at: retrievedAt),
                    vote(travelers[1], .approve, at: retrievedAt),
                    vote(travelers[2], .approve, at: retrievedAt)
                ],
                proposedByTravelerID: organizer.id,
                proposedAt: retrievedAt,
                resolvedAt: retrievedAt,
                eligibleTravelerIDs: eligibleIDs,
                revisionNumber: 1
            ),
            GroupDecision(
                title: "Add the Sumida night cruise",
                subject: .itineraryItem(dayTwoItems[1].id),
                rule: .majority,
                state: .voting,
                votes: [
                    vote(travelers[1], .approve, at: retrievedAt),
                    vote(travelers[2], .approve, at: retrievedAt)
                ],
                proposedByTravelerID: organizer.id,
                proposedAt: retrievedAt,
                eligibleTravelerIDs: eligibleIDs,
                revisionNumber: 1
            )
        ]
        let collaboration = TripCollaboration(
            membershipHistory: travelers.map {
                MembershipAuditRecord(
                    action: .joined,
                    actorTravelerID: $0.id,
                    subjectTravelerID: $0.id,
                    subjectDisplayName: $0.displayName,
                    resultingRole: $0.role,
                    occurredAt: $0.joinedAt
                )
            }
        )
        let communication = TripCommunication(
            messages: [
                TripMessage(
                    authorKind: .system,
                    body: "The judge-safe Tokyo demo plan is ready.",
                    systemEvent: .planUpdated,
                    createdAt: retrievedAt
                ),
                TripMessage(
                    authorKind: .gia,
                    body:
                        "I connected demo flights, stays, weather, "
                        + "routes, activities, and group decisions.",
                    createdAt: retrievedAt.addingTimeInterval(30)
                ),
                TripMessage(
                    authorKind: .member,
                    authorTravelerID: travelers[1].id,
                    body:
                        "The museum and vegan ramen options work for me.",
                    context: .itineraryItem(dayOneItems[2].id),
                    mentionedTravelerIDs: [organizer.id],
                    reactions: [
                        MessageReaction(
                            travelerID: travelers[2].id,
                            kind: .approve,
                            createdAt: retrievedAt
                        )
                    ],
                    createdAt: retrievedAt.addingTimeInterval(60)
                )
            ]
        )

        return Trip(
            id: tripID,
            title: "Tokyo Together",
            lifecycleState: .ready,
            organizerTravelerID: organizer.id,
            request: request,
            travelers: travelers,
            catalog: TripCatalog(
                flightOffers: flights,
                hotelOffers: hotels,
                places: [teamLab, restaurant, museum, temple],
                timedEvents: [cruise],
                weatherSnapshots: [weatherOne, weatherTwo]
            ),
            selections: TripSelections(
                flightOfferIDs: [flights[0].id],
                hotelOfferIDs: [hotels[0].id],
                placeIDs: [teamLab.id, restaurant.id, museum.id]
            ),
            itinerary: itinerary,
            budget: TripBudget(
                totalLimit: request.totalBudget,
                allocations: [
                    allocation(.flights, 1_600),
                    allocation(.lodging, 2_000),
                    allocation(.food, 800),
                    allocation(.activities, 700),
                    allocation(.transportation, 300),
                    allocation(.emergencyReserve, 600)
                ]
            ),
            decisions: decisions,
            collaboration: collaboration,
            communication: communication,
            createdAt: retrievedAt,
            updatedAt: retrievedAt
        )
    }

    private static func flightOffers(
        origin: TravelLocation,
        destination: TravelLocation,
        startDay: Date,
        endDay: Date,
        provenance: DataProvenance
    ) -> [FlightOffer] {
        let outbound = startDay.addingTimeInterval(-14_400)
        let returnDate = endDay.addingTimeInterval(39_600)
        let direct = FlightOffer(
            providerOfferIdentifier: "demo-delta-direct",
            outboundSegments: [
                segment(
                    airline: "Delta",
                    code: "DL",
                    number: "DL 295",
                    origin: origin,
                    destination: destination,
                    departure: outbound,
                    duration: 50_400
                )
            ],
            returnSegments: [
                segment(
                    airline: "Delta",
                    code: "DL",
                    number: "DL 296",
                    origin: destination,
                    destination: origin,
                    departure: returnDate,
                    duration: 43_200
                )
            ],
            totalDuration: 93_600,
            totalPrice: money(1_248),
            baggage: BaggageAllowance(
                personalItems: 1,
                carryOnBags: 1,
                checkedBags: 1,
                rawDescription:
                    "1 carry-on · 1 checked bag included"
            ),
            badges: [.giaRecommended, .fewestStops],
            carbonEmissionsGrams: 1_420_000,
            priceInsight: PriceInsight(
                level: .typical,
                typicalLow: money(1_090),
                typicalHigh: money(1_520),
                observedLowest: money(1_035)
            ),
            refundable: false,
            bookingURL: URL(
                string: "https://www.google.com/travel/flights"
            ),
            provenance: provenance
        )
        let sanFrancisco = location(
            "San Francisco International Airport",
            city: "San Francisco",
            country: "United States",
            countryCode: "US",
            iataCode: "SFO",
            latitude: 37.6213,
            longitude: -122.3790,
            timeZone: "America/Los_Angeles"
        )
        let valueDeparture = outbound.addingTimeInterval(-3_600)
        let value = FlightOffer(
            providerOfferIdentifier: "demo-united-one-stop",
            outboundSegments: [
                segment(
                    airline: "United",
                    code: "UA",
                    number: "UA 125",
                    origin: origin,
                    destination: sanFrancisco,
                    departure: valueDeparture,
                    duration: 18_000
                ),
                segment(
                    airline: "United",
                    code: "UA",
                    number: "UA 837",
                    origin: sanFrancisco,
                    destination: destination,
                    departure:
                        valueDeparture.addingTimeInterval(25_200),
                    duration: 39_600
                )
            ],
            returnSegments: [],
            totalDuration: 64_800,
            totalPrice: money(1_035),
            baggage: BaggageAllowance(
                personalItems: 1,
                carryOnBags: 1,
                checkedBags: 0,
                checkedBagFee: money(75),
                rawDescription:
                    "1 carry-on · checked bag available for a fee"
            ),
            badges: [.lowestPrice],
            carbonEmissionsGrams: 1_560_000,
            priceInsight: PriceInsight(
                level: .low,
                typicalLow: money(1_090),
                typicalHigh: money(1_520),
                observedLowest: money(1_035)
            ),
            bookingURL: URL(
                string: "https://www.google.com/travel/flights"
            ),
            provenance: provenance
        )
        return [direct, value]
    }

    private static func hotelOffers(
        primaryLocation: TravelLocation,
        provenance: DataProvenance
    ) -> [HotelOffer] {
        let primary = HotelOffer(
            providerOfferIdentifier: "demo-shibuya-stream",
            name: "Shibuya Stream Hotel",
            location: primaryLocation,
            lodgingType: .hotel,
            starRating: 4,
            guestRating: 4.6,
            guestRatingScale: 5,
            reviewCount: 2_100,
            nightlyPrice: money(238),
            totalPrice: money(1_666),
            taxesAndFeesIncluded: true,
            roomDescription:
                "Central group-friendly rooms beside Shibuya Station.",
            amenities: [.breakfast, .laundry, .wifi],
            checkInTime: "3:00 PM",
            checkOutTime: "11:00 AM",
            cancellationPolicy: CancellationPolicy(
                summary: "Free cancellation available in demo source"
            ),
            badges: [.giaRecommended, .flexible],
            bookingURL: URL(
                string: "https://www.google.com/travel/hotels"
            ),
            provenance: provenance
        )
        let alternative = HotelOffer(
            providerOfferIdentifier: "demo-gracery",
            name: "Hotel Gracery Shinjuku",
            location: location(
                "Hotel Gracery Shinjuku",
                city: "Tokyo",
                country: "Japan",
                countryCode: "JP",
                latitude: 35.6951,
                longitude: 139.7022
            ),
            lodgingType: .hotel,
            starRating: 4,
            guestRating: 4.4,
            guestRatingScale: 5,
            reviewCount: 9_400,
            nightlyPrice: money(188),
            totalPrice: money(1_316),
            taxesAndFeesIncluded: true,
            amenities: [.laundry, .wifi],
            checkInTime: "2:00 PM",
            checkOutTime: "11:00 AM",
            badges: [.lowestPrice],
            bookingURL: URL(
                string: "https://www.google.com/travel/hotels"
            ),
            provenance: provenance
        )
        return [primary, alternative]
    }

    private static func makeTravelers(
        range: TripDateRange,
        joinedAt: Date
    ) -> [Traveler] {
        [
            Traveler(
                accountIdentifier: "avery@demo.gia",
                displayName: "Avery",
                initials: "AV",
                role: .organizer,
                preferences: TravelerPreferences(
                    interests: [.culture, .food, .technology],
                    dietaryRequirements: [.vegetarian],
                    visibility: .tripMembers
                ),
                availability: [
                    availability(range, .available)
                ],
                personalBudgetLimit: money(2_000),
                joinedAt: joinedAt
            ),
            Traveler(
                accountIdentifier: "maya@demo.gia",
                displayName: "Maya",
                initials: "MK",
                role: .member,
                preferences: TravelerPreferences(
                    interests: [.art, .food],
                    dietaryRequirements: [.vegan],
                    accessibilityRequirements: [.reducedWalking],
                    visibility: .organizers
                ),
                availability: [
                    availability(range, .available)
                ],
                personalBudgetLimit: money(1_500),
                joinedAt: joinedAt
            ),
            Traveler(
                accountIdentifier: "noah@demo.gia",
                displayName: "Noah",
                initials: "NR",
                role: .member,
                preferences: TravelerPreferences(
                    interests: [.technology, .nightlife],
                    visibility: .privateToTraveler
                ),
                availability: [
                    availability(range, .available)
                ],
                personalBudgetLimit: money(1_350),
                joinedAt: joinedAt
            ),
            Traveler(
                accountIdentifier: "sofia@demo.gia",
                displayName: "Sofia",
                initials: "SL",
                role: .member,
                preferences: TravelerPreferences(
                    interests: [.shopping, .relaxation],
                    visibility: .tripMembers
                ),
                availability: [
                    availability(range, .tentative)
                ],
                personalBudgetLimit: money(1_400),
                joinedAt: joinedAt
            )
        ]
    }

    private static func segment(
        airline: String,
        code: String,
        number: String,
        origin: TravelLocation,
        destination: TravelLocation,
        departure: Date,
        duration: TimeInterval
    ) -> FlightSegment {
        FlightSegment(
            airlineCode: code,
            airlineName: airline,
            flightNumber: number,
            origin: origin,
            destination: destination,
            departure: departure,
            arrival: departure.addingTimeInterval(duration),
            departureTimeZoneIdentifier:
                origin.timeZoneIdentifier ?? "UTC",
            arrivalTimeZoneIdentifier:
                destination.timeZoneIdentifier ?? "UTC",
            duration: duration,
            travelClass: .economy
        )
    }

    private static func item(
        _ title: String,
        kind: ItineraryItemKind,
        day: Date,
        hour: Int,
        minutes: Int,
        location: TravelLocation,
        reference: ItineraryReference,
        cost: Decimal,
        fixed: Bool = false
    ) -> ItineraryItem {
        let zone = TimeZone(identifier: "Asia/Tokyo")!
        let start = Calendar.gregorian(
            timeZone: zone
        ).date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: day
        )!
        return ItineraryItem(
            title: title,
            kind: kind,
            status: .selected,
            flexibility: fixed ? .fixed : .flexible,
            start: start,
            end: start.addingTimeInterval(
                TimeInterval(minutes * 60)
            ),
            timeZoneIdentifier: zone.identifier,
            location: location,
            reference: reference,
            estimatedCost: money(cost),
            notes: "Bundled judge-safe demo data."
        )
    }

    private static func route(
        from origin: TravelLocation,
        to destination: TravelLocation,
        mode: TransportationMode,
        minutes: Int,
        cost: Decimal,
        retrievedAt: Date
    ) -> TransportationLeg {
        TransportationLeg(
            origin: origin,
            destination: destination,
            mode: mode,
            duration: TimeInterval(minutes * 60),
            estimatedCost: money(cost),
            bufferDuration: mode == .walking ? 300 : 600,
            confidence: .estimated,
            provenance: provenance(
                provider: .geoapify,
                identifier: "judge-demo-route",
                retrievedAt: retrievedAt,
                sourceURL: "https://www.geoapify.com"
            )
        )
    }

    private static func weather(
        id: UUID,
        location: TravelLocation,
        day: Date,
        description: String,
        condition: WeatherConditionCategory,
        temperature: Double,
        rain: Double,
        retrievedAt: Date
    ) -> WeatherSnapshot {
        WeatherSnapshot(
            id: id,
            location: location,
            timeZoneIdentifier: "Asia/Tokyo",
            periods: [
                WeatherPeriod(
                    start: day,
                    end: day.addingTimeInterval(86_400),
                    condition: condition,
                    providerDescription: description,
                    temperatureCelsius: temperature,
                    precipitationProbability: rain,
                    windKilometersPerHour: 14
                )
            ],
            provenance: provenance(
                provider: .weatherAPI,
                identifier: "judge-demo-weather",
                retrievedAt: retrievedAt,
                sourceURL: "https://www.weatherapi.com"
            )
        )
    }

    private static func location(
        _ name: String,
        city: String,
        country: String,
        countryCode: String,
        iataCode: String? = nil,
        latitude: Double,
        longitude: Double,
        timeZone: String = "Asia/Tokyo"
    ) -> TravelLocation {
        TravelLocation(
            name: name,
            city: city,
            country: country,
            countryCode: countryCode,
            iataCode: iataCode,
            coordinate: GeoCoordinate(
                latitude: latitude,
                longitude: longitude
            ),
            timeZoneIdentifier: timeZone
        )
    }

    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        timeZone: TimeZone
    ) -> Date {
        Calendar.gregorian(timeZone: timeZone).date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        )!
    }

    private static func provenance(
        provider: TravelProvider,
        identifier: String,
        retrievedAt: Date,
        sourceURL: String
    ) -> DataProvenance {
        DataProvenance(
            provider: provider,
            providerIdentifier: identifier,
            origin: .demo,
            retrievedAt: retrievedAt,
            sourceURL: URL(string: sourceURL)
        )
    }

    private static func money(_ amount: Decimal) -> Money {
        Money(amount: amount, currencyCode: "USD")
    }

    private static func allocation(
        _ category: BudgetCategory,
        _ limit: Decimal
    ) -> BudgetAllocation {
        BudgetAllocation(
            category: category,
            limit: money(limit),
            estimatedSpend: money(0),
            confirmedSpend: money(0)
        )
    }

    private static func availability(
        _ range: TripDateRange,
        _ status: AvailabilityStatus
    ) -> TravelerAvailability {
        TravelerAvailability(range: range, status: status)
    }

    private static func vote(
        _ traveler: Traveler,
        _ choice: VoteChoice,
        at date: Date
    ) -> TripVote {
        TripVote(
            travelerID: traveler.id,
            choice: choice,
            submittedAt: date
        )
    }
}

private extension Calendar {
    static func gregorian(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
