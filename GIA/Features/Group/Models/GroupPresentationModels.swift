import Foundation

struct GroupMemberPresentation: Identifiable {
    let traveler: Traveler
    let viewerID: UUID
    let trip: Trip

    var id: UUID { traveler.id }

    var isViewer: Bool {
        traveler.id == viewerID
    }

    var canViewSensitiveDetails: Bool {
        GroupWorkspacePrivacy.canViewPreferences(
            of: traveler,
            viewerID: viewerID,
            trip: trip
        )
    }

    var roleLabel: String {
        traveler.id == trip.organizerTravelerID
            ? "Organizer"
            : "Member"
    }

    var visibilityLabel: String {
        switch traveler.preferences.visibility {
        case .privateToTraveler:
            "Only me"
        case .organizers:
            "Organizers"
        case .tripMembers:
            "Trip members"
        }
    }

    var availabilityLabel: String {
        let statuses = Set(traveler.availability.map(\.status))
        if statuses.contains(.unavailable) {
            return "Dates need review"
        }
        if statuses.contains(.tentative) {
            return "Tentative"
        }
        if statuses.contains(.available) {
            return "Available"
        }
        return "Not supplied"
    }

    var availabilitySymbol: String {
        let statuses = Set(traveler.availability.map(\.status))
        if statuses.contains(.unavailable) {
            return "exclamationmark"
        }
        if statuses.contains(.tentative) {
            return "questionmark"
        }
        if statuses.contains(.available) {
            return "checkmark"
        }
        return "minus"
    }

    var budgetLabel: String {
        guard canViewSensitiveDetails else {
            return "Private"
        }
        guard let budget = traveler.personalBudgetLimit else {
            return "Not supplied"
        }
        return GroupPresentationFormatting.money(budget)
    }

    var preferenceSummary: String {
        guard canViewSensitiveDetails else {
            return "Preferences are private"
        }
        var parts: [String] = []
        if !traveler.preferences.interests.isEmpty {
            parts.append(
                traveler.preferences.interests
                    .map(\.rawValue)
                    .sorted()
                    .prefix(2)
                    .joined(separator: " · ")
            )
        }
        if !traveler.preferences.dietaryRequirements.isEmpty {
            parts.append(
                "\(traveler.preferences.dietaryRequirements.count) dietary"
            )
        }
        if !traveler.preferences.accessibilityRequirements.isEmpty {
            parts.append(
                "\(traveler.preferences.accessibilityRequirements.count) "
                + "accessibility"
            )
        }
        return parts.isEmpty
            ? "No preferences supplied"
            : parts.joined(separator: " · ")
    }
}

struct GroupWorkspacePresentation {
    let trip: Trip
    let viewerID: UUID

    var members: [GroupMemberPresentation] {
        trip.travelers
            .sorted {
                if $0.id == trip.organizerTravelerID {
                    return true
                }
                if $1.id == trip.organizerTravelerID {
                    return false
                }
                return $0.displayName.localizedCaseInsensitiveCompare(
                    $1.displayName
                ) == .orderedAscending
            }
            .map {
                GroupMemberPresentation(
                    traveler: $0,
                    viewerID: viewerID,
                    trip: trip
                )
            }
    }

    var pendingInvitations: [TripInvitation] {
        (trip.collaboration?.invitations ?? [])
            .filter { $0.status == .pending }
            .sorted { $0.invitedAt < $1.invitedAt }
    }

    var availableCount: Int {
        trip.travelers.count {
            $0.availability.contains { $0.status == .available }
        }
    }

    var constraintCount: Int {
        trip.travelers.reduce(0) { partial, traveler in
            partial
                + traveler.preferences.dietaryRequirements.count
                + traveler.preferences.accessibilityRequirements.count
        }
    }

    var canManage: Bool {
        GroupWorkspacePrivacy.canManageMembers(
            travelerID: viewerID,
            trip: trip
        )
    }
}

enum GroupPresentationFormatting {
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
