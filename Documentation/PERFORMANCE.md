# G.I.A. Performance Verification

## Status

**Simulator verified — physical-device sign-off pending**

Static controls, compact/large simulator runs, and a five-second Time Profiler
recording were completed through Card 30. Phase 7 also completed a seven-minute
active-Map simulator soak without app error logs. Physical-device sustained
FPS, memory, thermal, VoiceOver, and microphone checks remain pending.

## Rendering budget

- Preferred active Earth frame rate: 60 FPS
- Earth sphere segment count: 128
- Idle rotation: 190 seconds per revolution
- Earth texture: `earth-4096.jpg`, 4096 × 2048
- Antialiasing: four-sample multisampling
- Continuous rendering: active Map only
- Inactive rendering: stopped

The active Map requests 60 FPS because the SceneKit surface also drives the
voice-reactive transformation. Continuous rendering stops on Plan, Group,
background, and Reduce Motion. Hidden SwiftUI voice ripples are disabled.

## Runtime controls

- `SCNAction` owns idle rotation.
- `SCNView.rendersContinuously` and `isPlaying` share one active-state gate.
- Earth rotation pauses instead of being recreated.
- Map remains mounted to prevent scene/node duplication.
- Active voice Canvas runs only while Map is visible.
- Planning indicator stops outside active planning phases.
- Reduce Motion disables continuous visual work.
- Generated speech audio cache is purged on memory warning.
- Hidden SceneKit audio/actions are released on memory warning.
- Provider, notification, calendar, and audio work use async APIs.
- Large Plan containers use lazy stacks.

## Static verification

- [x] Full iOS Debug target builds.
- [x] IDE diagnostics contain no changed-file errors.
- [x] Project property-list syntax is valid.
- [x] iPhone-only target and portrait orientation remain configured.
- [x] Required microphone, speech, and calendar descriptions exist.
- [x] No tracking usage description exists.
- [x] Earth and active voice rendering have explicit visibility gates.
- [x] Minimum custom interaction target policy is 44 points.
- [x] Memory-pressure cleanup preserves durable trip data.

## Simulator matrix

### iPhone SE-class simulator

- Runtime: iOS 26.3.1
- Text: Accessibility Extra Extra Extra Large
- Increased Contrast: enabled
- Journey: offline Lisbon request
- Decorative Plan heading remained bounded after the Phase 7 fix.
- Request content remained fully enlarged and vertically scrollable.
- Planning rail remained horizontally scrollable.
- Persistent navigation stayed usable.
- No empty itinerary appeared without sourced results.

### iPhone 17 Pro Max

- Runtime: iOS 26.3.1
- Text: Accessibility Extra Extra Extra Large
- Increased Contrast: enabled
- Journey: offline Vancouver request
- Decorative header remained compact.
- Essential request/status content enlarged and scrolled.
- Persistent navigation remained bounded.

Simulator accessibility settings were restored after verification.

## Time Profiler record

- Template: Time Profiler
- Target: GIA on iPhone SE simulator
- Duration: 5.64 seconds
- Hang reporting threshold: 250 ms
- Potential hangs: 0
- End reason: time limit reached
- Process result: normal

The Animation Hitches instrument reports that hitch capture is unsupported on
the iOS Simulator. It must be run on a physical device.

## Phase 7 sustained simulator run

- Device: iPhone 17 Pro Max simulator
- Surface: active Map with normal motion
- Duration: 7 minutes
- G.I.A. error-level log entries: 0
- Final state: process alive and Map responsive

This proves simulator stability only. It does not prove device temperature,
battery use, GPU frame pacing, or thermal throttling.

## Remaining physical-device checks

- [ ] Verify all SF Symbols on minimum iOS 17.
- [ ] Record active Map and assistant-animation FPS.
- [ ] Confirm zero SceneKit continuous frames on Plan and Group.
- [ ] Inspect memory after launch and 20 tab switches.
- [ ] Run Map for seven minutes.
- [ ] Record thermal state before and after.
- [ ] Test Low Power Mode.
- [ ] Test lock/unlock and repeated background/foreground.
- [ ] Navigate all screens with VoiceOver.
- [ ] Exercise real microphone interruption and denial.
- [ ] Run Animation Hitches, Game Memory, and Leaks.

## Runtime measurement record

- Xcode: 26.3
- Simulator devices: iPhone SE (3rd generation), iPhone 17 Pro Max
- Simulator OS: iOS 26.3.1
- Configuration: Debug
- Fixtures: offline Lisbon/Vancouver and manual Tokyo demo
- Time Profiler: 5.64 seconds
- 250 ms+ potential hangs: 0
- Plan rendering: Earth and hidden voice Canvas paused by policy
- Group rendering: Earth and hidden voice Canvas paused by policy
- Offline path: exact request preserved with visible provider fallback
- Corrected defects:
  - Hidden 60 Hz voice Canvas behind Plan
  - Oversized accessibility navigation chrome
  - Two-column accessibility request/integration layouts
  - Sub-44-point custom controls
  - Unbounded motion in timeline/comparison/chat transitions
  - Missing memory-warning cleanup
  - Judge Debug permission startup race
  - Unbounded decorative Plan heading at accessibility size 5

## Completion gate

Card 30 source and simulator verification are complete. Physical-device
measurements remain required before claiming final 60 FPS, thermal, leak, and
VoiceOver sign-off.
