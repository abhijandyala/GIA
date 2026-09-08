# Phase 2 — Card 23: Selection and Demo Confirmation

## Status

Complete for flight and hotel selections with explicit FBLA demonstration and
external-provider checkout modes.

## Objective

Demonstrate a polished booking decision flow without collecting payment or
claiming that G.I.A. completed a real provider reservation.

## Flow

1. The user selects a sourced flight or hotel.
2. The shared trip selection updates.
3. A review sheet displays the exact option, source, total, retrieval time,
   and cancellation or change terms.
4. The sheet visibly identifies either FBLA Demonstration or External Provider
   Checkout.
5. Continue creates the appropriate typed booking record.
6. Demo mode displays “Demo booking confirmed.”
7. External mode opens the provider URL and remains “External checkout
   required.”
8. Flight or hotel nodes are added to the shared itinerary.

## Confirmation modes

### FBLA demonstration

- `BookingMode.demo`
- `BookingStatus.demoConfirmed`
- Demo provenance from G.I.A.
- No provider confirmation code
- No payment collection
- No claim of a real ticket or room
- Itinerary remains selected and carries an explicit demo note

Debug fixtures automatically use this mode because their provenance is Demo.
`GIA_FBLA_DEMO_MODE=1` explicitly enables it for the competition presentation.

### External provider

- `BookingMode.externalCheckout`
- `BookingStatus.externalCheckoutRequired`
- Original provider and source provenance retained
- Provider checkout URL retained and opened
- No confirmation code invented
- Selection remains unconfirmed until provider confirmation exists

An absent checkout URL produces a visible error and does not create a booking
record.

## Shared itinerary handoff

Confirmed selections create fixed itinerary nodes:

- Outbound and return flight journeys
- Hotel check-in
- Hotel check-out

Demo nodes remain `selected`, not `confirmed`, because `ItineraryItemStatus`
does not encode demo confirmation. Notes explicitly state that no real ticket
or room was issued.

Changing an unfinished selection cancels the superseded demo or external
checkout record while preserving history. A real provider-confirmed booking
cannot be silently replaced; the provider modification flow is required.

## Idempotency

Repeating the same confirmation updates its existing active record instead of
creating duplicates. Provider-confirmed records are returned unchanged and are
never downgraded to demo or external-checkout status.

## Interface

The review surface includes:

- Explicit mode badge
- Flight route or property location
- Sourced total
- Provider identity
- Live, cached, demo, or user-entered origin
- Cancellation/change terms
- Retrieval timestamp
- No-payment/no-booking disclosure
- Mode-specific Continue action

The completion surface includes:

- “Demo booking confirmed,” “Provider checkout opened,” or existing provider
  confirmation state
- Amount
- Provider
- Explicit status
- A final reminder when no real reservation exists

Flight and hotel module headers now distinguish:

- No booking made
- Demo confirmed
- Checkout required
- Provider confirmed

## Debug verification

- `GIA_DEBUG_BOOKING_REVIEW=flight` opens the flight review.
- `GIA_DEBUG_BOOKING_REVIEW=hotel` opens the hotel review.
- `GIA_FBLA_DEMO_MODE=1` forces the FBLA demonstration boundary.
- `GIA_DEBUG_AUTOCONFIRM_BOOKING=1` exercises the completion screen.

All fixture data remains marked Demo and compiles only in Debug.

## Automated verification

`BookingConfirmationVerificationMain.swift` checks:

- Demo mode and status
- No fabricated provider confirmation code
- Demo provenance
- Selection updates
- Flight itinerary insertion
- Idempotent reconfirmation
- External-checkout state
- Checkout URL retention
- Hotel check-in/check-out insertion
- Missing-checkout rejection
- Cancellation-term presentation
- Demo provenance and explicit environment mode selection

## Truthfulness and security

- G.I.A. never collects card or bank information.
- A provider URL is not treated as a successful booking.
- Demo confirmation is visually and structurally distinct from real
  confirmation.
- Only `BookingStatus.confirmed` represents provider confirmation.
- Supplied prices and terms retain source context.
- Existing real bookings cannot be silently replaced.

## FBLA evidence

This card demonstrates selection management, trip organization, safe external
integration, typed state transitions, itinerary coordination, data
provenance, and an honest competition-safe booking demonstration.
