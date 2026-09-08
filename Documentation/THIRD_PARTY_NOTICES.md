# G.I.A. Third-Party Notices

## NASA Blue Marble Earth Texture

G.I.A. includes the following visual asset:

- Title: Blue Marble — A Seamless Image Mosaic of the Earth
- File: `bluemarble-2048.png`
- Source: NASA/Goddard Space Flight Center Scientific Visualization Studio
- Source page: https://svs.gsfc.nasa.gov/2915/
- Data credit: Blue Marble Next Generation data courtesy of Reto Stockli
  (NASA/GSFC) and NASA Earth Observatory
- NASA media guidelines:
  https://www.nasa.gov/nasa-brand-center/images-and-media/

NASA-produced media and files used in 3D rendering are generally not subject to
copyright in the United States and may be used consistently with NASA's media
guidelines. NASA is acknowledged as the source. G.I.A. does not use a NASA insignia,
logotype, seal, or identifier and does not state or imply NASA endorsement.

The exact downloaded file, checksum, dimensions, and usage record are documented in
`SOURCES.md`.

## Apple Platform Resources

G.I.A. uses Apple operating-system frameworks, system typography, and SF Symbols.
Their use is governed by the applicable Apple developer agreements and licenses.
These resources are used only in an Apple-platform application.

## SceneKit Reference Repository

The following repository was reviewed as an educational reference:

https://github.com/SMGLOBAL-ops/Earth-3D-PlanetModel-SwiftUI-SceneKit

No source file, texture, binary, package, or other asset from that repository is
distributed with G.I.A. The repository README describes the project as MIT licensed,
but the inspected repository revision does not contain the referenced license text.
G.I.A. therefore independently implements its SceneKit Earth.

## OpenAI API

G.I.A.'s server gateway contains an adapter for the OpenAI Responses API. No
OpenAI SDK, model, or credential is bundled in the iOS application.

The planner receives validated trip constraints and bounded summaries of
previously sourced travel options. It returns a strict itinerary blueprint that
is independently validated against source identifiers, trip dates, and schedule
rules. G.I.A. does not treat model output as proof of price, availability, or
booking.

OpenAI API terms and policies apply when the service is enabled:

https://openai.com/policies

## SerpApi, Google Flights, and Google Hotels Results

G.I.A.'s server gateway contains adapters for SerpApi's Google Flights, Google
Hotels, Google Maps, and Google Events engines. No SerpApi credential or SDK is
bundled in the iOS application.

Flight names, schedules, prices, baggage descriptions, emissions estimates,
price insights, and external continuation links remain attributed to their
source. Hotel names, ratings, prices, amenities, images, cancellation context,
and property links also remain source-attributed. G.I.A. applies deterministic
comparison labels but does not represent a search result as reserved, purchased,
or guaranteed.

Google Events titles, source date text, venue context, images, and ticket links
remain attributed. Ticket links do not indicate purchase or reservation.

SerpApi terms apply when the service is enabled:

https://serpapi.com/legal

Google service terms may also govern downstream Google Flights data and links:

https://policies.google.com/terms

## Geoapify Places

G.I.A.'s server gateway uses Geoapify Places as its primary restaurant and
activity discovery source when destination coordinates are available. It also
uses Geoapify Routing for supported transportation estimates. No Geoapify
credential, SDK, or map tile is bundled in the iOS application.

Names, addresses, categories, coordinates, opening-hour text, websites, dietary
evidence, and wheelchair evidence remain source-attributed. Missing rating,
review, reservation, accessibility, and dietary data remains unknown.

Route distance, duration, geometry, and instructions remain source-attributed.
Approximated transit and traffic are labeled as estimates and do not imply a
carrier, ticket, fare, or live navigation guarantee.

Geoapify terms and attribution requirements apply when the service is enabled:

https://www.geoapify.com/terms-and-conditions/

SerpApi Google Maps may provide fallback discovery. Google and SerpApi terms
continue to apply to those fallback results.

## WeatherAPI.com

G.I.A.'s server gateway contains a WeatherAPI.com forecast and alert adapter.
No WeatherAPI credential, SDK, icon, or condition artwork is bundled in the iOS
application.

Forecast periods, provider condition descriptions, temperature, precipitation,
wind, reporting-agency alerts, and source links remain attributed. Alert
coverage varies by reporting region and is not represented as globally
guaranteed.

WeatherAPI.com terms apply when the service is enabled:

https://www.weatherapi.com/terms.aspx

## Translation Services

G.I.A.'s gateway supports Google Cloud Translation, DeepL, or a configured
LibreTranslate deployment. Only the provider explicitly selected in server
configuration is used. No translation SDK or credential is bundled in the iOS
application.

Original text remains available beside translated text. Protected names,
addresses, identifiers, dates, amounts, URLs, and emails are not translated.
Machine-generated translations are labeled as such.

Applicable terms depend on the configured provider:

- Google Cloud: https://cloud.google.com/terms
- DeepL: https://www.deepl.com/pro-license
- LibreTranslate: https://github.com/LibreTranslate/LibreTranslate

