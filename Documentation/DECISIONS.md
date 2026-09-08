# G.I.A. Decision Log

This log records product and engineering decisions that affect the competition entry.
New entries should describe the reason and rejected alternatives, not only the final
choice.

## D-001 — Native iPhone application

- Status: Accepted
- Phase: 1
- Decision: Build G.I.A. in Swift and SwiftUI as an iPhone application.
- Reason: The intended interaction, animation, accessibility, and App Store quality
  are specifically native to iOS.
- Constraints:
  - iPhone only
  - Portrait only during Phase 1
  - Mac Catalyst disabled
  - No desktop or browser layout requirements
- Rejected:
  - Three.js application embedded in a web view
  - Android-first implementation
  - Cross-platform framework during the initial implementation

## D-002 — Map is the home destination

- Status: Accepted
- Phase: 1
- Decision: Launch directly into Map with Earth as the primary visual anchor.
- Reason: G.I.A. is world-first and assistant-first, not chat-first or booking-first.
- Rejected:
  - Chat transcript home screen
  - Search box home screen
  - Dashboard of trip cards

## D-003 — SceneKit Earth

- Status: Accepted with isolation requirement
- Phase: 1
- Decision: Use SceneKit for the first native Earth implementation.
- Reference:
  https://github.com/SMGLOBAL-ops/Earth-3D-PlanetModel-SwiftUI-SceneKit
- Reason: The selected reference already demonstrates the relevant native concepts:
  a SwiftUI-hosted `SCNScene`, textured sphere, camera, lighting, and rotation.
- Constraint: SceneKit must remain isolated behind the Earth view/controller boundary
  so the rest of the app does not depend directly on it.
- Constraint: Reference code and textures cannot be copied until their licensing is
  fully verified.
- Rejected for Phase 1:
  - Three.js in `WKWebView`
  - Flat Earth image
  - Interactive web map

## D-004 — Restrained Earth scene

- Status: Accepted
- Phase: 1
- Decision: Show Earth only near the screen's visual center against near-empty dark
  space.
- Reason: The interface needs visual focus and negative space for G.I.A.'s identity.
- Rejected:
  - Moon orbit
  - Dense Milky Way background
  - Free drag and zoom
  - Centered planet demonstration
  - Decorative orbit rings

## D-005 — Plain GIA wordmark

- Status: Accepted
- Phase: 1
- Decision: Use `GIA` as plain text at top-center.
- Reason: A temporary typographic identity avoids prematurely committing to a generic
  AI icon and creates a replaceable boundary for the future assistant mark.
- Deferred:
  - Custom 3D G.I.A. object
  - Activation animation
  - Listening state

## D-006 — Empty menu remains visibly interactive

- Status: Accepted
- Phase: 1
- Decision: Hamburger opens a visible anchored dropdown with no menu rows.
- Reason: The requested menu behavior must be testable without inventing settings.
- Rejected:
  - Full-screen sheet
  - Invisible interaction
  - Fake or disabled settings
  - “Coming soon” content

## D-007 — Plan and Group are functional blank destinations

- Status: Accepted
- Phase: 1
- Decision: Plan and Group can be selected but contain no feature content.
- Reason: Navigation architecture can be validated while keeping Phase 1 narrowly
  scoped.
- Constraint: Bottom navigation remains visible.
- Constraint: Earth rendering pauses while either blank destination is active.

## D-008 — Offline-first Phase 1

- Status: Accepted
- Phase: 1
- Decision: Bundle every required asset and make no network requests.
- Reason: FBLA warns that conference internet may be unreliable, and the first slice
  does not require remote data.
- Rejected:
  - Remote Earth textures
  - Loading assets from GitHub
  - Analytics or remote configuration during Phase 1

## D-009 — Centralized lifecycle invariants

- Status: Accepted
- Phase: 1
- Decision: Translate SwiftUI scene lifecycle into app-owned activity state.
- Reason: Menu and Earth behavior must remain deterministic across tab changes,
  interruptions, backgrounding, and foregrounding.
- Invariants:
  - The menu can open only while Map and the application are active.
  - Tab selection always dismisses the menu.
  - Inactive and background states dismiss the menu.
  - Earth rendering runs only while Map and the application are active.
  - Reduce Motion independently disables Earth rotation.
- Rejected:
  - Independent lifecycle checks scattered through unrelated components
  - A permanently running SceneKit renderer behind blank tabs

## D-010 — Breathing-aperture idle identity

- Status: Accepted
- Phase: 1 visual refinement
- Decision: Place the wordmark inside a restrained circular aperture fixed over the
  center of Earth, with one intermittent outward ripple.
- Reason: Separating Earth and G.I.A. created competing focal points. The World Core
  composition makes G.I.A. feel as though it inhabits and navigates the world while
  avoiding the appearance of text printed onto the globe.
- Motion:
  - 4.8-second low-amplitude core breath
  - 1.55-second outward ripple
  - 3.6-second total ripple cycle, leaving a visible quiet interval
  - 30 FPS animation schedule while Map is active
- Constraints:
  - No neon glow
  - No Siri waveform
  - No continuous stack of radar rings
  - No hit behavior until assistant activation is implemented
  - Static aperture when Reduce Motion is enabled
- Architectural consequence: G.I.A. is an independent, screen-fixed `MapStage` layer
  aligned to the Earth frame rather than a child of `MapTopChrome`. Earth rotates
  beneath it without rotating the identity.

## D-011 — Monochrome spatial-intelligence foundation

- Status: Accepted
- Phase: 1 visual refinement
- Decision: Render Earth in high-contrast monochrome and increase the scale and
  presence of the central G.I.A. aperture.
- Reason: The globe is not only travel imagery; it is the visual foundation of
  G.I.A.'s future spatial intelligence states. Removing color lets assistant motion,
  routes, and state-specific accents become the meaningful color layer later.
- Implementation:
  - SceneKit camera saturation is zero.
  - Contrast is increased and exposure is slightly reduced.
  - Ambient lighting is neutral and restrained.
  - The source NASA texture remains unmodified in the asset catalog.
  - The G.I.A. core and wordmark are enlarged while retaining a single quiet ripple.
- Constraint: The direction may evoke a cinematic spatial computer, but it must use
  original G.I.A. graphics and must not reproduce Marvel/JARVIS interface assets,
  marks, sounds, or distinctive compositions.

## D-012 — Truthful spatial Plan shell

- Status: Accepted
- Phase: 2
- Decision: Establish the complete Plan information hierarchy before connecting
  live providers or rendering recommendation details.
- Reason: API response shapes and latency must not dictate the product's visual
  architecture. A stable shell lets domain state populate consistent locations
  while offline fixtures use the same interface.
- Visual system:
  - Near-black spatial canvas
  - Translucent charcoal surfaces
  - Fine white geometry
  - One restrained cool-blue intelligence accent
  - Horizontally scrollable planning modules
  - A vertical itinerary foundation
- Truthfulness constraints:
  - Missing request values display `Resolving`.
  - Modules remain `Queued` until their workflow phase begins.
  - `Ready` requires corresponding data in the shared trip.
  - The shell does not invent telemetry, counts, prices, or booking states.
- Accessibility consequence: surfaces have opaque and increased-contrast
  variants; module dimensions scale with Dynamic Type; status is communicated
  textually as well as visually.

## D-013 — Event-driven planning progress

- Status: Accepted
- Phase: 2
- Decision: Planning progress is updated by workflow and provider events, never
  by elapsed-time percentages.
- Reason: Timer-driven progress would imply work and results that may not exist,
  especially under slow, failed, cached, or offline provider conditions.
- Workstream states: queued, waiting for input, active, complete, unavailable,
  and cancelled.
- Data consequence:
  - Result counts are optional until a provider explicitly supplies them.
  - Provider attribution is stored with each workstream.
  - A zero-result response differs from a provider that has not responded.
  - Negative result counts are structurally rejected.
- UI consequence: the process spine and module rail consume the same shared
  progress snapshot.
- Cancellation consequence: completed work remains recorded while queued and
  active work is cancelled; Map performs the established return animation before
  the session becomes idle.

## D-014 — Gateway-only provider access

- Status: Accepted
- Phase: 2
- Decision: The iOS application communicates with one G.I.A. gateway and never
  calls a paid travel, AI, speech, weather, or translation provider directly.
- Reason: Provider secrets cannot be protected in a distributed application
  binary, and raw provider response shapes must not become application state.
- Client consequences:
  - Remote gateway URLs require HTTPS.
  - Authorization is injected and short-lived.
  - Provider failures map into a finite safe error vocabulary.
  - Retries are bounded and cancellable.
  - Feature modules depend on narrow domain service protocols.
- Cache consequences:
  - Request material is represented by SHA-256 keys.
  - Only successful sanitized responses are cached.
  - Price-sensitive data uses short TTLs.
  - Plans and generated speech are not response-cached.
- Gateway consequence: provider adapters may return sanitized JSON envelopes or
  secured binary speech, but upstream headers and internal errors are not
  forwarded.
- Production constraint: shared bearer credentials are development-only.
  App Store deployment requires authenticated user sessions and App Attest.

## D-015 — GPT selects sources but does not create facts

- Status: Accepted
- Phase: 2
- Decision: GPT returns a constrained `TripPlanBlueprint` containing source
  selections, schedule placement, rationales, and warnings.
- Reason: Prices, ratings, schedules, availability, and booking status must
  remain owned by the provider records that supplied them.
- Context constraint: the model receives bounded structured travel summaries,
  not the original transcript, checkout links, credentials, or raw provider
  payloads.
- Output constraint: strict Structured Outputs exclude factual and booking
  fields entirely.
- Validation consequence: server and iOS independently reject unknown IDs,
  missing IDs, source-kind mismatch, reversed times, overlaps, invalid time
  zones, and items outside the trip.
- Search consequence: general GPT web search is not used while constructing the
  itinerary. Any future web discovery must enter through a separately cited and
  validated source boundary.
- Storage consequence: OpenAI requests set `store` to false.

## D-016 — Flight search is sourced, short-lived, and not ticketing

- Status: Accepted
- Phase: 2
- Decision: SerpApi Google Flights results map into three-minute
  source-attributed `FlightOffer` values.
- Reason: Flight prices and continuation tokens change quickly and cannot be
  treated as durable inventory or proof of purchase.
- Validation consequence: search requires resolved IATA endpoints, endpoint
  time zones, chronological dates, bounded passenger counts, and ISO currency.
- Time consequence: exact provider local-clock strings are retained. Unknown
  connection time zones remain explicitly unresolved rather than silently
  becoming authoritative UTC schedules.
- Ranking consequence:
  - Lowest, fastest, and fewest-stop labels are deterministic.
  - Lower-emissions requires provider comparison data.
  - `giaRecommended` is reserved for grounded group-trip ranking.
- Round-trip consequence: initial outbound choices retain their continuation
  token; return segments remain empty until explicitly selected and retrieved.
- Booking consequence: Google Flights links are external continuation only.
  Search never creates a ticket, reservation, charge, cancellation, or
  confirmation.

## D-017 — Hotel search preserves uncertainty and rating scale

- Status: Accepted
- Phase: 2
- Decision: Google Hotels properties map into five-minute, source-attributed
  `HotelOffer` values with explicit rating scale and unknown optional fields.
- Reason: Hotel sources vary in rating scale, tax inclusion, cancellation
  detail, total pricing, and amenity language.
- Price consequence:
  - Nightly and total prices remain separate.
  - Total may be derived from nightly price and destination calendar nights only
    when the provider omits total.
  - Taxes remain unknown unless source fields establish inclusion.
- Rating consequence: Google Hotels guest ratings explicitly use a five-point
  scale.
- Filter consequence: class, rating, type, amenity, and nightly-price constraints
  are rechecked after provider mapping.
- Booking consequence: property links are external continuation only and never
  create reservation state.
- Recommendation consequence: provider mapping may mark lowest price or explicit
  cancellation flexibility but cannot assign `giaRecommended`.

## D-018 — Cost-aware place discovery with evidence-only attributes

- Status: Accepted
- Phase: 2
- Decision: Use Geoapify Places as the normal coordinate-based discovery source
  and SerpApi Google Maps only as fallback.
- Reason: Geoapify supports broad low-cost place discovery, while SerpApi can
  recover missing-coordinate/provider cases and may supply richer attributes at
  higher quota cost.
- Fallback triggers:
  - Missing destination coordinate
  - Geoapify unavailable
  - Geoapify returns no matches
  - Geoapify not configured
- Evidence consequence: rating, review count, price level, hours, dietary
  options, accessibility, images, indoor status, and reservation requirements
  remain absent unless a provider explicitly supports the claim.
- Link consequence: restaurant ordering links are not reservation links.
- Workflow consequence: Experiences progress derives contributing providers
  from returned provenance rather than assuming both providers ran.

## D-019 — Timed events are not flexible places

- Status: Accepted
- Phase: 2
- Decision: Concerts, games, festivals, and other events use a dedicated
  `TimedEvent` model rather than `PlaceRecommendation`.
- Reason: A venue may be flexible, but an event can have a fixed start, external
  ticket dependency, cancellation, postponement, and expiration.
- Time consequence:
  - Source date text is always preserved.
  - Fixed time requires a parsed calendar date, explicit clock range, and valid
    destination time zone.
  - Missing time remains unresolved rather than receiving an invented default.
- Filter consequence: cancelled, expired, duplicate, and provably out-of-range
  events are excluded.
- Ticket consequence: ticket links remain external and never create booking or
  payment state.
- GPT consequence: events enter planning by validated source UUID only.

## D-020 — Route confidence is explicit

- Status: Accepted
- Phase: 2
- Decision: Geoapify routes map into `TransportationLeg` with estimated,
  scheduled, or approximated confidence.
- Reason: Generic routing cannot prove live traffic, a transit operator, fare,
  ticket availability, or carrier-specific service.
- Mode consequence:
  - Walking and bicycle use their native routing modes.
  - Car and rideshare use driving estimates.
  - Transit attempts scheduled routing before approximated transit.
  - Carrier-specific airplane, train, subway, ferry, and bus requests are
    rejected at this boundary.
- Geometry consequence: route lines are validated, flattened, and bounded while
  preserving the destination.
- Time consequence: arrival derives from provider duration; safety buffer
  remains a separate planning value.
- Cost/booking consequence: both remain nil without a dedicated source.

## D-021 — Forecast horizon and weather advice are deterministic

- Status: Accepted
- Phase: 2
- Decision: WeatherAPI provides weather facts; local deterministic rules provide
  planning advisories.
- Reason: GPT cannot guarantee current conditions or official alerts, and
  current weather must not be shown as a distant trip forecast.
- Horizon consequence:
  - Forecast capability is configured and bounded.
  - Trips beyond the horizon skip provider access.
  - Missing distant forecasts display not-yet-available state.
- Data consequence: absent temperature, precipitation, wind, and alert fields
  remain unknown rather than zero or safe.
- Alert consequence: government alert aggregation retains agency/source evidence
  but is not represented as globally comprehensive.
- Planning consequence: alert, storm, rain, snow, wind, and extreme-temperature
  rules produce source-linked advisories without automatically changing the
  itinerary.

## D-022 — Translation preserves sources and sensitive text

- Status: Accepted
- Phase: 2
- Decision: translation returns `TranslatedText` containing original and
  translated values, language context, protected terms, machine status, and
  provenance.
- Reason: travel names, addresses, dates, amounts, URLs, emails, and identifiers
  must not be altered or lost.
- Segmentation consequence: protected ranges are removed before provider access,
  remaining text cores are translated, and exact protected values are
  recombined locally.
- Provider consequence: Google, DeepL, or trusted HTTPS LibreTranslate is chosen
  explicitly through server configuration; credential format is never used to
  guess a provider.
- Privacy consequence: translation responses use memory-only cache because
  travel messages may contain personal or accessibility context.
- UI consequence: machine-translated content must remain labeled and original
  text must remain accessible.

## D-023 — Flight focus, comparison, selection, and purchase are distinct

- Status: Accepted
- Phase: 2
- Decision: Flight UI separates temporary focus, up-to-three comparison,
  shared-trip selection, and external provider continuation.
- Reason: A user must be able to inspect options without accidentally changing
  group state or implying a ticket purchase.
- State consequence:
  - Focus and comparison remain local UI state.
  - Final selection validates source UUID against the shared trip catalog.
  - Provider links never mutate trip or booking status.
- Copy consequence: actions use `SELECT FLIGHT` and `VIEW WITH PROVIDER`; the
  section explicitly states `NO BOOKING MADE`.
- Data consequence: unresolved connection time zones and incomplete round-trip
  legs remain visibly disclosed.
- Fixture consequence: visual test options are labeled Demo and cannot be
  mistaken for live fares.

## D-024 — Hotel imagery and selection remain source-bound

- Status: Accepted
- Phase: 2
- Decision: Hotel UI separates focus, temporary comparison, shared-trip
  selection, and external provider continuation.
- Reason: Inspecting or selecting a property must not imply a reservation.
- Image consequence: only provider-supplied HTTPS images are loaded; missing or
  failed imagery uses an original spatial placeholder rather than unrelated
  stock photography.
- Rating consequence: guest rating always includes its source scale and remains
  separate from star class.
- Price consequence: nightly, total, and tax inclusion remain distinct.
- State consequence: final hotel selection validates catalog membership;
  temporary focus/comparison remains local.
- Copy consequence: the section states `NO RESERVATION MADE`, selection uses
  `SELECT STAY`, and continuation uses `VIEW WITH PROVIDER`.

## D-025 — Itinerary editing is constrained spatial data

- Status: Accepted
- Phase: 2
- Decision: the daily timeline renders shared itinerary data and routes all
  movement/lock changes through `TripPlanningSession`.
- Reason: local drag offsets must not become persisted schedule state or bypass
  chronology and overlap validation.
- Interaction consequence:
  - Only a visible handle drags flexible items.
  - Movement snaps to 15-minute increments.
  - Fixed and user-locked items cannot move.
  - VoiceOver receives equivalent earlier/later actions.
- Data consequence: valid moves preserve duration, target an existing itinerary
  day, remain inside trip boundaries, and reject overlap.
- Route consequence: connectors require a sourced route matching adjacent
  locations; missing routes remain visibly unconnected.
- Booking consequence: selected/confirmed/completed itinerary states remain
  distinct and selected never implies purchased.

