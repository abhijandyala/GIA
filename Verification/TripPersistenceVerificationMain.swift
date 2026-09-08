import Foundation
import SwiftData

@main
enum TripPersistenceVerificationMain {
    @MainActor
    static func main() throws {
        let schema = Schema(
            versionedSchema: GIAPersistenceSchemaV1.self
        )
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: GIAPersistenceMigrationPlan.self,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        let controller = TripPersistenceController()
        controller.configure(
            modelContext: context,
            isEphemeralFallback: true
        )

        let date = Date(timeIntervalSince1970: 1_812_758_400)
        let destination = TravelLocation(
            name: "Lisbon",
            city: "Lisbon",
            country: "Portugal",
            countryCode: "PT",
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let provenance = DataProvenance(
            provider: .geoapify,
            providerIdentifier: "place",
            origin: .demo,
            retrievedAt: date,
            sourceURL: URL(string: "https://example.com/place")
        )
        let place = PlaceRecommendation(
            providerPlaceIdentifier: "museum",
            name: "National Tile Museum",
            location: destination,
            categories: [.museum],
            provenance: provenance
        )
        let organizer = Traveler(
            accountIdentifier: "avery@example.com",
            displayName: "Avery",
            initials: "AV",
            role: .organizer
        )
        let request = TripRequest(
            rawTranscript: "This transcript must not persist.",
            destinations: [destination],
            dateRange: TripDateRange(
                start: date,
                end: date.addingTimeInterval(604_800),
                timeZoneIdentifier: "Europe/Lisbon"
            ),
            travelerCount: 1,
            totalBudget: Money(
                amount: 3_000,
                currencyCode: "USD"
            )
        )
        var trip = Trip(
            title: "Lisbon Offline",
            lifecycleState: .ready,
            organizerTravelerID: organizer.id,
            request: request,
            travelers: [organizer],
            catalog: TripCatalog(places: [place]),
            budget: TripBudget(totalLimit: request.totalBudget),
            collaboration: TripCollaboration(),
            communication: TripCommunication(
                messages: [
                    TripMessage(
                        authorKind: .member,
                        authorTravelerID: organizer.id,
                        body: "Keep this available offline.",
                        readReceipts: [
                            MessageReadReceipt(
                                travelerID: organizer.id,
                                readAt: date
                            )
                        ],
                        createdAt: date
                    )
                ]
            ),
            createdAt: date,
            updatedAt: date
        )
        let savedAt = date.addingTimeInterval(600)
        try controller.save(trip, at: savedAt)
        precondition(controller.summaries.count == 1)
        precondition(controller.summaries[0].savedAt == savedAt)
        precondition(
            controller.summaries[0].oldestProviderRetrievedAt == date
        )
        precondition(controller.summaries[0].containsDemoData)

        let loaded = try controller.load(trip.id)
        precondition(loaded.id == trip.id)
        precondition(loaded.request.rawTranscript == nil)
        precondition(
            loaded.travelers.map(\.id) == trip.travelers.map(\.id)
        )
        precondition(
            loaded.travelers.map(\.displayName)
                == trip.travelers.map(\.displayName)
        )
        precondition(
            loaded.catalog.places.map(\.id)
                == trip.catalog.places.map(\.id)
        )
        precondition(
            loaded.catalog.places.first?.provenance.provider
                == .geoapify
        )
        precondition(loaded.itinerary == trip.itinerary)
        precondition(loaded.decisions == trip.decisions)
        precondition(loaded.bookings == trip.bookings)
        precondition(
            loaded.communication?.messages.first?.body
                == "Keep this available offline."
        )
        precondition(
            loaded.communication?.messages.first?.authorTravelerID
                == organizer.id
        )

        let session = TripPlanningSession()
        try session.restorePersistedTrip(loaded)
        precondition(session.phase == .ready)
        precondition(session.currentTrip?.id == trip.id)
        precondition(session.activeTravelerID == organizer.id)

        trip.title = "Lisbon Offline Updated"
        trip.updatedAt = date.addingTimeInterval(900)
        try controller.save(
            trip,
            at: date.addingTimeInterval(1_000)
        )
        precondition(controller.summaries.count == 1)
        precondition(
            controller.summaries[0].title
                == "Lisbon Offline Updated"
        )

        let encoded = try JSONEncoder().encode(trip)
        let unsupportedID = UUID()
        context.insert(
            StoredTripRecord(
                tripIdentifier: unsupportedID,
                tripSchemaVersion:
                    TripDomainSchema.currentVersion + 1,
                title: "Future Trip",
                lifecycleStateRawValue:
                    TripLifecycleState.ready.rawValue,
                tripCreatedAt: date,
                tripUpdatedAt: date,
                savedAt: date.addingTimeInterval(1_100),
                oldestProviderRetrievedAt: nil,
                containsDemoData: false,
                payload: encoded
            )
        )
        try context.save()
        controller.refresh()
        do {
            _ = try controller.load(unsupportedID)
            fatalError("Unsupported schema was loaded.")
        } catch let error as TripPersistenceError {
            precondition(
                error
                    == .unsupportedTripSchema(
                        TripDomainSchema.currentVersion + 1
                    )
            )
        }
        precondition(
            controller.summaries.contains {
                $0.id == unsupportedID
            }
        )
        precondition(
            controller.loadMostRecentTrip()?.id == trip.id
        )

        try controller.delete(trip.id)
        precondition(
            !controller.summaries.contains { $0.id == trip.id }
        )
        precondition(
            controller.summaries.contains {
                $0.id == unsupportedID
            }
        )

        print("SwiftData trip persistence lifecycle passed.")
    }
}
