# G.I.A. Frameworks, Libraries, and Templates

## Application Frameworks

### SwiftUI

- Provider: Apple Inc.
- Type: operating-system framework
- Purpose: interface composition, state-driven presentation, accessibility, and
  application lifecycle integration
- External package: no

### SceneKit

- Provider: Apple Inc.
- Type: operating-system framework
- Purpose: native 3D Earth geometry, material, lighting, camera, and animation
- External package: no
- Isolation boundary:
  `GIA/Features/Map/Earth`

### Observation

- Provider: Apple Inc.
- Type: Swift/operating-system framework
- Purpose: observable application and Map state
- External package: no

### UIKit

- Provider: Apple Inc.
- Type: operating-system framework
- Purpose: host `SCNView` inside SwiftUI and load the local Earth texture
- External package: no

### AVFAudio

- Provider: Apple Inc.
- Type: operating-system framework
- Purpose: one live microphone engine for wake recognition, request capture,
  and voice-surface amplitude
- External package: no

### Speech

- Provider: Apple Inc.
- Type: operating-system framework
- Purpose: partial wake-phrase and full travel-request transcription
- External package: no

### Accelerate

- Provider: Apple Inc.
- Type: operating-system framework
- Purpose: efficient RMS microphone-level measurement with `vDSP`
- External package: no

### Foundation networking and CryptoKit

- Provider: Apple Inc.
- Type: operating-system frameworks
- Purpose: typed HTTP transport, JSON contracts, request cancellation,
  SHA-256 cache keys, dates, URLs, and protected local response caching
- External package: no

## System Resources

### SF Symbols

- Provider: Apple Inc.
- Purpose: Plan, Map, and Group navigation symbols
- Symbols currently requested:
  - `list.bullet`
  - `map`
  - `map.fill`
  - `person.2`
  - `person.2.fill`
- Distribution: system symbols referenced by name; symbol files are not bundled

### Apple system typography

- Provider: Apple Inc.
- Purpose: location, G.I.A. identity, and navigation labels
- Distribution: system fonts; font files are not bundled

## External Packages

None.

The iOS project currently contains no Swift Package Manager dependencies,
CocoaPods, Carthage frameworks, web views, or externally distributed binary
libraries. The gateway uses Node's standard library and currently has no npm
runtime dependencies.

## External Services

### OpenAI Responses API

- Provider: OpenAI
- Integration location: server gateway only
- SDK dependency: none; standards-based HTTPS through Node `fetch`
- Purpose: strict, grounded trip-plan blueprint generation
- Default model configuration: `gpt-5.4`
- Live status: adapter implemented; rotated-key verification pending

### SerpApi Google Flights, Hotels, Maps, and Events APIs

- Provider: SerpApi, LLC
- Integration location: server gateway only
- SDK dependency: none; standards-based HTTPS through Node `fetch`
- Purpose: flight search, comparison, price insight, baggage, emissions, and
  external booking continuation; hotel search, pricing, rating, amenities,
  imagery, and cancellation context; fallback place discovery; timed events,
  venues, and external ticket context
- Live status: adapter implemented; rotated-key verification pending

### Geoapify Places/Routing and SerpApi Google Maps APIs

- Providers: Geoapify GmbH and SerpApi, LLC
- Integration location: server gateway only
- SDK dependency: none; standards-based HTTPS through Node `fetch`
- Purpose: restaurants, cafés, museums, attractions, parks, entertainment,
  landmarks, shopping, nightlife, and sports discovery; supported
  transportation routing, geometry, instructions, duration, and distance
- Provider strategy: Geoapify primary; SerpApi fallback
- Live status: adapters implemented; rotated-key verification pending

### WeatherAPI.com

- Provider: WeatherAPI.com
- Integration location: server gateway only
- SDK dependency: none; standards-based HTTPS through Node `fetch`
- Purpose: hourly weather, forecast conditions, temperatures, precipitation,
  wind, and government alert aggregation
- Live status: adapter implemented; rotated-key verification pending

### Configurable translation provider

- Supported providers: Google Cloud Translation, DeepL, or HTTPS LibreTranslate
- Integration location: server gateway only
- SDK dependency: none; standards-based HTTPS through Node `fetch`
- Purpose: source-preserving translation of bounded travel text
- Live status: adapter implemented; provider selection pending

## Template and Sample References

### Earth-3D-PlanetModel-SwiftUI-SceneKit

- Repository:
  https://github.com/SMGLOBAL-ops/Earth-3D-PlanetModel-SwiftUI-SceneKit
- Revision inspected:
  `0c1442b3a97bfad6129c34d653e609245f5954ec`
- Role: educational reference for the general concept of a SwiftUI-hosted SceneKit
  planet
- Included as a package or submodule: no
- Source code copied into G.I.A.: no
- Assets copied into G.I.A.: no

G.I.A.'s scene graph, lifecycle controls, camera, lighting, rotation budget, layout,
and asset handling were implemented independently. The reference repository's README
states MIT, but its inspected tree does not contain a license file; therefore its code
was not imported.

## Verification Procedure

Before presentation or release:

1. Inspect Xcode's package-dependency list.
2. Confirm no unrecorded framework is embedded in the application target.
3. Confirm every external source and asset appears in `SOURCES.md`.
4. Update this document whenever a dependency or template is introduced.

