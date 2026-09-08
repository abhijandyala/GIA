import Foundation

enum PlanSourceKind: String, Codable, CaseIterable, Sendable {
    case flight
    case hotel
    case place
    case event
    case route
    case freeTime = "free_time"
}

struct PlannedItineraryItem: Codable, Hashable, Sendable {
    var sourceKind: PlanSourceKind
    var sourceIdentifier: UUID?
    var start: Date
    var end: Date
    var rationale: String
}

struct PlannedItineraryDay: Codable, Hashable, Sendable {
    var date: String
    var timeZoneIdentifier: String
    var items: [PlannedItineraryItem]
}

struct PlanRecommendationRationale: Codable, Hashable, Sendable {
    var sourceKind: PlanSourceKind
    var sourceIdentifier: UUID
    var reasons: [String]
}

struct TripPlanBlueprint: Codable, Hashable, Sendable {
    var title: String
    var summary: String
    var selectedFlightOfferIDs: [UUID]
    var selectedHotelOfferIDs: [UUID]
    var days: [PlannedItineraryDay]
    var recommendationRationales: [PlanRecommendationRationale]
    var warnings: [String]
}

struct TripPlanBlueprintIssue:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    enum Code: String, Codable, Sendable {
        case emptyTitle
        case invalidDay
        case invalidTimeZone
        case unknownSource
        case missingSource
        case unexpectedSource
        case reversedTime
        case outOfTripRange
        case overlappingItems
        case unknownFlightSelection
        case unknownHotelSelection
    }

    var code: Code
    var fieldPath: String
    var message: String

    var id: String {
        "\(code.rawValue):\(fieldPath)"
    }
}

enum TripPlanBlueprintValidator {
    static func issues(
        in blueprint: TripPlanBlueprint,
        criteria: TripGenerationCriteria
    ) -> [TripPlanBlueprintIssue] {
        var issues: [TripPlanBlueprintIssue] = []

        if blueprint.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        {
            issues.append(
                issue(
                    .emptyTitle,
                    path: "title",
                    message: "The plan title cannot be empty."
                )
            )
        }

        let flightIDs = Set(criteria.flightOffers.map(\.id))
        let hotelIDs = Set(criteria.hotelOffers.map(\.id))
        let placeIDs = Set(criteria.places.map(\.id))
        let eventIDs = Set(criteria.events.map(\.id))
        let routeIDs = Set(criteria.routes.map(\.id))

        for (index, id) in blueprint.selectedFlightOfferIDs.enumerated()
        where !flightIDs.contains(id) {
            issues.append(
                issue(
                    .unknownFlightSelection,
                    path: "selectedFlightOfferIDs[\(index)]",
                    message:
                        "The plan selected an unknown flight offer."
                )
            )
        }

        for (index, id) in blueprint.selectedHotelOfferIDs.enumerated()
        where !hotelIDs.contains(id) {
            issues.append(
                issue(
                    .unknownHotelSelection,
                    path: "selectedHotelOfferIDs[\(index)]",
                    message:
                        "The plan selected an unknown hotel offer."
                )
            )
        }

        for (dayIndex, day) in blueprint.days.enumerated() {
            if !isValidDateOnly(day.date) {
                issues.append(
                    issue(
                        .invalidDay,
                        path: "days[\(dayIndex)].date",
                        message:
                            "The itinerary day is not a valid date."
                    )
                )
            }

            if TimeZone(identifier: day.timeZoneIdentifier) == nil {
                issues.append(
                    issue(
                        .invalidTimeZone,
                        path:
                            "days[\(dayIndex)].timeZoneIdentifier",
                        message:
                            "The itinerary day has an invalid time zone."
                    )
                )
            }

            let sorted = day.items.sorted { $0.start < $1.start }
            for (itemIndex, item) in day.items.enumerated() {
                let path = "days[\(dayIndex)].items[\(itemIndex)]"
                if item.start > item.end {
                    issues.append(
                        issue(
                            .reversedTime,
                            path: path,
                            message:
                                "An itinerary item ends before it starts."
                        )
                    )
                }

                if
                    let range = criteria.request.dateRange,
                    (
                        item.start < range.start
                        || item.end
                            > range.end.addingTimeInterval(86_400)
                    )
                {
                    issues.append(
                        issue(
                            .outOfTripRange,
                            path: path,
                            message:
                                "An itinerary item falls outside the trip."
                        )
                    )
                }

                switch item.sourceKind {
                case .freeTime:
                    if item.sourceIdentifier != nil {
                        issues.append(
                            issue(
                                .unexpectedSource,
                                path: "\(path).sourceIdentifier",
                                message:
                                    "Free time cannot reference provider data."
                            )
                        )
                    }
                case .flight, .hotel, .place, .event, .route:
                    guard let sourceID = item.sourceIdentifier else {
                        issues.append(
                            issue(
                                .missingSource,
                                path: "\(path).sourceIdentifier",
                                message:
                                    "Sourced itinerary items require an ID."
                            )
                        )
                        continue
                    }

                    let sourceExists: Bool
                    switch item.sourceKind {
                    case .flight:
                        sourceExists = flightIDs.contains(sourceID)
                    case .hotel:
                        sourceExists = hotelIDs.contains(sourceID)
                    case .place:
                        sourceExists = placeIDs.contains(sourceID)
                    case .event:
                        sourceExists = eventIDs.contains(sourceID)
                    case .route:
                        sourceExists = routeIDs.contains(sourceID)
                    case .freeTime:
                        sourceExists = false
                    }

                    if !sourceExists {
                        issues.append(
                            issue(
                                .unknownSource,
                                path: "\(path).sourceIdentifier",
                                message:
                                    "The itinerary references unknown data."
                            )
                        )
                    }
                }
            }

            if sorted.count > 1 {
                for index in 1..<sorted.count
                where sorted[index].start < sorted[index - 1].end {
                    issues.append(
                        issue(
                            .overlappingItems,
                            path: "days[\(dayIndex)].items",
                            message:
                                "Itinerary items cannot overlap."
                        )
                    )
                    break
                }
            }
        }

        for (index, recommendation) in
            blueprint.recommendationRationales.enumerated()
        {
            let sourceExists: Bool
            switch recommendation.sourceKind {
            case .flight:
                sourceExists = flightIDs.contains(
                    recommendation.sourceIdentifier
                )
            case .hotel:
                sourceExists = hotelIDs.contains(
                    recommendation.sourceIdentifier
                )
            case .place:
                sourceExists = placeIDs.contains(
                    recommendation.sourceIdentifier
                )
            case .event:
                sourceExists = eventIDs.contains(
                    recommendation.sourceIdentifier
                )
            case .route:
                sourceExists = routeIDs.contains(
                    recommendation.sourceIdentifier
                )
            case .freeTime:
                sourceExists = false
            }

            if !sourceExists {
                issues.append(
                    issue(
                        .unknownSource,
                        path:
                            "recommendationRationales[\(index)]"
                            + ".sourceIdentifier",
                        message:
                            "A recommendation references unknown data."
                    )
                )
            }
        }

        return issues
    }

    static func isValid(
        _ blueprint: TripPlanBlueprint,
        criteria: TripGenerationCriteria
    ) -> Bool {
        issues(in: blueprint, criteria: criteria).isEmpty
    }

    private static func issue(
        _ code: TripPlanBlueprintIssue.Code,
        path: String,
        message: String
    ) -> TripPlanBlueprintIssue {
        TripPlanBlueprintIssue(
            code: code,
            fieldPath: path,
            message: message
        )
    }

    private static func isValidDateOnly(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false

        guard let date = formatter.date(from: value) else {
            return false
        }
        return formatter.string(from: date) == value
    }
}
