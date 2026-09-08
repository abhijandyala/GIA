# Phase 2 — Card 20: Spatial Daily Timeline

## Status

Complete with Debug-only itinerary fixtures. Live itinerary population awaits
provider orchestration and blueprint assembly.

## Objective

Turn the shared itinerary into the central time-aware Plan experience while
preserving fixed schedules, flexible edits, sourced transportation, weather,
cost, and booking truthfulness.

## Timeline hierarchy

### Day selector

- Chronological itinerary days
- Local weekday/day label
- Weather summary when sourced
- Selected-state text and visual treatment
- Horizontal overflow

### Day header

- Full local calendar date
- Sourced weather condition
- Temperature when available

### Itinerary nodes

Each item may display:

- Type icon
- Title
- Local start/end
- Location
- Estimated cost
- Proposed, selected, confirmed, completed, or cancelled status
- Fixed, flexible, or user-locked state
- Expandable notes
- Lock action when applicable
- Visible drag handle only when movable

### Transportation connectors

Adjacent item locations are connected only when a sourced
`TransportationLeg` matches origin and destination by coordinate or normalized
name.

Connected routes display:

- Mode
- Duration
- Estimated/scheduled/approximated/live confidence

Missing routes explicitly display `Route not connected`.

## Editing contract

`TripPlanningSession.moveItineraryItem` requires:

- Ready or partially available trip
- Existing source item
- Flexible item
- Chronological start/end
- Time inside trip boundaries
- Existing target itinerary day
- No overlap with another item

The operation:

1. Preserves item duration.
2. Removes the item from its previous day.
3. Inserts it into the target day.
4. Restores chronological order.
5. Updates trip timestamp and session revision.

Invalid edits leave the trip unchanged.

## Drag behavior

- Dragging is attached only to the visible handle.
- Vertical Plan scrolling remains available elsewhere.
- Movement snaps in 15-minute increments.
- Drag preview is bounded to 96 points.
- Failed edits return to the original location.
- Reduce Motion uses an immediate offset reset.

## Lock behavior

- Fixed items cannot be unlocked.
- Flexible items can become user locked.
- User-locked items can be unlocked.
- Locked items cannot move.
- Lock state is shared trip data, not local presentation state.

## Accessibility

Movable items expose:

- Move 15 minutes earlier
- Move 15 minutes later

Fixed and locked items do not expose ineffective movement actions.

Every item combines title, time, location, flexibility, and cost into an
accessible summary. Day buttons expose selection state. Transportation
connectors combine mode, duration, and confidence.

## Truthfulness

- Selected does not mean booked.
- Confirmed is displayed only when domain state says confirmed.
- Costs remain estimated unless booking records establish otherwise.
- Weather remains provider sourced.
- Missing route remains missing.
- Fixed event times are not draggable.
- Route buffers do not alter displayed provider duration.
- No vote avatars appear before collaboration data exists.

## Debug verification

`GIA_DEBUG_TIMELINE_FIXTURE=1` creates:

- Two Lisbon itinerary days
- Sourced weather
- Flexible breakfast
- Fixed museum entry
- Flexible restaurant
- Fixed ticketed outdoor event
- User-locked activity
- Open group time
- Sourced transit and walking connectors

`GIA_DEBUG_SCROLL_TO_TIMELINE=1` scrolls directly to the timeline.

All fixture data is marked Demo and compiles only in Debug.

## Verification

Automated verification covers:

- Chronological day/item presentation
- Local time/date formatting
- Weather summary
- Cost formatting
- Route matching and duration
- Valid flexible move
- Duration preservation
- Overlap rejection
- Fixed-item rejection
- User lock/unlock
- Locked-item rejection
- Unknown item and trip boundaries

Runtime verification covers:

- Day selector
- Weather context
- Node hierarchy and connector lines
- Flexible/fixed labels
- Drag handles
- Costs
- Sourced route confidence
- Persistent bottom navigation

## FBLA evidence

This card supports:

- Scheduling and trip management
- Transportation organization
- Budget visibility
- Weather awareness
- Semantic edit validation
- Accessible equivalent interactions
- Original spatial interface design
