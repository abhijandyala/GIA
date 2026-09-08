# Phase 2 — Card 25: Voting and Approvals

## Status

Complete with deterministic vote thresholds, proposal controls, member ballots,
tie handling, revisions that preserve history, Debug fixtures, and executable
verification.

## Objective

Let accepted trip members make auditable group decisions without allowing GPT,
UI percentages, or changing membership to invent an outcome.

## Voteable subjects

The proposal builder resolves typed subjects from current trip data:

- Destination
- Dates
- Flights
- Hotels
- Restaurants and activities through Place
- Itinerary items
- Budget

Unknown or removed subject identifiers are rejected before a proposal is
created and reported by structural validation when decoding.

## Approval rules

The organizer chooses one rule when opening a vote.

### Majority

- Approval threshold is `floor(eligible / 2) + 1`.
- Approval closes the vote when Yes reaches the threshold.
- Rejection closes the vote when No reaches the threshold.
- If every eligible member votes and neither side reaches the threshold, the
  state becomes Tie.

### Unanimous

- Every eligible member must vote Yes.
- Any No vote rejects immediately.
- If all ballots are cast but one or more members pass, the state becomes Tie.

### Organizer

- Only the trip organizer is eligible.
- Organizer Yes approves.
- Organizer No rejects.
- Organizer Pass creates a Tie requiring resolution.

All calculations are pure Swift in `GroupDecisionEngine`.

## Eligibility and ballots

Each proposal snapshots `eligibleTravelerIDs`.

- Only accepted trip members may vote.
- Organizer-only proposals reduce eligibility to the organizer.
- One `TripVote` is allowed per traveler per decision.
- A second ballot is rejected rather than replacing the original.
- Ballots store traveler, choice, optional comment, and timestamp.
- UI counts are derived from the typed ballots.

## Decision states

- Proposed
- Voting
- Approved
- Rejected
- Tied
- Needs revision

Resolved decisions retain their final state and resolution timestamp.

## Revisions

The organizer can create a revision from a Tied, Rejected, or Needs Revision
decision.

The revision:

- Creates a new `GroupDecision` identifier.
- Stores `supersedesDecisionID`.
- Increments `revisionNumber`.
- Snapshots current eligible members.
- Starts with no ballots.
- Leaves the original title, votes, result, and timestamp unchanged.

This preserves the group's decision history instead of mutating an unfavorable
result.

## Group interface

The Group workspace now includes:

- Open/total proposal count
- Organizer-only Propose control
- Typed subject and approval-rule proposal sheet
- Yes, No, and Pass totals
- Member ballot initials
- Exact cast/eligible count
- Exact approval threshold
- Current member's ballot
- Yes, No, and Pass actions
- Approved, rejected, voting, tie, and revision labels
- Organizer revision action on eligible outcomes

No fabricated percentage is displayed.

## Debug verification

`GIA_DEBUG_GROUP_WORKSPACE=1` includes:

- Approved majority destination decision
- 2–2 tied budget decision
- Open unanimous activity decision

`GIA_DEBUG_DECISION_PROPOSAL=1` opens the proposal sheet.

## Automated verification

`VotingEngineVerificationMain.swift` checks:

- Eligible-member snapshot
- Majority threshold
- Duplicate-vote rejection
- Closed-decision rejection
- Unanimous rejection
- Organizer-only eligibility
- 2–2 tie
- Revision lineage and empty replacement ballot
- Original vote-history preservation
- Member inability to select approval rules
- Structural duplicate-ballot detection

## Truthfulness and security

- Only accepted members vote.
- One traveler cannot vote twice.
- GPT cannot calculate or override outcomes.
- Removed or invalid trip subjects cannot receive new proposals.
- A revision never erases prior ballots.
- A tie is visible and cannot masquerade as approval.
- UI colors are paired with state text and accessible labels.

## FBLA evidence

This card demonstrates group decision-making, majority and unanimous logic,
roles and permissions, collaboration history, semantic validation, typed state
transitions, and transparent conflict resolution.
