# G.I.A. Sources and Copyright Record

This file tracks external material considered or used by G.I.A. It must be updated
when an external asset, library, article, sample, or code fragment enters the project.

## Competition Guidelines

### FBLA Mobile Application Development Guidelines

- Organization: Future Business Leaders of America
- Competition year: 2026–2027
- Topic: Together We Go: Group Trip Planner
- Document revision reviewed: August 2026
- Purpose: competition requirements, rating sheet, and presentation constraints
- Copyright owner: National Future Business Leaders of America, Inc.
- Project usage: requirements reference only; the guideline document is not bundled
  with the application

### FBLA Honor Code

- Organization: Future Business Leaders of America
- URL: https://www.fbla.org/honor-code/
- Purpose: originality, independence, citation, and competition-integrity requirements
- Project usage: compliance reference only

## SceneKit Earth Reference

### Earth-3D-PlanetModel-SwiftUI-SceneKit

- Author/organization: SMGLOBAL-ops
- Repository:
  https://github.com/SMGLOBAL-ops/Earth-3D-PlanetModel-SwiftUI-SceneKit
- Revision inspected: `0c1442b3a97bfad6129c34d653e609245f5954ec`
- Files inspected:
  - `PlanetScene.swift`
  - `PlanetView.swift`
  - `AnimationTicker.swift`
  - `README.md`
- Intended role: technical and visual reference for hosting a SceneKit planet inside
  SwiftUI
- Concepts considered:
  - `SCNScene`
  - `SCNSphere`
  - Texture-backed planet material
  - Scene camera and lighting
  - Continuous planet rotation
- Code-copy status: not approved
- Asset-copy status: not approved

The repository README states that the project is MIT licensed, but the inspected
repository tree does not contain a `LICENSE` file. Until the full license text and
asset provenance are verified, G.I.A. must independently implement the required
SceneKit behavior rather than copy repository source code.

The repository does not contain the texture assets referenced by its source code.
Those asset names do not establish ownership or permission. G.I.A. must not copy or
redistribute them without a separate verified source and license.

## Apple Frameworks

### SwiftUI

- Owner: Apple Inc.
- Documentation: https://developer.apple.com/documentation/swiftui
- Purpose: native application interface and state-driven presentation
- Distribution: operating-system framework; not bundled as a third-party library

### SceneKit

- Owner: Apple Inc.
- Documentation: https://developer.apple.com/documentation/scenekit
- Purpose: native 3D Earth rendering
- Distribution: operating-system framework; not bundled as a third-party library

## Earth Texture

### Blue Marble — Seamless Image Mosaic of Earth

- Status: Selected and bundled
- Source organization: NASA/Goddard Space Flight Center Scientific Visualization
  Studio
- Visualization: https://svs.gsfc.nasa.gov/2915/
- Direct asset:
  https://svs.gsfc.nasa.gov/vis/a000000/a002900/a002915/bluemarble-2048.png
- Original filename: `bluemarble-2048.png`
- Project asset name: `EarthTexture`
- Dimensions: 2048 by 1024 pixels
- Download date: September 5, 2026
- SHA-256:
  `ae6214b078ed0864c96f74bcb10ae3021f6eb116f8059797efe0fa9ea8b89d35`
- Source-file modification: none
- Runtime presentation: SceneKit renders the texture at zero saturation with
  increased contrast; the bundled NASA image remains unchanged
- Credit requested by source: NASA/Goddard Space Flight Center Scientific
  Visualization Studio; Blue Marble Next Generation data courtesy of Reto Stockli
  (NASA/GSFC) and NASA Earth Observatory
- NASA media guidelines:
  https://www.nasa.gov/nasa-brand-center/images-and-media/
- Usage basis: NASA-produced media and 3D texture-map material are generally not
  subject to copyright in the United States and may be used consistently with NASA's
  media guidelines. NASA must be acknowledged, protected NASA identifiers must not
  be used, and the application must not imply NASA endorsement.
- Bundled location:
  `GIA/Resources/Assets.xcassets/EarthTexture.imageset/bluemarble-2048.png`

The selected image contains no NASA logo or identifiable person. G.I.A. uses it as a
factual visualization of Earth and does not state or imply NASA endorsement.

## Icons and Typography

### Current application icon

- Project file: `GIA/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- Dimensions: 1024 by 1024 pixels
- Alpha channel: none
- SHA-256:
  `3d7a4b83970273202e315e2f07db08dd92a2c64ce96430218d12a8eec82d7b6e`
- Asset-catalog status: assigned to the universal iOS AppIcon slot
- Creator and creation process: not yet recorded
- Copyright/license status: not yet recorded

The icon now compiles correctly, but its authorship and creation process must be
documented before FBLA submission or App Store distribution.

### SF Symbols

- Owner: Apple Inc.
- Purpose: native navigation icons where appropriate
- Usage constraint: use only within Apple-platform applications and follow Apple's
  SF Symbols license terms

### System Typography

- Owner: Apple Inc.
- Purpose: interface typography
- Project usage: system-provided fonts; no font files redistributed

## AI Service Documentation

### OpenAI Responses API

- Provider: OpenAI
- Status: server adapter implemented; live credential verification pending
- API documentation:
  https://developers.openai.com/api/docs/guides/migrate-to-responses
- Structured Outputs documentation:
  https://developers.openai.com/api/docs/guides/structured-outputs
- Model documentation:
  https://developers.openai.com/api/docs/models/gpt-5.4
- Purpose: create a grounded itinerary blueprint from validated requests and
  previously sourced travel options
- Data boundary: raw provider credentials, booking URLs, and the original spoken
  transcript are not included in model context
- Output boundary: strict JSON schema followed by server and iOS source-ID,
  schedule, and trip-range validation
- Storage request: Responses requests set `store` to `false`
- Distribution: no OpenAI SDK or model is bundled in the iOS application

### SerpApi Google Flights API

- Provider: SerpApi, LLC
- Status: server adapter implemented; rotated-key verification pending
- API documentation: https://serpapi.com/google-flights-api
- Result documentation: https://serpapi.com/google-flights-results
- Price insights:
  https://serpapi.com/google-flights-price-insights
- Booking options:
  https://serpapi.com/google-flights-booking-options
- Purpose: worldwide flight search, comparison, price insights, baggage context,
  emissions estimates, and external booking continuation
- Data boundary: the API key remains in the server gateway
- Cache boundary: mapped flight responses expire after three minutes
- Booking boundary: search results and links are not represented as confirmed
  ticket purchases
- Distribution: no SerpApi SDK or Google Flights asset is bundled in the iOS
  application

### SerpApi Google Hotels API

- Provider: SerpApi, LLC
- Status: server adapter implemented; rotated-key verification pending
- API documentation: https://serpapi.com/google-hotels-api
- Property result documentation:
  https://serpapi.com/google-hotels-properties
- Purpose: property discovery, nightly and total pricing, ratings, reviews,
  amenities, images, cancellation context, and external property links
- Data boundary: the API key remains in the server gateway
- Cache boundary: mapped hotel responses expire after five minutes
- Rating boundary: Google Hotels ratings retain an explicit 5-point scale
- Booking boundary: property results and links are not represented as confirmed
  reservations
- Distribution: no SerpApi SDK or Google Hotels asset is bundled in the iOS
  application

### Geoapify Places API

- Provider: Geoapify GmbH
- Status: primary server adapter implemented; rotated-key verification pending
- API documentation: https://apidocs.geoapify.com/docs/places/
- Purpose: coordinate-based restaurants, cafés, museums, attractions, parks,
  entertainment, landmarks, shopping, nightlife, and sports discovery
- Data boundary: the API key remains in the server gateway
- Evidence boundary: absent rating, review, dietary, accessibility, hours, and
  reservation information remains unknown
- Cache boundary: mapped place responses expire after six hours
- Distribution: no Geoapify SDK or map tile is bundled in the iOS application

### Geoapify Routing API

- Provider: Geoapify GmbH
- Status: server adapter implemented; rotated-key verification pending
- API documentation: https://apidocs.geoapify.com/docs/routing
- Purpose: walking, bicycle, car, rideshare-estimate, transit, route geometry,
  duration, distance, and turn instruction data
- Confidence boundary: driving uses approximated traffic; transit fallback uses
  explicitly approximated OpenStreetMap route data
- Mode boundary: unsupported carrier-specific train, subway, ferry, airplane,
  and bus ticket claims are rejected
- Cache boundary: mapped route responses expire after 15 minutes
- Distribution: no Geoapify SDK or map tile is bundled in the iOS application

### SerpApi Google Maps API

- Provider: SerpApi, LLC
- Status: fallback server adapter implemented; rotated-key verification pending
- API documentation: https://serpapi.com/google-maps-api
- Purpose: fallback place discovery with ratings, reviews, price level, hours,
  images, websites, and explicit booking links when supplied
- Activation boundary: used only when Geoapify cannot provide usable results
- Booking boundary: ordering links are not treated as reservation links, and
  result links are not confirmation
- Distribution: no SerpApi SDK or Google Maps asset is bundled in the iOS
  application

### SerpApi Google Events API

- Provider: SerpApi, LLC
- Status: server adapter implemented; rotated-key verification pending
- API documentation: https://serpapi.com/google-events-api
- Purpose: concerts, sports, exhibitions, festivals, and other timed-event
  discovery with venue and external ticket context
- Date boundary: exact source text is retained; fixed schedule is created only
  when calendar date, clock range, and destination time zone can be resolved
- Filter boundary: cancelled, expired, duplicate, and provably out-of-range
  events are excluded
- Ticket boundary: source ticket links are external continuation, not proof of
  purchase or availability
- Cache boundary: mapped event responses expire after 30 minutes
- Distribution: no SerpApi SDK or Google Events asset is bundled in the iOS
  application

### WeatherAPI.com

- Provider: WeatherAPI.com
- Status: server adapter implemented; rotated-key verification pending
- API documentation: https://www.weatherapi.com/docs/
- Purpose: destination hourly forecasts, condition codes, precipitation, wind,
  temperatures, and government-issued alert aggregation
- Horizon boundary: the configured free-tier-compatible horizon defaults to
  three days; trips beyond it do not trigger a request
- Alert boundary: coverage depends on local reporting agencies and is not
  represented as globally guaranteed
- Cache boundary: mapped weather responses expire after 15 minutes
- Distribution: no WeatherAPI SDK, key, icon, or condition artwork is bundled in
  the iOS application

### Translation provider boundary

- Status: configurable server adapter implemented; current credential provider
  identification pending
- Supported provider documentation:
  - Google Cloud Translation:
    https://cloud.google.com/translate/docs/reference/rest/v2/translate
  - DeepL API: https://developers.deepl.com/docs/getting-started/quickstart
  - LibreTranslate: https://docs.libretranslate.com/
- Purpose: machine translation of bounded travel descriptions and messages
- Preservation boundary: original text, names, addresses, dates, amounts, URLs,
  emails, and identifiers remain available and protected as applicable
- Cache boundary: translations use memory-only cache and are not written to the
  response disk cache
- Distribution: no translation SDK or credential is bundled in the iOS
  application

## Source Intake Rule

No external item may be added to the application target until:

1. Its creator and original source are known.
2. Its license or permission is recorded.
3. App distribution is permitted.
4. Required attribution is documented.
5. The team can explain what was used and what was created independently.

