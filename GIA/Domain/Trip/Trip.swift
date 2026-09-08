import Foundation

enum TripLifecycleState: String, Codable, CaseIterable, Sendable {
    case draft
    case planning
    case voting
    case ready
    case active
    case completed
    case archived
}

struct TripCatalog: Codable, Hashable, Sendable {
    var flightOffers: [FlightOffer]
    var hotelOffers: [HotelOffer]
    var places: [PlaceRecommendation]
    var timedEvents: [TimedEvent]
    var weatherSnapshots: [WeatherSnapshot]

    init(
        flightOffers: [FlightOffer] = [],
        hotelOffers: [HotelOffer] = [],
        places: [PlaceRecommendation] = [],
        timedEvents: [TimedEvent] = [],
        weatherSnapshots: [WeatherSnapshot] = []
    ) {
        self.flightOffers = flightOffers
        self.hotelOffers = hotelOffers
        self.places = places
        self.timedEvents = timedEvents
        self.weatherSnapshots = weatherSnapshots
    }
}

struct TripSelections: Codable, Hashable, Sendable {
    var flightOfferIDs: Set<UUID>
    var hotelOfferIDs: Set<UUID>
    var placeIDs: Set<UUID>

    init(
        flightOfferIDs: Set<UUID> = [],
        hotelOfferIDs: Set<UUID> = [],
        placeIDs: Set<UUID> = []
    ) {
        self.flightOfferIDs = flightOfferIDs
        self.hotelOfferIDs = hotelOfferIDs
        self.placeIDs = placeIDs
    }
}

struct Trip: Codable, Hashable, Identifiable, Sendable {
    var schemaVersion: Int
    let id: UUID
    var title: String
    var lifecycleState: TripLifecycleState
    var organizerTravelerID: UUID
    var request: TripRequest
    var travelers: [Traveler]
    var catalog: TripCatalog
    var selections: TripSelections
    var itinerary: TripItinerary
    var budget: TripBudget
    var decisions: [GroupDecision]
    var bookings: [BookingRecord]
    var collaboration: TripCollaboration?
    var communication: TripCommunication?
    var integrations: TripIntegrations?
    var createdAt: Date
    var updatedAt: Date

    init(
        schemaVersion: Int = TripDomainSchema.currentVersion,
        id: UUID = UUID(),
        title: String,
        lifecycleState: TripLifecycleState = .draft,
        organizerTravelerID: UUID,
        request: TripRequest,
        travelers: [Traveler],
        catalog: TripCatalog = TripCatalog(),
        selections: TripSelections = TripSelections(),
        itinerary: TripItinerary = TripItinerary(),
        budget: TripBudget = TripBudget(),
        decisions: [GroupDecision] = [],
        bookings: [BookingRecord] = [],
        collaboration: TripCollaboration? = nil,
        communication: TripCommunication? = nil,
        integrations: TripIntegrations? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.lifecycleState = lifecycleState
        self.organizerTravelerID = organizerTravelerID
        self.request = request
        self.travelers = travelers
        self.catalog = catalog
        self.selections = selections
        self.itinerary = itinerary
        self.budget = budget
        self.decisions = decisions
        self.bookings = bookings
        self.collaboration = collaboration
        self.communication = communication
        self.integrations = integrations
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var organizer: Traveler? {
        travelers.first { $0.id == organizerTravelerID }
    }

    var usesDemoData: Bool {
        catalog.flightOffers.contains {
            $0.provenance.origin == .demo
        }
        || catalog.hotelOffers.contains {
            $0.provenance.origin == .demo
        }
        || catalog.places.contains {
            $0.provenance.origin == .demo
        }
        || catalog.timedEvents.contains {
            $0.provenance.origin == .demo
        }
        || catalog.weatherSnapshots.contains {
            $0.provenance.origin == .demo
        }
        || itinerary.transportationLegs.contains {
            $0.provenance.origin == .demo
        }
        || bookings.contains {
            $0.provenance.origin == .demo
        }
    }
}
