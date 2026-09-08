# Phase 2 — Card 16: Weather Intelligence

## Status

Source complete. Live-key verification remains pending until the exposed
WeatherAPI credential is rotated.

## Objective

Provide destination-aware hourly forecasts and government alert context without
using current weather as a substitute for a distant trip forecast or allowing
GPT to invent safety guidance.

## Forecast horizon

WeatherAPI forecasts begin today. The gateway uses
`WEATHERAPI_FORECAST_DAYS_LIMIT`, defaulting to three days for free-tier
compatibility and bounded to 1–14.

The adapter:

1. Calculates today in the destination time zone.
2. Calculates the configured forecast horizon.
3. Intersects the trip dates with that horizon.
4. Skips the provider request when the trip begins beyond the horizon.
5. Returns zero snapshots with `Forecast not yet available` workflow context.

Distant trips therefore consume no weather quota and never display today's
weather as their forecast.

## Request validation

The gateway requires:

- Location identifier and name
- Valid coordinate
- Valid IANA time zone
- Chronological trip date range
- Trip that has not already ended
- Explicit alert preference

Invalid requests fail before provider access.

## WeatherAPI request

The adapter uses:

- `GET /v1/forecast.json`
- Latitude/longitude query
- Bounded forecast-day count
- `alerts=yes` only when requested
- `aqi=no`
- Server-only API key

## Hourly mapping

Each mapped `WeatherPeriod` contains:

- Deterministic UUID
- One-hour start/end
- Clear, cloudy, fog, rain, snow, storm, wind, or unknown category
- Original provider condition code
- Original provider description
- Temperature Celsius when supplied
- Feels-like Celsius when supplied
- Rain/snow probability when supplied
- Wind speed when supplied

Missing values remain nil. Missing rain/snow probability never becomes zero.

Only hourly periods intersecting the requested trip dates enter the snapshot.

## Alert mapping

Government alert fields include:

- Headline
- Reporting agency when supplied
- Minor, moderate, severe, extreme, or unknown severity
- Effective time
- Expiration
- Instructions
- HTTPS source URL

Expired and duplicate alerts are removed. Alerts are omitted entirely when the
request does not ask for them.

WeatherAPI coverage depends on reporting agencies and country. The application
must never state that global official warning coverage is guaranteed.

## Provenance

`WeatherSnapshot` preserves:

- Provider-resolved location and time zone
- Hourly periods
- Active alerts
- WeatherAPI provider identity
- Retrieval timestamp
- Fifteen-minute expiration
- Non-secret source URL

No URL containing the WeatherAPI key reaches the app.

## Deterministic advisories

`WeatherAdvisoryEngine` produces non-destructive planning advice:

- Severe/extreme alert → critical avoid-outdoor advisory
- Storm → critical avoid-outdoor advisory
- Snow → allow extra transportation time
- Rain probability at least 60% → prefer indoor
- Strong wind → review/reschedule outdoor activity
- Temperature at or above 35°C or at/below 0°C → prefer climate-controlled
  activity

Advisories retain their source alert or weather-period identifier and effective
window.

The engine does not automatically move or cancel itinerary items. The later
conflict engine must compare these advisories with sourced activity traits and
ask for approval.

## Workflow integration

`WeatherSearchCoordinator`:

1. Marks Weather active with WeatherAPI attribution.
2. Calls the `WeatherProviding` protocol.
3. Supports cancellation.
4. Completes Weather with the actual snapshot count.
5. Uses a truthful distant-forecast message for zero snapshots.
6. Marks Weather unavailable after provider failure.

## Failure behavior

Safe errors cover:

- Missing configuration
- Missing location/coordinate/time zone
- Reversed or completed trip dates
- Timeout
- Transport failure
- Rate limit
- Authorization failure
- Provider failure
- Invalid JSON
- Missing or malformed forecast structure

## Verification

Gateway tests cover:

- Forecast horizon calculation
- Zero-quota distant-trip behavior
- Destination coordinate and day parameters
- Alert request behavior
- Hourly condition mapping
- Condition categorization
- Rain/snow probability
- Missing optional-value preservation
- Provider location/time zone
- Government alert mapping
- Duplicate/expired alert removal
- Fifteen-minute provenance
- Invalid preflight requests
- Missing forecast detection
- Sanitized authorization failure
- Missing-key failure

Swift verification decodes the exact gateway contract, updates Weather progress,
and confirms deterministic critical-alert and rain advisories.

No test consumes WeatherAPI quota.

## Deliberate exclusions

- No live weather request
- No weather animation layer
- No automatic itinerary mutation
- No guaranteed global warning claim
- No GPT-authored weather fact

## FBLA evidence

This card supports:

- Weather-aware group planning
- Safety-conscious design
- Time-zone-aware data handling
- Semantic validation
- Secure provider integration
- Honest forecast uncertainty
- Deterministic original planning logic
