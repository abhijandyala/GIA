# Phase 2 — Card 3: Trip Planning Session State Machine

## Status

Complete.

## Objective

Create one guarded source of truth for the complete assistant-to-plan workflow.
Visual animation flags may remain local to their renderer, but semantic planning
state must not be represented by unrelated booleans across Map, Plan, and Group.

## Shared ownership

`RootContainer` creates one `TripPlanningSession` and injects it through the
SwiftUI environment. The same session can be observed by Map, Plan, and Group
without moving feature-specific rendering details into global state.

`MapScreen` now derives assistant-active and returning semantics from the shared
session. Manual activation and wake-phrase activation use the same guarded
workflow. Existing SceneKit and SwiftUI animation state remains local to Map.

## Phases

```text
idle
├── wakePhraseDetected
│   └── listening
└── listening
    ├── transcribing
    ├── validating
    │   ├── needsClarification
    │   └── searching
    │       ├── comparing
    │       │   └── buildingItinerary
    │       │       └── presenting
    │       │           └── ready
    │       └── partiallyAvailable
    ├── failed
    ├── cancelled
    └── returning
        └── idle
```

Failure, cancellation, partial availability, and return transitions are also
allowed from the applicable in-progress phases.

## Session data

The session owns:

- Current phase
- Manual, wake-phrase, or debug activation source
- Current validated request
- Completed trip
- Required clarification fields
- Unavailable providers
- User-safe failure details
- A bounded transition history
- A monotonic revision value for observers

It deliberately does not own:

- SceneKit nodes
- Ripple reveal progress
- Microphone amplitude
- API credentials
- Provider DTOs
- View presentation details

## Transition integrity

Every public operation validates its transition before mutating related session
data. Invalid operations throw `TripPlanningTransitionError` and leave the
session unchanged.

Examples:

- Search cannot begin without a request.
- A trip cannot become ready if structural domain issues exist.
- Retry is available only from failure.
- Return must complete before the session becomes idle.
- A completed trip is preserved after returning.
- The transient request is cleared before the next activation.

## Failure safety

Only a user-safe error code, message, recoverability flag, and timestamp enter
the observable session. Provider errors, request payloads, and secrets remain
outside this layer.

## Verification

`Verification/TripPlanningSessionStateMachineMain.swift` checks:

- Initial idle state
- Rejection of invalid transitions
- Atomic failure behavior
- Wake detection through listening
- Transcription and validation
- Clarification and resumed listening
- Search, comparison, itinerary build, and presentation
- Completion with a structurally valid trip
- Return while preserving the completed trip
- Clearing stale requests before a new activation
- Recoverable failure and retry
- Cancellation and return
- Transition history and revision updates

The existing assistant cycle was also launched in the simulator with automatic
activation and return to verify that centralizing semantic state did not alter
the approved visual transition.

## FBLA evidence

This card supports:

- Expert architectural patterns
- Predictable application functionality
- Semantic input-validation foundations
- Recoverable error handling
- Clear separation between workflow, domain, provider, and rendering layers
- Tangible planning and technical documentation
