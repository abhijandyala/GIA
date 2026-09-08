# Phase 2 — Card 21: Budget and Conflict Engine

## Status

Complete with deterministic Swift analysis, a live Plan surface, Debug-only
conflict fixtures, and command-line verification.

## Objective

Add original application logic for budget calculation and trip feasibility.
GPT may explain the engine's output, but it does not calculate totals, decide
whether a rule passed, or create conflict evidence.

## Budget ledger

The engine calculates these categories:

- Flights
- Lodging
- Food
- Activities
- Local transportation
- Emergency reserve

Selected flight and hotel offers, itinerary estimates, transportation costs,
and booking records are deduplicated by source identifier. Cancelled and
failed bookings do not contribute spend.

`confirmedSpend` includes only provider-confirmed booking records. Selected,
demo-confirmed, processing, and external-checkout records remain estimated so
the application does not present a demonstration as a real purchase.

Unknown costs remain explicit and do not silently become zero.

## Currency rules

`CurrencyConversionRate` retains:

- Source currency
- Destination currency
- Decimal rate
- Retrieval timestamp
- Optional expiration timestamp
- Provider provenance

The newest unexpired direct or inverse rate is used. If no valid rate exists,
the amount is excluded from the mathematical total and a
`currencyConversionMissing` conflict is produced. The Plan surface displays
the latest rate timestamp used by the calculation.

Legacy `TripBudget` JSON without currency rates continues to decode with an
empty rate collection.

## Conflict rules

The deterministic engine detects:

- Overlapping itinerary items
- Insufficient travel time, including route buffers
- Explicitly closed venues from weekday source text
- Total budget overflow after protecting the emergency reserve
- Per-category budget overflow
- Duplicate activities
- Disruptive weather on outdoor or weather-dependent items
- Missing dietary evidence
- Missing accessibility evidence
- Excessive daily travel for the requested trip pace
- Selected flights, stays, events, and reservation-required places that lack
  a provider-confirmed booking record
- Missing currency conversions

Every conflict contains:

- Stable identifier
- Kind
- Advisory, warning, or critical severity
- Plain-language title
- Evidence-based explanation
- Recommended resolution
- Related itinerary identifiers
- Related day identifier when applicable

Conflict ordering is stable: critical first, then warning and advisory,
followed by conflict kind and identifier.

## Session integration

`TripPlanningSession` owns the current `TripBudgetConflictAnalysis`.

Analysis runs when:

- A trip becomes ready
- A flight selection changes
- A hotel selection changes
- An itinerary item moves
- An itinerary item is locked or unlocked

This keeps the Plan surface synchronized with shared trip mutations without
network access or GPT calls.

## Plan interface

The Budget / Conflict Core includes:

- Budget utilization ring
- Planned and confirmed spend
- Available amount after reserve
- Six-category ledger
- Category limits and progress bars
- Explicit unknown-cost count
- Critical and review conflict cards
- Explanation and resolution for every flag
- Exchange-rate evidence timestamp
- Visible statement that totals are calculated locally

Amber indicates review or conflict, green is reserved for protected or
confirmed states, and labels ensure meaning never depends on color alone.

## Debug verification

`GIA_DEBUG_BUDGET_CONFLICT_FIXTURE=1` creates a Lisbon trip with:

- A protected emergency reserve
- A timestamped EUR-to-USD conversion
- Food category overflow
- A route-buffer shortfall
- An explicitly closed restaurant
- Missing dietary and accessibility evidence
- A weather conflict for an outdoor ticketed event
- A selected event without a provider-confirmed reservation

`GIA_DEBUG_SCROLL_TO_BUDGET_CONFLICT=1` scrolls directly to the analysis
surface.

## Automated verification

`BudgetConflictEngineVerificationMain.swift` checks:

- Category and total arithmetic
- Emergency-reserve protection
- Currency conversion and timestamp retention
- Total and category overflow
- Travel-buffer conflicts
- Closed venue detection
- Dietary and accessibility checks
- Weather conflicts
- Missing reservation detection
- Stable severity ordering
- Backward-compatible budget decoding

## Truthfulness

- Different currencies are never added without a timestamped rate.
- Missing prices are never converted to fabricated zero-dollar costs.
- Demo confirmation is never counted as provider-confirmed spend.
- Selected does not mean booked.
- GPT cannot change deterministic totals or rule outcomes.
- Weather and venue claims require sourced domain evidence.

## FBLA evidence

This card demonstrates original algorithms, arithmetic and semantic
validation, budget management, schedule feasibility, accessible explanations,
source-aware currency handling, and responsible AI boundaries.
