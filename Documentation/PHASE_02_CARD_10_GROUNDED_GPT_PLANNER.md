# Phase 2 — Card 10: Grounded GPT Planning Orchestrator

## Status

Source complete. Live-key verification is intentionally pending until the
exposed credential has been rotated and installed in the gateway environment.

## Objective

Use GPT to select and organize sourced travel options without allowing the model
to invent prices, ratings, schedules, availability, bookings, or provider
records.

## Architecture

```text
Validated TripGenerationCriteria
└── G.I.A. gateway
    ├── Remove transcript and checkout URLs
    ├── Bound provider collections
    └── OpenAI Responses API
        └── Strict TripPlanBlueprint JSON
            ├── Server grounding validation
            └── iOS grounding validation
```

The iOS application never calls OpenAI directly and never contains an OpenAI
credential.

## Model configuration

- API: OpenAI Responses API
- Default model: `gpt-5.4`
- Model override: `OPENAI_MODEL`
- Output: strict Structured Outputs JSON schema
- Reasoning effort: medium
- OpenAI storage request: disabled with `store: false`
- Web search: disabled for itinerary construction

Web search is not used because price, schedule, and availability claims must
come from typed provider results. Later discovery may use web search as a
separate cited tool, but it cannot silently enter a sourced itinerary.

## Model context

Included:

- Structured destinations and origin
- Dates and duration
- Traveler count
- Budget and currency
- Interests
- Dietary and accessibility requirements
- Flight and hotel preferences
- Bounded sourced flights
- Bounded sourced hotels
- Bounded sourced places
- Bounded sourced routes
- Bounded sourced weather

Excluded:

- Provider API keys
- Gateway authorization
- Original raw spoken transcript
- Booking and checkout URLs
- Provider response headers
- Internal errors
- User authentication credentials

## Blueprint output

GPT may output:

- Plan title
- Short summary
- Selected flight UUIDs
- Selected hotel UUIDs
- Itinerary days
- Sourced itinerary item UUIDs
- Free-time blocks
- Recommendation reasons
- Warnings

GPT cannot output:

- Prices
- Ratings
- Availability claims
- Booking status
- Confirmation codes
- Refund status
- New provider records
- Arbitrary source names

Those values remain attached to the original domain records.

## Strict validation

The server rejects:

- Unknown flight or hotel selections
- Unknown itinerary source identifiers
- Missing source identifiers
- Provider identifiers on free-time blocks
- Reversed start/end times
- Items outside the trip date range
- Overlapping itinerary items
- Invalid day formats
- Missing required blueprint properties
- Additional unexpected properties
- Oversized strings or collections

The server rebuilds a sanitized blueprint object rather than forwarding the
parsed model object.

The iOS `TripPlanBlueprintValidator` repeats critical checks for defense in
depth:

- Source identity and source kind
- Flight/hotel selections
- Item chronology
- Item overlap
- Trip boundaries
- Time-zone identifiers
- Free-time source rules
- Codable integrity

## Error handling

The gateway maps OpenAI failures into safe responses:

- Not configured
- Transport unavailable
- Timeout
- Rate limited
- Authorization failure
- Invalid response
- Missing output
- Invalid JSON
- Invalid grounded blueprint

Upstream response bodies and authorization details never reach the iOS client.

## Deliberate exclusions

- No live OpenAI request was made.
- No exposed key was read.
- No provider search was started.
- No Plan progress was advanced.
- No blueprint was persisted.
- No itinerary UI was populated.
- No booking claim was produced.

Those operations require later provider and orchestration cards.

## Verification

Gateway tests verify:

- Valid sourced blueprints
- Duplicate selection normalization
- Unknown-source rejection
- Overlap rejection
- Transcript and checkout URL removal
- Responses API request shape
- Strict schema configuration
- `store: false`
- Configurable model
- Missing-key failure
- Sanitized authorization failure

iOS verification confirms:

- Valid source references
- Unknown-source rejection
- Overlap rejection
- Free-time source rejection
- Unknown flight selection rejection
- Blueprint Codable round trip
- Successful application build

No test consumes OpenAI quota.

## FBLA evidence

This card supports:

- Original functionality beyond an AI wrapper
- Secure API architecture
- Comprehensive semantic validation
- Source and copyright documentation
- Explainable recommendation logic
- Data integrity
- Honest separation between AI reasoning and factual travel data
