# Phase 8 — Card 1: Provider Configuration Contract

## Status

Complete. Translation activation belongs to Card 2 because its credential
provider has not been identified.

## Objective

Give the gateway one deterministic, server-only environment contract so local
development, automated tests, and deployment use the same provider names
without exposing credentials or silently ignoring configured keys.

## Canonical environment

The project-root `.env` is the local development source. `Gateway/npm start`
loads `../.env`.

Canonical credential names:

- `SERPAPI_API_KEY`
- `OPENAI_API_KEY`
- `ELEVENLABS_API_KEY`
- `GEOAPIFY_API_KEY`
- `WEATHERAPI_API_KEY`
- `TRANSLATION_API_KEY`

The gateway temporarily accepts the previous camel-case names:

- `SerpAPIKey`
- `OpenAIAPIKey`
- `ElevenLabsAPIKey`
- `GeoapifyAPIKey`
- `WeatherAPIKey`
- `TranslationAPIKey`

Canonical values take precedence when both forms exist. Provider handlers read
only the normalized environment object after startup.

## Translation boundary

A translation credential alone is not enough to mark translation configured.
Health reports translation ready only when:

1. `TRANSLATION_API_KEY` is present.
2. `TRANSLATION_PROVIDER` is `google`, `deepl`, or `libretranslate`.
3. LibreTranslate also has an HTTPS `TRANSLATION_BASE_URL`.

Card 1 reports incomplete translation configuration without guessing the
credential's provider. Card 2 selects and validates the provider and connects
translation to a user-facing workflow.

## Non-secret diagnostics

`GET /health` retains provider readiness booleans and adds
`configurationIssues`. Supported issue codes are:

- `translation_provider_missing`
- `translation_api_key_missing`
- `translation_provider_unsupported`
- `translation_base_url_missing`
- `translation_base_url_invalid`

No issue contains a key, credential fragment, request body, traveler data, or
provider response.

## Local security

- The root `.env` and legacy `Gateway/.env` are ignored.
- Provider keys remain outside the iOS application and source files.
- The known localhost token is a development boundary only.
- Production must replace the development token with short-lived sessions and
  App Attest validation.
- Changing `.env` requires restarting the gateway because Node loads
  environment files only at process startup.

## Verification

- Legacy names normalize to canonical names.
- Canonical names override aliases.
- Incomplete translation configuration reports disabled plus a safe issue.
- DeepL configuration reports ready without a custom base URL.
- LibreTranslate requires an HTTPS base URL.
- Gateway health output never contains test secret values.
- Gateway syntax and provider tests pass.
- Live health reads the project-root `.env`.

Recorded verification on September 7, 2026:

- Syntax checked all 15 gateway modules.
- All 93 mocked provider, validation, and security tests passed.
- Canonical `npm start` loaded `../.env`.
- Health reported gateway authentication and five providers configured.
- Health reported `translation_provider_missing` without credential material.
- The secured OpenAI response route returned HTTP 200 using the reloaded key.

## Completion gate

Card 1 is complete when:

- The local `.env` uses canonical names.
- `npm start` loads the root file.
- Every server handler uses normalized configuration.
- Health diagnostics describe incomplete setup without exposing secrets.
- Automated gateway verification passes.
