# Phase 2 — Card 6: Plan Spatial Shell

## Status

Complete.

## Objective

Establish the permanent Plan information hierarchy before provider results,
comparison cards, or itinerary logic are connected. The shell must feel
spatial and intelligent while remaining readable, truthful, responsive, and
accessible.

## Delivered regions

### Planning header

- Compact animated GIA indicator
- `PLAN SYNTHESIS` identity
- Current semantic planning phase
- Restrained cool-blue active state

### Request surface

- Original captured transcript
- Destination
- Dates
- Traveler count
- Budget

Unresolved fields explicitly display `Resolving`. The shell never invents
values from transcript text.

### Planning systems

A horizontally aligned module rail reserves stable locations for:

- Flights
- Stay
- Experiences
- Routes
- Weather

Modules can display queued, active, ready, or unavailable state. Ready state is
allowed only when the shared `Trip` contains the relevant domain data.

### Timeline foundation

The initial itinerary surface exposes three truthful stages:

1. Request captured
2. Travel options
3. Shared itinerary

The timeline does not display fake days or activities before the itinerary
builder produces them.

## Presentation architecture

`PlanPresentationModels` maps shared domain and workflow state into view-facing
metrics:

- Phase title and detail
- Destination/date/traveler/budget context
- Module status
- Result-presence checks

Views do not inspect provider DTOs or infer success from elapsed time.

Reusable Plan components:

- `GIAPlanningIndicator`
- `PlanHeaderView`
- `PlanSurfaceModifier`
- `PlanningModuleRail`
- `PlanTimelineFoundation`
- `PlanWorkspaceView`

## Visual language

- Near-black spatial canvas
- Translucent charcoal surfaces
- Thin white geometry
- One cool-blue intelligence accent
- Fine borders and restrained bloom
- Rounded native typography
- No decorative fake telemetry
- No dead controls

## Responsive behavior

- Screen-edge spacing derives from container width.
- Module cards horizontally scroll rather than compressing content.
- Module width and minimum height scale with Dynamic Type.
- The header switches to a stacked composition at accessibility text sizes.
- Request metrics use a flexible two-column grid.
- The entire workspace vertically scrolls.
- Bottom navigation remains persistent.

## Accessibility

- Increased Contrast strengthens Plan surface borders.
- Reduce Transparency produces opaque surfaces.
- Reduce Motion freezes the planning indicator.
- Every module exposes its name and status.
- Timeline rows combine their content and expose state.
- Request metrics do not communicate resolution through color alone.
- The original request remains readable as text.

## Truthfulness rules

- `Resolving` means no parsed value exists.
- `Queued` means no provider operation is represented as active.
- `Ready` requires actual data in the shared trip aggregate.
- Partial availability is visibly distinct from success.
- No price, result count, booking, or itinerary item is fabricated.

## Verification

Automated presentation verification checks:

- Four context metrics are always present.
- Parsed values become resolved.
- Missing values remain `Resolving`.
- Validating modules remain queued.
- Search phases become active.
- Partial phases become unavailable.
- Ready module state requires corresponding trip data.

Runtime verification confirms:

- Plan handoff opens the full shell.
- Plan remains selected.
- The original transcript remains intact.
- Header, request, modules, and timeline fit the large iPhone viewport.
- Horizontal module overflow clearly communicates scrollability.
- No content collides with persistent bottom navigation.
- Accessibility Large text avoids compressed or hyphenated phase titles.
- Increased Contrast produces clearly strengthened surface boundaries.

## FBLA evidence

This card supports:

- Original and consistent interface design
- Intuitive information hierarchy
- Accessible responsive behavior
- Expert component separation
- Honest application functionality
- A clear foundation for collaboration, scheduling, budgeting, and trip
  management
