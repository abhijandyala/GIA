import Foundation

struct TripMessagePresentation: Identifiable {
    let message: TripMessage
    let trip: Trip
    let viewerID: UUID

    var id: UUID { message.id }

    var authorLabel: String {
        switch message.authorKind {
        case .gia:
            "GIA · ASSISTANT"
        case .system:
            "TRIP UPDATE"
        case .member:
            trip.travelers.first {
                $0.id == message.authorTravelerID
            }?.displayName ?? "Former member"
        }
    }

    var authorInitials: String {
        switch message.authorKind {
        case .gia:
            "GIΛ"
        case .system:
            "•"
        case .member:
            trip.travelers.first {
                $0.id == message.authorTravelerID
            }?.initials ?? "—"
        }
    }

    var isOwnMessage: Bool {
        message.authorKind == .member
            && message.authorTravelerID == viewerID
    }

    var isUnread: Bool {
        !message.readReceipts.contains {
            $0.travelerID == viewerID
        }
    }

    var contextLabel: String {
        CommunicationContextResolver.label(
            for: message.context,
            in: trip
        )
    }

    var timestamp: String {
        message.createdAt.formatted(
            date: .omitted,
            time: .shortened
        )
    }

    var mentionLabels: [String] {
        message.mentionedTravelerIDs.compactMap { id in
            trip.travelers.first {
                $0.id == id
            }.map { "@\($0.displayName)" }
        }.sorted()
    }

    func reactionCount(_ kind: MessageReactionKind) -> Int {
        message.reactions.count { $0.kind == kind }
    }

    func viewerReacted(_ kind: MessageReactionKind) -> Bool {
        message.reactions.contains {
            $0.kind == kind && $0.travelerID == viewerID
        }
    }
}

enum CommunicationContextResolver {
    static func availableContexts(
        in trip: Trip
    ) -> [(TripMessageContext, String)] {
        var contexts: [(TripMessageContext, String)] = [
            (.trip, "Whole trip")
        ]
        contexts += trip.itinerary.days
            .flatMap(\.items)
            .prefix(30)
            .map {
                (.itineraryItem($0.id), $0.title)
            }
        contexts += trip.decisions.prefix(20).map {
            (.decision($0.id), "Decision · \($0.title)")
        }
        return contexts
    }

    static func label(
        for context: TripMessageContext,
        in trip: Trip
    ) -> String {
        switch context {
        case .trip:
            "Whole trip"
        case .itineraryItem(let id):
            trip.itinerary.days
                .flatMap(\.items)
                .first { $0.id == id }?.title
                ?? "Archived itinerary item"
        case .decision(let id):
            trip.decisions.first {
                $0.id == id
            }.map { "Decision · \($0.title)" }
                ?? "Archived decision"
        }
    }
}

enum TripShareSummaryBuilder {
    static func text(for trip: Trip) -> String {
        var lines = ["\(trip.title) — shared with GIA"]
        if let destination = trip.request.destinations.first {
            lines.append("Destination: \(destination.name)")
        }
        if let range = trip.request.dateRange {
            lines.append(
                "Dates: "
                + range.start.formatted(date: .abbreviated, time: .omitted)
                + " – "
                + range.end.formatted(date: .abbreviated, time: .omitted)
            )
        }
        lines.append("Travelers: \(trip.travelers.count)")
        lines.append("Itinerary days: \(trip.itinerary.days.count)")
        let openDecisionCount = trip.decisions.count {
            $0.state == .voting || $0.state == .tied
        }
        lines.append("Open decisions: \(openDecisionCount)")
        lines.append(
            "Open GIA to review sourced prices, timing, and booking status."
        )
        return lines.joined(separator: "\n")
    }
}
