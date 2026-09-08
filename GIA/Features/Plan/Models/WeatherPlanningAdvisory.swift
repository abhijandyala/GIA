import Foundation

enum WeatherAdvisorySeverity: String, Codable, Sendable {
    case information
    case caution
    case critical
}

enum WeatherAdvisoryAction: String, Codable, Sendable {
    case monitorAlert
    case preferIndoor
    case rescheduleOutdoor
    case allowExtraTravelTime
    case avoidOutdoor
}

enum WeatherAdvisorySource: Codable, Hashable, Sendable {
    case period(UUID)
    case alert(UUID)
}

struct WeatherPlanningAdvisory:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    var source: WeatherAdvisorySource
    var severity: WeatherAdvisorySeverity
    var action: WeatherAdvisoryAction
    var message: String
    var effectiveStart: Date?
    var effectiveEnd: Date?

    var id: String {
        "\(sourceKey):\(action.rawValue)"
    }

    private var sourceKey: String {
        switch source {
        case .period(let id):
            "period:\(id.uuidString)"
        case .alert(let id):
            "alert:\(id.uuidString)"
        }
    }
}

enum WeatherAdvisoryEngine {
    static func advisories(
        for snapshots: [WeatherSnapshot]
    ) -> [WeatherPlanningAdvisory] {
        var results: [WeatherPlanningAdvisory] = []

        for snapshot in snapshots {
            for alert in snapshot.alerts {
                results.append(
                    advisory(for: alert)
                )
            }

            for period in snapshot.periods {
                results.append(
                    contentsOf: advisories(for: period)
                )
            }
        }

        var seen = Set<String>()
        return results.filter {
            seen.insert($0.id).inserted
        }
    }

    private static func advisory(
        for alert: WeatherAlert
    ) -> WeatherPlanningAdvisory {
        let isCritical =
            alert.severity == .severe
            || alert.severity == .extreme

        return WeatherPlanningAdvisory(
            source: .alert(alert.id),
            severity: isCritical ? .critical : .caution,
            action: isCritical ? .avoidOutdoor : .monitorAlert,
            message: alert.headline,
            effectiveStart: alert.effectiveAt,
            effectiveEnd: alert.expiresAt
        )
    }

    private static func advisories(
        for period: WeatherPeriod
    ) -> [WeatherPlanningAdvisory] {
        var values: [WeatherPlanningAdvisory] = []

        switch period.condition {
        case .storm:
            values.append(
                periodAdvisory(
                    period,
                    severity: .critical,
                    action: .avoidOutdoor,
                    message:
                        "Avoid outdoor activities during the storm."
                )
            )
        case .snow:
            values.append(
                periodAdvisory(
                    period,
                    severity: .caution,
                    action: .allowExtraTravelTime,
                    message:
                        "Allow additional transportation time for snow."
                )
            )
        case .rain:
            if
                let probability = period.precipitationProbability,
                probability >= 0.60
            {
                values.append(
                    periodAdvisory(
                        period,
                        severity: .caution,
                        action: .preferIndoor,
                        message:
                            "Prefer an indoor activity during likely rain."
                    )
                )
            }
        case .wind:
            values.append(
                periodAdvisory(
                    period,
                    severity: .caution,
                    action: .rescheduleOutdoor,
                    message:
                        "Review exposed outdoor activities for strong wind."
                )
            )
        case .clear, .cloudy, .fog, .unknown:
            break
        }

        if
            let wind = period.windKilometersPerHour,
            wind >= 50,
            period.condition != .wind
        {
            values.append(
                periodAdvisory(
                    period,
                    severity: .caution,
                    action: .rescheduleOutdoor,
                    message:
                        "Review outdoor activities for winds above 50 km/h."
                )
            )
        }

        if
            let temperature = period.temperatureCelsius,
            temperature >= 35 || temperature <= 0
        {
            values.append(
                periodAdvisory(
                    period,
                    severity: .caution,
                    action: .preferIndoor,
                    message:
                        "Prefer climate-controlled activities during "
                        + "extreme temperatures."
                )
            )
        }

        return values
    }

    private static func periodAdvisory(
        _ period: WeatherPeriod,
        severity: WeatherAdvisorySeverity,
        action: WeatherAdvisoryAction,
        message: String
    ) -> WeatherPlanningAdvisory {
        WeatherPlanningAdvisory(
            source: .period(period.id),
            severity: severity,
            action: action,
            message: message,
            effectiveStart: period.start,
            effectiveEnd: period.end
        )
    }
}
