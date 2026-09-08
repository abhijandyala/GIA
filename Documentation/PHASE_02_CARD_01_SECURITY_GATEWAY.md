# Phase 2 — Card 1: Secret Security and API Gateway

## Status

Source complete. External key rotation and production deployment remain user
actions.

## Objective

Create a security boundary between the iOS application and travel/AI providers.
No provider credential may be compiled into, logged by, or committed with the
mobile application.

## Delivered

- Repository ignore rules for environment files, signing keys, provisioning
  profiles, and secret Xcode configuration files
- A tracked environment template containing variable names only
- A Node 20-compatible API gateway foundation
- Provider-agnostic routes for planning, travel search, routing, weather, and
  speech
- Fail-closed gateway authentication
- Constant-time bearer credential comparison
- Browser-origin allowlisting
- Request body limits
- Request rate limiting
- Provider timeouts
- Sanitized error envelopes
- Non-sensitive health reporting
- Automated gateway security and behavior tests

## Route contract

```text
GET  /health
POST /v1/plan
POST /v1/search/flights
POST /v1/search/hotels
POST /v1/search/places
POST /v1/route
POST /v1/weather
POST /v1/speech
POST /v1/translation
```

Provider routes intentionally return `501 provider_not_connected` until their
respective implementation cards are complete.

## Security decisions

### Fail closed

Provider routes reject requests when `GATEWAY_ACCESS_TOKEN` is not configured.
This prevents an accidentally deployed gateway from becoming an unauthenticated
proxy for paid APIs.

### No secrets in health or errors

The health route reports only Boolean provider-configuration status. Unexpected
provider errors are converted to a generic response so credentials, upstream
payloads, and internal implementation details do not reach clients.

### Development authentication is temporary

The initial bearer token protects development endpoints but is not sufficient
for an App Store release because values embedded in an iOS binary are
extractable. Production must replace it with authenticated user sessions and
Apple App Attest validation.

### Provider logic remains isolated

The gateway accepts injected provider handlers. Later cards can add SerpApi,
OpenAI, ElevenLabs, Geoapify, WeatherAPI, and translation adapters without
changing the HTTP security boundary or mobile interface.

## Required user actions

1. Rotate every provider credential previously displayed in screenshots, chat,
   logs, or other shared material.
2. Use a restricted OpenAI project key rather than an organization admin key.
3. Copy `Gateway/.env.example` to `Gateway/.env`.
4. Store only newly rotated credentials in the untracked file.
5. Choose and configure a deployment platform before connecting the iOS app.

## Verification

Card verification must include:

- JavaScript syntax checks
- Gateway unit tests
- Health response inspection
- Authentication failure checks
- Repository secret-pattern scan excluding ignored local secret files
- Existing iOS target build

## FBLA evidence

This card supports the rating sheet's expectations for:

- Expert use of modules and components
- Appropriate mobile architecture
- Comprehensive and secure data handling
- Professional documentation
- Reliable behavior when external services are missing
