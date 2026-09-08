# Phase 2 — Card 30: Accessibility and Performance

## Status

Source and simulator verification complete. Physical-device VoiceOver,
microphone, thermal, and sustained 60 FPS evidence remain final acceptance
checks because the simulator cannot represent those accurately.

## Objective

Keep the complete Map, Plan, and Group experience understandable without
animation, operable without precision gestures, readable at accessibility text
sizes, and inactive when hidden.

## Accessibility quality policy

`GIAQualityPolicy` centralizes:

- 44-point minimum interactive target
- Continuous-animation visibility gate
- Reduce Motion rendering gate
- Earth rendering gate
- Compact/accessibility vertical-layout decision

## VoiceOver

Implemented semantics include:

- Named Map, Plan, and Group tabs with selected state
- Manual G.I.A. activation and return labels
- Menu state and presentation-control hints
- Assistant status/transcript output
- Plan phase heading
- Flight and hotel summaries
- Timeline chronological summaries
- Equivalent 15-minute timeline move actions
- Booking truth disclosures
- Group roles, availability, budget, and privacy
- Decision rule/state/tally/actions
- Chat author/context/reaction/read controls
- Offline storage open/delete actions
- Notification and calendar actions

Generated G.I.A. text is hidden from VoiceOver only while the same content is
actively spoken, preventing duplicate output. Visible fallback text remains
accessible when audio fails.

## Dynamic Type

Card 30 changes:

- Request metrics become one column at accessibility sizes.
- Trip Alert and Calendar cards become a vertical stack.
- Persistent bottom navigation caps only its chrome typography and height so it
  cannot obscure most of the screen.
- Essential tab content continues to use accessibility sizes and scrolls.
- Group title/count chrome uses stable compact typography instead of breaking
  into oversized decorative headings.
- Existing expandable flight, hotel, timeline, booking, member, proposal, and
  chat surfaces grow vertically.

## Touch targets

Interactive targets were raised to at least 44 points for:

- Offline Save, Manage, Open, and Delete
- Trip Alert and Calendar actions
- Group decision proposal, vote, and revision
- Chat share, open, context, mention, and send controls
- Chat reaction controls
- Flight/hotel comparison controls
- Map presentation menu actions
- Manual G.I.A. activation

Timeline drag retains named VoiceOver move actions, so dragging is never the
only editing method.

## Reduce Motion

Continuous and transition behavior now respects Reduce Motion:

- Earth continuous rendering stops.
- Active voice TimelineView stops.
- G.I.A. planning indicator uses a static state.
- Map/Plan handoff uses the existing crossfade.
- Tab switching uses a short fade.
- Timeline day selection, expand/collapse, and drag reset become immediate.
- Flight/hotel focus and detail expansion become immediate.
- Chat auto-scroll becomes immediate.
- Demo reset uses an immediate transition.

## Reduce Transparency and Increased Contrast

- Plan surfaces become fully opaque with no translucent highlight gradient.
- Navigation and Map menu become opaque.
- Borders become thicker and brighter.
- Unselected navigation content becomes brighter.
- Voice-disc outline strength increases.
- Meaning remains paired with text and symbols rather than color.

## Permission denial

- Manual and visual G.I.A. functionality remains available without microphone
  permission.
- Microphone denial now stops before requesting speech-recognition permission.
- Judge-safe Debug startup bypasses wake-listening permission requests.
- ElevenLabs failure retains visible text.
- Notification and calendar denial leaves trip planning usable.
- Map displays a persistent voice-access banner with a Settings action.
- Plan displays a usable unavailable/failure state instead of a blank canvas.
- Notification/calendar denial displays persistent Settings guidance.

## Rendering lifecycle

`EarthSceneView`:

- Runs continuously only while Map is active and Reduce Motion is off.
- Sets SceneKit `isPlaying` and `rendersContinuously` together.
- Pauses idle rotation when inactive.
- Clears the scene on dismantle.

Hidden Map assistant ripples now receive `isAnimationActive = false`, preventing
the 60 FPS SwiftUI TimelineView from running behind Plan or Group.

When the application backgrounds, Map cancels activation, speech wrapper, and
demo-watchdog tasks. The demo watchdog intentionally remains alive only during
an active in-app Map-to-Plan tab handoff.

Low Power Mode lowers active Earth rendering from 60 FPS to 30 FPS and restores
the configured rate when power state changes.

## Memory pressure

On memory warning:

- In-memory generated speech audio is purged.
- SceneKit audio players are removed.
- Hidden Earth voice actions stop.
- Hidden rotation remains paused.
- Durable trip storage and user data remain intact.
- Gateway memory cache is capped at 64 unexpired entries.

## Main-thread work

- Provider calls, speech generation, notification scheduling, and permission
  requests use async APIs.
- Microphone-level publication is coalesced to at most 30 MainActor updates per
  second while recognition still receives every audio buffer.
- Persistence saves are debounced.
- Large Plan and Group stacks use lazy containers.
- Images use AsyncImage.
- Earth deformation stays in SceneKit shader modifiers.

## Simulator matrix

### iPhone SE (3rd generation), iOS 26.3.1

- Standard Large text
- Judge-safe Tokyo Plan
- Compact request metrics
- Horizontal planning rail remains scrollable
- Bottom navigation remains visible and usable
- No first-launch permission dependency in judge-safe startup

### iPhone 17 Pro Max, iOS 26.3.1

- Accessibility Extra Extra Extra Large
- Increased Contrast
- Group workspace
- Header chrome remains compact
- Essential status cards enlarge and scroll
- Trip Assistance switches to vertical cards
- Bottom navigation remains bounded

Simulator settings were restored after verification.

## Runtime profiling

A five-second Time Profiler recording was captured while the complete
judge-safe Plan was idle on iPhone SE.

- Duration: 5.64 seconds
- Potential-hang threshold: 250 ms
- Potential hangs reported: 0
- Process exited normally

The Animation Hitches instrument reports that hitch recording is unsupported on
the iOS Simulator. Final 60 FPS and thermal evidence therefore requires a
physical-device Game Performance or Animation Hitches trace.

## Automated verification

`QualityPolicyVerificationMain.swift` checks:

- 44-point minimum target
- Visible animation allowed
- Hidden animation denied
- Reduce Motion animation denied
- Map-active Earth rendering
- Hidden/Reduce Motion Earth pause
- Accessibility/compact vertical-layout policy

The full app target and all changed files build without diagnostics.

## Remaining physical-device sign-off

- Navigate all screens with VoiceOver
- Record sustained Map and activation FPS
- Run seven-minute thermal observation
- Test real microphone/speech denial and interruption
- Confirm EventKit and notification permission copy
- Run Leaks/Game Memory after repeated tab switching

## FBLA evidence

This card demonstrates accessibility semantics, equivalent non-gesture actions,
Dynamic Type, motion/transparency/contrast adaptations, lifecycle-aware 3D
rendering, memory-pressure handling, async work boundaries, compact/large device
testing, and evidence-based performance profiling.
