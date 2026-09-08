# G.I.A. Phase 1 Accessibility Record

## Accessibility Intent

G.I.A.'s cinematic presentation must remain operable without relying on animation,
transparency, color, or precise touch. Accessibility is part of the implementation,
not a presentation-only claim.

## Implemented Behavior

### VoiceOver

- The location context is announced as “Current location, Space.”
- The idle aperture is announced as “G.I.A., Idle.”
- The hamburger is announced as “Menu.”
- The hamburger reports expanded or collapsed state.
- While expanded, its hint explains that no options are currently available and that
  another activation closes it.
- The empty menu panel and dismissal surface do not create meaningless focus stops.
- The standard escape accessibility action dismisses an open menu.
- Plan, Map, and Group have explicit accessibility labels.
- The selected destination exposes both a selected trait and selected value.
- The decorative SceneKit Earth is hidden from the accessibility tree.
- Hidden Map content is removed from accessibility while Plan or Group is selected.

### Dynamic Type

- Location, G.I.A., and navigation labels use semantic SwiftUI text styles.
- Top-chrome height scales relative to the caption text style.
- The empty menu anchor follows the scaled top-chrome height.
- Bottom-navigation minimum height scales relative to the caption text style.
- G.I.A. remains geometrically centered independently of the leading and trailing
  controls.

### Reduce Motion

- Earth rotation stops.
- The idle aperture becomes static and removes its outward ripple.
- The SceneKit view does not render continuously.
- Menu and tab transitions use a shorter opacity transition.

### Reduce Transparency

- The empty dropdown becomes fully opaque.
- Bottom navigation becomes fully opaque.

### Increased Contrast

- Top labels and hamburger lines become fully opaque.
- Unselected navigation items receive stronger contrast.
- Menu and navigation separators become stronger and thicker where appropriate.

### Differentiate Without Color

- A selected navigation destination has a visible line indicator.
- Map and Group use filled selected symbols.
- VoiceOver exposes the selected trait and value.
- Selection therefore does not depend only on foreground color.

### Touch Targets

- Hamburger target: 44 by 44 points
- Navigation targets: at least 56 points high and equal-width across the screen
- Visible icon geometry remains restrained inside the larger interaction area

## Permission and Privacy Surface

Phase 1 requests no access to:

- Location
- Microphone
- Camera
- Photos
- Contacts
- Calendars
- Motion data
- Bluetooth
- Tracking

No permission usage-description keys should exist in the generated application
property list during Phase 1.

## Verification Status

Source-level accessibility behavior is implemented. The following items require a
physical iPhone or iOS Simulator with Xcode and must not be marked complete until
manually tested:

- VoiceOver focus order
- Two-finger scrub menu dismissal
- All supported Dynamic Type sizes
- Increased Contrast
- Reduce Transparency
- Reduce Motion
- Compact and large portrait iPhone layouts
- Hardware rendering and thermal behavior

Manual results belong in `TESTING.md`.

