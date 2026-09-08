import Foundation

enum TravelerRole: String, Codable, CaseIterable, Sendable {
    case organizer
    case member
}

enum PreferenceVisibility: String, Codable, CaseIterable, Sendable {
    case privateToTraveler
    case organizers
    case tripMembers
}

struct TravelerPreferences: Codable, Hashable, Sendable {
    var interests: Set<TripInterest>
    var dietaryRequirements: Set<DietaryRequirement>
    var accessibilityRequirements: Set<AccessibilityRequirement>
    var preferredPace: TravelPace
    var maximumWalkingMinutesPerLeg: Int?
    var notes: String?
    var visibility: PreferenceVisibility

    init(
        interests: Set<TripInterest> = [],
        dietaryRequirements: Set<DietaryRequirement> = [],
        accessibilityRequirements: Set<AccessibilityRequirement> = [],
        preferredPace: TravelPace = .balanced,
        maximumWalkingMinutesPerLeg: Int? = nil,
        notes: String? = nil,
        visibility: PreferenceVisibility = .tripMembers
    ) {
        self.interests = interests
        self.dietaryRequirements = dietaryRequirements
        self.accessibilityRequirements = accessibilityRequirements
        self.preferredPace = preferredPace
        self.maximumWalkingMinutesPerLeg =
            maximumWalkingMinutesPerLeg
        self.notes = notes
        self.visibility = visibility
    }
}

enum TravelPace: String, Codable, CaseIterable, Sendable {
    case relaxed
    case balanced
    case active
}

enum AvailabilityStatus: String, Codable, CaseIterable, Sendable {
    case available
    case unavailable
    case tentative
}

struct TravelerAvailability: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var range: TripDateRange
    var status: AvailabilityStatus
    var note: String?

    init(
        id: UUID = UUID(),
        range: TripDateRange,
        status: AvailabilityStatus,
        note: String? = nil
    ) {
        self.id = id
        self.range = range
        self.status = status
        self.note = note
    }
}

struct Traveler: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var accountIdentifier: String?
    var displayName: String
    var initials: String
    var role: TravelerRole
    var preferences: TravelerPreferences
    var availability: [TravelerAvailability]
    var personalBudgetLimit: Money?
    var joinedAt: Date

    init(
        id: UUID = UUID(),
        accountIdentifier: String? = nil,
        displayName: String,
        initials: String,
        role: TravelerRole,
        preferences: TravelerPreferences = TravelerPreferences(),
        availability: [TravelerAvailability] = [],
        personalBudgetLimit: Money? = nil,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.accountIdentifier = accountIdentifier
        self.displayName = displayName
        self.initials = initials
        self.role = role
        self.preferences = preferences
        self.availability = availability
        self.personalBudgetLimit = personalBudgetLimit
        self.joinedAt = joinedAt
    }
}
