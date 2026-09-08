# Phase 6 — Cards 13 and 14

## Card 13: In-memory planning orchestration

`TripPlanningOrchestrator` is the single owner of a live planning run. It:

1. Resolves the requested destination name through the authenticated gateway.
2. Uses returned coordinates, time zone, and provider-supplied IATA code.
3. Starts eligible flight, hotel, place, event, and weather searches
   concurrently.
4. Preserves successful workstreams when another source fails.
5. Assembles provider-backed recommendations into an in-memory `Trip`.
6. Requests routes only between itinerary items with sourced coordinates.
7. Cancels the complete task tree for Cancel, New Request, Return, or app
   backgrounding.

There is no Japan-only planning branch. Tokyo remains an explicitly labeled
judge-demo fixture. Normal typed and spoken requests retain their requested
destination, including Unicode names such as São Paulo and Reykjavík.

Flights run only when both endpoints have provider-resolved IATA codes and time
zones. Weather runs only with provider-resolved coordinates and a time zone.
Hotel, place, and event searches can continue from the destination name when
map context is unavailable.

`TransientTripAssembler` uses only identifiers and facts returned by providers.
It creates proposed itinerary items, carries booking/reservation disclaimers,
and does not imply that a selection is purchased.

## Card 14: Progressive and truthful Plan UI

The orchestrator publishes `previewTrip` after every completed provider
workstream. Plan content sections are conditional on the corresponding arrays,
so flight, hotel, experience, weather, and itinerary UI cannot appear before
those results exist.

The planning rail remains visible for queued, active, empty, complete, and
unavailable workstreams. Counts come directly from returned arrays. A valid
zero-result response is shown as zero results; a failed request is shown as
unavailable.

When the gateway is absent or providers fail:

- The original request remains in memory.
- No demo trip is inserted automatically.
- No prices, options, or progress counts are fabricated.
- Available workstreams remain visible.
- The user can retry the complete live search or begin a new request.

## Verification evidence

- Gateway syntax and all 88 provider tests pass.
- Geoapify location tests cover Unicode-safe queries, timezone/coordinate
  mapping, nearest airport mapping, absent IATA codes, and missing
  configuration.
- The iOS Debug simulator target builds successfully.
- A simulator run with the gateway deliberately disabled reaches Plan, labels
  provider workstreams unavailable, shows no result cards, and provides Retry.
- A simulator run against an unreachable endpoint shows the resolving state
  with all result modules queued and no fabricated cards.

All trip state in these cards is transient. SwiftData restoration and group
workspace behavior are outside the active Map-and-Plan UI scope.
