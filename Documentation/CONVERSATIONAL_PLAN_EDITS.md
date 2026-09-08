# Conversational Plan Edits

## End-of-speech behavior

`VoiceSessionCoordinator` does not depend on a speech-recognition final event
alone. It uses recognized transcript updates as the speech boundary:

- At least 0.45 seconds of request capture prevents instant completion.
- 0.95 seconds without a transcript change completes a request, so music,
  movement, or ambient noise cannot keep the session open.
- Six seconds without any speech produces a recoverable no-speech state.
- Twenty seconds is the hard request limit.
- Completion increments one sequence and tears down the audio tap, so one
  utterance cannot create duplicate Plan sessions.

Raw microphone energy never drives the listening waveform by itself. The
animation receives microphone level only for 0.70 seconds after the recognizer
confirms new transcript text. Non-speech sound therefore remains visually
quiet; G.I.A. playback continues to use its separate audio-player meter.

## Initial request flow

1. The user invokes G.I.A. manually or by name.
2. G.I.A. gives one short rotating greeting, such as “What's up? What trip are
   we planning?” or “I'm here. What's the plan?”
3. Microphone transcription starts after the greeting finishes.
4. Map enters listening and displays the live transcript.
5. End-of-speech completes the request.
6. G.I.A. acknowledges the request.
7. Plan opens immediately; audio may continue across the transition.
8. Real provider modules appear progressively.
9. G.I.A. may narrate live search, itinerary assembly, and completion when the
   voice channel is idle.

Microphone recognition is paused for all G.I.A. playback so the assistant
cannot trigger itself.

## Human clarification

Incomplete requests remain on Map. G.I.A. asks one spoken question at a time:

1. Destination, when missing.
2. Travel dates.
3. Number of travelers.
4. Any invalid supplied constraint.
5. An optional “Anything else?” preference turn.

Budget is optional and appears as `No limit set` when omitted. Dates and group
size remain required because live availability cannot be searched truthfully
without them.

Natural contextual answers such as `May 10 to May 14`, `two people`, or
`Vancouver` update the current request without requiring a form. `That's it`,
`done`, `no thanks`, `go ahead`, and `use that` complete the optional preference
turn.

If Plan is opened manually during clarification, it displays one Continue with
GIA card and directs the user back to Map. It does not render a questionnaire.

ElevenLabs remains the primary configured voice. If secured speech generation
is absent, slow, or invalid, `AVSpeechSynthesizer` speaks the same response so
the conversation does not become a Voice unavailable error. This fallback is
explicitly secondary and does not replace the selected ElevenLabs voice when
the gateway is available.

The gateway fixes G.I.A.'s ElevenLabs voice to
`3Drdg7QWqr45nZmYpXRP`; the iOS client sends no competing voice choice.

## Conversation tone and stop behavior

G.I.A. is written as a composed personal assistant rather than a status bot:
short responses, varied openings, brief acknowledgment of social language, and
one direct question at a time. It never claims bookings or facts that are not
grounded in the current request and provider results.

`Stop`, `Stop GIA`, `GIA stop`, `goodbye`, `bye GIA`, `see you later`, and
`that's all` close the active voice conversation. G.I.A. replies
`See you later.` A completed Plan is preserved; an incomplete conversation is
discarded and Map returns to idle. Phrases such as `find a bus stop` or
`stop at one museum` are not mistaken for the stop command.

## Follow-up flow

Wake listening remains armed on Map, Plan, and Group while the app is in the
foreground, including while provider planning is active. Saying `GIA`,
`Hey GIA`, `G I A`, or `Gee eye ay`:

1. Stops the Plan wake session.
2. Returns to Map.
3. Asks what should be added, changed, or removed.
4. Starts a fresh request-transcription window after the prompt finishes.
5. Applies the supported mutation to the current in-memory request.
6. Rebuilds Plan from a clean progressive draft.

The same mutations work through the Type action when a current Plan exists.

## Supported mutations

- Change destination, origin, dates, trip length, travelers, or budget.
- Add or remove interests.
- Add or remove dietary and accessibility requirements.
- Add, change, or remove flight class, stop, bag, refund, and departure-time
  preferences.
- Add or remove lodging type, star rating, amenities, refund preference, and
  nightly-rate constraints.
- Change itinerary pace.
- Say `cancel`, `never mind`, or use Return to preserve the existing Plan.

Unsupported text preserves the existing Plan and gives a concise correction
prompt. It never silently mutates data.

Wake recognition pauses only while the user is already dictating, while G.I.A.
audio is playing, when the app is inactive/backgrounded, or after permission is
denied. These pauses prevent self-triggering and comply with iOS microphone
lifecycle expectations; recognition rearms automatically afterward.

## Verification

- Wake aliases and false-positive boundaries pass deterministic verification.
- Silence completion at 0.95 seconds, no-speech at 6 seconds, and maximum
  duration at 20 seconds pass deterministic verification.
- Add, change, remove, numeric update, destination update, and cancellation
  commands pass request-mutation verification.
- Ready and partially available sessions return safely from cancelled
  follow-ups.
- Active provider planning can be interrupted by name and safely restarted
  after a cancelled change.
- Simulator choreography changed Lisbon/$4,000 to Vancouver/$6,000 and rebuilt
  the Plan without stale result cards.
- Simulator cancellation retained the original Lisbon/$4,000 Plan.
