# Phase 8 — Card 2: Google Translation Activation

## Status

Source complete with mocked provider verification and successful iOS builds.
Live sign-off is blocked because the current `TRANSLATION_API_KEY` is not a
valid Google API key.

## Objective

Offer optional multilingual Plan descriptions without replacing source text,
translating identifiers, increasing initial planning latency, or spending
translation quota for content the traveler never opens.

## Provider configuration

The selected provider is Google Cloud Translation Basic:

```text
TRANSLATION_PROVIDER=google
TRANSLATION_API_KEY=<server-side Google API key>
```

The key remains in the root `.env` and is sent only from the gateway to
`translation.googleapis.com`. The iOS application never receives it.

## Plan language control

Plan exposes one compact language menu with:

- English
- Spanish
- French
- German
- Italian
- Japanese

English is the default. The selection is stored locally in `UserDefaults` and
does not alter the trip's destination language, time zone, currency, provider
queries, or source objects.

## On-demand translation

Translation occurs only when translated content is visible:

- A hotel room description is translated when hotel details are expanded.
- An itinerary note is translated when its timeline item is expanded.

This avoids translating every flight, hotel, event, and itinerary item during
initial planning. It also keeps provider search and Plan rendering independent
from Google Translation latency.

## Source preservation

The shared `Trip` remains unchanged. Translations are display-only values held
in memory by `PlanTranslationCoordinator`.

Every request sends protected terms for:

- GIA
- Hotel and itinerary item names
- Place, city, region, and country names
- Timeline subtitles and location names

The gateway also protects URLs, emails, identifiers, ISO dates, and currency
amounts. Translated content is labeled `MACHINE TRANSLATED · GOOGLE`.
Selecting English immediately returns to the original provider text.

## Failure behavior

- Missing gateway configuration disables the language menu.
- Cancellation does not display an error.
- Invalid, unauthorized, unavailable, or malformed translations leave the
  original text visible.
- The Plan remains usable and no provider result is removed.
- A translation failure never falls back to fabricated text.

## Verification

Automated gateway tests verify:

- Google request format and official host
- Original and translated text coexist
- Protected names and dates survive byte-for-byte
- Same-language content consumes no provider request
- Address and identifier content bypasses translation
- Provider errors are sanitized
- Translation remains memory-only

Runtime verification on September 7, 2026:

- Gateway health reports translation configured with no structural issue.
- A live Google request returned `400 INVALID_ARGUMENT`.
- Google reported that the current API key is not valid.
- The app therefore retains original English content until a valid Google
  Cloud API key replaces the current value.

## Completion gate

Card 2 receives live-complete status when:

- Cloud Translation API is enabled in a Google Cloud project with billing.
- `TRANSLATION_API_KEY` contains a valid server key restricted to the Cloud
  Translation API.
- A live English-to-Spanish request returns HTTP 200.
- GIA and place names remain unchanged.
- The Plan displays the translated text and machine-translation label.
