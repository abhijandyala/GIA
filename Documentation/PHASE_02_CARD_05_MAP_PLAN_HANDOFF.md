# Phase 2 — Card 5: Map-to-Plan Handoff

## Status

Complete.

## Objective

Move a completed spoken request from the active GIA sphere into Plan as one
continuous visual and semantic transition. Wake detection alone must not change
tabs, and this card must not imply that provider search has started.

## Trigger contract

The handoff begins only when:

- Map is active
- Request transcription completed
- `TripPlanningSession` accepted a `TripRequest`
- The planning phase is `validating`

The captured transcript is placed in the request before navigation. Plan
therefore never appears with a visual request that is absent from shared state.

## Motion sequence

```text
Active GIA sphere with transcript
└── Request completes
    ├── TripPlanningSession → validating
    ├── Structured conversational response begins
    ├── Sphere contracts to 19 percent
    ├── Sphere moves toward the Plan header
    └── At the visual handoff point
        ├── Plan becomes the selected tab
        ├── Map pauses and fades
        └── Compact planning indicator takes over
```

The active circle's visible diameter and target position are calibrated to the
72-point Plan indicator. The Plan insertion uses a short scale/opacity settle so
the destination indicator reads as the same object rather than a replacement.

## Plan landing state

Card 5 adds only the handoff destination, not the complete Plan interface:

- Compact animated GIA planning indicator
- Semantic planning-status label
- Captured request
- Short description of the current phase
- Correct selected Plan navigation state

The landing component already maps later session phases to truthful labels:
validation, clarification, search, comparison, itinerary construction,
presentation, partial results, ready, failure, and cancellation.

No fake provider counts, percentages, options, prices, or booking states are
displayed.

## Cancellation and lifecycle

- Starting another assistant activation cancels stale handoff work.
- Returning to Earth cancels the handoff and restores full circle scale.
- Leaving Map cancels pending delayed navigation.
- Backgrounding during validation does not switch tabs.
- Returning to Map does not automatically bounce back into Plan.
- Voice capture stops when Map becomes inactive.
- G.I.A. audio is owned above the tabs and may finish after Plan appears.
- Slow response generation never blocks the tab transition.

## Accessibility

- Reduce Motion replaces contraction with a short crossfade.
- The planning indicator exposes a concise VoiceOver status.
- The captured request and current phase are combined into readable content.
- The menu escape action remains attached to the menu overlay itself.
- The handoff does not rely on color to communicate state.

## Debug verification

Debug builds accept:

`GIA_AUTORUN_PLAN_HANDOFF_TRANSCRIPT`

The value becomes a complete request and exercises the same validating and
navigation handoff without consuming speech or provider quota.

Verification confirms:

- Plan becomes selected
- Captured text survives navigation
- The compact indicator is visible
- Map is no longer selected
- Bottom navigation remains persistent
- No provider request is made
- Existing iOS build and Xcode project remain valid

## FBLA evidence

This card supports:

- A coherent user journey
- Original spatial interaction design
- Appropriate app-state architecture
- Accessible motion alternatives
- Honest application functionality
- Clear separation between input capture and live provider search
