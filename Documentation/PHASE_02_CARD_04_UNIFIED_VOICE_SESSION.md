# Phase 2 — Card 4: Unified Voice Session

## Status

Source complete. Physical-device speech verification remains required because
automated simulator tests cannot supply controlled microphone speech.

## Objective

Use one audio engine for wake recognition, full travel-request transcription,
and voice-surface amplitude. The assistant must transition from “Hey GIA” into
request capture without competing microphone taps or recording audio to storage.

## Architecture

`VoiceSessionCoordinator` is the only owner of:

- `AVAudioEngine`
- The input-node tap
- `AVAudioSession`
- `SFSpeechRecognizer`
- Wake and request recognition tasks
- Microphone amplitude
- End-of-speech detection
- Speech permission and availability state

The former independent wake and microphone-level services were removed.

Pure recognition policy is isolated in `VoiceRecognitionRules` so wake matching
and endpoint decisions can be tested without iOS microphone hardware.

## Modes

```text
stopped
├── wakePhrase
└── requestTranscription
```

Only one mode and one recognition request may be active at a time. Session
generations invalidate stale audio and recognition callbacks when modes change.

## User flow

```text
Map idle
└── Listen for GIA
    └── Wake phrase detected
        ├── Activate existing Earth/ripple transition
        ├── TripPlanningSession: listening
        └── TripPlanningSession: transcribing
            ├── Show partial transcript inside active circle
            ├── Animate ripples from the same microphone buffers
            └── End-of-speech
                └── TripPlanningSession: validating
```

Manual activation enters the same request-transcription flow without fabricating
a wake event.

## Wake matching

Accepted forms include:

- `GIA`
- `Hey GIA`
- `G. I. A.`
- `gee eye ay`
- A sentence containing `Gia` as a distinct word

Substring matching is deliberately rejected so words such as `Georgia`,
`giant`, and `energy` do not activate the assistant.

## Endpoint behavior

Request transcription completes when:

- Recognized speech is followed by 0.95 seconds without new transcript text, or
- The speech recognizer marks the result final, or
- The 20-second request ceiling is reached with usable text

The coordinator reports no-speech failure after six seconds of initial
silence. A minimum request window prevents brief microphone dips from ending
capture immediately.

## Active-circle presentation

The assistant circle now supports:

- Live multiline transcript
- A concise semantic phase label
- A GIA identity fallback before words are recognized
- Dynamic scaling for longer requests
- VoiceOver label and transcript value

The transcript UI does not alter the established sphere transformation, ripple
response, or return choreography.

## Privacy

- Audio buffers are processed in memory and are not written to disk.
- Transcripts remain session data until later persistence policy is defined.
- The microphone stops when leaving Map, returning to idle, or preparing speech
  playback.
- The app requests both microphone and speech-recognition permission with
  purpose-specific usage descriptions.
- On-device recognition is preferred when supported. If it fails before
  producing usable text, G.I.A. retries once with standard Apple recognition.
  Apple's framework may then use Apple processing, as described by the system
  permission sheet.

## Reliability

- Wake recognition restarts after normal recognizer completion or interruption.
- Map visibly distinguishes voice-ready, requesting, denied, and unavailable
  states.
- A failed on-device recognizer cannot enter an endless same-mode retry loop.
- Stale callbacks are rejected with session-generation identifiers.
- Permission denial and unavailable recognition remain recoverable.
- Manual activation remains available as a fallback.
- Speech playback has an explicit pause boundary to prevent GIA from recognizing
  its own generated voice.

## Verification

Automated verification covers:

- Accepted wake forms
- Common phonetic letter variants
- False-positive rejection
- Wake-prefix removal without damaging place names
- Initial-silence continuation and timeout
- End-of-speech silence
- Maximum request duration
- iOS target compilation
- Xcode project validity
- IDE diagnostics
- Transcript layout in the active assistant circle
- Existing activation and return compatibility

Required device checks:

- Speak each accepted wake form
- Dictate short and long trip requests
- Pause naturally mid-sentence
- Remain silent through timeout
- Deny and restore permissions
- Background and foreground during recognition
- Verify no GIA self-trigger during future ElevenLabs playback

## FBLA evidence

This card supports:

- Natural and accessible user input
- Expert separation of hardware, policy, workflow, and presentation
- Semantic validation foundations
- Privacy-conscious data handling
- Recoverable failure behavior
- Tangible testing and architecture documentation
