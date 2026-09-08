# Phase 2 — Card 2: Trip Domain Model

## Status

Complete.

## Objective

Define a provider-independent, UI-independent source of truth for group trips.
The domain layer must preserve data origin, money, time zones, user selections,
collaboration, itinerary structure, and booking truthfulness before Plan visuals
or provider adapters are implemented.

## Delivered model groups

### Shared values

- Currency-aware `Money`
- Validated geographic coordinates
- Reusable travel locations
- Time-zone-aware trip date ranges
- Live, cached, demo, and user-entered data origins
- Extensible travel-provider identifiers
- Retrieval, expiration, source URL, and provider provenance
- Accessibility, dietary, and interest values

### Requests and travelers

- Raw voice transcript storage boundary
- Origin and multiple destinations
- Dates, party size, budget, interests, and notes
- Flight and hotel preferences
- Traveler roles, availability, budgets, pace, and preferences
- Preference visibility for sensitive traveler requirements

### Travel inventory

- Flight offers, segments, baggage, price insights, emissions, and badges
- Hotel offers, room information, amenities, taxes, and cancellation policy
- Restaurants, attractions, activities, opening information, dietary options,
  accessibility, images, and provider links
- Transportation legs with route confidence and provider attribution
- Weather periods and official-alert metadata

### Itinerary and collaboration

- Time-zone-aware itinerary days and items
- Fixed, flexible, and user-locked activities
- References from itinerary items back to sourced offers
- Group decisions, voting rules, votes, and resolution states
- Category-based group budget allocations

### Booking truthfulness

- Separate demo, external-checkout, and provider-confirmed modes
- Explicit `demoConfirmed` status
- Provider confirmation, receipt, and checkout fields
- Structural rejection of a demo booking marked as genuinely confirmed

### Aggregate

`Trip` owns:

- Schema version
- Organizer and travelers
- Original request
- Provider catalog
- User selections
- Itinerary and transportation
- Budget
- Group decisions
- Booking records
- Lifecycle and timestamps

## Architectural rules

- Domain files import Foundation only.
- Domain models do not import SwiftUI, SceneKit, networking SDKs, or persistence
  frameworks.
- Provider DTOs must be mapped into these types at service boundaries.
- UI views consume domain types rather than raw SerpApi or Geoapify payloads.
- All sourced recommendations retain provenance.
- All money retains an explicit currency code.
- All itinerary dates retain a time-zone identifier.
- Demo and live booking states remain mechanically distinguishable.

## Structural validation

The initial structural validator detects:

- Unsupported schema versions
- Missing organizers
- Duplicate traveler identifiers
- Reversed trip and itinerary ranges
- Invalid traveler counts
- Invalid currency-code lengths
- Selections missing from their catalog
- Demo bookings incorrectly marked as real confirmations

Semantic request validation, provider availability checks, scheduling conflicts,
and budget calculations remain scoped to their later cards.

## Verification

Verification includes:

- iOS target compilation
- IDE diagnostics
- A comprehensive fixture containing flight, hotel, place, route, weather,
  itinerary, vote, budget, and demo-booking data
- JSON encode/decode equality
- Structural validation of a valid fixture
- Detection of a deliberately misleading demo-booking state

The executable verification fixture is located at:

`Verification/TripDomainRoundTripMain.swift`

## FBLA evidence

This card supports:

- Expert use of classes, modules, and components
- Appropriate architectural patterns
- Syntactic and semantic validation foundations
- Data integrity and secure data handling
- Reliable offline serialization
- Clear separation of original application logic from third-party APIs
