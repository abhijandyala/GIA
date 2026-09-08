# G.I.A.

G.I.A. is a native iPhone group-travel assistant being developed for the 2026–2027
FBLA Mobile Application Development topic, **Together We Go: Group Trip Planner**.

G.I.A. is designed as another member of the trip group rather than a generic booking
application with a chatbot attached. Its default experience begins with Earth, not a
chat transcript or search form.

## Current Phase

The current implementation is the Phase 1 home foundation:

- Map is the default destination.
- A high-contrast monochrome SceneKit Earth rotates at the screen's visual center.
- `SPACE` identifies the current world-level context.
- `GIA` is represented by a quiet, screen-fixed breathing aperture over Earth.
- A minimal hamburger opens an intentionally empty dropdown.
- Custom Plan, Map, and Group navigation is functional.
- Plan and Group are intentionally blank.
- The entire experience operates offline.

This phase does not yet implement group collaboration, scheduling, budgeting,
communication, persistence, authentication, speech, AI, or travel APIs. It must not
be represented as the completed competition application.

## Platform

- Swift
- SwiftUI
- SceneKit
- iOS 17 or newer
- iPhone only
- Portrait orientation
- Dark appearance
- No Mac Catalyst or desktop target

No external Swift packages or binary frameworks are currently used.

## Open and Run

1. Install a complete version of Xcode that supports the project's Swift and iOS
   deployment settings.
2. Open `GIA.xcodeproj`.
3. Select the `GIA` scheme.
4. Select an iPhone Simulator or connected iPhone.
5. For a physical iPhone, select the appropriate development team in Signing &
   Capabilities.
6. Build and run.

The Earth texture is included in the asset catalog, so the Phase 1 interface does not
require internet access.

## Architecture

The application uses feature-oriented MVVM:

- `App` owns global destination, menu, and lifecycle state.
- `Core` contains small models and visual-system definitions.
- `Features` separates Map, Plan, and Group.
- `Components` contains reusable layout, chrome, menu, and navigation views.
- The SceneKit renderer is isolated under the Map feature.

Detailed architecture and state diagrams are in
`Documentation/ARCHITECTURE.md`.

## Accessibility

Phase 1 includes:

- VoiceOver labels and selected states
- Minimum native touch-target sizes
- Dynamic Type-aware chrome and navigation
- Reduce Motion behavior
- Reduce Transparency behavior
- Increased Contrast behavior
- Navigation selection that does not depend only on color

Implementation and pending device checks are recorded in
`Documentation/ACCESSIBILITY.md`.

## Performance

The Earth uses:

- A 30 FPS rendering budget
- A 128-segment sphere
- A 2048-by-1024 bundled texture
- A 190-second idle rotation
- Rendering suspension off Map and while the app is inactive

Static checks, an iOS Simulator Debug build, and an unsigned generic-iPhone Release
build have passed with Xcode 26.3. Launched Simulator, Instruments, and
physical-device results remain pending. See `Documentation/PERFORMANCE.md`.

## Sources and Copyright

- Source and asset details: `Documentation/SOURCES.md`
- Third-party notices: `Documentation/THIRD_PARTY_NOTICES.md`
- Architecture decisions: `Documentation/DECISIONS.md`
- Scope contract: `Documentation/PHASE_01_SCOPE.md`
- Test plan: `Documentation/TESTING.md`

The bundled Earth texture is NASA Blue Marble imagery. NASA is acknowledged as the
source, and G.I.A. does not imply NASA endorsement.

## Current Release Blockers

Before this phase can be called runtime-verified:

- Run the documented Simulator and physical-iPhone checks.
- Capture performance and thermal measurements.
- Confirm and document the authorship of the current App Store icon.
- Resolve any warnings discovered by a complete iOS build.

Before G.I.A. can be called competition-complete, later work must directly demonstrate
collaboration, communication, scheduling, budgeting, organization, and shared trip
management for multiple users.

