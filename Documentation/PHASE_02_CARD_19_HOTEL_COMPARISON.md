# Phase 2 — Card 19: Hotel Comparison Interface

## Status

Complete with Debug-only sourced fixtures. Live hotel rendering awaits rotated
credentials and orchestration.

## Objective

Present sourced lodging options with clear price, rating, amenity, location, and
cancellation context while separating temporary comparison, shared-trip
selection, and external reservation continuation.

## Display contract

The interface renders only when `Trip.catalog.hotelOffers` is nonempty.

Each property may display:

- Name
- City and country
- Lodging type
- Star class
- Guest rating and source scale
- Review count
- Nightly price
- Total stay price
- Tax/fee inclusion
- Amenities
- Check-in and checkout
- Cancellation context
- Provider image or original fallback visual
- Live, cached, demo, or user-entered origin
- External property URL

Missing values remain explicitly unavailable or unconfirmed.

## Visual hierarchy

### Featured stay

- Provider image or spatial lodging placeholder
- Grounded recommendation/comparison badge
- Source pill
- Property name and location
- Rating, nightly rate, and total rate
- Review count
- Scrollable amenity chips
- Cancellation and tax context
- Expandable details
- Selection, comparison, and provider actions

The original spatial placeholder is used when no image is supplied. G.I.A. never
shows an unrelated stock image for a real property.

### Alternatives

Horizontally scrollable cards show:

- Source
- Property name
- Rating and reviews
- Total price
- Selected/focused state
- Comparison toggle

Focusing does not change the shared trip selection.

### Comparison sheet

Two or three options may be compared by:

- Total
- Nightly
- Rating
- Reviews
- Star class
- Cancellation
- Taxes
- Amenities
- Source

Cards use minimum height so property names, cancellation text, amenities, and
Dynamic Type remain within their surface.

## Rating integrity

Guest rating is always displayed with its source scale, for example `4.8/5`.
Star class remains a separate value.

The interface never compares a five-point rating with an unmarked ten-point
rating.

## Price integrity

- Nightly and total prices remain separate.
- Currency comes from the source `Money`.
- Missing nightly rate remains unavailable.
- Missing tax/fee inclusion remains unconfirmed.
- A total derived by the provider adapter is still identified by provider
  provenance and expiration.

## Selection architecture

`TripPlanningSession.selectHotelOffer`:

- Is allowed only for ready or partially available trips
- Requires a current trip
- Requires the hotel UUID to exist in the trip catalog
- Replaces the selected hotel set
- Updates trip timestamp and session revision

Unknown hotel IDs and invalid workflow phases are rejected.

Temporary focus and comparison remain local UI state.

## Truthfulness

- `SELECT STAY` means selection within G.I.A., not reservation.
- The section states `NO RESERVATION MADE`.
- `VIEW WITH PROVIDER` opens an external property source.
- Provider links do not mutate booking state.
- Missing cancellation remains unknown.
- Missing taxes remain unknown.
- Debug fixtures display `DEMO`.
- Provider adapters cannot assign `GIA RECOMMENDED`; only grounded planning can.

## Image behavior

- Only provider-supplied HTTPS image URLs are loaded.
- Loading/failure uses the same original spatial placeholder.
- Images crop inside the property surface.
- Images are accessibility-hidden because textual property identity follows.
- Image source and provider remain documented.

## Debug verification

`GIA_DEBUG_HOTEL_RESULTS_FIXTURE=1` creates:

- Grounded recommended/flexible property
- Lowest-total property
- Highest-rated/flexible property

`GIA_DEBUG_SCROLL_TO_HOTELS=1` scrolls to the featured stay.

`GIA_DEBUG_COMPARE_HOTELS=1` opens all three in comparison.

All fixture properties are visibly Demo and compile only in Debug.

## Verification

Automated Swift verification covers:

- Selected-first ordering
- Location
- Explicit rating scale
- Reviews
- Nightly and total formatting
- Tax uncertainty
- Cancellation uncertainty
- Typed amenity labels
- Badge priority
- Valid shared-trip selection
- Unknown-hotel rejection

Runtime verification covers:

- Featured stay and spatial placeholder
- Horizontal alternatives
- Selected/focused distinction
- Comparison sheet
- Long cancellation/amenity containment
- Provider-link wording
- Demo labeling
- Persistent bottom navigation

## FBLA evidence

This card supports:

- Intuitive lodging comparison
- Original visual design
- User selection validation
- Honest reservation boundaries
- Accessible responsive layout
- Meaningful use of provider data
- Group voting foundation
