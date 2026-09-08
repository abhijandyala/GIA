# G.I.A. Application Record

G.I.A. (Group Intelligence Assistant) is a native iPhone group-travel assistant for the 2026–2027 FBLA Mobile Application Development topic **Together We Go: Group Trip Planner**.

This file is the current-state record of the product. It exists so frontend, voice, and in-app functionality can keep moving on `main` while database, accounts, and onboarding work happens on a separate branch.

**Repository:** [https://github.com/abhijandyala/GIA](https://github.com/abhijandyala/GIA)

---

## Ownership and branch split

| Track | Owner | Branch | Scope |
| --- | --- | --- | --- |
| Voice, UI, and in-app functionality | Abhi Jandyala | `main` | Map, Plan, voice conversation, assistant identity, trip planning UX, gateway-backed live search, judge-safe demo, accessibility, and visual polish |
| Database, accounts, and onboarding | Separate track | `database-onboarding` | User onboarding, authentication, remote storage, multi-device sync, invitations over a network, and wiring persistence into app launch |

Abhi built the working product on this repository: the iPhone interface, the voice assistant, the trip-planning session, Plan comparison and itinerary surfaces, the local domain models, and the Node gateway that talks to travel providers. That work is the source of truth on `main`.

The `database-onboarding` branch starts from the same snapshot. It is the place to add accounts, first-launch onboarding, and a real backend without blocking voice or UI work.

Do not treat the two tracks as finished products that can be merged blindly. Database work should consume the existing `Trip` domain aggregate. It should not invent a second trip model or change spoken copy, Map layout, or Plan cards unless a contract change is required.

---

## What the product is

G.I.A. is designed as another member of the trip group, not a booking website with a chatbot attached.

- Launch opens **Map**, not a chat thread or search form.
- A SceneKit Earth sits at the visual center of a dark space canvas.
- **GIA** is a persistent assistant identity over Earth, not a logo in a nav bar.
- The user speaks a trip request. G.I.A. clarifies missing facts, then builds a live Plan from real provider results.
- **Plan** is the shared source of truth for flights, hotels, places, events, routes, weather, itinerary, budget, and conflicts.
- **Group** is the people, votes, and conversation destination. The collaboration domain exists; the Group tab is currently hidden while Map and Plan are refined.
- G.I.A. never claims a real booking it did not complete. Demo confirmation and external checkout are separate states.

The intended spoken demo is: someone says a destination, G.I.A. plans the trip, and the group can review the result. Commercial storyboard notes live in the parent workspace file `VideoDemo.md`.

---

## Platform

- Language: Swift
- Interface: SwiftUI
- 3D Earth: SceneKit
- Local storage library: SwiftData (implemented, not fully wired at launch)
- Audio: AVFAudio, Speech, Accelerate
- Calendar and reminders: EventKit, UserNotifications
- Minimum OS: iOS 17
- Device: iPhone only, portrait, dark appearance
- No Mac Catalyst, no iPad layout, no web client
- No external Swift packages
- Server: Node.js 20+ API gateway in `Gateway/`

---

## Current product status

The application is past the empty Phase 1 shell. Map, voice, live planning, Plan UI, local collaboration models, a judge-safe Tokyo demo, and the provider gateway are implemented.

### Done on `main` (Abhi: frontend and functionality)

1. Native app shell with Map / Plan / Group navigation.
2. World-first Map home with rotating Earth, starfield, top chrome, hamburger, and bottom tabs.
3. Unified voice session: wake phrase, request transcription, silence endpointing, barge-in, typed conversation fallback.
4. Spoken and on-screen replies stay aligned through `GIAConversationCopy`. GPT writes live replies. Generic canned phrases are last-resort fallbacks only.
5. Request interpretation, one-question-at-a-time clarification, and conversational Plan edits.
6. Shared `TripPlanningSession` state machine and progressive Plan assembly.
7. Live provider planning through the local gateway: location, flights, hotels, places, events, routes, weather, GPT blueprint, ElevenLabs speech, translation.
8. Plan UI: progress rail, flight comparison, hotel comparison, spatial itinerary timeline, budget and conflict cards, demo or external booking review.
9. Local group domain: invitations, roles, votes, chat, privacy-aware preferences. Group tab UI is temporarily parked behind an empty state.
10. Local SwiftData schema and trip library code. Startup restore is not attached at `GIAApp` yet.
11. Judge-safe offline Tokyo fixture and demo reset.
12. Accessibility and quality policy: VoiceOver, Dynamic Type, Reduce Motion, Reduce Transparency, Increased Contrast, 44-point controls.
13. Gateway security boundary so provider keys never live in the iOS binary.

### Not done (belongs on `database-onboarding`)

- First-launch onboarding and account creation
- Sign in, sign up, session tokens, Sign in with Apple
- Remote user identity bound to a traveler
- Cloud database for trips, members, votes, and messages
- Multi-device and multi-user sync
- Network invitations and email or SMS delivery
- Production authentication instead of a compiled gateway development token
- App Attest or equivalent device attestation
- Retention, deletion, and privacy policy for stored traveler data
- Input validation for account and profile forms
- Wiring `TripPersistenceController` into `GIAApp` / `RootContainer` as the local cache in front of remote storage

### Intentionally out of scope for both tracks until later

- Collecting real payment inside G.I.A.
- Claiming provider-confirmed tickets or hotel reservations
- Android or web clients
- Landscape or iPad layouts

---

## Repository layout

```text
GIA/
├── APPLICATION.md              <- this file
├── README.md                   <- older Phase 1 open-and-run notes
├── GIA.xcodeproj
├── .env                        <- local secrets, never commit
├── GIA/                        <- iOS application target
│   ├── App/                    <- launch, navigation, planning session
│   ├── Components/             <- chrome, menu, bottom navigation, Map stage
│   ├── Core/                   <- theme, networking, persistence, quality
│   ├── Domain/                 <- provider-independent trip models
│   └── Features/
│       ├── Assistant/          <- voice visuals, speech session, replies
│       ├── Map/                <- Earth, Map screen, starfield
│       ├── Plan/               <- Plan workspace, search, comparison, timeline
│       ├── Group/              <- group workspace, chat, votes, trip library
│       ├── Demo/               <- judge-safe offline Tokyo journey
│       └── TravelTools/        <- notifications and calendar export
├── Gateway/                    <- Node API gateway
│   ├── src/
│   ├── test/
│   └── scripts/
├── Verification/               <- command-line Swift proof programs
└── Documentation/              <- phase cards, architecture, FBLA evidence
```

The iOS target never calls SerpApi, OpenAI, ElevenLabs, Geoapify, WeatherAPI, or Google Translation directly. It talks only to the gateway.

---

## How the app is structured

Feature-oriented MVVM.

- `AppState` owns tab, menu, lifecycle, and whether Earth may render.
- `TripPlanningSession` owns the semantic trip workflow: wake, listen, clarify, search, compare, itinerary, ready, fail, cancel.
- `RootContainer` mounts Map, Plan, and Group, keeps bottom navigation visible, and injects the shared session.
- Views render state. They do not own provider clients or credentials.
- `Domain/Trip` is the only trip source of truth. Provider JSON never becomes app state.
- SceneKit stays behind `EarthSceneController` and `EarthSceneView`.

```text
User speech or typed text
        │
        ▼
VoiceSessionCoordinator / typed composer
        │
        ▼
TripPlanningSession
        │
        ├── TripRequestInterpreter          (local, deterministic)
        ├── GIAResponseCoordinator          (spoken + displayed reply)
        └── TripPlanningOrchestrator
                    │
                    ▼
            GatewayTravelService
                    │
                    ▼
            G.I.A. Node gateway
                    │
                    ├── OpenAI conversation / interpret / plan
                    ├── SerpApi flights, hotels, events
                    ├── Geoapify location, places, routes
                    ├── WeatherAPI
                    ├── ElevenLabs speech
                    └── Google Translation
```

---

## Screens and UI (Abhi)

### Map, home

`Features/Map` plus `Components`.

- Dark space canvas, procedural starfield, NASA Blue Marble Earth.
- Earth rotates while Map is active and the app is foregrounded. It pauses on Plan, Group, background, Reduce Motion, and Low Power Mode.
- Top chrome: `SPACE`, centered GIA identity, hamburger.
- Hamburger opens an empty anchored menu and closes on second tap, outside tap, tab change, or app interruption.
- Custom Plan / Map / Group bar. Map is the default selected tab.
- GIA idle mark is a quiet breathing aperture. Activation expands into the live voice disc.

### Voice and assistant identity

`Features/Assistant` plus Map conversation logic in `MapScreen.swift`.

- One `AVAudioEngine` for wake listening, request capture, and amplitude.
- Wake phrases include `GIA`, `Hey GIA`, `G I A`, and `Gee eye ay`.
- End of speech uses transcript stability, not microphone noise: about 0.45 seconds minimum capture, 0.95 seconds without transcript change to complete, 6 seconds no-speech recovery, 20 second hard cap.
- Live transcript appears in the active voice disc.
- ElevenLabs voice `3Drdg7QWqr45nZmYpXRP` is the primary voice. `AVSpeechSynthesizer` is the fallback so silence never becomes a Voice unavailable error.
- Microphone pauses during G.I.A. playback so the assistant cannot trigger itself.
- Typed conversation is a first-class fallback, not a hidden debug path.
- Spoken and displayed text are sanitized together: no em dashes, no en dashes, no abbreviations such as `hrs` or `Mon`. Airport codes may stay as codes.
- Stop phrases such as `Stop GIA` and `goodbye` close the conversation with `See you later.` A completed Plan is kept. An incomplete conversation is discarded.

Conversation rules for future UI work:

- GPT writes live replies. Do not hardcode trip-specific spoken lines.
- Ask one clarification question at a time: destination, dates, traveler count, then optional preferences.
- Budget is optional. Dates and group size are required for truthful search.
- Follow-up wake on Map, Plan, or Group can change destination, dates, travelers, budget, interests, dietary or accessibility needs, flight or hotel preferences, and pace, then rebuild Plan from a clean draft.

### Plan

`Features/Plan`.

- Plan stays empty until a validated request exists. Opening Plan during clarification shows a Continue with GIA card instead of a questionnaire.
- After a valid request, Map hands off to Plan. The voice disc contracts into the compact Plan indicator.
- Progressive modules appear as real provider workstreams finish. Completion is never faked with a timer.
- Flight and hotel comparison: featured option, alternatives, evidence (price, bags, emissions, ratings, cancellation), local three-option compare, UUID-guarded selection.
- Spatial daily timeline: day and weather selector, local-time nodes, sourced transport connectors, drag in 15-minute steps, VoiceOver move actions.
- Budget ledger and conflict cards: estimated versus provider-confirmed spend, emergency reserve, timing, travel, venue, weather, dietary, accessibility, and reservation conflicts.
- Booking review is either FBLA demonstration or external provider checkout. No in-app payment. Missing checkout links are rejected.

### Group

`Features/Group`.

Domain and views exist for:

- Organizer and member roles
- Invited-only access
- Pending, accepted, and revoked invitations
- Availability, personal budget, dietary and accessibility coordination
- Three-level preference privacy
- Destination, date, flight, hotel, place, itinerary, and budget votes
- Chat threads, mentions, G.I.A. and system authors, reactions, read receipts
- Local offline trip library and deletion warning

`GroupScreen` currently shows a parked empty state: group tools are hidden while Map and Plan are refined. The underlying workspace views remain in the same file. Database work should restore Group against remote identity, not rewrite the domain from scratch.

---

## Trip domain

`GIA/Domain/Trip` is provider-independent and Foundation-only.

The `Trip` aggregate holds travelers, request, catalog, selections, itinerary, budget, bookings, collaboration, votes, messages, weather, routes, and provenance.

Hard rules:

- Every sourced object keeps provenance (provider, retrieved at, expiration).
- Every money value keeps its currency.
- Every itinerary time keeps time-zone context. Unresolved clock text stays unresolved.
- Demo booking status is mechanically distinct from provider-confirmed status.
- GPT may return a `TripPlanBlueprint` of sourced UUIDs, times, rationales, and warnings. It cannot invent prices, ratings, availability, or bookings.
- Raw transcripts are not persisted. Persistence copies the trip and clears `TripRequest.rawTranscript` before encode.

If database work needs tables, map them from this aggregate. Do not persist raw SerpApi or OpenAI payloads.

---

## Local storage versus the database branch

SwiftData already exists:

- `StoredTripRecord` stores a versioned Codable `Trip` payload plus searchable summary metadata.
- Schema: `GIAPersistenceSchemaV1`.
- Autosave, in-memory fallback if the container cannot open, unsupported-schema preservation, and a local library UI are implemented as code.
- Verification lives in `Verification/TripPersistenceVerificationMain.swift`.

What is missing, and why this is database work:

- `GIAApp` does not attach a `ModelContainer` or configure `TripPersistenceController` at launch.
- There is no user account, so a saved trip is not owned by a person.
- There is no remote store, so two phones cannot share one trip.
- Group invitations cannot leave the device.
- First launch has no onboarding, name, or permission explanation sequence beyond the system microphone and speech prompts.

Recommended database-track direction:

1. Add first-launch onboarding: who the user is, what G.I.A. is, microphone and speech purpose, optional notifications and calendar.
2. Create authenticated users (Sign in with Apple is the natural iOS path).
3. Keep SwiftData as the offline cache of the same `Trip` payload.
4. Add a server store keyed by trip ID and member IDs.
5. Sync travelers, invitations, votes, and messages.
6. Replace `GATEWAY_ACCESS_TOKEN` with short-lived user sessions before any public deployment.

---

## API gateway

`Gateway/` is the security boundary.

### Routes

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Non-secret configuration status |
| POST | `/v1/respond` | Short structured G.I.A. dialogue |
| POST | `/v1/resolve/location` | Geoapify place resolution |
| POST | `/v1/plan` | Grounded GPT trip blueprint |
| POST | `/v1/search/flights` | Google Flights through SerpApi |
| POST | `/v1/search/hotels` | Google Hotels through SerpApi |
| POST | `/v1/search/places` | Geoapify Places, Google Maps fallback |
| POST | `/v1/route` | Geoapify routing |
| POST | `/v1/weather` | WeatherAPI forecast and alerts |
| POST | `/v1/speech` | ElevenLabs audio |
| POST | `/v1/translation` | Google Cloud Translation |

Unconnected providers return structured `501 provider_not_connected`. Health checks expose issue codes, never credential values.

### Local run

1. Copy `Gateway/.env.example` to `GIA/.env`.
2. Fill server-only keys. Rotate any key that has appeared in a screenshot or chat.
3. From `Gateway`: `npm start`
4. `curl http://127.0.0.1:8787/health`
5. `npm test` and `npm run check`

The iOS Debug build sends `GIA_GATEWAY_ACCESS_TOKEN` when it differs from the localhost default. Remote URLs must be HTTPS. Localhost HTTP is allowed for development.

### Security rules already in the gateway

- Fail closed without gateway authentication
- Constant-time bearer compare
- Browser origins denied unless allowlisted
- 64 KiB body limit, rate limit, hard timeout
- Provider errors sanitized
- `no-store` responses
- Request logs: method, route, status, request ID only

Do not log traveler names, accessibility needs, dietary needs, budgets, or transcripts.

`.env` is gitignored. Never commit it.

---

## Demo and competition notes

- Bundled Tokyo journey covers flights, hotels, restaurants, activities, events, weather, routes, itinerary, budget, group, votes, and chat.
- Demo provenance is explicit. The UI must not claim live provider results for fixture data.
- Unresolved live providers fall back in place after a short watchdog.
- `GIA_FBLA_DEMO_MODE=1` forces demonstration booking confirmation.
- Debug fixtures exist for Plan, hotels, itinerary, budget, group, votes, and chat.

FBLA rating-sheet mapping and remaining gaps are in `Documentation/FBLA_EVIDENCE.md`. That file still describes some Phase 1 limits. Prefer this `APPLICATION.md` for what the app actually does now.

---

## How to run the current app

1. Install Xcode that supports the project’s Swift and iOS settings.
2. Open `GIA.xcodeproj`.
3. Select the `GIA` scheme and an iPhone Simulator or device.
4. For a physical iPhone, set the development team in Signing and Capabilities.
5. Start the gateway if you want live providers.
6. Build and run.

Without the gateway, Map, Earth, voice capture, typed conversation, and the judge demo still need to remain usable. Live flights, hotels, GPT planning, and ElevenLabs require the gateway and rotated keys.

---

## Verification

Command-line Swift programs live in `Verification/`. Gateway tests live in `Gateway/test/`.

Covered areas include the planning state machine, voice session rules, request interpretation, networking contracts, flight and hotel presentation, timeline, budget conflicts, group workspace, voting, communication, persistence, quality policy, and the judge demo.

Physical-device VoiceOver, thermal, and sustained Earth FPS sign-off are still pending. Live provider sign-off needs rotated keys that have never been pasted into chat or screenshots.

---

## Documentation map

| File | Use |
| --- | --- |
| `APPLICATION.md` | Current product, ownership, branch split |
| `README.md` | Original Phase 1 run instructions |
| `Documentation/ARCHITECTURE.md` | Layers, state ownership, renderer boundary |
| `Documentation/PLANNING.md` | Phase cards and deferred requirements |
| `Documentation/DECISIONS.md` | Why Map-first, SceneKit, no chatbot home |
| `Documentation/CONVERSATIONAL_PLAN_EDITS.md` | Voice timing and follow-up mutations |
| `Documentation/TESTING.md` | Device and interaction checks |
| `Documentation/ACCESSIBILITY.md` | Assistive behavior |
| `Documentation/FBLA_EVIDENCE.md` | Rating sheet evidence |
| `Gateway/README.md` | Gateway setup and security |
| `Documentation/PHASE_02_CARD_*.md` | Per-feature implementation evidence |

---

## Git workflow

Remote: `https://github.com/abhijandyala/GIA`

```text
main                    Abhi continues voice, functionality, and UI
  └── database-onboarding     accounts, onboarding, remote database, sync
```

Rules:

1. Abhi keeps pushing voice, UI, and planning-behavior work to `main`.
2. Database and onboarding work stays on `database-onboarding` until it can merge without breaking Map or Plan.
3. Rebase or merge `main` into `database-onboarding` often so persistence work tracks the current `Trip` shape.
4. Do not commit `.env`, `Gateway/node_modules`, Xcode user state, or DerivedData.
5. Do not put provider keys in the iOS target, Info.plist, or Swift source.

When database work is ready, open a pull request into `main` rather than force-pushing over frontend commits.

---

## Open work checklist

### Voice, UI, and functionality (`main`)

- [ ] Keep polishing wake, endpointing, typed chat, and spoken copy
- [ ] Restore or redesign the Group tab against the existing domain
- [ ] Physical-device speech, VoiceOver, and Earth performance sign-off
- [ ] Finish any remaining live-provider visual polish on Plan cards
- [ ] Keep conversation copy fully spoken: no dashes, no abbreviations

### Database and onboarding (`database-onboarding`)

- [ ] First-launch onboarding
- [ ] Authenticated user identity
- [ ] Attach SwiftData at app launch as an offline cache
- [ ] Remote trip store and member store
- [ ] Sync invitations, votes, and messages
- [ ] Replace the development gateway token with user sessions
- [ ] Define retention and deletion for traveler data

This is the working description of G.I.A. as of 8 September 2026.
