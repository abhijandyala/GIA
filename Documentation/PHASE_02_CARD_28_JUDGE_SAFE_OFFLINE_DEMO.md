# Phase 2 — Card 28: Judge-Safe Offline Demonstration

## Status

Complete with a comprehensive bundled Tokyo fixture, manual-only activation,
explicit Demo labeling, the normal Plan interface, and repeatable reset.

## Objective

Guarantee that the seven-minute FBLA presentation can demonstrate the complete
group-trip journey without conference internet or live API availability.

## Bundled Tokyo fixture

`JudgeDemoTripFactory` is compiled into the application and performs no network
access.

It contains:

- Atlanta origin
- Tokyo destination and time zone
- April 3–10, 2027 date range
- Four travelers
- Traveler roles, availability, budgets, interests, dietary needs, and
  accessibility needs
- Two flight options
- Two hotel options
- Restaurants
- Museums and attractions
- One fixed ticketed event
- Two weather days
- Three local transportation legs
- Two itinerary days
- Six budget allocations and emergency reserve
- Flight/hotel/place selections
- Approved and open group decisions
- Labeled System and G.I.A. chat messages
- Mentions and reactions
- Membership audit history

Every provider-backed object uses `DataOrigin.demo`. No fixture price,
availability, rating, route, weather condition, or reservation is represented
as live.

## Normal request isolation

The fixture is never an automatic fallback. Offline, timeout, and provider
failures preserve the requested destination and show unavailable or partial
workstreams. They cannot load Tokyo or replace a normal typed/voice request.

The bundled fixture can enter the planning session only through the explicit
menu action (or the debug-only manual-demo launch flag).

## Manual presentation control

The Map hamburger menu includes:

- Start Offline Demo
- Restart Offline Demo
- Reset Demo
- No Network Required label

Manual start uses the same assistant focus and Plan handoff before loading the
fixture.

## Reset

Reset:

- Cancels pending demo loading
- Stops speech and microphone work
- Clears demo state
- Clears the active planning session
- Returns to Map
- Restores the Earth/assistant idle presentation
- Resumes normal wake-listening eligibility

The factory uses one stable Trip UUID so repeated demo launches remain
deterministic.

## Visual labeling

Plan displays:

- `JUDGE-SAFE OFFLINE DEMO`
- Trigger reason
- `DEMO` pill
- `Bundled Tokyo fixture`
- `No live booking or provider availability claimed`

Flights, hotels, and booking surfaces retain their existing Demo
labels and truth disclosures.

## Session lifecycle

The demo is in memory only. Relaunch starts on a clean Map and never restores
the fixture.

## Debug verification

- `GIA_DEBUG_JUDGE_DEMO=1` runs manual judge-demo startup automatically.

## Automated verification

`JudgeDemoVerificationMain.swift` checks:

- Stable demo Trip identity
- Structural validity
- Tokyo request
- Flights, hotels, places, event, weather, routes, itinerary, budget, group,
  decisions, and chat completeness
- Selected travel options
- Demo origin on every provider-backed object
- Manual-only controller active/reset lifecycle
- Session completion and reset
- Repeatable factory output

## Truthfulness

- Demo data is never labeled Live or Cached.
- A fixture selection is not a real booking.
- The banner states that provider availability is not claimed.
- The fallback does not fabricate a successful network response.
- Reset does not claim to cancel provider reservations.
- The same accessibility and reduced-motion paths remain available.

## FBLA evidence

This card protects the required live presentation from unreliable venue
internet while demonstrating flights, hotels, restaurants, activities,
weather, transportation, budgeting, group preferences, voting, communication,
offline persistence, and responsible Demo labeling in one coherent journey.
