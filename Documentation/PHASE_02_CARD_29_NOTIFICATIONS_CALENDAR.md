# Phase 2 — Card 29: Notifications and Calendar

## Status

Complete with deterministic reminder planning, contextual notification and
calendar permissions, stable duplicate-safe scheduling, destination time zones,
privacy-safe notification copy, EventKit upsert markers, persisted integration
settings, Debug visual evidence, and executable verification.

## Objective

Help travelers act on the shared plan without requesting permissions at launch,
creating duplicate events, exposing sensitive preferences on the lock screen, or
losing destination-local timing.

## Persisted integration state

`TripIntegrations` stores:

- Per-device notification settings
- Enabled reminder kinds
- Owning traveler ID
- Settings update timestamp
- Calendar export records

Each calendar record stores:

- Itinerary item ID
- EventKit identifier
- Exported start/end
- IANA time-zone identifier
- Export timestamp

`Trip.integrations` is optional, so trips saved before Card 29 still decode.

## Contextual permission policy

Permissions are never requested during launch, trip restore, or normal tab
navigation.

- Notification permission is requested only after Enable Alerts.
- Calendar full-access permission is requested only after Export Plan.
- Denial leaves the trip fully usable.
- The interface displays denied state without repeatedly prompting.

The generated Info.plist explains that calendar items are created only when the
user chooses Export Plan.

## Deterministic reminders

`TripReminderPlanner` derives reminders from typed trip state.

### Trip countdown

- Seven days before trip start
- 9:00 AM in the trip destination time zone

### Voting

- Open, tied, or revision-needed decisions
- Stable identifier per decision

### Schedule changes

- Triggered from typed `itineraryChanged` system messages
- Generic lock-screen text

### Flight check-in

- 24 hours before selected outbound departure
- Departure airport time zone
- Says check-in may be available and directs the user to the airline

### Departure

- Three hours before selected outbound departure
- Departure airport time zone
- Reminds the user to review documents and airport buffer

### Hotel check-in

- Two hours before a hotel check-in itinerary node
- Hotel/item time zone

### Weather warning

- Moderate, severe, or extreme sourced WeatherAlert
- Alert effective time and weather snapshot time zone
- Expired alerts excluded

## Privacy-safe notification content

Lock-screen messages exclude:

- Traveler names
- Email addresses
- Dietary requirements
- Accessibility requirements
- Personal budgets
- Booking identifiers
- Provider confirmation codes
- Chat content

Details remain inside the authenticated application.

## Scheduling and duplicate prevention

Reminder identifiers use:

`gia.trip.<trip UUID>.<kind>.<source UUID>`

On refresh:

1. Existing pending reminders for the trip prefix are removed.
2. Current reminders are rebuilt from source state.
3. Already delivered stable identifiers are not re-added.
4. Each identifier is added once.

This makes itinerary edits and time-zone changes update reminders rather than
creating duplicates.

## Time-zone behavior

Each reminder and calendar event carries an explicit IANA time zone from its
source:

- Destination zone for countdown and group decisions
- Departure airport zone for flight reminders
- Item zone for hotel and itinerary events
- Weather snapshot zone for alerts

The app refreshes enabled reminders when:

- Trip revision changes
- App becomes active
- System time zone changes

## EventKit export

`TripCalendarEventPlanner` creates one draft for every non-cancelled,
chronological itinerary item.

Each EventKit event includes:

- Item title
- Start/end
- IANA time zone
- Location name when available
- Selected/proposed/confirmed status
- Reminder to verify booking details in the provider app
- Hidden stable marker:
  `GIA-ID:<trip UUID>:<item UUID>`

Export resolves an existing event first by stored EventKit identifier, then by
the marker. Repeated export updates that event instead of adding another.

## Trip Assistance interface

The Group workspace displays:

- Days until departure
- Alert authorization/enabled status
- Scheduled reminder count
- Enable/Disable action
- Calendar authorization/export status
- Exported item count
- Duplicate-safe/time-zone explanation
- Contextual-permission disclosure

## Automated verification

`TripIntegrationVerificationMain.swift` checks:

- All seven reminder kinds
- Stable unique identifiers
- Deterministic ordering
- Destination, flight, and item time zones
- Privacy-safe titles and bodies
- Calendar item coverage
- Unique EventKit markers
- Calendar note privacy
- Notification owner persistence
- Calendar record upsert by itinerary item
- Unknown-item export rejection
- Legacy Trip decoding without integrations

## Truthfulness and accessibility

- Check-in copy says it may be available.
- Local notifications do not claim provider confirmation.
- Calendar export does not create or alter reservations.
- Permission denial does not block planning.
- Every status has text and an accessible action.

## FBLA evidence

This card demonstrates local notifications, calendar integration, contextual
permission handling, schedule awareness, time-zone correctness, duplicate
prevention, privacy-conscious lock-screen content, and accessible travel
organization.
