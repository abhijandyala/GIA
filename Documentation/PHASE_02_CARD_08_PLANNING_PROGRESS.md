# Phase 2 — Card 8: Truthful Planning Progress

## Status

Complete.

## Objective

Make GIA's planning work visible without fabricated percentages, fake provider
counts, or timer-driven success. Progress must be workflow data updated by
validated application events and future provider adapters.

## Workstreams

The shared session tracks:

1. Request understanding
2. Destination resolution
3. Flights
4. Stay
5. Experiences
6. Weather
7. Routes
8. Schedule
9. Budget

Each workstream has exactly one state:

- Queued
- Waiting for input
- Active
- Complete
- Unavailable
- Cancelled

## Progress data

`PlanningWorkItem` stores:

- Workstream identifier
- Current status
- Optional real result count
- Providers that contributed data
- User-safe status message
- Start timestamp
- Completion timestamp

`TripPlanningProgress` owns an ordered collection of these items. It exposes the
active item, completed count, and whether any provider-backed work has actually
started.

No percentage is stored or calculated.

## Session integration

`TripPlanningSession` is the only mutator of shared progress.

- Validation starts Request understanding.
- Clarification changes Request to waiting for input.
- A correction resumes Request understanding.
- Beginning search completes Request and Destination.
- Provider adapters may begin, complete, or mark their workstreams unavailable.
- Completing a trip synchronizes statuses only from data actually present in
  the trip aggregate.
- Cancellation preserves completed work but cancels queued, active, and
  input-waiting work.
- Returning without a completed trip resets progress.

Progress mutations are phase guarded. For example, Budget cannot begin during
provider search, and a negative result count is rejected without changing
state.

## Plan visualization

The `GIA PROCESS` surface provides:

- Current active work description
- Explicit statement when no live search has started
- Cancel control during cancellable phases
- Horizontally scrollable workstream nodes
- Textual status for every node
- Real result counts when supplied
- Provider-independent active, complete, unavailable, and cancelled treatment

Existing Plan module cards now read the same progress data. They no longer infer
activity solely from the broad planning phase.

## Truthfulness rules

- Result count remains absent until explicitly provided.
- Zero is a valid real result count.
- Counts cannot be negative.
- A timer never marks work complete.
- A module cannot display Ready solely because time elapsed.
- Provider failure becomes Unavailable, not Complete.
- Debug fixture counts exist only under `DEBUG` and never run in production.
- The interface does not imply booking activity.

## Cancellation

Cancel uses a confirmation dialog explaining:

- The captured request will be cleared.
- No provider booking has been made.

After confirmation:

1. Session moves to cancelled.
2. Open workstreams become cancelled.
3. Map becomes selected.
4. Map recognizes the cancelled workflow.
5. Existing sphere-to-Earth return animation runs.
6. Session returns to idle.
7. Wake listening resumes.

## Accessibility

- Cancel has an explicit accessibility label.
- Every progress node exposes workstream and status.
- Status does not depend on color.
- Horizontal overflow remains scrollable at large text sizes.
- Active glow is supplemental rather than required.
- Increased Contrast inherits the stronger Plan surface boundary.

## Debug verification

`GIA_DEBUG_PROGRESS_FIXTURE=1` configures a source-labeled progress fixture after
a complete debug request reaches Plan.

`GIA_DEBUG_AUTOCANCEL_PLAN=1` exercises the full Plan cancellation and Earth
return path.

These controls are compiled only in Debug builds.

## Verification

Automated verification checks:

- Nine initially queued workstreams
- No false provider-start state
- Validation and clarification status
- Search transition completion
- Phase-guarded workstream updates
- Provider attribution
- Real result-count storage
- Negative-count rejection
- Unavailable provider state
- Cancellation behavior
- Idle reset after return

Runtime verification confirms:

- Active and complete nodes render distinctly.
- Real counts appear in both progress and module surfaces.
- Current active work is readable.
- Cancel returns through the existing Earth animation.
- Correct date-only values do not shift across time zones.

## FBLA evidence

This card supports:

- Honest application functionality
- Original planning visualization
- Expert workflow architecture
- Data integrity and validation
- Accessible state communication
- Recoverable cancellation
- Clear preparation for live provider integration
