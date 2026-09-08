# Phase 2 — Card 24: Group Workspace

## Status

Complete as a local, domain-backed collaboration workspace with invited access,
roles, privacy-aware preferences, availability, personal budgets, invitation
management, guarded removal, and membership audit history. Remote identity and
sync remain future infrastructure work.

## Objective

Make group travel collaboration a first-class trip capability rather than an
avatar decoration.

## Collaboration domain

`TripCollaboration` stores:

- Invitations
- Invitation status
- Inviting traveler
- Requested role
- Acceptance identity
- Membership history

`MembershipAuditRecord` preserves:

- Invite
- Join
- Removal
- Role change
- Departure
- Preference-visibility change
- Actor
- Subject identifier and display name
- Previous/resulting role
- Timestamp
- Context note

The collaboration property is optional so trips encoded before Card 24 continue
to decode.

## Authorization

`GroupWorkspacePrivacy` is deterministic Foundation logic.

- Only a traveler in `Trip.travelers` can access the workspace.
- Only `Trip.organizerTravelerID` can invite, revoke, or remove.
- Pending invitations do not grant access.
- Acceptance requires the invited email identity.
- Accepted travelers are forced to Member role.
- An organizer cannot be removed without a future ownership-transfer flow.
- A provider-confirmed or planning state is unrelated to membership authority.

`TripPlanningSession.activeTravelerID` represents the authenticated viewer
boundary for the current local prototype. It defaults to the trip organizer
when a trip becomes ready. Future authentication must supply this identity.

## Preference privacy

Each traveler owns one `PreferenceVisibility`:

- `privateToTraveler`: only that traveler
- `organizers`: that traveler and the organizer
- `tripMembers`: every accepted member

The rule protects:

- Interests
- Dietary requirements
- Accessibility requirements
- Preferred pace
- Walking limits
- Notes
- Personal budget

Hidden values are omitted from member cards and detail sheets rather than
blurred or partially disclosed. The traveler can change their own visibility;
the organizer cannot edit another member's private setting.

## Invitations

The organizer can create a pending invitation with a display name and validated
email address.

Rules:

- Invalid names or email addresses are rejected.
- Duplicate pending invitations are rejected.
- Existing member identities cannot be reinvited.
- Pending invitations can be revoked.
- Only accepted invitations create membership.
- Invite and join events are added to permanent audit history.

This card creates local invitation state only. It does not claim to send email
or provide remote account delivery.

## Member removal

Removing a member:

1. Requires the active organizer.
2. Rejects removal of the organizer.
3. Removes active trip access.
4. Preserves prior votes and decisions.
5. Appends a removal audit record with the former name and role.
6. Leaves the history available after the Traveler object is removed.

## Group interface

The Group tab includes:

- Group constellation and invited-access label
- Active-viewer identity
- Organizer/member role labels
- Availability readiness
- Group constraint count
- Pending invitation count
- Personal budget context
- Privacy state per member
- Member detail sheets
- Own preference-visibility control
- Organizer-only invitation and removal actions
- Pending invitation list and revoke action
- Invitation-required access-denied state
- Empty state before a trip exists

All privacy and role meaning has text and symbols; it does not depend only on
color.

## Debug verification

`GIA_DEBUG_GROUP_WORKSPACE=1`:

- Opens the Group tab
- Loads four Lisbon travelers
- Includes Organizer and Member roles
- Includes available and tentative dates
- Includes dietary/accessibility constraints
- Includes different personal budgets
- Includes Trip Members, Organizers, and Only Me privacy
- Adds one pending invitation and membership history

`GIA_DEBUG_GROUP_MEMBER=private` opens a private member profile.
Any other `GIA_DEBUG_GROUP_MEMBER` value opens the organizer profile and
visibility control.

## Automated verification

`GroupWorkspaceVerificationMain.swift` checks:

- Accepted-member access
- Outsider denial
- Organizer preference visibility
- Invalid and duplicate invitation rejection
- Invite acceptance and forced Member role
- Active identity handoff
- Own privacy updates and audit records
- Member inability to remove others
- Organizer removal of a member
- Vote-history preservation
- Removal audit preservation
- Organizer-removal rejection
- Legacy Trip decoding without collaboration state

## Truthfulness and security

- Pending invitations do not imply access.
- Local invitations do not claim email delivery.
- Private data is omitted from unauthorized presentation models.
- Organizer controls do not bypass private-to-traveler visibility.
- Removal does not erase prior decision evidence.
- Debug identities are not represented as production authentication.

## FBLA evidence

This card directly supports group trip planning through member management,
roles, invitations, shared availability, preferences, budget context,
accessibility and dietary coordination, privacy controls, and auditable
collaboration changes.
