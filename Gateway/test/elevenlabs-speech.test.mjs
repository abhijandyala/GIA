import assert from "node:assert/strict";
import test from "node:test";

import {
  createElevenLabsSpeech,
  validateSpeechCriteria
} from "../src/providers/elevenlabs-speech.mjs";

const VOICE_ID = "3Drdg7QWqr45nZmYpXRP";

test("speech criteria enforce bounded text and configured voice", () => {
  const result = validateSpeechCriteria({
    text: "  Okay, I've got it.  ",
    voiceIdentifier: VOICE_ID,
    outputFormat: "mp3_44100_128"
  });

  assert.equal(result.text, "Okay, I've got it.");
  assert.equal(result.voiceIdentifier, VOICE_ID);
  assert.equal(result.outputFormat, "mp3_44100_128");
  assert.throws(
    () => validateSpeechCriteria({
      text: "",
      voiceIdentifier: VOICE_ID,
      outputFormat: "mp3_44100_128"
    }),
    (error) => error.code === "invalid_speech_text"
  );
  assert.throws(
    () => validateSpeechCriteria({
      text: "Hello",
      voiceIdentifier: "another-voice",
      outputFormat: "mp3_44100_128"
    }),
    (error) => error.code === "invalid_voice_identifier"
  );
  assert.throws(
    () => validateSpeechCriteria({
      text: "Hello",
      voiceIdentifier: VOICE_ID,
      outputFormat: "pcm_44100"
    }),
    (error) => error.code === "invalid_speech_output_format"
  );
});

test("ElevenLabs request uses server key and streams MP3 audio", async () => {
  let capturedURL;
  let capturedOptions;
  const generateSpeech = createElevenLabsSpeech({
    apiKey: "server-only-key",
    voiceIdentifier: VOICE_ID,
    normalizeImplementation: async (audio) => audio,
    fetchImplementation: async (url, options) => {
      capturedURL = new URL(url);
      capturedOptions = options;
      return new Response(
        new Uint8Array([0x49, 0x44, 0x33]),
        {
          headers: {
            "content-type": "audio/mpeg",
            "request-id": "provider-secret-metadata"
          }
        }
      );
    }
  });

  const response = await generateSpeech({
    text: "Your plan is ready.",
    outputFormat: "mp3_44100_128"
  });
  const body = JSON.parse(capturedOptions.body);

  assert.equal(
    capturedURL.pathname,
    `/v1/text-to-speech/${VOICE_ID}`
  );
  assert.equal(
    capturedURL.searchParams.get("output_format"),
    "mp3_44100_128"
  );
  assert.equal(
    capturedOptions.headers["xi-api-key"],
    "server-only-key"
  );
  assert.equal(body.text, "Your plan is ready.");
  assert.equal(body.model_id, "eleven_flash_v2_5");
  assert.deepEqual(body.voice_settings, {
    stability: 0.32,
    similarity_boost: 0.78,
    style: 0.52,
    use_speaker_boost: true
  });
  assert.equal(body.apply_text_normalization, "auto");
  assert.equal(
    JSON.stringify(body).includes("server-only-key"),
    false
  );
  assert.equal(response.headers.get("content-type"), "audio/mpeg");
  assert.equal(response.headers.has("request-id"), false);
  assert.deepEqual(
    new Uint8Array(await response.arrayBuffer()),
    new Uint8Array([0x49, 0x44, 0x33])
  );
});

test("short spoken lines skip ffmpeg normalization", async () => {
  let normalized = false;
  const generateSpeech = createElevenLabsSpeech({
    apiKey: "server-only-key",
    voiceIdentifier: VOICE_ID,
    normalizeImplementation: async (audio) => {
      normalized = true;
      return audio;
    },
    fetchImplementation: async () => new Response(
      new Uint8Array([0x49, 0x44, 0x33]),
      {
        headers: {
          "content-type": "audio/mpeg"
        }
      }
    )
  });

  await generateSpeech({
    text: "What's up? What trip are we planning?",
    outputFormat: "mp3_44100_128"
  });
  assert.equal(normalized, false);

  const longText = "Okay. ".repeat(41);
  await generateSpeech({
    text: longText,
    outputFormat: "mp3_44100_128"
  });
  assert.equal(normalized, true);
});

test("speech provider errors and missing configuration are sanitized", async () => {
  const unconfigured = createElevenLabsSpeech({});
  await assert.rejects(
    () => unconfigured({
      text: "Hello",
      voiceIdentifier: VOICE_ID,
      outputFormat: "mp3_44100_128"
    }),
    (error) => error.code === "elevenlabs_not_configured"
  );

  const unauthorized = createElevenLabsSpeech({
    apiKey: "bad-key",
    fetchImplementation: async () => new Response(
      JSON.stringify({
        detail: "provider account and quota details"
      }),
      {
        status: 401,
        headers: {
          "content-type": "application/json"
        }
      }
    )
  });
  await assert.rejects(
    () => unauthorized({
      text: "Hello",
      voiceIdentifier: VOICE_ID,
      outputFormat: "mp3_44100_128"
    }),
    (error) => (
      error.code === "speech_provider_authorization_failed"
      && !error.message.includes("account")
    )
  );
});
