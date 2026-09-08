# Phase 2 — Card 12: SerpApi Hotel Search

## Status

Source complete. Live-key verification remains pending until previously exposed
credentials are rotated.

## Objective

Retrieve worldwide Google Hotels results through the secure gateway, preserve
their pricing and source context, and map them into consistent `HotelOffer`
domain values without claiming that a room is reserved.

## Request validation

The server requires:

- Destination name
- Destination IANA time zone
- Check-in date
- Checkout after check-in
- Adult count from 1–30
- Room count from 1–10
- Room count not exceeding adult count
- Three-letter currency
- Minimum hotel class from 2–5 when supplied
- Guest rating from 0–5 when supplied
- Positive matching-currency maximum nightly rate when supplied

Invalid input fails before a SerpApi request.

## SerpApi request

The adapter maps criteria to:

- `engine=google_hotels`
- `q`
- `check_in_date`
- `check_out_date`
- `adults`
- `rooms`
- `children=0`
- `currency`
- `sort_by=3`
- `hotel_class`
- `rating`
- `free_cancellation`
- `max_price`
- `hl=en`

Date-only values are formatted in the destination time zone.

## Domain mapping

The adapter maps:

- Stable provider token and deterministic UUID
- Property name and description
- Hotel, hostel, resort, apartment, or vacation-rental type
- Coordinates and destination context
- Star class
- Guest rating and explicit 5-point scale
- Review count
- Nightly rate
- Total stay rate
- Tax/fee inclusion only when source fields establish it
- Typed amenities
- Up to ten HTTPS images
- Check-in and checkout times
- Free-cancellation summary
- HTTPS property link
- Five-minute live-data provenance

If SerpApi omits total stay cost but supplies nightly price, the adapter derives
total cost from calendar nights in the destination time zone.

## Typed amenities

Source text maps into:

- Accessible room
- Airport shuttle
- Breakfast
- Fitness center
- Kitchen
- Laundry
- Parking
- Pool
- Spa
- Wi-Fi

Unknown amenity text is not converted into unsupported claims.

## Defense-in-depth filters

Provider query filters are rechecked after mapping:

- Allowed lodging types
- Minimum star class
- Minimum guest rating
- Required amenities
- Maximum nightly rate

This protects the app when an upstream search ignores or partially applies a
filter.

## Deterministic badges

- `lowestPrice` uses the lowest mapped total stay cost.
- `flexible` requires explicit free-cancellation data.
- `giaRecommended` is never assigned by the provider adapter.

Final recommendation remains the responsibility of the grounded planning
workflow.

## Truthfulness boundaries

- Missing taxes remain unknown.
- Missing cancellation terms remain unknown.
- Property website links are external continuation only.
- Search does not reserve inventory.
- Search does not charge a card.
- Search does not modify or cancel a stay.
- Search does not create a confirmation code.
- Price and availability require rechecking before checkout.

## Failure behavior

Safe errors cover:

- Missing configuration
- Invalid destination/time zone
- Invalid dates
- Invalid occupancy
- Invalid currency/class/rating
- Timeout
- Transport failure
- Rate limit
- Authorization failure
- Provider failure
- Invalid JSON
- Unsupported property shape

A genuine empty result returns zero offers. A response containing only malformed
properties becomes a provider error. Valid properties filtered out by user
constraints remain a genuine zero-result response.

## Workflow integration

`HotelSearchCoordinator`:

1. Marks Stay active with SerpApi attribution.
2. Calls the `HotelSearching` protocol.
3. Supports cancellation.
4. Completes Stay with the actual result count.
5. Marks Stay unavailable after provider failure.

It does not select a hotel, create a booking, or advance unrelated workstreams.

## Verification

Gateway tests cover:

- Documented query parameters
- Destination time-zone date formatting
- Occupancy and date validation
- Class, rating, cancellation, and maximum-price filters
- Stable UUIDs
- Price and calendar-night total mapping
- Explicit rating scale
- Coordinates
- Typed amenities
- Images
- Cancellation
- Lowest-price/flexible badges
- No false GIA recommendation
- Post-mapping constraint enforcement
- Empty-versus-malformed distinction
- Sanitized provider errors
- Missing-key failure

Swift verification decodes the exact gateway JSON into `HotelOffer` and confirms
money, rating scale, amenities, coordinates, badges, provenance, and the Stay
workstream's real result count.

No test consumes SerpApi quota.

## FBLA evidence

This card supports:

- Secure live-data architecture
- Meaningful hotel comparison
- Semantic input validation
- Source and image documentation
- Honest price and booking boundaries
- Accessible progress reporting
- Recoverable external-service failure
