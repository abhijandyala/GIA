# Phase 2 — Card 26: Group Communication

## Status

Complete as local trip communication with typed threads, mentions, system and
G.I.A. labels, reactions, read receipts, native iOS sharing, Debug fixtures,
and executable lifecycle verification. Remote message transport remains future
infrastructure work.

## Objective

Connect group decisions and itinerary changes to a shared conversation without
exposing private traveler preferences or implying remote delivery before a
backend exists.

## Communication domain

`TripCommunication` contains chronological `TripMessage` values.

Each message stores:

- Member, G.I.A., or System author kind
- Optional traveler author
- Message body
- Whole-trip, itinerary-item, or decision context
- Mentioned traveler IDs
- Typed system event
- Reactions
- Read receipts
- Creation and optional edit timestamps

`Trip.communication` is optional so trips encoded before Card 26 continue to
decode.

## Authorization

Communication uses the Card 24 membership boundary.

- Only the active accepted trip member can send.
- Only accepted members can be mentioned.
- Only accepted members can react or create read receipts.
- Empty messages are rejected.
- Messages are limited to 2,000 characters.
- Item and decision contexts must exist when a new message is sent.
- Removed members cannot regain chat access.

Historical messages from removed members remain and display Former member
rather than losing discussion history.

## Threads

Messages can link to:

- Whole trip
- Specific itinerary item
- Specific group decision

The chat includes All and typed context filters. Every linked message displays
its current item or decision label. If referenced content is later archived,
the message remains as an archived-context record.

## Mentions

The composer lets a member select one or more current travelers. Mention IDs
are stored separately from message text and rendered as explicit `@Name`
labels. Self-mentions are removed.

## Reactions

Supported reactions:

- Approve
- Heart
- Celebrate
- Question

A traveler may add each reaction once. Selecting the same reaction again
removes it. Structural validation rejects duplicate traveler/reaction pairs.

## Read status

Opening chat adds one read receipt per current traveler and message.

- Receipts are timestamped.
- Repeated reads are idempotent.
- The chat summary displays unread count.
- Each message displays its exact read count.
- Structural validation rejects duplicate reader receipts.

## Labeled generated messages

G.I.A. messages use `TripMessageAuthorKind.gia` and render as
`GIA · ASSISTANT`.

System messages use `TripMessageAuthorKind.system` and render as `TRIP UPDATE`.
System events are generated for:

- Booking selection continuation
- Decision opened
- Decision resolved
- Itinerary item moved
- Member invited
- Member joined
- Member removed

Generated messages never impersonate a traveler.

## Native share integration

The Group summary and chat toolbar use SwiftUI `ShareLink`, which opens the
native iOS share sheet and makes installed social and messaging applications
directly reachable.

The shared text contains only:

- Trip title
- Destination
- Dates
- Traveler count
- Itinerary-day count
- Open-decision count

It excludes email addresses, messages, dietary needs, accessibility needs,
personal budgets, booking identifiers, and private notes.

## Interface

The Group tab contains a compact Trip Chat summary with:

- Latest two messages
- Unread indicator
- Open-chat control
- Native share control

The full chat contains:

- Context filter rail
- Labeled member, G.I.A., and System bubbles
- Item/decision links
- Mentions
- Reaction controls and counts
- Read counts
- Item-link menu
- Mention menu
- Multi-line composer
- Native share toolbar action

## Debug verification

`GIA_DEBUG_GROUP_WORKSPACE=1` includes:

- One system plan update
- One labeled G.I.A. message
- One museum item discussion
- Mentions
- Approve and Heart reactions
- Different read states

`GIA_DEBUG_GROUP_CHAT=1` opens the full chat automatically.

## Automated verification

`GroupCommunicationVerificationMain.swift` checks:

- Member author and own read receipt
- Typed itinerary context
- Valid mentions
- Empty-message rejection
- Unknown mention rejection
- Invalid context rejection
- Reaction add/remove idempotency
- Read-receipt idempotency
- Outsider denial
- Labeled G.I.A. authorship
- Decision-opened and resolved system events
- Itinerary-change system event
- Privacy-safe share summary
- Duplicate reaction/read structural validation
- Legacy Trip decoding without communication

## Truthfulness and privacy

- Local chat does not claim remote delivery.
- System and G.I.A. authors are visibly distinct from members.
- Share text omits sensitive traveler data.
- Read status reflects stored receipts, not simulated presence.
- Deleted membership does not erase historical conversation.
- The native share sheet requires user action before sending externally.

## FBLA evidence

This card demonstrates group communication, item-specific collaboration,
mentions, reactions, read status, plan-change notifications, labeled AI
content, social sharing integration, privacy boundaries, and auditable data
modeling.
