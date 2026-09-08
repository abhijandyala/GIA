# Phase 2 — Card 7: Interpreted Request and Clarification

## Status

Complete.

## Objective

Show what GIA understood before any provider call, validate required planning
constraints, and let a traveler correct one field without repeating the entire
request.

## Deterministic interpretation

`TripRequestInterpreter` provides a local, API-independent baseline parser. It
extracts:

- Origin when explicitly phrased as `from … to …`
- Destination
- Trip duration in days, nights, or weeks
- Explicit ISO date ranges
- Traveler count in digits or common number words
- Numeric or spoken budgets
- USD, EUR, and GBP currency context
- Interests
- Dietary requirements
- Accessibility requirements

This parser is intentionally deterministic and testable. A later GPT card may
expand natural-language coverage, but GPT output must pass the same validation
and domain model.

## Required planning constraints

Before search, GIA requires:

- Destination
- Exact travel dates
- Traveler count
- Positive total budget with a currency

Duration alone does not invent dates. For example, `seven days in Lisbon`
displays `7 days · choose dates` and asks the user to provide the exact range.

## Semantic validation

The validator detects:

- Missing destination
- Missing exact dates
- Return before departure
- Past travel dates
- Duration outside 1–90 days
- Missing group size
- Group size outside 1–30
- Missing budget
- Nonpositive budget
- Invalid currency-code length
- Identical origin and destination

Issues carry a field, severity, and user-facing explanation. Provider errors and
internal implementation details never enter this model.

## Planning-state integration

```text
transcribing
└── interpret transcript
    └── validating
        ├── no issues → remain validating
        └── issues → needsClarification
            └── field correction
                └── validating
                    ├── remaining issues → needsClarification
                    └── no issues → ready for search card
```

`TripPlanningSession.replaceRequestDuringValidation` updates requests only while
the session is validating or clarifying. Invalid workflow phases reject the
mutation.

## Plan visualization

Resolved context uses the existing Plan intelligence accent. Missing context:

- Remains textually identifiable
- Uses a restrained luminous indicator
- Displays a concrete clarification question
- Is selectable through the complete metric region
- Provides a VoiceOver edit hint

The phase header changes to `ONE MORE DETAIL` while clarification is required.

## Correction interface

The spatial correction sheet supports:

- Destination text
- Departure and return dates
- Group size from 1–30
- Positive budget and currency

Save is disabled until the current field is syntactically valid. Saving:

1. Updates only the selected field.
2. Preserves the original transcript and all other extracted constraints.
3. Revalidates the complete request.
4. Returns to clarification if another required value remains.
5. Returns to validation when all required fields are valid.

## Current parsing boundary

Natural-language dates such as `next spring` or `the second week of June` are
not guessed locally. They remain unresolved until corrected manually or parsed
by the later GPT interpretation card. Explicit `YYYY-MM-DD to YYYY-MM-DD`
ranges are supported for deterministic verification.

## Verification

Automated verification covers:

- Lisbon extraction
- Atlanta origin and Tokyo destination extraction
- Day and night duration conversion
- Digit and number-word traveler counts
- Numeric and spoken budgets
- Currency extraction
- Interest, dietary, and accessibility matching
- Missing-date clarification
- Complete-request validation
- Field correction from clarification to validation
- Request preservation in shared session state

Runtime verification confirms:

- Interpreted values appear in Plan.
- Only missing dates remain luminous for the demo fixture.
- The precise clarification question appears.
- The date correction sheet opens above the existing Plan context.
- Provider modules remain queued.

## FBLA evidence

This card directly supports:

- Syntactic input validation
- Semantic input validation
- Intuitive correction behavior
- Accessible user input
- Original application logic beyond an AI wrapper
- Honest separation between understood constraints and live data
