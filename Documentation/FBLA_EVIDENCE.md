# G.I.A. FBLA Evidence Map

## Purpose

This record maps the current Phase 1 implementation to the 2026–2027 Mobile
Application Development rating sheet. It distinguishes demonstrated evidence from
future work so the presentation does not overstate the application.

## Design and Code Quality

### Planning process

Current evidence:

- `PHASE_01_SCOPE.md`
- `PLANNING.md`
- `DECISIONS.md`
- `ARCHITECTURE.md`
- `TESTING.md`
- `PERFORMANCE.md`
- `ACCESSIBILITY.md`

Presentation point:

The first implementation was constrained as a vertical slice. Scope, user journey,
state transitions, architecture, performance budgets, accessibility behavior, and
copyright intake were documented before or alongside implementation.

### Classes, modules, and components

Current evidence:

- `AppState` centralizes destination, overlay, and lifecycle invariants.
- `MapViewModel` owns Map presentation state.
- `EarthSceneController` owns SceneKit scene construction and animation.
- `EarthSceneView` isolates the native 3D renderer from SwiftUI features.
- `MapStage` owns the portrait-iPhone spatial coordinate system.
- Top chrome, menu, and navigation are reusable components.
- Plan, Map, and Group remain separate feature boundaries.

Presentation point:

Components are divided by responsibility rather than placing the application in one
content view.

### Mobile architectural pattern

Current evidence:

- Feature-oriented MVVM
- Observable application and feature state
- Rendering implementation isolated behind a view boundary
- State-driven SwiftUI navigation and presentation

Presentation point:

Views render state, application state enforces cross-feature rules, and the Map
view model owns Map-specific presentation state.

### Innovation and creativity

Current evidence:

- World-first Map home
- Earth as the primary visual anchor
- G.I.A. represented as a persistent identity rather than a chat transcript
- Plan / Map / Group mental model
- Deliberate rejection of a dashboard, booking funnel, and chatbot home

Limitation:

The full G.I.A. assistant journey is outside Phase 1 and must be implemented before
the complete innovation claim can be demonstrated.

## User Experience

### User journey and rationale

Current evidence:

- Phase 1 journey in `PLANNING.md`
- Exact screen composition in `PHASE_01_SCOPE.md`
- State transitions in `ARCHITECTURE.md`
- Design alternatives and decisions in `DECISIONS.md`

### Accessibility

Current evidence:

- VoiceOver semantics
- Dynamic Type-aware layout
- Reduce Motion
- Reduce Transparency
- Increased Contrast
- Non-color selected states
- Native touch-target sizing
- No unnecessary permission prompts

Evidence record:

- `ACCESSIBILITY.md`

Limitation:

Physical assistive-technology testing is pending until the project is run with Xcode
on an iOS Simulator or iPhone.

### Intuitive interface

Current evidence:

- Three persistent, labeled destinations
- Map selected by default
- Standard hamburger affordance
- Visible selected state
- Menu closes through expected interactions

### Icons and graphical elements

Current evidence:

- Consistent Apple SF Symbols for primary navigation
- NASA Blue Marble Earth integrated into the application's main graphic
- One restrained monochrome icon language

Limitation:

The current application icon is assigned and compiles, but its authorship and final
design status have not yet been documented. The current `GIA` wordmark is
intentionally temporary.

### Input validation

Status: not applicable to the current slice.

Phase 1 collects no user input. Later forms and natural-language inputs must
demonstrate syntactic and semantic validation to earn this rating-sheet category.

## Application Functionality

### Addresses all parts of the topic

Status: incomplete by design.

Phase 1 establishes only the application shell and world-first home. Before final
competition presentation, the application still needs demonstrable:

- Collaboration
- Communication
- Scheduling
- Budgeting
- Organization
- Trip management
- Multiple-user behavior

The current slice must be presented as foundation evidence, not as the complete
solution.

### Social-media integration

Status: not implemented.

No social-feed placeholder or false integration is included. A later implementation
must directly integrate an appropriate system or social sharing workflow if this
rating-sheet category is to be earned.

## Data Handling and Storage

Status: not implemented because Phase 1 has no user or trip data.

Current privacy evidence:

- No networking
- No authentication
- No database
- No tracking
- No permission usage-description keys
- Local read-only Earth texture only

Later data architecture must address integrity, access control, privacy, secure
storage, and deletion before claiming this category.

## Documentation and Copyright

Current evidence:

- `SOURCES.md`
- `LIBRARIES.md`
- `THIRD_PARTY_NOTICES.md`
- NASA asset URL, dimensions, checksum, credit, and media-guideline record
- SceneKit reference repository, inspected revision, and non-copy status
- Apple framework, typography, and symbol usage record

Presentation point:

The source-intake rule requires known authorship, an original source, verified
distribution permission, recorded attribution, and an explanation of what the team
created independently.

## Standalone and Error-Free Requirement

Current evidence:

- All assets are local.
- Application Swift source contains no networking or web-view implementation.
- Available source subsets pass type checking.
- The complete source set passes parsing.
- The complete source set compiles in iOS Simulator Debug configuration.
- The complete source set compiles in unsigned generic-iPhone Release configuration.
- The asset catalog compiles without unassigned-child warnings.
- The Xcode project file is syntactically valid.
- IDE diagnostics report no current errors.

Limitation:

The application has not yet been launched and exercised in an iOS Simulator or on a
physical iPhone. It must not be called runtime-verified until the checklist in
`PERFORMANCE.md` and `TESTING.md` is completed.

## Presentation Protocol Evidence

Prepare separately before competition:

- Device-count plan
- Fully charged iPhone and backup device
- Offline demonstration path
- Seven-minute presentation timing
- Three-minute setup checklist with no judge interaction
- Adapter plan if advancing to a final room with projector
- No external speaker
- No judge interaction with links or QR codes
- No materials left with judges

The current application does not depend on a link, QR code, external speaker, or
conference internet.

## Open Evidence Gaps

- Simulator screenshots
- Physical-iPhone screenshots
- Seven-minute thermal test
- Instruments performance measurements
- VoiceOver and accessibility-setting test results
- Application-icon authorship record and final-design confirmation
- Git history or another accepted version-history record
- Written record of any required authorization or disclosure for external tools
- Complete trip-planning functionality required by the topic

