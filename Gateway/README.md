# G.I.A. API Gateway

This directory is the server-side security boundary for G.I.A.'s travel
providers. The iOS target must never contain provider API keys.

Card 1 establishes the gateway contract and secure defaults only. Provider
implementations are intentionally deferred to their feature cards.

## Routes

- `GET /health`
- `POST /v1/respond`
- `POST /v1/resolve/location`
- `POST /v1/plan`
- `POST /v1/search/flights`
- `POST /v1/search/hotels`
- `POST /v1/search/places`
- `POST /v1/route`
- `POST /v1/weather`
- `POST /v1/speech`
- `POST /v1/translation`

Unconnected provider routes return a structured `501 provider_not_connected`
response. This prevents the interface from implying that a provider is live
before its adapter and validation are complete.

Provider handlers normally return values wrapped in the gateway JSON envelope.
Speech handlers may return a `Response` with binary audio. The gateway preserves
only its content type and replaces all other provider headers with the standard
secured response headers.

`POST /v1/speech` is backed by ElevenLabs and accepts:

- `text` between 1 and 800 characters
- The configured G.I.A. voice identifier
- `mp3_44100_128` or `mp3_22050_32`

The gateway fixes the model and voice settings, sends the API key only in the
server-to-provider header, and streams the provider audio body without exposing
ElevenLabs response metadata. Configure `ELEVENLABS_API_KEY`,
`ELEVENLABS_VOICE_ID`, and `ELEVENLABS_MODEL_ID` in the untracked `.env`.

`POST /v1/respond` creates short structured G.I.A. dialogue through OpenAI.
It accepts only a typed intent, a bounded request summary, and grounded facts.
The response includes separate spoken/display text and cannot claim a booking
or introduce unsupported numeric facts. The iOS app uses deterministic copy
when this endpoint is unavailable.

`POST /v1/resolve/location` resolves arbitrary user-entered place names
through Geoapify. It returns coordinates and time-zone context, plus a nearby
IATA airport code only when the provider supplies one. The app skips flight or
weather workstreams that lack the provider facts they require; it does not
substitute a hardcoded city or airport.

`POST /v1/translation` uses Google Cloud Translation when
`TRANSLATION_PROVIDER=google`. Plan requests translations only for expanded
hotel descriptions and itinerary notes, keeps the original source text, and
labels translated output. Translation failure never blocks live planning.

## Local setup

1. Rotate every credential that has appeared in a screenshot, message, log, or
   commit.
2. From `Gateway`, copy `.env.example` to the project root:

   ```sh
   cp .env.example ../.env
   ```

3. Replace `GATEWAY_ACCESS_TOKEN` with a development token and pass the same
   value to the Debug app through `GIA_GATEWAY_ACCESS_TOKEN` when it differs
   from the localhost default.
4. Add provider credentials only to the root, untracked `.env`.
   Canonical variable names are uppercase:
   `SERPAPI_API_KEY`, `OPENAI_API_KEY`, `ELEVENLABS_API_KEY`,
   `GEOAPIFY_API_KEY`, `WEATHERAPI_API_KEY`, and
   `TRANSLATION_API_KEY`.
   Legacy camel-case credential names remain compatible during migration.
5. Start the gateway:

   ```sh
   npm start
   ```

6. Check its non-sensitive status. `configurationIssues` identifies incomplete
   provider setup by code without returning credential values:

   ```sh
   curl http://127.0.0.1:8787/health
   ```

Run verification with:

```sh
npm run check
npm test
```

## Security behavior

- Provider routes fail closed if gateway authentication is absent.
- Bearer credentials are compared in constant time.
- Browser origins are denied unless explicitly allowlisted.
- Request bodies are limited to 64 KiB.
- Requests are rate-limited.
- Provider execution has a hard timeout.
- Internal provider errors are replaced with safe client messages.
- Responses are marked `no-store`.
- Health checks expose only whether each provider is configured.
- Request logs contain method, route, status, and request ID only.

`GATEWAY_ACCESS_TOKEN` is a development boundary, not final mobile
authentication. A token embedded in an iOS binary can be extracted. Before
production, replace it with short-lived user sessions and Apple App Attest
validation.

The in-memory rate limiter protects local development and a single gateway
process. A deployed multi-instance gateway must use its platform's shared rate
limiter.

## Key ownership

Server-side only:

- SerpApi
- OpenAI
- ElevenLabs
- Geoapify
- WeatherAPI
- Translation provider

The ElevenLabs voice identifier is configuration, not a secret:
`3Drdg7QWqr45nZmYpXRP`.

Do not log requests containing traveler names, accessibility needs, dietary
needs, budgets, or conversation transcripts. Future persistence must define
retention and deletion behavior before storing these fields.
