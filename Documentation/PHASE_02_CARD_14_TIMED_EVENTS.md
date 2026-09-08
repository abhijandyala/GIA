# Phase 2 — Card 14: Timed Events

## Status

Source complete. Live-key verification remains pending until the displayed
SerpApi credential is rotated.

## Objective

Represent concerts, games, exhibitions, festivals, and other fixed-time events
separately from flexible places so itinerary logic cannot arbitrarily move or
invent their schedule.

## Domain model

`TimedEvent` stores:

- Deterministic UUID
- Provider event identifier
- Title and summary
- Venue and location
- Optional resolved start and end
- Exact provider date text
- Time-zone identifier and resolution state
- Upcoming, postponed, cancelled, or unknown status
- Scheduling traits
- Venue rating and explicit rating scale
- Review count
- Image
- Source link
- External ticket links
- Provider provenance

Scheduling traits include:

- Fixed time
- Flexible time
- Reservation available
- Ticket required
- Walk-in
- Weather dependent
- Indoor
- Outdoor

Traits appear only when source evidence or explicit event text supports them.

## Search contract

The event request requires:

- Destination
- Valid IANA destination time zone
- Chronological trip date range
- Optional bounded search query
- Interests
- Result limit from 1–50

The server builds one Google Events query containing:

- Event topic
- Destination
- Requested start date
- Requested end date
- English result language

Interests may specialize the event topic for sports, art, food, nightlife, or
general events.

## Time interpretation

SerpApi event dates are often human-readable. The adapter:

1. Preserves the exact `when` or `start_date` source text.
2. Parses explicit ISO dates directly.
3. Parses month/day values only by choosing a year within the requested trip.
4. Parses explicit 12-hour or 24-hour time ranges.
5. Converts local clock time using the destination IANA time zone.
6. Handles overnight end times.

The adapter never invents a default time. If a date exists without a provable
clock range, `start` and `end` remain nil and the event cannot receive
`fixedTime`.

Postponed events preserve their source evidence but lose resolved schedule
placement until a provider supplies a new time.

## Filtering

The server excludes:

- Cancelled events
- Resolved events that have already ended
- Recognizable event dates outside the trip
- Duplicate provider events

An unresolved date is preserved only when it cannot be proven outside the
requested trip.

## Ticket and booking boundary

Only `ticket_info` entries explicitly marked as ticket links become
`ticketURLs`.

Ticket links indicate external availability, not:

- Purchase
- Reservation
- Payment
- Confirmation
- Refundability
- Guaranteed inventory

The event itself never receives a booked status from search.

## Gateway and workflow

New endpoint:

`POST /v1/search/events`

`GatewayTravelService` conforms to `EventSearching`.

`EventSearchCoordinator`:

1. Marks Experiences active.
2. Calls the event service.
3. Supports cancellation.
4. Completes Experiences with the actual event count.
5. Marks Experiences unavailable on provider failure.

`TripCatalog` now stores timed events separately from places.
Trip completion combines place and event counts for Experiences.

## GPT grounding

`TripGenerationCriteria` now includes timed events. GPT may reference an event
only by an existing event UUID.

Server and iOS blueprint validation reject unknown event identifiers.
Prices, ticket availability, and booking state remain excluded from GPT output.

## Failure behavior

Safe errors cover:

- Missing configuration
- Invalid destination/time zone
- Reversed dates
- Invalid query/limit
- Timeout
- Transport failure
- Rate limit
- Authorization failure
- Provider failure
- Invalid JSON
- Unsupported event shape

Empty results remain distinct from malformed nonempty results.

## Verification

Gateway tests cover:

- Destination/date query construction
- Interest-specific event topic
- Year inference within trip dates
- Destination time-zone conversion
- Fixed-time and unresolved-time events
- Overnight-safe time ranges
- Ticket-link filtering
- Venue rating scale
- Outdoor/weather-dependent evidence
- Stable identity
- Duplicate removal
- Cancelled, expired, and out-of-range filtering
- Postponed schedule removal
- Invalid preflight criteria
- Empty-versus-malformed distinction
- Sanitized provider failure
- Missing-key failure

Swift verification decodes resolved and unresolved events into `TimedEvent`,
confirms traits, ticket URLs, rating scale, provenance, and the Experiences
workstream count.

No test consumes SerpApi quota.

## FBLA evidence

This card supports:

- Scheduling and organization
- Time-zone-aware data handling
- Real activity discovery
- Semantic input validation
- Weather-aware planning foundations
- Honest ticket and booking boundaries
- Secure provider integration
