# G.I.A. Phase 1 Planning Record

## Problem Framing

Group travel planning becomes fragmented across messages, calendars, notes, booking
sites, and spreadsheets. G.I.A.'s long-term role is to participate as an intelligent
group member that turns natural constraints and group decisions into a shared trip
plan.

The home experience must establish that product identity without becoming a chat
screen or a compressed travel website.

## Phase 1 User Goal

On launch, a user should immediately understand three things:

1. G.I.A. operates in a world-scale travel context.
2. Map is the application's home.
3. Plan and Group are the two other primary destinations.

The first slice deliberately proves the product's spatial foundation before trip,
group, schedule, budget, or AI functionality is introduced.

## Phase 1 User Journey

```text
Launch G.I.A.
  └── Map opens
      ├── User sees SPACE
      ├── User sees GIA
      ├── User sees a slowly rotating Earth
      └── User sees Plan / Map / Group

Map
  ├── Hamburger
  │   ├── Opens an empty anchored dropdown
  │   └── Closes by second tap, outside tap, tab change, or app interruption
  ├── Plan
  │   └── Opens an intentionally blank destination
  └── Group
      └── Opens an intentionally blank destination

Plan or Group
  └── Map
      ├── Returns to the existing Earth scene
      └── Resumes rotation without resetting orientation
```

## Design Rationale

### Earth as the anchor

Earth communicates possibility and geographic scale before the user enters a
destination. Centering it beneath the edge-aligned chrome lets G.I.A. inhabit the
planet directly and gives future assistant states a coherent spatial origin.

### Restrained top chrome

`SPACE` and the hamburger remain in a restrained navigation layer. G.I.A. occupies
an independent, screen-fixed layer over Earth's center, where a quiet breathing
aperture makes the identity feel present rather than reading as a conventional
navigation title or a logo printed onto the planet.

### Custom bottom navigation

Plan, Map, and Group represent the product's core mental model:

- Plan: the shared source of truth
- Map: the world-first home
- Group: the people and conversation

Map receives selected-state emphasis without becoming an oversized center action.

### Intentionally empty destinations

Plan and Group remain blank so Phase 1 does not imply functionality that does not
exist. Their working navigation establishes durable feature boundaries for later
implementation.

### Offline-first behavior

The Earth texture and all interface resources are bundled locally. This avoids a
presentation dependency on venue internet and produces predictable launch behavior.

## Architectural Planning

The project uses feature-oriented MVVM:

- `AppState` enforces destination, menu, and lifecycle invariants.
- `MapViewModel` owns Map presentation state.
- Reusable SwiftUI components own local presentation only.
- `EarthSceneController` owns SceneKit implementation details.
- `EarthSceneView` is the SwiftUI/SceneKit boundary.
- Blank Plan and Group views remain separate feature destinations.

See `ARCHITECTURE.md` for source structure and state diagrams.

## Implementation Cards

### Card 1 — Scope baseline

- Status: complete
- Evidence: `PHASE_01_SCOPE.md`, initial architecture, source, test, and decision
  records

### Card 2 — Project foundation

- Status: complete
- Evidence: native app entry, root container, central state, feature boundaries,
  design-system tokens, and valid asset catalog

### Card 3 — Mobile coordinate system

- Status: complete
- Evidence: portrait-iPhone `MapStage`, responsive iPhone edge spacing, independent
  chrome/world/overlay layers

### Card 4 — Native Earth

- Status: source complete; runtime rendering inspection pending
- Evidence: SceneKit controller and view, local NASA texture, lifecycle-aware rotation

### Card 5 — Top chrome

- Status: source complete; runtime layout inspection pending
- Evidence: location context, centered G.I.A. identity, minimal hamburger

### Card 6 — Empty menu

- Status: source complete; runtime interaction inspection pending
- Evidence: anchored panel, dismissal behavior, accessible state

### Card 7 — Primary navigation

- Status: source complete; runtime interaction inspection pending
- Evidence: custom bottom navigation and separate blank destinations

### Card 8 — State coordination

- Status: source complete
- Evidence: centralized activity state and deterministic menu/Earth invariants

### Card 9 — Accessibility

- Status: source complete; assistive-technology device verification pending
- Evidence: `ACCESSIBILITY.md`

### Card 10 — Performance verification

- Status: static and iOS build checks complete; launched runtime checks pending
- Evidence: `PERFORMANCE.md`

### Card 11 — Documentation and evidence

- Status: complete when this evidence set passes consistency verification
- Evidence: README, planning record, source ledger, framework record, third-party
  notices, rubric mapping, architecture, decisions, accessibility, performance, and
  testing records

## Phase 2 Implementation Cards

### Card 1 — Secret security and API gateway

- Status: source complete; provider key rotation and deployment remain external
  setup actions
- Evidence: protected secret patterns, server-only environment template,
  fail-closed gateway routes, security tests, and
  `PHASE_02_CARD_01_SECURITY_GATEWAY.md`

### Card 2 — Shared trip domain model

- Status: complete
- Evidence: provider-independent trip aggregate, travelers, requests, offers,
  routes, weather, itinerary, collaboration, budget, booking truthfulness,
  structural validation, Codable verification fixture, and
  `PHASE_02_CARD_02_TRIP_DOMAIN.md`

### Card 3 — Trip planning session state machine

- Status: complete
- Evidence: environment-injected shared planning session, guarded and atomic
  transitions, failure/retry/cancellation handling, Map activation integration,
  executable transition verification, simulator cycle verification, and
  `PHASE_02_CARD_03_PLANNING_STATE_MACHINE.md`

### Card 4 — Unified voice session

- Status: source complete; controlled physical-device speech checks pending
- Evidence: one audio engine for wake recognition, request transcription, and
  amplitude; testable phrase and endpoint rules; live active-circle transcript;
  planning-state integration; permission and interruption handling; and
  `PHASE_02_CARD_04_UNIFIED_VOICE_SESSION.md`

### Card 5 — Map-to-Plan handoff

- Status: complete
- Evidence: validation-gated navigation, active-sphere contraction, compact Plan
  indicator, captured-request continuity, lifecycle cancellation, Reduce Motion
  fallback, debug handoff fixture, simulator visual verification, and
  `PHASE_02_CARD_05_MAP_PLAN_HANDOFF.md`

### Card 6 — Plan spatial shell

- Status: complete
- Evidence: responsive Plan workspace, request/context surface, five-system
  module rail, itinerary foundation, shared surface styling, truthful
  presentation mapping, automated presentation rules, accessibility behavior,
  simulator visual verification, and
  `PHASE_02_CARD_06_PLAN_SPATIAL_SHELL.md`

### Card 7 — Interpreted request and clarification

- Status: complete
- Evidence: deterministic transcript interpretation, semantic validation,
  field-specific clarification, duration-aware unresolved dates, editable
  request metrics, correction sheet, state-machine request replacement,
  executable interpretation/correction verification, simulator visual evidence,
  and `PHASE_02_CARD_07_INTERPRETED_REQUEST.md`

### Card 8 — Truthful planning progress

- Status: complete
- Evidence: nine guarded workstreams, explicit provider attribution and real
  result counts, shared progress/module presentation, no timer-derived
  completion, confirmed cancellation, timezone-safe date display, executable
  progress verification, simulator active/cancel states, and
  `PHASE_02_CARD_08_PLANNING_PROGRESS.md`

### Card 9 — Networking and provider boundaries

- Status: complete; live provider adapters remain later cards
- Evidence: typed domain service contracts, HTTPS/localhost gateway client,
  injected authorization, bounded retry and `Retry-After`, typed errors,
  SHA-256 memory/protected-disk cache, JSON and binary response support,
  provider-agnostic travel service, executable networking verification, gateway
  tests, and `PHASE_02_CARD_09_NETWORKING_FOUNDATION.md`

### Card 10 — Grounded GPT planning orchestrator

- Status: source complete; live rotated-key verification pending
- Evidence: OpenAI Responses adapter, configurable GPT-5.4 model, strict
  Structured Outputs schema, transcript/checkout stripping, server and iOS
  source-ID validation, overlap and trip-range enforcement, no price or booking
  output fields, sanitized failures, 16 gateway tests, executable Swift
  blueprint verification, source documentation, and
  `PHASE_02_CARD_10_GROUNDED_GPT_PLANNER.md`

### Card 11 — SerpApi flight search

- Status: source complete; rotated-key live verification pending
- Evidence: validated Google Flights request mapping, stable sourced domain
  offers, local-time and unresolved-time-zone preservation, prices, baggage,
  emissions, price insights, deterministic deal badges, three-minute
  provenance, workflow result counts, external-booking boundary, mocked
  provider tests, Swift gateway contract verification, and
  `PHASE_02_CARD_11_SERPAPI_FLIGHTS.md`

### Card 12 — SerpApi hotel search

- Status: source complete; rotated-key live verification pending
- Evidence: validated Google Hotels request mapping, deterministic HotelOffer
  identity, nightly/total prices, calendar-night fallback, explicit rating
  scale, reviews, coordinates, typed amenities, images, cancellation context,
  post-mapping filter enforcement, five-minute provenance, external-property
  boundary, Stay workstream result counts, mocked provider tests, Swift gateway
  contract verification, and `PHASE_02_CARD_12_SERPAPI_HOTELS.md`

### Card 13 — Restaurant and activity discovery

- Status: source complete; rotated-key live verification pending
- Evidence: Geoapify Places primary adapter, SerpApi Google Maps fallback,
  category/interest query mapping, stable PlaceRecommendation identity,
  evidence-only hours/dietary/accessibility fields, ratings and links when
  sourced, six-hour provenance, empty/malformed distinction, fallback tests,
  Experiences workstream attribution/counts, Swift mixed-provider contract
  verification, and `PHASE_02_CARD_13_PLACE_DISCOVERY.md`

### Card 14 — Timed events

- Status: source complete; rotated-key live verification pending
- Evidence: separate TimedEvent domain, fixed/flexible scheduling traits,
  SerpApi Google Events adapter, trip-range year inference, destination-zone
  clock conversion, unresolved-time preservation, cancelled/expired/out-of-range
  filtering, external ticket boundary, event-aware GPT grounding, Experiences
  workflow integration, mocked provider tests, Swift contract verification, and
  `PHASE_02_CARD_14_TIMED_EVENTS.md`

### Card 15 — Transportation routing

- Status: source complete; rotated-key live verification pending
- Evidence: validated route coordinates/modes, Geoapify Routing adapter,
  walking/bicycle/car/rideshare/transit mapping, scheduled-to-approximated transit
  fallback, bounded GeoJSON geometry, instructions, sourced duration/distance,
  derived arrival, explicit confidence, planning buffers, 15-minute provenance,
  Routes workstream result counts, mocked provider tests, Swift contract
  verification, and `PHASE_02_CARD_15_TRANSPORTATION_ROUTING.md`

### Card 16 — Weather intelligence

- Status: source complete; rotated-key live verification pending
- Evidence: destination-zone forecast horizon, distant-trip zero-quota behavior,
  WeatherAPI forecast/alert adapter, hourly condition mapping, nil-preserving
  optional data, government alert evidence, 15-minute provenance, deterministic
  weather advisories, Weather workstream result counts, mocked provider tests,
  Swift gateway/advisory verification, and
  `PHASE_02_CARD_16_WEATHER_INTELLIGENCE.md`

### Card 17 — Source-preserving translation

- Status: source complete; credential-provider selection and live verification
  pending
- Evidence: TranslatedText domain, original/machine/provenance preservation,
  automatic and caller-supplied protected terms, segment-based translation,
  whitespace-safe recombination, Google/DeepL/LibreTranslate adapters, HTTPS
  endpoint restrictions, memory-only cache, mocked provider tests, Swift
  gateway/cache contract verification, and
  `PHASE_02_CARD_17_TRANSLATION_LAYER.md`

### Card 18 — Flight comparison interface

- Status: complete with Debug fixtures; live rendering pending orchestration and
  rotated credentials
- Evidence: featured sourced flight, horizontal alternatives, expandable
  segments, price/baggage/emissions/insight formatting, source/time-zone/return
  warnings, local three-option comparison, guarded shared-trip selection,
  external-provider boundary, Dynamic Type-safe comparison cards, executable
  presentation/selection verification, simulator visual evidence, and
  `PHASE_02_CARD_18_FLIGHT_COMPARISON.md`

### Card 19 — Hotel comparison interface

- Status: complete with Debug fixtures; live rendering pending orchestration and
  rotated credentials
- Evidence: featured stay, provider-image/original-placeholder behavior,
  nightly/total/tax/rating-scale presentation, amenities and cancellation,
  horizontal alternatives, local three-property comparison, guarded shared-trip
  selection, external-property boundary, Dynamic Type-safe comparison cards,
  executable presentation/selection verification, simulator visual evidence,
  and `PHASE_02_CARD_19_HOTEL_COMPARISON.md`

### Card 20 — Spatial daily timeline

- Status: complete with Debug fixtures; live itinerary population pending
  orchestration and blueprint assembly
- Evidence: day/weather selector, local-time item nodes, sourced transport
  connectors, fixed/flexible/locked states, expandable details, 15-minute handle
  drag, VoiceOver move actions, guarded chronology/trip/overlap edits, shared
  lock state, Debug Lisbon itinerary, executable presentation/editing
  verification, simulator visual evidence, and
  `PHASE_02_CARD_20_SPATIAL_TIMELINE.md`

### Card 21 — Budget and conflict engine

- Status: complete with deterministic Swift analysis and Debug fixtures
- Evidence: six-category budget ledger, protected emergency reserve,
  estimated-versus-provider-confirmed spend, timestamped currency conversion,
  unknown-cost preservation, timing/travel/venue/weather/dietary/accessibility/
  reservation conflict rules, stable severity ordering, session re-analysis
  after selections and itinerary edits, explainable Plan conflict cards,
  backward-compatible budget decoding, executable engine verification,
  simulator visual evidence, and
  `PHASE_02_CARD_21_BUDGET_CONFLICT_ENGINE.md`

### Card 22 — ElevenLabs response service

- Status: complete with server adapter, iOS playback coordinator, and visible
  fallback; live credential verification pending
- Evidence: fixed G.I.A. voice `3Drdg7QWqr45nZmYpXRP`, server-only API key,
  bounded text/output validation, streamed binary gateway response, sanitized
  provider errors, microphone pause before generation, in-memory common-phrase
  cache, real playback metering, voice-synchronized assistant ripples,
  cross-tab playback state, visible audio-failure response, VoiceOver
  de-duplication, mocked gateway tests, Swift fallback verification, and
  `PHASE_02_CARD_22_ELEVENLABS_RESPONSE.md`

### Card 23 — Selection and demo confirmation

- Status: complete for flight and hotel selection paths
- Evidence: sourced review sheet, price/provider/cancellation/retrieval
  evidence, explicit FBLA demonstration and external-checkout modes,
  demo-confirmed versus provider-confirmed status, no-payment disclosure,
  provider checkout continuation, missing-link rejection, idempotent records,
  protected real confirmations, shared itinerary flight/check-in/check-out
  nodes, Debug review/confirmation fixtures, executable booking verification,
  simulator visual evidence, and
  `PHASE_02_CARD_23_SELECTION_DEMO_CONFIRMATION.md`

### Card 24 — Group workspace

- Status: complete as a local domain-backed workspace; remote identity/sync
  pending
- Evidence: invited-only access, Organizer/Member authorization, pending/
  accepted/revoked invitations, identity-bound acceptance, availability and
  personal-budget context, dietary/accessibility coordination, three-level
  preference privacy, organizer-only management, guarded member removal,
  preserved votes and membership audit history, legacy trip decoding, Debug
  collaboration fixture, executable access/privacy verification, simulator
  visual evidence, and `PHASE_02_CARD_24_GROUP_WORKSPACE.md`

### Card 25 — Voting and approvals

- Status: complete with deterministic local decision state
- Evidence: typed destination/date/flight/hotel/place/itinerary/budget
  subjects, organizer-selected majority/unanimous/organizer rules, eligible
  member snapshots, one ballot per traveler, exact deterministic thresholds,
  approved/rejected/tied states, visible tie resolution, revisions linked by
  superseded decision ID, preserved prior ballots, structural vote validation,
  Debug approval/tie fixtures, executable voting verification, simulator
  visual evidence, and `PHASE_02_CARD_25_VOTING_APPROVALS.md`

### Card 26 — Group communication

- Status: complete as local typed communication; remote transport pending
- Evidence: accepted-member chat authorization, whole-trip/item/decision
  threads, member mentions, labeled G.I.A. and System authors, plan-change
  system events, idempotent reactions, timestamped read receipts, unread
  counts, former-member history preservation, privacy-safe ShareLink summary,
  native iOS share sheet, structural communication validation, Debug item
  discussion fixture, executable lifecycle verification, simulator visual
  evidence, and `PHASE_02_CARD_26_GROUP_COMMUNICATION.md`

### Card 27 — SwiftData offline storage

- Status: complete with versioned local storage and automatic restore
- Evidence: versioned SwiftData schema/migration plan, validated Codable Trip
  payload, queryable summary metadata, travelers/selections/itinerary/votes/
  messages/weather/provenance persistence, debounced autosave, background
  flush, startup restoration, transient transcript sanitization, provider-age
  display, update-by-Trip-ID, unsupported-schema preservation, in-memory failure
  fallback, local library, explicit deletion warning, stable Debug fixture,
  executable in-memory lifecycle verification, simulator visual evidence, and
  `PHASE_02_CARD_27_SWIFTDATA_OFFLINE_STORAGE.md`

### Card 28 — Judge-safe offline demonstration

- Status: complete with bundled Tokyo journey and repeatable reset
- Evidence: stable comprehensive fixture, flights/hotels/restaurants/
  activities/event/weather/routes/itinerary/budget/group/votes/chat coverage,
  Demo provenance on provider-backed data, 1.25-second unresolved-provider
  watchdog, automatic in-place Plan fallback, manual Map menu launch/restart/
  reset, standard transition and result modules, persistent offline relaunch,
  explicit trigger/Demo/no-live-claim banners, fixed Trip ID, executable fixture
  completeness verification, simulator manual/timeout visual evidence, and
  `PHASE_02_CARD_28_JUDGE_SAFE_OFFLINE_DEMO.md`

### Card 29 — Notifications and calendar

- Status: complete with contextual permissions and local integrations
- Evidence: seven deterministic reminder kinds, stable trip/source IDs,
  pending-reminder replacement, delivered-ID suppression, destination/airport/
  item/weather time zones, app-active and system-zone refresh, privacy-safe
  lock-screen copy, persisted owner settings, EventKit itinerary drafts,
  stored identifier plus hidden-marker upsert, duplicate-free export,
  unknown-item rejection, Trip Assistance UI, legacy decode, executable
  reminder/calendar verification, simulator visual evidence, and
  `PHASE_02_CARD_29_NOTIFICATIONS_CALENDAR.md`

### Card 30 — Accessibility and performance

- Status: source/simulator complete; physical-device VoiceOver, thermal, and
  sustained FPS sign-off pending
- Evidence: centralized quality policy, 44-point controls, bounded navigation
  chrome, accessibility-size one-column/vertical layouts, VoiceOver labels and
  gesture alternatives, Reduce Motion/Transparency, Increased Contrast,
  hidden-TimelineView suspension, SceneKit pause/dismantle, memory-pressure
  audio/action cleanup, denied-microphone short circuit, iPhone SE and Pro Max
  accessibility matrix, 5.64-second Time Profiler trace with zero 250ms+
  potential hangs, executable policy verification, and
  `PHASE_02_CARD_30_ACCESSIBILITY_PERFORMANCE.md`

## Phase 8 Live Intelligence Completion

### Card 1 — Provider configuration contract

- Status: implemented; translation provider selection remains Card 2
- Evidence: canonical project-root environment names, legacy alias
  normalization, normalized handler configuration, non-secret health issue
  codes, ignored local credential files, environment contract tests, and
  `PHASE_08_CARD_01_PROVIDER_CONFIGURATION.md`

### Card 2 — Google Translation activation

- Status: source complete; valid Google Cloud Translation credential required
  for live sign-off
- Evidence: explicit Google provider configuration, persistent Plan language
  choice, on-demand hotel and itinerary translation, protected proper names,
  display-only source preservation, machine-translation labels, safe original
  fallback, gateway translation tests, and
  `PHASE_08_CARD_02_GOOGLE_TRANSLATION.md`

## Deferred Requirements

This phase does not claim completion of:

- Scheduling
- Group budget voting and approvals
- Shared organization
- Remote multi-user synchronization and authentication
- Input validation for trip data
- Social integration
- Remote encrypted synchronization and authenticated storage
- End-to-end live provider booking confirmation

Those items remain necessary before the complete application can fully address the
FBLA topic and rating sheet.

