# G.I.A. Phase 1 — Home Foundation

## Purpose

This phase establishes the first native iPhone slice of G.I.A., an AI-powered group
travel assistant for the 2026–2027 FBLA Mobile Application Development event.

The product is not a chatbot-first travel application. The default experience is a
world-first Map screen in which Earth is the main visual anchor and G.I.A. is a
restrained presence in the interface.

This document is the scope contract for Phase 1. Work outside this boundary belongs
to a later phase.

## Platform Baseline

- Platform: Apple iPhone
- Language: Swift
- Interface framework: SwiftUI
- Earth renderer: SceneKit
- Architecture: feature-oriented MVVM
- Minimum operating system: iOS 17
- Supported device family: iPhone
- Supported orientation: portrait
- Appearance: dark
- Distribution goal: App Store-quality native application
- Competition requirement: smartphone deployable
- Network dependency: none

The application does not target macOS, Mac Catalyst, desktop browsers, or desktop
window sizes. Layout verification is limited to supported portrait iPhone displays.

## Included Experience

### Map/Home

- Map is selected on a clean launch.
- A near-black, full-screen canvas creates the appearance of restrained outer space.
- `SPACE` appears at the top-left as the current location context.
- `GIA` appears inside a restrained idle aperture fixed over the center of Earth.
- A lightweight three-line hamburger button appears at the top-right.
- The hamburger opens a visually detectable but content-free anchored dropdown.
- A slowly rotating, monochrome SceneKit Earth appears near the visual center.
- The upper area retains substantial negative space.

### Bottom Navigation

- Three destinations are available: Plan, Map, and Group.
- Map is selected by default and receives restrained visual emphasis.
- Plan and Group are functional navigation destinations with blank content canvases.
- The bottom navigation remains available on all three destinations.

### Interaction

- The menu can be opened and closed.
- Tapping outside an open menu dismisses it.
- Selecting another tab dismisses the menu.
- Earth rendering pauses when Map is not active or the app is backgrounded.
- Returning to Map resumes the existing Earth scene without resetting it.

## Explicitly Excluded

Phase 1 does not include:

- A chat interface or text composer
- Voice activation, microphone access, or speech recognition
- G.I.A. activation or listening animation
- Real device location or Core Location permission
- User accounts or authentication
- Networking, remote APIs, or cloud services
- AI model integrations
- Flight, hotel, activity, or booking integrations
- Trip creation or itinerary generation
- Travel groups, group chat, voting, or collaboration data
- Calendar integrations or schedule constraints
- Budgets, payments, or financial data
- Persistence or a database
- Social-media integration
- Menu options or settings content
- Moon simulation, orbital controls, free globe rotation, or map gestures
- iPad-specific, macOS, Mac Catalyst, web, or desktop layouts

## Visual Constraints

- Earth must sit near the screen's visual center without colliding with the top chrome
  or bottom navigation.
- The top portion of the screen must remain visually open.
- The interface must not resemble ChatGPT, a dashboard, or a travel website.
- No floating prompt box, large AI button, excessive gradient, decorative sparkle,
  emoji, or card grid is permitted.
- The G.I.A. aperture must be geometrically centered independently of the widths of
  `SPACE` and the hamburger.
- The custom bottom navigation must feel integrated with the screen and must not be
  an oversized floating pill.
- Plan and Group must remain intentionally blank during this phase.

## Accessibility Baseline

- Every interactive control has a minimum 44-by-44-point hit target.
- Navigation items expose labels and selected state to VoiceOver.
- The hamburger exposes its label and expanded/collapsed state.
- Selection is not communicated by color alone.
- Reduce Motion stops continuous Earth rotation and simplifies menu transitions.
- Text remains usable with larger accessibility text settings.
- Decorative 3D content does not create meaningless VoiceOver elements.

## Reliability Baseline

- Every Phase 1 asset is bundled in the application.
- The application works in airplane mode.
- No continuous SwiftUI timer drives the Earth rotation.
- SceneKit work pauses while Map is not visible.
- The release build contains no debug controls or placeholder error messages.
- The application runs without crashes, missing assets, or programming errors.

## FBLA Alignment

Phase 1 is an architectural and visual foundation. It demonstrates:

- Native mobile development
- Deliberate planning
- Appropriate component boundaries
- Use of a mobile architectural pattern
- Original user-experience direction
- Accessibility planning
- Standalone operation
- Source and copyright documentation

Phase 1 alone does not fully address the competition topic. Later phases must add
collaboration, communication, scheduling, budgeting, organization, and trip
management for multiple users before the application is represented as complete.

Only registered competitors should make competition decisions and submit project
work. Any authorized use of external tools, source material, or AI assistance should
be retained with the team's competition records and disclosed as required by FBLA.

## Phase 1 Definition of Done

Phase 1 is complete when all of the following are true:

- [ ] The application launches directly into Map.
- [ ] `SPACE`, the G.I.A. aperture, and the hamburger are correctly positioned.
- [ ] The hamburger opens and dismisses an empty anchored dropdown.
- [ ] The Earth is dimensional, centered, monochrome, slowly rotating, and fully
  offline.
- [ ] Plan, Map, and Group navigation works.
- [ ] Plan and Group remain blank.
- [ ] Earth rendering follows tab and application lifecycle state.
- [ ] VoiceOver and Reduce Motion behavior is verified.
- [ ] Supported portrait iPhone sizes are verified.
- [ ] Source, asset, and license records are complete.
- [ ] A release build runs without programming errors.

