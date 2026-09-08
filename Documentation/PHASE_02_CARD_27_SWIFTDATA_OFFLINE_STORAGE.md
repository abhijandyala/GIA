# Phase 2 — Card 27: SwiftData Offline Storage

## Status

Complete with versioned SwiftData storage, automatic save and restore, a local
trip library, explicit deletion, transient-transcript sanitization, migration
safety, cache-age presentation, Debug fixtures, and executable in-memory
verification.

## Objective

Keep complete trip plans available without internet while preserving the
existing domain boundary and avoiding a fragile graph of provider-specific
SwiftData relationships.

## Storage architecture

`StoredTripRecord` is a SwiftData model containing:

- Stable Trip UUID
- Trip schema version
- Searchable title
- Lifecycle state
- Trip creation/update dates
- Device save date
- Oldest provider retrieval date
- Demo-data indicator
- Codable Trip payload

The complete nested `Trip` payload retains:

- Travelers and preferences
- Selections
- Flight, hotel, place, event, route, and weather data
- Itinerary
- Budget
- Booking records
- Decisions and votes
- Invitations and membership audit
- Messages, reactions, and read receipts
- Provider provenance

Provider DTOs are not persisted.

## Why a Codable aggregate payload

The application already treats `Trip` as one validated aggregate. Persisting
that aggregate:

- Preserves invariants across nested data.
- Avoids dozens of mutable SwiftData relationships.
- Keeps persistence independent from provider response formats.
- Reuses verified Codable fixtures.
- Allows an unsupported payload to remain untouched until a compatible app
  version is installed.

Summary metadata remains queryable without decoding every trip.

## Versioning and migration

`GIAPersistenceSchemaV1` and `GIAPersistenceMigrationPlan` establish the
versioned SwiftData boundary.

- The first schema has no destructive migration stages.
- Every payload stores `Trip.schemaVersion`.
- Records with a newer unsupported Trip schema are not decoded or deleted.
- Unsupported records remain visible in the library and report that a newer
  G.I.A. version is required.
- Legacy Trip payloads retain optional collaboration and communication
  compatibility.

If the persistent ModelContainer cannot open, the app falls back to an
in-memory container and visibly warns that the session is temporary instead of
crashing.

## Privacy

Before encoding, the repository copies the trip and clears
`TripRequest.rawTranscript`.

This preserves Card 4's rule that voice transcripts are not permanently stored
without consent. Structured trip details remain available offline.

The repository never persists:

- Provider API keys
- Gateway bearer credentials
- Raw provider responses
- Generated speech audio
- Voice-request transcript

## Autosave

`RootContainer` owns one shared `TripPersistenceController`.

- Ready and partially available trip revisions queue a short debounced save.
- Background/inactive transitions flush the current trip immediately.
- A trip created before repository configuration is saved immediately after
  configuration.
- Saving the same Trip UUID updates one record rather than creating a duplicate.
- Debug group fixtures use a stable Trip UUID for repeatable demonstrations.

## Restore

At launch:

1. SwiftData opens.
2. Summaries load by newest save date.
3. Debug fixture launches skip automatic restore.
4. The newest normal saved trip is decoded.
5. Structural domain validation runs.
6. `TripPlanningSession.restorePersistedTrip` rebuilds progress, active traveler,
   and deterministic budget/conflict analysis.

The Map remains the launch surface; Plan and Group can immediately open the
restored trip without network access.

## Provider cache boundary

`GatewayResponseCache` remains a separate short-lived network optimization.

- Gateway cache: request/response data with provider TTL.
- SwiftData: durable user trip aggregate.

Generated plans and speech remain excluded from the gateway response cache.
Persisted trip metadata stores the oldest source retrieval date so stale
provider information is visible.

## Offline library interface

The Group workspace shows:

- Saved trip count
- Available-offline state
- Last save age
- Oldest provider source age
- Demo-data label
- Save-now action
- Manage action

The library sheet shows all local trips with:

- Title
- Lifecycle
- Saved age
- Demo label
- Open action
- Delete action

Deletion requires confirmation and clearly states that deleting local data does
not cancel provider reservations.

## Debug verification

- `GIA_DEBUG_GROUP_WORKSPACE=1` creates and autosaves the complete collaborative
  Lisbon trip.
- `GIA_DEBUG_OFFLINE_LIBRARY=1` opens the local trip library.

## Automated verification

`TripPersistenceVerificationMain.swift` uses an in-memory SwiftData container
and checks:

- Insert and summary metadata
- Provider source age
- Demo-data indicator
- Transcript removal
- Traveler/catalog/itinerary/decision/booking/message restoration
- Session restoration
- Active organizer restoration
- Upsert without duplicates
- Unsupported schema preservation
- Explicit deletion
- No collateral deletion of unsupported records

## Truthfulness and reliability

- A saved trip is not treated as fresh provider availability.
- Source retrieval age remains visible.
- Deleting local data does not imply provider cancellation.
- Invalid payloads do not enter application state.
- Unsupported records are preserved.
- Storage failure degrades to a visible temporary session.

## FBLA evidence

This card demonstrates database use, offline reliability, schema versioning,
data lifecycle management, privacy-aware persistence, validation before
restore, cache separation, and user-controlled deletion.
