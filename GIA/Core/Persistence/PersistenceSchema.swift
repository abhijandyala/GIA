import Foundation
import SwiftData

@Model
final class StoredTripRecord {
    @Attribute(.unique)
    var tripIdentifier: UUID
    var tripSchemaVersion: Int
    var title: String
    var lifecycleStateRawValue: String
    var tripCreatedAt: Date
    var tripUpdatedAt: Date
    var savedAt: Date
    var oldestProviderRetrievedAt: Date?
    var containsDemoData: Bool
    var payload: Data

    init(
        tripIdentifier: UUID,
        tripSchemaVersion: Int,
        title: String,
        lifecycleStateRawValue: String,
        tripCreatedAt: Date,
        tripUpdatedAt: Date,
        savedAt: Date,
        oldestProviderRetrievedAt: Date?,
        containsDemoData: Bool,
        payload: Data
    ) {
        self.tripIdentifier = tripIdentifier
        self.tripSchemaVersion = tripSchemaVersion
        self.title = title
        self.lifecycleStateRawValue = lifecycleStateRawValue
        self.tripCreatedAt = tripCreatedAt
        self.tripUpdatedAt = tripUpdatedAt
        self.savedAt = savedAt
        self.oldestProviderRetrievedAt =
            oldestProviderRetrievedAt
        self.containsDemoData = containsDemoData
        self.payload = payload
    }
}

enum GIAPersistenceSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [StoredTripRecord.self]
    }
}

enum GIAPersistenceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GIAPersistenceSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum GIAPersistenceContainerFactory {
    static func makePersistentContainer()
        -> (container: ModelContainer, isEphemeralFallback: Bool)
    {
        let schema = Schema(
            versionedSchema: GIAPersistenceSchemaV1.self
        )
        do {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: GIAPersistenceMigrationPlan.self,
                configurations: [configuration]
            )
            return (container, false)
        } catch {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            let container = try! ModelContainer(
                for: schema,
                migrationPlan: GIAPersistenceMigrationPlan.self,
                configurations: [configuration]
            )
            return (container, true)
        }
    }
}
