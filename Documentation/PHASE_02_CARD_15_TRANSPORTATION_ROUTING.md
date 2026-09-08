# Phase 2 — Card 15: Transportation Routing

## Status

Source complete. Live-key verification remains pending until the exposed
Geoapify credential is rotated.

## Objective

Connect itinerary locations with source-grounded route duration, distance,
geometry, and instructions without claiming unsupported transit modes, live
traffic, ticket availability, or transportation cost.

## Supported request modes

The adapter supports:

- Walking → Geoapify `walk`
- Bicycle → Geoapify `bicycle`
- Car → Geoapify `drive`
- Rideshare estimate → Geoapify `drive`
- Public transit → Geoapify `transit`

The adapter rejects airplane, train, subway, ferry, and operator-specific bus
requests as direct modes because a generic routing result cannot prove a
specific carrier or ticket.

Those modes require later operator inventory or a validated transit result.

## Request validation

The server requires:

- Origin identifier and name
- Origin coordinate
- Destination identifier and name
- Destination coordinate
- Different origin and destination points
- One to four unique supported modes
- Optional valid departure time
- Three-letter currency code

Invalid criteria fail before Geoapify is called.

## Geoapify request

The adapter uses:

- `GET /v1/routing`
- Two coordinate waypoints
- Provider travel mode
- Metric units
- English instructions
- `instruction_details`
- Approximated traffic for driving
- Server-only API key

Each requested mode uses a separate provider request so confidence and mode
remain distinguishable.

## Transit fallback

Public transit first requests Geoapify `transit`.

If no scheduled transit route is returned, the adapter requests
`approximated_transit`. Those results:

- Retain app mode `transit`
- Use confidence `approximated`
- Never claim a timetable, operator, fare, or ticket

Scheduled transit results use confidence `scheduled`.

Walking, cycling, car, and rideshare routes use confidence `estimated`, not
`live`, because approximated traffic is not live traffic telemetry.

## Domain mapping

Each `TransportationLeg` contains:

- Stable deterministic UUID
- Origin and destination
- Requested transportation mode
- Optional planned departure
- Arrival derived only from provider duration
- Duration in seconds
- Distance in meters
- Bounded route geometry
- Deduplicated instructions
- Mode-specific transfer buffer
- Explicit confidence
- Nil estimated cost unless a later source supplies one
- Nil booking URL unless a later operator source supplies one
- Fifteen-minute Geoapify provenance

## Geometry protection

Geoapify returns nested GeoJSON line geometry. The mapper:

- Recursively extracts valid longitude/latitude pairs
- Rejects out-of-range coordinates
- Requires at least two points
- Bounds output to approximately 1,000 points
- Preserves the final destination point

This prevents oversized route payloads from controlling memory or UI work.

## Buffers

Deterministic planning buffers:

- Walking: 5 minutes
- Bicycle: 5 minutes
- Car: 10 minutes
- Rideshare: 10 minutes
- Transit: 10 minutes

Buffers are planning safety margins, not part of provider travel duration.

## Failure behavior

Safe errors cover:

- Missing provider configuration
- Missing or invalid coordinates
- Identical route points
- Unsupported or excessive modes
- Invalid departure/currency
- Timeout
- Transport failure
- Rate limit
- Authorization failure
- Provider failure
- Invalid JSON
- Unsupported route shape

If one of several requested modes fails and another succeeds, usable routes
remain available. If every mode fails, the first safe provider failure is
returned.

## Workflow integration

`RoutePlanningCoordinator`:

1. Marks Routes active with Geoapify attribution.
2. Calls the `RoutePlanning` protocol.
3. Supports cancellation.
4. Completes Routes with the actual result count.
5. Marks Routes unavailable after provider failure.

It does not schedule itinerary items, purchase transit, calculate fares, or
advance unrelated workstreams.

## Verification

Gateway tests cover:

- Documented route parameters
- Mode mapping
- Approximated driving traffic
- Duration and distance
- Planned arrival derivation
- Nested geometry extraction
- Geometry bounding and final-point preservation
- Instruction extraction and deduplication
- Mode buffers
- Scheduled versus approximated transit
- Transit fallback
- Unsupported-mode preflight rejection
- Empty-versus-malformed distinction
- Sanitized authorization failure
- Missing-key failure

Swift verification decodes a route into `TransportationLeg` and confirms dates,
mode, confidence, duration, distance, geometry, instructions, buffer,
provenance, and the Routes workstream result count.

No test consumes Geoapify quota.

## FBLA evidence

This card supports:

- Time-aware trip management
- Transportation organization
- Semantic input validation
- Accessible future route presentation
- Honest data-confidence communication
- Secure provider integration
- Reliable fallback behavior
