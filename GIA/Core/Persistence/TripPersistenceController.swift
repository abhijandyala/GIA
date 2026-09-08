import Foundation
import Observation
import SwiftData

struct StoredTripSummary: Identifiable, Hashable, Sendable {
    var id: UUID { tripIdentifier }
    var tripIdentifier: UUID
    var title: String
    var lifecycleState: TripLifecycleState
    var tripUpdatedAt: Date
    var savedAt: Date
    var oldestProviderRetrievedAt: Date?
    var containsDemoData: Bool
    var tripSchemaVersion: Int
}

enum TripPersistenceError: Error, Equatable {
    case notConfigured
    case encodingFailed
    case decodingFailed
    case invalidTrip
    case unsupportedTripSchema(Int)
    case recordNotFound(UUID)
    case storageFailed

    var userMessage: String {
        switch self {
        case .notConfigured:
            "Local trip storage is not ready."
        case .encodingFailed, .storageFailed:
            "The trip could not be saved locally."
        case .decodingFailed, .invalidTrip:
            "The saved trip could not be opened safely."
        case .unsupportedTripSchema:
            "This saved trip needs a newer version of GIA."
        case .recordNotFound:
            "The saved trip is no longer available."
        }
    }
}

@MainActor
@Observable
final class TripPersistenceController {
    private(set) var summaries: [StoredTripSummary] = []
    private(set) var isConfigured = false
    private(set) var isEphemeralFallback = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored
    private var modelContext: ModelContext?
    @ObservationIgnored
    private var pendingSaveTask: Task<Void, Never>?
    @ObservationIgnored
    private let encoder: JSONEncoder
    @ObservationIgnored
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        self.decoder = decoder
    }

    func configure(
        modelContext: ModelContext,
        isEphemeralFallback: Bool
    ) {
        guard !isConfigured else { return }
        self.modelContext = modelContext
        self.isEphemeralFallback = isEphemeralFallback
        isConfigured = true
        refresh()
    }

    func queueSave(_ trip: Trip) {
        guard isConfigured else { return }
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled, let self else { return }
            do {
                try self.save(trip)
            } catch let error as TripPersistenceError {
                self.lastErrorMessage = error.userMessage
            } catch {
                self.lastErrorMessage =
                    TripPersistenceError.storageFailed.userMessage
            }
        }
    }

    func save(_ trip: Trip, at savedAt: Date = Date()) throws {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        guard let modelContext else {
            throw TripPersistenceError.notConfigured
        }

        var persistedTrip = trip
        persistedTrip.request.rawTranscript = nil
        let payload: Data
        do {
            payload = try encoder.encode(persistedTrip)
        } catch {
            throw TripPersistenceError.encodingFailed
        }

        do {
            let identifier = trip.id
            var descriptor = FetchDescriptor<StoredTripRecord>(
                predicate: #Predicate {
                    $0.tripIdentifier == identifier
                }
            )
            descriptor.fetchLimit = 1
            let existing = try modelContext.fetch(descriptor).first
            let oldestProviderDate =
                Self.oldestProviderRetrievedAt(in: trip)
            if let existing {
                existing.tripSchemaVersion = trip.schemaVersion
                existing.title = trip.title
                existing.lifecycleStateRawValue =
                    trip.lifecycleState.rawValue
                existing.tripCreatedAt = trip.createdAt
                existing.tripUpdatedAt = trip.updatedAt
                existing.savedAt = savedAt
                existing.oldestProviderRetrievedAt =
                    oldestProviderDate
                existing.containsDemoData = trip.usesDemoData
                existing.payload = payload
            } else {
                modelContext.insert(
                    StoredTripRecord(
                        tripIdentifier: trip.id,
                        tripSchemaVersion: trip.schemaVersion,
                        title: trip.title,
                        lifecycleStateRawValue:
                            trip.lifecycleState.rawValue,
                        tripCreatedAt: trip.createdAt,
                        tripUpdatedAt: trip.updatedAt,
                        savedAt: savedAt,
                        oldestProviderRetrievedAt:
                            oldestProviderDate,
                        containsDemoData: trip.usesDemoData,
                        payload: payload
                    )
                )
            }
            try modelContext.save()
            lastErrorMessage = nil
            refresh()
        } catch let error as TripPersistenceError {
            throw error
        } catch {
            throw TripPersistenceError.storageFailed
        }
    }

    func load(_ tripID: UUID) throws -> Trip {
        guard let modelContext else {
            throw TripPersistenceError.notConfigured
        }
        let descriptor = FetchDescriptor<StoredTripRecord>(
            predicate: #Predicate {
                $0.tripIdentifier == tripID
            }
        )
        let record: StoredTripRecord
        do {
            guard let value = try modelContext.fetch(descriptor).first else {
                throw TripPersistenceError.recordNotFound(tripID)
            }
            record = value
        } catch let error as TripPersistenceError {
            throw error
        } catch {
            throw TripPersistenceError.storageFailed
        }
        guard
            record.tripSchemaVersion
                <= TripDomainSchema.currentVersion
        else {
            throw TripPersistenceError.unsupportedTripSchema(
                record.tripSchemaVersion
            )
        }

        let trip: Trip
        do {
            trip = try decoder.decode(
                Trip.self,
                from: record.payload
            )
        } catch {
            throw TripPersistenceError.decodingFailed
        }
        guard trip.structuralIssues.isEmpty else {
            throw TripPersistenceError.invalidTrip
        }
        return trip
    }

    func loadMostRecentTrip() -> Trip? {
        var latestError: TripPersistenceError?
        for summary in summaries {
            guard
                summary.tripSchemaVersion
                    <= TripDomainSchema.currentVersion
            else {
                latestError = .unsupportedTripSchema(
                    summary.tripSchemaVersion
                )
                continue
            }
            do {
                let trip = try load(summary.id)
                lastErrorMessage = nil
                return trip
            } catch let error as TripPersistenceError {
                latestError = error
            } catch {
                latestError = .storageFailed
            }
        }
        lastErrorMessage = latestError?.userMessage
        return nil
    }

    func delete(_ tripID: UUID) throws {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        guard let modelContext else {
            throw TripPersistenceError.notConfigured
        }
        let descriptor = FetchDescriptor<StoredTripRecord>(
            predicate: #Predicate {
                $0.tripIdentifier == tripID
            }
        )
        do {
            guard let record = try modelContext.fetch(descriptor).first else {
                throw TripPersistenceError.recordNotFound(tripID)
            }
            modelContext.delete(record)
            try modelContext.save()
            lastErrorMessage = nil
            refresh()
        } catch let error as TripPersistenceError {
            throw error
        } catch {
            throw TripPersistenceError.storageFailed
        }
    }

    func refresh() {
        guard let modelContext else { return }
        do {
            let descriptor = FetchDescriptor<StoredTripRecord>(
                sortBy: [
                    SortDescriptor(\.savedAt, order: .reverse)
                ]
            )
            summaries = try modelContext.fetch(descriptor).map {
                StoredTripSummary(
                    tripIdentifier: $0.tripIdentifier,
                    title: $0.title,
                    lifecycleState:
                        TripLifecycleState(
                            rawValue: $0.lifecycleStateRawValue
                        ) ?? .draft,
                    tripUpdatedAt: $0.tripUpdatedAt,
                    savedAt: $0.savedAt,
                    oldestProviderRetrievedAt:
                        $0.oldestProviderRetrievedAt,
                    containsDemoData: $0.containsDemoData,
                    tripSchemaVersion: $0.tripSchemaVersion
                )
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage =
                TripPersistenceError.storageFailed.userMessage
        }
    }

    private static func oldestProviderRetrievedAt(
        in trip: Trip
    ) -> Date? {
        let dates =
            trip.catalog.flightOffers.map {
                $0.provenance.retrievedAt
            }
            + trip.catalog.hotelOffers.map {
                $0.provenance.retrievedAt
            }
            + trip.catalog.places.map {
                $0.provenance.retrievedAt
            }
            + trip.catalog.timedEvents.map {
                $0.provenance.retrievedAt
            }
            + trip.catalog.weatherSnapshots.map {
                $0.provenance.retrievedAt
            }
            + trip.itinerary.transportationLegs.map {
                $0.provenance.retrievedAt
            }
            + trip.bookings.map {
                $0.provenance.retrievedAt
            }
        return dates.min()
    }
}
