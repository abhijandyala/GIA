# Phase 7 — Cards 15 and 16

## Card 15: Offline and service fallback

Normal requests and the bundled demo now have a strict boundary:

- Connectivity is observed with `NWPathMonitor`.
- A known offline path skips network work immediately.
- The exact typed or spoken request remains in memory.
- Plan labels the state `OFFLINE` and exposes Retry and New Request.
- Partial provider failures preserve successful provider results.
- Missing gateway configuration is distinct from known offline connectivity.
- Speech-generation or playback failure preserves visible response text.
- Navigation to Plan does not wait for ElevenLabs audio.
- Microphone denial offers Settings and the always-available Type action.

The obsolete automatic demo watchdog, timeout activation reason, and restored
demo state were removed. `JudgeDemoTripFactory` is reachable only from the
explicit Offline Demo menu action or the debug flag that exercises that same
manual action. Normal planning cannot replace Chicago, Lisbon, Vancouver,
Reykjavík, or another destination with Tokyo.

## Card 16: End-to-end QA

### Automated checks passed

- Five-destination request matrix: Chicago, Tokyo, Lisbon, Vancouver, and
  Reykjavík.
- Repeated in-memory request replacement with no stale request restoration.
- Deterministic correction and clarification verification.
- Visible G.I.A. response fallback when response or audio providers fail.
- Manual-only demo identity, completeness, activation, and reset.
- Gateway syntax plus all 88 provider/security tests.
- Debug and Release iOS simulator builds.
- IDE diagnostics report no errors in changed files.
- Source scan found only deliberate fake gateway tokens in test fixtures.

### Simulator scenarios passed

- Known offline planning preserves a Vancouver request and shows no result
  cards or itinerary shells.
- Unreachable gateway shows progressive queued work without fabricated counts.
- Disabled ElevenLabs keeps the Reykjavík response visible and opens Plan.
- Denied microphone access shows Settings and Type without blocking Map.
- iPhone SE at accessibility text size 5 and Increase Contrast remains
  scrollable after bounding the decorative Plan heading.
- iPhone 17 Pro Max at accessibility text size 5 and Increase Contrast remains
  scrollable.
- With Reduce Motion enabled, two Map captures three seconds apart showed no
  Earth rotation or continuous voice animation.
- A seven-minute active-Map simulator soak completed with no G.I.A. error-level
  log entries; the app remained alive and visually responsive afterward.

### Physical-device evidence still required

The simulator cannot truthfully prove:

- Ten consecutive acoustic “Hey GIA” wake detections.
- Five actual microphone requests in realistic room noise.
- VoiceOver swipe order and spoken pronunciation quality.
- Audio-session interruption from calls, alarms, Bluetooth, or route changes.
- Seven-minute device thermal behavior and battery impact.
- ElevenLabs voice quality through device speakers.
- End-to-end live provider behavior with deployed gateway credentials.

These remain a physical-iPhone acceptance checklist, not assumed passes.

## Competition run order

1. Relaunch and confirm clean Map.
2. Deny microphone once; confirm Settings and Type remain available.
3. Type five different destinations and use New Request between each.
4. Test five spoken destinations.
5. Perform ten wake detections without tapping the activation button.
6. Interrupt listening once and speech playback once.
7. Disable network and confirm the current destination remains visible.
8. Start Offline Demo manually and verify every Demo label.
9. Reset Demo and confirm the clean Map returns.
10. Run VoiceOver, Reduce Motion, and a seven-minute device soak.
