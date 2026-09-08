# Phase 2 — Card 22: ElevenLabs Response Service

## Status

Complete with a secured ElevenLabs gateway adapter, shared iOS playback
coordination, common-phrase memory caching, on-device fallback, mocked provider
tests, Swift lifecycle verification, and a live simulator gateway check.

## Objective

Give G.I.A. one consistent voice without shipping an ElevenLabs credential,
blocking the interface, causing microphone feedback, or hiding information when
audio fails.

## Voice configuration

- Voice ID: `3Drdg7QWqr45nZmYpXRP`
- Default model: `eleven_flash_v2_5`
- Default format: `mp3_44100_128`
- Alternate low-bandwidth format: `mp3_22050_32`
- Maximum text: 800 characters
- Stability: `0.43`
- Similarity boost: `0.82`
- Style: `0.24`
- Speaker boost: enabled

The voice identifier and model are server configuration. The ElevenLabs API key
exists only in the gateway's untracked environment.
The iOS client no longer sends a hardcoded voice identifier; changing
`ELEVENLABS_VOICE_ID` updates G.I.A.'s voice without rebuilding the app.

## Conversational response generation

The live voice path uses short grounded responses immediately so an optional
wording provider cannot block speech. The `/v1/respond` endpoint remains
available for future non-critical response variation through OpenAI:

- Separate spoken and visible text
- Typed conversation intent
- Explicit follow-up-listening decision
- Maximum spoken length of 240 characters
- Non-stored OpenAI request
- Grounded numeric-claim validation
- Booking-claim rejection

Injected response generators are limited to 0.35 seconds. The shipping
coordinator does not place this optional request ahead of ElevenLabs.

## Gateway boundary

`createElevenLabsSpeech`:

1. Validates the request object, text, configured voice, and output format.
2. Calls the ElevenLabs text-to-speech endpoint with `xi-api-key` server-side.
3. Applies fixed voice settings for consistent output.
4. Normalizes MP3 loudness to an approximately −18 LUFS target with a
   −1.5 dB true-peak ceiling.
5. Uses the gateway timeout abort signal.
6. Returns the normalized audio through the secured binary boundary.
7. Removes provider headers and returns `Cache-Control: no-store`.
8. Maps authorization, capacity, malformed-audio, and network failures to
   sanitized errors.

The gateway never logs response text or exposes provider account details.

## iOS response coordinator

`GIAResponseCoordinator` is shared by Map and Plan through SwiftUI environment
injection.

It owns:

- Speech generation state
- Visible response text
- `AVAudioPlayer`
- Playback-level metering
- In-memory common-phrase audio cache
- Audio-session activation/deactivation
- Cancellation and delegate completion
- Visible fallback state

The response coordinator does not own speech recognition. Before requesting
audio, `MapScreen` tells `VoiceSessionCoordinator` to pause and release the
recording audio session.

## Phrase library

- “Okay, I've got it.”
- “I need one more detail.”
- “I found a better flight option.”
- “Your plan is ready.”
- “That change creates a timing conflict.”
- “What's up? What trip are we planning?”
- “Hey—how are you doing? Where are we thinking of going?”
- “I'm here. What's the plan?”
- “See you later.”

These deterministic phrases are cached only in process memory. Generated
request-specific speech remains outside the response cache and is never written
to disk.

## Map-to-Plan behavior

After transcription:

1. The request is interpreted and validated.
2. Microphone recognition stops.
3. G.I.A. begins generating either the captured or clarification phrase.
4. The Plan handoff starts without waiting for the entire audio file to finish.
5. Playback state remains alive across the tab transition.
6. Real player meter levels drive the assistant ripple while Map is visible.

Returning to Map stops any stale response and the existing wake-listening
lifecycle resumes after the return transition.

## Visible fallback

If ElevenLabs is unavailable, unconfigured, slow, or returns invalid audio,
the app first speaks the same response through the on-device system voice. If
both voice paths fail:

- The exact G.I.A. response remains visible.
- A “Voice unavailable” explanation appears.
- The Plan transition continues.
- No trip state is lost.
- The user can dismiss the fallback banner.
- A hard UI deadline prevents “Preparing GIA” from remaining indefinitely.

Debug builds default to `http://127.0.0.1:8787` and the local-development
gateway boundary. Either value can be overridden with:

- `GIA_GATEWAY_BASE_URL`
- `GIA_GATEWAY_ACCESS_TOKEN`

No provider key is accepted by the iOS application.

## Accessibility

The spoken response remains visually present, but its duplicate accessibility
element is hidden while generated audio is actively playing. If audio fails,
the visible fallback remains available to VoiceOver. Playback status and
failure meaning are not represented by animation alone.

## Debug verification

`GIA_DEBUG_SPEECH_RESPONSE=1` requests “Your plan is ready” when Plan appears.
Without a configured gateway, this deliberately exercises the visible fallback
banner. With a local gateway and development bearer token, it exercises live
generation and playback.

## Automated verification

Gateway tests cover:

- Text bounds
- Configured voice enforcement
- Output-format enforcement
- ElevenLabs request URL, model, and server-side authentication
- MP3 streaming
- Provider-header removal
- Missing configuration
- Sanitized authorization failures

Swift verification covers:

- Exact phrase library
- Phrase uniqueness
- Missing-service fallback
- Visible response preservation
- Idle reset behavior

Live simulator verification on September 7, 2026:

- Authenticated app request reached `POST /v1/speech`.
- Gateway returned HTTP 200 with `audio/mpeg`.
- Direct voice proof returned 35,988 bytes at 44.1 kHz.
- Estimated audio duration was 2.22 seconds.
- The request URL used voice `3Drdg7QWqr45nZmYpXRP`.
- Pre-normalization sample: −35.3 dB mean, −18.8 dB peak.
- Normalized sample: −20.0 dB mean, −2.0 dB peak.
- Flash v2.5 gateway samples completed in 0.31–0.51 seconds.

## Truthfulness and security

- No ElevenLabs key ships in the app.
- Failed audio never becomes a false success.
- Visible text remains the authoritative response.
- Audio is not persisted to disk.
- Microphone recognition is stopped before provider audio begins.
- VoiceOver does not duplicate active G.I.A. speech.

## FBLA evidence

This card demonstrates secure API integration, multimedia playback, asynchronous
state management, accessible fallback behavior, cross-screen continuity,
resource coordination, and responsible protection of third-party credentials.
