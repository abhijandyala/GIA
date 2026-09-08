# Phase 2 — Card 13: Restaurant and Activity Discovery

## Status

Source complete. Live-key verification remains pending until previously exposed
credentials are rotated.

## Objective

Discover real restaurants and activities while minimizing paid search usage and
preserving uncertainty around ratings, hours, dietary support, accessibility,
and reservations.

## Provider strategy

```text
Validated PlaceSearchCriteria
├── Geoapify configured + destination coordinate
│   └── Geoapify Places primary search
│       ├── Results found → return Geoapify results
│       ├── Zero results + SerpApi configured → fallback
│       └── Provider failure + SerpApi configured → fallback
└── SerpApi Google Maps fallback
```

Geoapify is the normal low-cost path. SerpApi runs only when:

- Destination coordinates are unavailable
- Geoapify fails
- Geoapify returns no matches
- Geoapify is not configured

## Request validation

The gateway validates:

- Destination name
- Optional coordinate range
- Result limit from 1–50
- Radius from 100–50,000 meters
- At least one supported place category

Interests may expand categories:

- Food → restaurants and cafés
- Museums or art → museums
- Nature → parks
- Shopping → shopping
- Nightlife → bars/nightlife
- Sports → sports

When no category or matching interest exists, discovery defaults to restaurants
and attractions.

## Geoapify request

The adapter uses:

- `GET /v2/places`
- Supported category list
- Circle filter around destination coordinates
- Proximity bias
- Bounded result limit
- Server-only API key

Typed mappings include:

- Restaurants
- Cafés
- Museums
- Attractions
- Parks
- Entertainment
- Landmarks
- Shopping
- Nightlife
- Sports

## SerpApi fallback

The fallback uses:

- `engine=google_maps`
- Category-aware destination query
- Search type
- Optional coordinate/zoom bias
- English result language
- Server-only API key

## Domain mapping

Both providers map into `PlaceRecommendation`:

- Stable provider identifier and deterministic UUID
- Name
- Coordinates
- City, region, country, and country code when available
- Typed place categories
- Description or formatted address
- Rating and review count when supplied
- Price level when supplied
- Raw opening-hours evidence
- Open/closed state at retrieval when supplied
- HTTPS images when supplied
- Official website when supplied
- Explicit booking link when supplied
- Dietary evidence when present in source categories
- Wheelchair evidence when explicitly supplied
- Six-hour live provenance

## Uncertainty rules

Geoapify does not normally provide ratings or reviews. Those fields remain nil;
the adapter never fabricates them.

The adapter does not infer:

- Dietary suitability from a restaurant name
- Accessibility from absence of barriers
- Indoor/outdoor status
- Whether reservations are required
- Whether a booking slot is available
- Typical visit duration
- Cost when the provider does not supply it

SerpApi `order_online` links are not treated as reservation links.

## Hours boundary

Provider opening-hour strings are preserved as source text. An open/closed
Boolean is stored only when the provider explicitly supplies current state.

Scheduling logic must parse and validate operating windows in its own later
card before placing a venue in the itinerary.

## Failure behavior

Safe errors cover:

- Missing provider configuration
- Missing coordinates when Geoapify is the only provider
- Invalid limits/radius/categories
- Timeout
- Transport failure
- Rate limit
- Authorization failure
- Provider failure
- Invalid JSON
- Unsupported response shape

A genuine empty result remains an empty result. A nonempty response where every
record lacks usable identity or coordinates becomes a provider error.

## Workflow integration

`PlaceSearchCoordinator`:

1. Marks Experiences active with possible provider attribution.
2. Calls the narrow `PlaceSearching` protocol.
3. Supports cancellation.
4. Derives actual contributing providers from returned provenance.
5. Completes Experiences with the real result count.
6. Marks Experiences unavailable after provider failure.

It does not select, schedule, reserve, or book a place.

## Verification

Gateway tests cover:

- Geoapify category, radius, bias, and limit parameters
- Category expansion from interests
- Stable Geoapify mapping
- No fabricated rating/review data
- Dietary and wheelchair evidence
- Opening-hour preservation
- SerpApi query mapping
- Ratings, reviews, price level, hours, image, website, and booking link
- Geoapify failure fallback
- Coordinate-missing fallback
- Empty-versus-malformed distinction
- Invalid preflight criteria
- Missing-provider failure

Swift verification decodes mixed Geoapify/SerpApi results into
`PlaceRecommendation` and confirms typed categories, dietary/accessibility
evidence, ratings, price level, URLs, provenance, contributing providers, and
the Experiences workstream result count.

No test consumes Geoapify or SerpApi quota.

## FBLA evidence

This card supports:

- Real restaurant and activity discovery
- Cost-aware provider design
- Secure credential handling
- Dietary and accessibility consideration
- Honest unknown-data behavior
- Source attribution
- Recoverable service fallback
