# Phase 2 — Card 9: Networking and Provider Boundaries

## Status

Complete. No live provider is connected by this card.

## Objective

Create a typed, secure, cancellable, retryable, and cache-aware path from the
iOS application to the Card 1 gateway. The mobile app must never call SerpApi,
OpenAI, ElevenLabs, Geoapify, WeatherAPI, or the translation provider directly.

## Domain service contracts

Provider-independent protocols now define:

- Flight search
- Hotel search
- Place search
- Route planning
- Weather retrieval
- Grounded trip-plan generation
- Speech generation
- Translation

Each protocol consumes typed criteria and returns shared Card 2 domain models.
No upstream provider DTO appears in a feature view or workflow session.

## Gateway endpoints

The iOS client supports:

```text
POST /v1/plan
POST /v1/search/flights
POST /v1/search/hotels
POST /v1/search/places
POST /v1/route
POST /v1/weather
POST /v1/speech
POST /v1/translation
```

The gateway now supports both sanitized JSON envelopes and secured binary
responses for generated speech. Provider response headers are not forwarded.

## Client security

`GIAGatewayClient` enforces:

- HTTPS for remote hosts
- HTTP only for localhost development
- Injected authorization
- No hard-coded mobile credential
- Unique request identifiers
- JSON content type
- Explicit accepted content type
- URLSession cache bypass
- Request timeout
- Typed, sanitized errors

Authorization is provided through a protocol. The included ephemeral provider
holds a short-lived token in memory. A Debug-only environment provider supports
local gateway testing without compiling the development token into the app.

Final production authorization must use user sessions and App Attest; a shared
token embedded in the application is not secure.

## Retry policy

The standard retry policy makes up to three attempts with bounded exponential
delay.

Retryable:

- HTTP 429
- HTTP 502
- HTTP 503
- HTTP 504
- Timeout
- Lost connection
- Offline connection
- Host connection failure
- DNS lookup failure

Not retryable:

- Unauthorized
- Forbidden
- Invalid request
- Decoding failure
- Explicit cancellation

`Retry-After` is respected and bounded by the configured maximum delay.

## Error contract

The client maps failures into:

- Invalid base URL
- Invalid response
- Encoding failure
- Decoding failure
- Unauthorized
- Forbidden
- Rate limited
- Provider unavailable
- Server failure
- Transport failure
- Timeout
- Cancellation

Feature code receives no raw provider exception, stack trace, credential, or
upstream response body.

## Cache policy

The application cache stores only successful sanitized gateway responses.
Request bodies are never used as filenames; endpoint and encoded request are
SHA-256 hashed.

Current TTL:

- Flights: 3 minutes
- Hotels: 5 minutes
- Places: 6 hours
- Routes: 15 minutes
- Weather: 15 minutes
- Translation: 24 hours in memory only
- Generated plans: not cached
- Speech audio: not cached

Memory is checked first. Disk entries are JSON-wrapped with expiration and use
atomic writes. On iOS, files receive complete-until-first-authentication data
protection.

Disk caching does not replace the later offline trip store. It is a short-lived
network optimization and stale-data fallback.

## Provider-agnostic service

`GatewayTravelService` implements all domain service protocols and maps gateway
response envelopes into:

- `[FlightOffer]`
- `[HotelOffer]`
- `[PlaceRecommendation]`
- `[TransportationLeg]`
- `[WeatherSnapshot]`
- `TripPlanBlueprint`
- `GeneratedSpeech`
- Translated text

Feature modules can depend on the narrow protocol they need rather than the
complete gateway service.

## Verification

Automated networking verification covers:

- Authorization header injection
- Correct endpoint construction
- Request identifier creation
- JSON envelope decoding
- Memory cache hits
- Protected disk cache reload
- Hash-only cache filenames
- HTTP 429 retry
- `Retry-After`
- Provider error mapping
- Cancellation during retry
- Binary speech responses
- Content type preservation

Gateway verification covers:

- JavaScript syntax
- Existing security tests
- Secured binary response behavior
- Provider-header removal

The iOS target and Xcode project are also built and validated.

## Deliberate exclusions

- No live key is read.
- No `.env` file is read by the iOS target.
- No provider API call is made.
- No background synchronization is started.
- No user or trip data is persisted permanently.
- No Plan progress is advanced by this card.

## FBLA evidence

This card supports:

- Expert modular architecture
- Comprehensive data-protection planning
- Reliable cancellation and failure handling
- Offline-aware design
- Provider and UI separation
- Testable code without consuming paid API quota
