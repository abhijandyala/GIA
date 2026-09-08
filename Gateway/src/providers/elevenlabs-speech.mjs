import { spawn } from "node:child_process";

import ffmpegPath from "ffmpeg-static";

import { GatewayError } from "../gateway.mjs";

const DEFAULT_VOICE_ID = "3Drdg7QWqr45nZmYpXRP";
const DEFAULT_MODEL_ID = "eleven_flash_v2_5";
const MAX_TEXT_LENGTH = 800;
const SUPPORTED_OUTPUT_FORMATS = new Map([
  ["mp3_44100_128", "audio/mpeg"],
  ["mp3_22050_32", "audio/mpeg"]
]);

export function createElevenLabsSpeech({
  apiKey,
  voiceIdentifier = DEFAULT_VOICE_ID,
  modelIdentifier = DEFAULT_MODEL_ID,
  normalizeImplementation = normalizeMP3,
  fetchImplementation = globalThis.fetch
}) {
  return async function generateSpeech(criteria, context = {}) {
    if (!apiKey) {
      throw new GatewayError(
        503,
        "elevenlabs_not_configured",
        "Speech generation is not configured."
      );
    }

    const validated = validateSpeechCriteria(
      criteria,
      voiceIdentifier
    );
    const url = new URL(
      `/v1/text-to-speech/${encodeURIComponent(voiceIdentifier)}`,
      "https://api.elevenlabs.io"
    );
    url.searchParams.set(
      "output_format",
      validated.outputFormat
    );

    let response;
    try {
      response = await fetchImplementation(url, {
        method: "POST",
        headers: {
          accept: SUPPORTED_OUTPUT_FORMATS.get(
            validated.outputFormat
          ),
          "content-type": "application/json",
          "xi-api-key": apiKey
        },
        body: JSON.stringify({
          text: validated.text,
          model_id: modelIdentifier,
          voice_settings: {
            stability: 0.32,
            similarity_boost: 0.78,
            style: 0.52,
            use_speaker_boost: true
          },
          apply_text_normalization: "auto"
        }),
        signal: context.signal
      });
    } catch (error) {
      if (error?.name === "AbortError") {
        throw error;
      }
      throw new GatewayError(
        502,
        "speech_provider_unavailable",
        "Speech generation is temporarily unavailable."
      );
    }

    if (!response.ok) {
      throw mapElevenLabsError(response.status);
    }

    const contentType = (
      response.headers.get("content-type") ?? ""
    ).toLowerCase();
    if (!contentType.startsWith("audio/")) {
      throw new GatewayError(
        502,
        "invalid_speech_response",
        "Speech generation returned an invalid response."
      );
    }
    if (!response.body) {
      throw new GatewayError(
        502,
        "empty_speech_response",
        "Speech generation returned no audio."
      );
    }

    const originalAudio = Buffer.from(
      await response.arrayBuffer()
    );
    if (validated.text.length <= 240) {
      return new Response(originalAudio, {
        status: 200,
        headers: {
          "content-type":
            SUPPORTED_OUTPUT_FORMATS.get(validated.outputFormat),
          "cache-control": "no-store"
        }
      });
    }
    let normalizedAudio = originalAudio;
    try {
      normalizedAudio = await normalizeImplementation(
        originalAudio,
        context.signal
      );
    } catch {
      normalizedAudio = originalAudio;
    }

    return new Response(normalizedAudio, {
      status: 200,
      headers: {
        "content-type":
          SUPPORTED_OUTPUT_FORMATS.get(validated.outputFormat),
        "cache-control": "no-store"
      }
    });
  };
}

export async function normalizeMP3(audio, signal) {
  if (!ffmpegPath || !audio?.length) {
    return audio;
  }
  return new Promise((resolve, reject) => {
    const process = spawn(
      ffmpegPath,
      [
        "-hide_banner",
        "-loglevel", "error",
        "-i", "pipe:0",
        "-af", "loudnorm=I=-18:LRA=7:TP=-1.5",
        "-codec:a", "libmp3lame",
        "-b:a", "128k",
        "-ar", "44100",
        "-ac", "1",
        "-f", "mp3",
        "pipe:1"
      ],
      {
        stdio: ["pipe", "pipe", "ignore"]
      }
    );
    const chunks = [];
    const abort = () => {
      process.kill("SIGTERM");
      reject(new Error("Audio normalization cancelled."));
    };
    signal?.addEventListener("abort", abort, { once: true });
    process.stdout.on("data", (chunk) => chunks.push(chunk));
    process.on("error", reject);
    process.on("close", (code) => {
      signal?.removeEventListener("abort", abort);
      const output = Buffer.concat(chunks);
      if (code === 0 && output.length > 0) {
        resolve(output);
      } else {
        reject(new Error("Audio normalization failed."));
      }
    });
    process.stdin.end(audio);
  });
}

export function validateSpeechCriteria(
  criteria,
  configuredVoiceIdentifier = DEFAULT_VOICE_ID
) {
  if (!criteria || typeof criteria !== "object"
      || Array.isArray(criteria)) {
    throw new GatewayError(
      422,
      "invalid_speech_request",
      "Speech generation requires a request object."
    );
  }

  const text = String(criteria.text ?? "").trim();
  if (text.length < 1 || text.length > MAX_TEXT_LENGTH) {
    throw new GatewayError(
      422,
      "invalid_speech_text",
      "Speech text must contain between 1 and 800 characters."
    );
  }

  const requestedVoice = String(
    criteria.voiceIdentifier ?? configuredVoiceIdentifier
  ).trim();
  if (requestedVoice !== configuredVoiceIdentifier) {
    throw new GatewayError(
      422,
      "invalid_voice_identifier",
      "The requested G.I.A. voice is not available."
    );
  }

  const outputFormat = String(
    criteria.outputFormat ?? "mp3_44100_128"
  );
  if (!SUPPORTED_OUTPUT_FORMATS.has(outputFormat)) {
    throw new GatewayError(
      422,
      "invalid_speech_output_format",
      "The requested speech output format is unsupported."
    );
  }

  return {
    text,
    voiceIdentifier: requestedVoice,
    outputFormat
  };
}

function mapElevenLabsError(status) {
  if (status === 429) {
    return new GatewayError(
      503,
      "speech_capacity_unavailable",
      "Speech generation is busy. Try again shortly."
    );
  }
  if (status === 401 || status === 403) {
    return new GatewayError(
      502,
      "speech_provider_authorization_failed",
      "Speech generation is temporarily unavailable."
    );
  }
  return new GatewayError(
    502,
    "speech_provider_failed",
    "Speech generation is temporarily unavailable."
  );
}
