# G.I.A. Architecture Record

## Phase 1 Architectural Goal

G.I.A. uses a feature-oriented MVVM structure. The app shell owns destination and
overlay state, the Map feature owns world presentation state, and the SceneKit layer
owns 3D implementation details.

Phase 1 intentionally avoids speculative services and models that are not required by
the current interface.

## Phase 2 Domain Extension

Phase 2 introduces a shared `Domain/Trip` layer between application features and
external providers:

```text
GIA/
├── App/
│   └── TripPlanningSession.swift
├── Domain/
│   └── Trip/
│       ├── CollaborationAndBooking.swift
│       ├── Itinerary.swift
│       ├── RouteAndWeather.swift
│       ├── Trip.swift
│       ├── TripDomainValidation.swift
│       ├── TripRequest.swift
│       ├── Traveler.swift
│       ├── TravelOffers.swift
│       └── TravelValueTypes.swift
├── Gateway/
│   ├── src/
│   └── test/
└── Verification/
    └── TripDomainRoundTripMain.swift
```

The Domain layer imports Foundation only. It does not know how provider payloads
are fetched, how models are persisted, or how they are presented. Plan, Map,
Group, persistence adapters, and provider adapters may depend on Domain; Domain
must not depend on those layers.

Provider DTOs remain at provider boundaries and map into domain models. This
prevents SerpApi, Geoapify, WeatherAPI, OpenAI, or ElevenLabs response shapes from
becoming application state.

Every sourced domain object retains provenance. Every monetary value retains its
currency. Every itinerary time retains its time-zone context. Demo booking states
are mechanically distinct from provider-confirmed bookings.

### Networking boundary

Domain service protocols define flight, hotel, place, route, weather, planning,
speech, and translation capabilities without naming an upstream provider.

```text
Feature / workflow
└── Domain service protocol
    └── GatewayTravelService
        └── GIAGatewayClient
            ├── GatewayTransport
            ├── GatewayAuthorizationProviding
            └── GatewayResponseCache
                └── G.I.A. server gateway
                    └── Provider adapter
```

The iOS target never calls a provider directly. The gateway maps upstream DTOs
into shared domain contracts before returning sanitized JSON or speech audio.

`GIAGatewayClient` owns endpoint construction, authentication injection,
request identifiers, retries, status mapping, decoding, and cancellation.
`GatewayResponseCache` owns short-lived memory/disk response caching with hashed
keys and iOS file protection.

Remote gateway URLs require HTTPS. Localhost HTTP is allowed for development.
Mobile authorization remains injected; production must use user sessions and
App Attest rather than a compiled shared token.

### Grounded intelligence boundary

`TripIntelligence` returns `TripPlanBlueprint`, not a provider response or a
completed booking. The blueprint contains sourced UUID selections, itinerary
times, rationales, and warnings; it cannot contain prices, ratings,
availability, or booking status.

The server OpenAI adapter:

1. Validates the planning request.
2. Removes raw transcript and checkout URLs.
3. Bounds and summarizes sourced travel records.
4. Requests strict Structured Output.
5. Rejects unknown identifiers, invalid times, overlaps, and out-of-range items.
6. Reconstructs a sanitized blueprint.

`GatewayTravelService` repeats source grounding with
`TripPlanBlueprintValidator` before returning a blueprint to workflow code.
Neither server nor client treats GPT output as factual provider data.

### Flight provider boundary

`FlightSearchCoordinator` depends on `FlightSearching`, not SerpApi. The
production implementation routes through `GatewayTravelService` and the server
`serpapi-flights` adapter.

```text
FlightSearchCoordinator
├── TripPlanningSession Flights workstream
└── FlightSearching
    └── GatewayTravelService
        └── POST /v1/search/flights
            └── SerpApi Google Flights adapter
                └── FlightOffer domain mapping
```

The server validates IATA codes, endpoint time zones, dates, party size, and
currency before making a request. It creates deterministic offer/segment
identifiers, provider provenance, and bounded expiration.

Connection airports without a resolved IANA time zone retain their exact local
clock text and explicit unresolved flags. The domain does not silently treat
those placeholders as authoritative schedule instants.

`HotelSearchCoordinator` follows the same boundary through `HotelSearching`,
`GatewayTravelService`, and the server Google Hotels adapter. It validates
destination time zone, stay dates, occupancy, currency, class, and rating before
network access. Provider-side filters are repeated after mapping before a
`HotelOffer` enters the app.

Google Hotels guest ratings retain their source scale, prices retain currency,
and missing tax/cancellation fields remain unknown. Property links never become
booking confirmation.

`PlaceSearchCoordinator` depends on `PlaceSearching`. The gateway
`place-discovery` adapter uses Geoapify Places as the coordinate-based primary
source and SerpApi Google Maps as fallback.

```text
PlaceSearchCoordinator
└── PlaceSearching
    └── GatewayTravelService
        └── POST /v1/search/places
            ├── Geoapify Places
            └── SerpApi Google Maps fallback
```

Both sources map into `PlaceRecommendation`. Ratings, reviews, hours, dietary
options, accessibility, images, and booking links remain optional evidence-based
fields. Provider absence never becomes a generated claim.

`TimedEvent` remains separate from `PlaceRecommendation`. `EventSearchCoordinator`
uses `EventSearching` and the server Google Events adapter. Resolved events retain
fixed start/end instants and destination time zone; unresolved source date text
remains discoverable but cannot be scheduled as fixed.

`TripCatalog` stores places and timed events independently. Experiences progress
may report either search operation, while completed trip synchronization combines
their actual counts. GPT blueprint source validation includes an explicit event
source kind and rejects unknown event identifiers.

`RoutePlanningCoordinator` depends on `RoutePlanning`. The server Geoapify
Routing adapter maps supported modes into `TransportationLeg` with bounded
geometry, instructions, sourced duration/distance, planning buffer, explicit
confidence, and short-lived provenance.

Scheduled transit is attempted before approximated transit. Carrier-specific
transport modes and ticket claims remain outside this boundary. Route cost and
booking links remain nil until a separate source establishes them.

`WeatherSearchCoordinator` depends on `WeatherProviding`. The server WeatherAPI
adapter validates coordinate, time zone, dates, and forecast horizon before
provider access. Trips beyond the configured horizon return no snapshots and
consume no weather quota.

`WeatherAdvisoryEngine` is deterministic Plan logic over sourced
`WeatherSnapshot` values. It creates source-linked advisories but does not mutate
the itinerary. GPT may receive weather records, but it cannot author weather
facts or override provider alerts.

`TranslationProviding` returns `TranslatedText`, not a bare translated string.
The value preserves original text, source/target language, machine status,
protected terms, and provenance.

The server translation adapter segments protected names, addresses, identifiers,
dates, amounts, URLs, and emails before calling the configured provider. It
supports Google, DeepL, or trusted HTTPS LibreTranslate without exposing provider
credentials to iOS. Translation uses memory-only cache because traveler messages
may contain sensitive context.

### Unified voice boundary

`VoiceSessionCoordinator` is the sole owner of live microphone and speech
recognition resources. It coordinates wake-phrase recognition, full-request
transcription, microphone amplitude, silence detection, permission state, and
recognizer restart behavior through one `AVAudioEngine`.

`VoiceRecognitionRules` contains hardware-independent policy for wake matching
and request completion. This lets phrase and silence rules run in command-line
verification without linking the iOS-only audio session.

The dependency flow is:

```text
MapScreen
├── VoiceSessionCoordinator
│   ├── AVFAudio
│   ├── Speech
│   └── VoiceRecognitionRules
├── TripPlanningSession
└── EarthSceneController
```

The voice coordinator emits transcript and event state; it does not navigate,
construct trips, call providers, persist transcripts, or manipulate SceneKit.
`MapScreen` bridges its output into planning-session transitions and visual
speech intensity.

### Map-to-Plan handoff

`MapScreen` initiates navigation only after `TripPlanningSession` reaches
`validating` with a nonnil request. Local handoff progress contracts the active
voice disc toward the Plan header; semantic request and phase data remain in the
shared planning session.

`PlanScreen` reads the shared request and phase. It does not read Map animation
state or own navigation. Its Card 5 responsibility is limited to the compact
planning indicator, captured request, and truthful phase description.

`AppState` remains the navigation authority. The handoff calls `select(.plan)`,
which preserves existing menu and tab invariants.

## Planned Source Structure

```text
GIA/
├── App/
│   ├── GIAApp.swift
│   ├── RootContainer.swift
│   └── AppState.swift
├── Core/
│   ├── Theme/
│   │   ├── GIAColor.swift
│   │   ├── GIASpacing.swift
│   │   ├── GIATypography.swift
│   │   └── GIAMotion.swift
│   └── Models/
│       ├── ApplicationActivity.swift
│       ├── AppTab.swift
│       └── LocationContext.swift
├── Features/
│   ├── Assistant/
│   │   └── Views/
│   │       └── GIAIdleMark.swift
│   ├── Map/
│   │   ├── Views/
│   │   │   └── MapScreen.swift
│   │   ├── ViewModels/
│   │   │   └── MapViewModel.swift
│   │   └── Earth/
│   │       ├── EarthRenderingConfiguration.swift
│   │       ├── EarthSceneController.swift
│   │       └── EarthSceneView.swift
│   ├── Plan/
│   │   └── Views/
│   │       └── PlanScreen.swift
│   └── Group/
│       └── Views/
│           └── GroupScreen.swift
├── Components/
│   ├── Layout/
│   │   └── MapStage.swift
│   ├── Menu/
│   │   └── EmptyMenuOverlay.swift
│   ├── Navigation/
│   │   └── BottomNavigationBar.swift
│   └── TopChrome/
│       ├── HamburgerButton.swift
│       ├── LocationContextView.swift
│       └── MapTopChrome.swift
├── Resources/
│   └── Assets.xcassets
└── Documentation/
```

## Responsibility Boundaries

### Application shell

`AppState` is the single source of truth for:

- Selected tab
- Menu presentation
- Application activity (`active`, `inactive`, or `background`)
- Whether the Map may perform live Earth rendering

`AppState` enforces the following invariants:

- Map is the initial destination.
- Menu presentation is allowed only while Map and the application are active.
- Selecting any tab closes the menu.
- Leaving the active application state closes the menu.
- Earth rendering is allowed only while Map and the application are active.

`TripPlanningSession` is the shared semantic workflow state for:

- Wake and manual activation
- Listening, transcription, and validation
- Clarification
- Provider search and comparison
- Itinerary construction and presentation
- Ready, partial, failed, cancelled, and returning outcomes

It validates transitions before mutating session data and retains a bounded,
non-sensitive transition history. It may own the current request and completed
trip, but it does not own renderer state, provider credentials, raw provider
payloads, or persistence implementation.

`RootContainer`:

- Selects the active destination
- Keeps bottom navigation persistent
- Closes incompatible overlays during navigation
- Injects one shared trip-planning session into Map, Plan, and Group
- Does not construct or control SceneKit nodes

The Map screen remains mounted beneath blank Plan and Group destinations. Its
SceneKit renderer is paused and hidden while inactive, preserving Earth orientation
without spending rendering resources. The bottom navigation is installed with a
bottom safe-area inset so controls remain above the iPhone home indicator while the
canvas continues beneath it.

### Map feature

`MapViewModel` owns:

- Current location context
- Whether the Earth should be active
- A future-compatible camera-mode boundary

`MapScreen` will compose:

- Earth scene
- Top chrome
- Menu overlay

The view does not create SceneKit materials, lights, cameras, or actions.

`MapStage` owns the portrait iPhone coordinate system for its visual layers.
It calculates:

- Screen-edge spacing
- The top-chrome frame
- The independent assistant-identity frame
- A visually centered square world frame
- Full-screen overlay bounds

The stage accepts independent world, chrome, assistant, and overlay content. This
keeps Earth and G.I.A. placement separate from navigation controls and allows the
assistant identity to move independently during later activation states.

### Plan feature

`PlanScreen` reads the shared planning request, phase, and completed trip. It
owns no provider clients and does not mutate provider or domain data.

`PlanPresentationModels` maps workflow/domain values into truthful presentation
states:

- Phase identity and detail
- Destination, date, traveler, and budget context
- Queued, active, ready, and unavailable planning modules
- Result-presence checks against the shared trip aggregate

`TripRequestInterpreter` is a deterministic local service between voice
transcription and provider search. It maps transcript text into `TripRequest`,
then returns field-specific semantic validation issues. It does not call GPT,
the gateway, or travel providers.

Corrections flow back through
`TripPlanningSession.replaceRequestDuringValidation`. Plan views never mutate
session-owned request values directly.

`TripPlanningProgress` is workflow data owned by `TripPlanningSession`. It
tracks nine ordered workstreams with queued, input-waiting, active, complete,
unavailable, or cancelled state. Provider adapters must explicitly supply
result counts and provider attribution; views cannot infer completion from
animation time.

`PlanningProgressView` and `PlanningModuleRail` read the same progress snapshot.
Plan cancellation transitions the session to cancelled, then selects Map. Map
recognizes that semantic state and performs the existing sphere-to-Earth return
before the session becomes idle.

Reusable Plan views own layout and accessibility only:

- `FlightComparisonSection`
- `PlanHeaderView`
- `GIAPlanningIndicator`
- `PlanningModuleRail`
- `PlanningProgressView`
- `PlanTimelineFoundation`
- `PlanSurfaceModifier`
- `TripRequestCorrectionSheet`

This separation lets live provider adapters and itinerary logic populate the
existing shell without embedding network assumptions in the visual components.

`FlightPresentationModels` formats sourced `FlightOffer` values for Plan without
changing their factual fields. Temporary comparison selection remains local view
state. Final flight selection passes the source UUID to
`TripPlanningSession.selectFlightOffer`, which validates catalog membership
before updating the shared trip.

`HotelPresentationModels` and `HotelComparisonSection` follow the same state
boundary for `HotelOffer`. Rating scale, nightly/total price, taxes,
cancellation, amenities, source, and image availability remain explicit.
Temporary hotel focus/comparison stays local; final selection passes the UUID to
`TripPlanningSession.selectHotelOffer`.

`ItineraryPresentationModels` maps itinerary days, items, weather, cost, and
transport routes into the spatial timeline. `SpatialItineraryTimeline` owns day
selection, expansion, and drag presentation. Shared item movement and lock state
flow through guarded `TripPlanningSession` methods.

Route connectors appear only when adjacent item locations match a sourced
`TransportationLeg`. Timeline views do not calculate travel duration, estimate
missing routes, or mutate fixed event times.

### Earth renderer

`EarthSceneController` owns:

- `SCNScene`
- Camera node
- Earth tilt node
- Earth surface node
- Lighting nodes
- Rotation action
- Pause and resume behavior

`EarthSceneFactory` constructs the scene graph and materials.

`EarthSceneView` is the SwiftUI-to-SceneKit boundary. No other feature imports or
manipulates SceneKit directly.

This boundary is important because SceneKit should remain replaceable without
rewriting the application shell or Map feature.

### Reusable components

Top chrome, menu presentation, and bottom navigation are independent components.
They receive values and actions from their owner rather than reading unrelated global
state.

## State Model

```text
Launch
└── selectedTab = Map
    ├── locationContext = Space
    ├── isMenuPresented = false
    └── Earth active

Hamburger tap
└── Toggle isMenuPresented

Outside-menu tap
└── isMenuPresented = false

Plan or Group selection
├── isMenuPresented = false
├── selectedTab changes
└── Earth pauses

Map selection
├── selectedTab = Map
└── Earth resumes

Application inactive/backgrounded
├── Menu closes
├── AppState disallows live Earth rendering
└── Earth pauses

Trip planning
└── idle
    ├── wakePhraseDetected → listening
    └── listening
        ├── transcribing → validating
        │   ├── needsClarification → listening
        │   └── searching → comparing
        │       └── buildingItinerary → presenting → ready
        ├── failed
        ├── cancelled
        └── returning → idle
```

## Scene Graph

```text
SCNScene.rootNode
├── CameraNode
├── EarthTiltNode
│   └── EarthSurfaceNode
├── KeyLightNode
└── AmbientLightNode
```

Axial tilt and surface rotation are separated so later camera movement and geographic
focus do not become coupled to idle globe rotation.

## Layout Model

The application targets portrait iPhone displays only.

- The background extends through all safe areas.
- Top controls respect the top safe area.
- `SPACE`, `GIA`, and the hamburger use independent anchors.
- `GIA` is anchored to the screen's horizontal center.
- Earth is positioned near the screen's visual center.
- Bottom navigation respects the bottom safe area.
- No desktop breakpoints, resizable-window behavior, mouse interactions, or keyboard
  navigation are part of Phase 1.

## Dependency Direction

```text
App shell
  ├── Core models and design system
  ├── Core networking
  ├── Domain service contracts
  ├── Feature views
  └── Reusable components

Map feature
  ├── Core models and design system
  └── Earth renderer

Earth renderer
  ├── SceneKit
  └── UIKit where required by SCNView
```

The Earth renderer must not import or depend on Plan, Group, menu, or application
navigation code.

## Deferred Architecture

The following are deliberately deferred until a feature requires them:

- Persistence layer
- Networking layer
- Authentication
- AI/agent services
- Calendar services
- Deep-link routing
- Notification services
- Analytics

Adding empty protocols or unused models during Phase 1 would make the architecture
look larger without making it more extensible.

