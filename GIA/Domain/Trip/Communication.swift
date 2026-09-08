import Foundation

enum TripMessageAuthorKind: String, Codable, CaseIterable, Sendable {
    case member
    case gia
    case system
}

enum TripMessageContext: Codable, Hashable, Sendable {
    case trip
    case itineraryItem(UUID)
    case decision(UUID)
}

enum SystemMessageEvent: String, Codable, CaseIterable, Sendable {
    case bookingSelectionChanged
    case decisionOpened
    case decisionResolved
    case itineraryChanged
    case memberInvited
    case memberJoined
    case memberRemoved
    case planUpdated
}

enum MessageReactionKind: String, Codable, CaseIterable, Sendable {
    case approve
    case celebrate
    case heart
    case question
}

struct MessageReaction:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: UUID
    var travelerID: UUID
    var kind: MessageReactionKind
    var createdAt: Date

    init(
        id: UUID = UUID(),
        travelerID: UUID,
        kind: MessageReactionKind,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.travelerID = travelerID
        self.kind = kind
        self.createdAt = createdAt
    }
}

struct MessageReadReceipt:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: UUID
    var travelerID: UUID
    var readAt: Date

    init(
        id: UUID = UUID(),
        travelerID: UUID,
        readAt: Date = Date()
    ) {
        self.id = id
        self.travelerID = travelerID
        self.readAt = readAt
    }
}

struct TripMessage: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var authorKind: TripMessageAuthorKind
    var authorTravelerID: UUID?
    var body: String
    var context: TripMessageContext
    var mentionedTravelerIDs: Set<UUID>
    var systemEvent: SystemMessageEvent?
    var reactions: [MessageReaction]
    var readReceipts: [MessageReadReceipt]
    var createdAt: Date
    var editedAt: Date?

    init(
        id: UUID = UUID(),
        authorKind: TripMessageAuthorKind,
        authorTravelerID: UUID? = nil,
        body: String,
        context: TripMessageContext = .trip,
        mentionedTravelerIDs: Set<UUID> = [],
        systemEvent: SystemMessageEvent? = nil,
        reactions: [MessageReaction] = [],
        readReceipts: [MessageReadReceipt] = [],
        createdAt: Date = Date(),
        editedAt: Date? = nil
    ) {
        self.id = id
        self.authorKind = authorKind
        self.authorTravelerID = authorTravelerID
        self.body = body
        self.context = context
        self.mentionedTravelerIDs = mentionedTravelerIDs
        self.systemEvent = systemEvent
        self.reactions = reactions
        self.readReceipts = readReceipts
        self.createdAt = createdAt
        self.editedAt = editedAt
    }
}

struct TripCommunication: Codable, Hashable, Sendable {
    var messages: [TripMessage]

    init(messages: [TripMessage] = []) {
        self.messages = messages
    }
}
