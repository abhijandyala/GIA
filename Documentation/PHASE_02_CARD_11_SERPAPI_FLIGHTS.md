# Phase 2 — Card 11: SerpApi Flight Search

## Status

Source complete. Live-key verification remains pending because previously
displayed credentials must be rotated before use.

## Objective

Retrieve worldwide Google Flights comparisons through the server gateway and
map them into source-grounded `FlightOffer` domain models without exposing the
SerpApi key or treating search results as completed bookings.

## Request contract

The adapter requires:

- Resolved three-letter origin IATA code
- Resolved three-letter destination IATA code
- Valid IANA time zones for origin and destination
- Departure date
- Optional return date
- Adult count from 1–9
- Child count from 0–8
- Three-letter currency code
- Travel class
- Stop preference

Origin and destination cannot be identical. Invalid criteria fail before an
external request is attempted.

## SerpApi mapping

`FlightSearchCriteria` maps to:

- `engine=google_flights`
- `departure_id`
- `arrival_id`
- `outbound_date`
- `return_date`
- `type`
- `travel_class`
- `stops`
- `adults`
- `children`
- `currency`
- `hl=en`

The API key is added only by the server adapter.

## Domain mapping

The adapter maps:

- Best and other flight collections
- Airline name and code
- Flight number
- Airport names and IATA codes
- Local departure and arrival clock strings
- Absolute dates when time zones are resolved
- Segment and total duration
- Aircraft
- Travel class
- Baggage descriptions
- Total price and currency
- Price insight level and typical range
- Carbon-emission estimate
- Google Flights search URL
- Provider continuation or booking token
- Three-minute live-data expiration
- SerpApi provenance

Offer and segment UUIDs are deterministic hashes of provider identity rather
than random values. A changed provider token or material offer changes identity.

## Deal badges

Badges are deterministic and source-based:

- `lowestPrice` from the minimum mapped fare
- `fastest` from minimum total duration
- `fewestStops` from minimum segment count
- `lowerEmissions` only when SerpApi supplies a negative emissions comparison

`giaRecommended` is never assigned by the provider adapter. That badge requires
the grounded planning/ranking workflow.

## Time-zone integrity

SerpApi returns local clock text but may not return an IANA time zone for every
connection airport.

- Search origin and destination use validated request time zones.
- Their absolute `Date` values are resolved.
- Unknown connection airports preserve exact source clock text.
- Unknown connection airports use a UTC placeholder only for Codable
  compatibility.
- `departureTimeZoneIsResolved` and `arrivalTimeZoneIsResolved` remain false.

Scheduling logic must not treat unresolved connection timestamps as authoritative
until an airport time-zone provider resolves them.

## Round-trip boundary

An initial Google Flights round-trip search primarily returns outbound choices
and continuation tokens. Card 11 preserves the continuation token in
`providerOfferIdentifier` and leaves `returnSegments` empty.

The UI must not claim a complete round-trip itinerary until a later on-demand
return-flight selection retrieves and pairs the second leg.

## Booking boundary

`bookingURL` is an HTTPS Google Flights search link when SerpApi supplies one.
It is an external search/checkout continuation, not proof of booking.

The adapter does not:

- Purchase a ticket
- Charge a card
- Reserve inventory
- Modify a reservation
- Cancel a reservation
- Create a confirmation code

## Error handling

Safe gateway errors cover:

- Missing configuration
- Invalid airport or time-zone data
- Reversed dates
- Invalid passenger counts
- Invalid currency
- Timeout
- Transport failure
- Rate limit
- Authorization failure
- Provider failure
- Invalid JSON
- Unsupported result shape

A valid empty provider result maps to zero offers. A nonempty provider response
where every offer is malformed produces an error rather than pretending no
flights exist.

## Workflow integration

`FlightSearchCoordinator`:

1. Marks Flights active with SerpApi attribution.
2. Calls the narrow `FlightSearching` protocol.
3. Supports task cancellation.
4. Completes Flights with the actual result count.
5. Marks Flights unavailable on recoverable provider failure.

It does not construct a trip or advance unrelated workstreams.

## Verification

Gateway tests verify:

- Documented query parameters
- Round-trip and one-way request configuration
- Stable UUID mapping
- Local-time conversion for resolved airports
- Explicit unresolved connection clocks
- Price, baggage, emissions, and price-insight mapping
- Deterministic deal badges
- No false GIA recommendation
- Live provenance and expiration
- Empty-versus-malformed result distinction
- Preflight validation
- Sanitized provider failures
- Missing-key failure

Swift verification decodes the exact gateway response into `FlightOffer`,
including fractional ISO timestamps, badges, money, local clock text, time-zone
resolution, URLs, and provenance. It also verifies the Flights workstream
receives the real result count.

No test consumes SerpApi quota.

## FBLA evidence

This card supports:

- Live-data architecture
- Secure credential handling
- Meaningful comparison logic
- Data validation and integrity
- Honest booking boundaries
- Documented sources and limitations
- Recoverable provider failures
