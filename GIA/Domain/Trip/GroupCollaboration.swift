import Foundation

enum TripInvitationStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case accepted
    case declined
    case revoked
    case expired
}

struct TripInvitation:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: UUID
    var inviteeName: String
    var inviteeEmailAddress: String
    var role: TravelerRole
    var status: TripInvitationStatus
    var invitedByTravelerID: UUID
    var invitedAt: Date
    var respondedAt: Date?
    var acceptedTravelerID: UUID?

    init(
        id: UUID = UUID(),
        inviteeName: String,
        inviteeEmailAddress: String,
        role: TravelerRole = .member,
        status: TripInvitationStatus = .pending,
        invitedByTravelerID: UUID,
        invitedAt: Date = Date(),
        respondedAt: Date? = nil,
        acceptedTravelerID: UUID? = nil
    ) {
        self.id = id
        self.inviteeName = inviteeName
        self.inviteeEmailAddress =
            inviteeEmailAddress.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).lowercased()
        self.role = role
        self.status = status
        self.invitedByTravelerID = invitedByTravelerID
        self.invitedAt = invitedAt
        self.respondedAt = respondedAt
        self.acceptedTravelerID = acceptedTravelerID
    }
}

enum MembershipAuditAction: String, Codable, CaseIterable, Sendable {
    case invited
    case joined
    case roleChanged
    case removed
    case left
    case preferenceVisibilityChanged
}

struct MembershipAuditRecord:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: UUID
    var action: MembershipAuditAction
    var actorTravelerID: UUID
    var subjectTravelerID: UUID?
    var subjectDisplayName: String
    var previousRole: TravelerRole?
    var resultingRole: TravelerRole?
    var occurredAt: Date
    var note: String?

    init(
        id: UUID = UUID(),
        action: MembershipAuditAction,
        actorTravelerID: UUID,
        subjectTravelerID: UUID? = nil,
        subjectDisplayName: String,
        previousRole: TravelerRole? = nil,
        resultingRole: TravelerRole? = nil,
        occurredAt: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.action = action
        self.actorTravelerID = actorTravelerID
        self.subjectTravelerID = subjectTravelerID
        self.subjectDisplayName = subjectDisplayName
        self.previousRole = previousRole
        self.resultingRole = resultingRole
        self.occurredAt = occurredAt
        self.note = note
    }
}

struct TripCollaboration: Codable, Hashable, Sendable {
    var invitations: [TripInvitation]
    var membershipHistory: [MembershipAuditRecord]

    init(
        invitations: [TripInvitation] = [],
        membershipHistory: [MembershipAuditRecord] = []
    ) {
        self.invitations = invitations
        self.membershipHistory = membershipHistory
    }
}

enum GroupWorkspacePrivacy {
    static func canAccessTrip(
        travelerID: UUID,
        trip: Trip
    ) -> Bool {
        trip.travelers.contains { $0.id == travelerID }
    }

    static func canManageMembers(
        travelerID: UUID,
        trip: Trip
    ) -> Bool {
        travelerID == trip.organizerTravelerID
            && canAccessTrip(travelerID: travelerID, trip: trip)
    }

    static func canViewPreferences(
        of subject: Traveler,
        viewerID: UUID,
        trip: Trip
    ) -> Bool {
        guard canAccessTrip(travelerID: viewerID, trip: trip) else {
            return false
        }
        if subject.id == viewerID {
            return true
        }
        switch subject.preferences.visibility {
        case .privateToTraveler:
            return false
        case .organizers:
            return viewerID == trip.organizerTravelerID
        case .tripMembers:
            return true
        }
    }
}
