# Phase 2 — Card 18: Flight Comparison Interface

## Status

Complete with Debug-only sourced fixtures. Live provider rendering awaits rotated
credentials and orchestration.

## Objective

Present sourced flight options as a clean spatial comparison, support selection
and temporary comparison, and preserve the distinction between choosing an
option and purchasing a ticket.

## Display contract

The interface renders only when `Trip.catalog.flightOffers` is nonempty.

Each option may display:

- Airline
- Origin and destination IATA codes
- Local departure and arrival clocks
- Departure calendar date
- Total duration
- Number of stops
- Total price and currency
- Baggage evidence
- Emissions estimate
- Price insight
- Deterministic source badges
- Live, cached, demo, or user-entered origin
- Return-flight status
- External provider link

Missing fields remain visibly unavailable rather than receiving placeholders
that imply factual values.

## Visual hierarchy

### Featured flight

- Primary badge
- Source-origin pill
- Airline and date
- Spatial route line
- Departure and arrival nodes
- Duration, route, and total-price metrics
- Price insight
- Time-zone warning when applicable
- Return-selection warning when applicable
- Expandable details
- Selection, comparison, and provider actions

### Alternatives

Horizontally scrollable compact cards show:

- Source state
- Route
- Departure
- Duration
- Price
- Selected/focused state
- Comparison toggle

Focusing an alternative updates the featured surface without changing the
shared trip selection.

### Comparison sheet

Two or three temporary comparison options display:

- Total price
- Duration
- Stops
- Baggage
- Emissions
- Price insight
- Data source
- Selection action

Card dimensions use minimum height rather than fixed clipping so long baggage
text and Dynamic Type remain inside each surface.

## Selection architecture

`TripPlanningSession.selectFlightOffer`:

- Is allowed only for ready or partially available trip state
- Requires a current trip
- Requires the offer UUID to exist in the trip catalog
- Replaces the selected flight set with the chosen option
- Updates the trip timestamp and session revision

Unknown IDs and invalid workflow phases are rejected.

Comparison IDs remain local view state and are limited to three. Comparing does
not mutate the trip.

## Truthfulness

- `SELECT FLIGHT` means selection inside G.I.A., not purchase.
- `VIEW WITH PROVIDER` opens an external source.
- The section states `NO BOOKING MADE`.
- Provider links do not change booking state.
- Initial outbound-only round-trip results display `Return flight selection
  pending`.
- Unresolved connection time zones display a warning.
- Provider adapters cannot assign `GIA RECOMMENDED`; that badge requires a
  grounded plan selection.
- Demo fixtures display `DEMO`, never `LIVE`.

## Formatting

- Currency uses source currency.
- Duration uses hour/minute form.
- Zero-count baggage values are omitted.
- Local provider clock text takes precedence over reformatting.
- Price-insight icon matches low, typical, or high state.
- Emissions convert provider grams to rounded kilograms CO₂e.

## Debug verification

`GIA_DEBUG_FLIGHT_RESULTS_FIXTURE=1` builds three demo offers:

- GIA recommended balanced option
- Lowest-price connection
- Fastest/lower-emissions option

`GIA_DEBUG_SCROLL_TO_FLIGHTS=1` scrolls the Plan shell to the featured section.

`GIA_DEBUG_COMPARE_FLIGHTS=1` opens all three options in comparison.

These controls and fixture data compile only in Debug builds.

## Verification

Automated Swift verification covers:

- Selected-first ordering
- Lowest-price and fastest ordering
- Route and local-time formatting
- Duration, stop, baggage, emissions, and price formatting
- Price-insight text and symbols
- Time-zone resolution warnings
- Return-selection status
- Valid shared-trip selection
- Unknown-offer rejection

Runtime verification covers:

- Featured card composition
- Horizontal alternatives
- Selected and focused distinction
- Comparison sheet
- Long baggage text containment
- Demo/source labeling
- Provider-link wording
- Persistent bottom navigation

## FBLA evidence

This card supports:

- Intuitive travel comparison
- Original visual design
- User input and selection validation
- Honest purchase boundaries
- Accessible responsive UI
- Meaningful use of live-provider domain data
- Group-decision foundation
