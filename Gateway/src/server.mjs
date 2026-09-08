import { createServer } from "node:http";

import { createGateway } from "./gateway.mjs";
import { createOpenAIPlanner } from "./providers/openai-planner.mjs";
import {
  createOpenAIConversationResponder
} from "./providers/openai-conversation.mjs";
import {
  createOpenAIReplyInterpreter
} from "./providers/openai-interpret-reply.mjs";
import {
  createSerpApiFlightSearch,
  createSerpApiRoundTripCompletion
} from "./providers/serpapi-flights.mjs";
import {
  createSerpApiHotelSearch
} from "./providers/serpapi-hotels.mjs";
import {
  createPlaceDiscovery
} from "./providers/place-discovery.mjs";
import {
  createSerpApiEventSearch
} from "./providers/serpapi-events.mjs";
import {
  createGeoapifyRoutePlanning
} from "./providers/geoapify-routes.mjs";
import {
  createGeoapifyLocationResolver
} from "./providers/geoapify-location.mjs";
import {
  createWeatherAPIProvider
} from "./providers/weatherapi-weather.mjs";
import {
  createTranslationProvider
} from "./providers/translation-provider.mjs";
import {
  createElevenLabsSpeech
} from "./providers/elevenlabs-speech.mjs";
import {
  bufferSpeechResponse,
  createSpeechPrefetchCache
} from "./speech-prefetch-cache.mjs";
import {
  normalizeGatewayEnvironment
} from "./provider-environment.mjs";
import {
  createSerialProviderQueue
} from "./provider-queue.mjs";

const gatewayEnvironment =
  normalizeGatewayEnvironment(process.env);
const strictProviderErrors =
  gatewayEnvironment.STRICT_PROVIDER_ERRORS === "1";
const serpApiQueue = createSerialProviderQueue();
const serializeSerpApi = (handler) => (
  body,
  context
) => serpApiQueue.run(() => handler(body, context));

const speechCache = createSpeechPrefetchCache();
const generateSpeech = createElevenLabsSpeech({
  apiKey: gatewayEnvironment.ELEVENLABS_API_KEY,
  voiceIdentifier:
    gatewayEnvironment.ELEVENLABS_VOICE_ID
    ?? "3Drdg7QWqr45nZmYpXRP",
  modelIdentifier:
    gatewayEnvironment.ELEVENLABS_MODEL_ID
    ?? "eleven_flash_v2_5"
});

function prefetchConversationSpeech(text) {
  const promise = Promise.resolve(
    generateSpeech({
      text,
      outputFormat: "mp3_44100_128"
    })
  ).then(bufferSpeechResponse);
  speechCache.store(text, promise);
}

async function generateSpeechWithPrefetch(body, context) {
  const cached = speechCache.take(
    typeof body?.text === "string" ? body.text : ""
  );
  if (cached) {
    try {
      return await cached;
    } catch {
      // Fall through to a fresh speech request.
    }
  }
  return generateSpeech(body, context);
}

const port = readPort(gatewayEnvironment.PORT);
const handle = createGateway({
  env: gatewayEnvironment,
  handlers: {
    resolveLocation: createGeoapifyLocationResolver({
      apiKey: gatewayEnvironment.GEOAPIFY_API_KEY
    }),
    generateResponse: createOpenAIConversationResponder({
      apiKey: gatewayEnvironment.OPENAI_API_KEY,
      model: gatewayEnvironment.OPENAI_RESPONSE_MODEL
        ?? "gpt-5.4-mini",
      prefetchSpeech: prefetchConversationSpeech
    }),
    interpretReply: createOpenAIReplyInterpreter({
      apiKey: gatewayEnvironment.OPENAI_API_KEY,
      model: gatewayEnvironment.OPENAI_RESPONSE_MODEL
        ?? "gpt-5.4-mini"
    }),
    plan: createOpenAIPlanner({
      apiKey: gatewayEnvironment.OPENAI_API_KEY,
      model: gatewayEnvironment.OPENAI_MODEL ?? "gpt-5.4"
    }),
    searchFlights: serializeSerpApi(
      createSerpApiFlightSearch({
        apiKey: gatewayEnvironment.SERPAPI_API_KEY
      })
    ),
    completeRoundTrip: serializeSerpApi(
      createSerpApiRoundTripCompletion({
        apiKey: gatewayEnvironment.SERPAPI_API_KEY
      })
    ),
    searchHotels: serializeSerpApi(
      createSerpApiHotelSearch({
        apiKey: gatewayEnvironment.SERPAPI_API_KEY
      })
    ),
    searchPlaces: createPlaceDiscovery({
      geoapifyKey: gatewayEnvironment.GEOAPIFY_API_KEY,
      serpApiKey: gatewayEnvironment.SERPAPI_API_KEY,
      strictProviderErrors
    }),
    searchEvents: serializeSerpApi(
      createSerpApiEventSearch({
        apiKey: gatewayEnvironment.SERPAPI_API_KEY
      })
    ),
    planRoute: createGeoapifyRoutePlanning({
      apiKey: gatewayEnvironment.GEOAPIFY_API_KEY,
      strictProviderErrors
    }),
    getWeather: createWeatherAPIProvider({
      apiKey: gatewayEnvironment.WEATHERAPI_API_KEY,
      forecastDaysLimit:
        gatewayEnvironment.WEATHERAPI_FORECAST_DAYS_LIMIT
    }),
    generateSpeech: generateSpeechWithPrefetch,
    translate: createTranslationProvider({
      provider: gatewayEnvironment.TRANSLATION_PROVIDER,
      apiKey: gatewayEnvironment.TRANSLATION_API_KEY,
      baseURL: gatewayEnvironment.TRANSLATION_BASE_URL
    })
  }
});

const server = createServer(async (incoming, outgoing) => {
  try {
    const request = await makeRequest(incoming);
    const response = await handle(request, {
      clientIdentifier:
        incoming.socket.remoteAddress ?? "local"
    });

    outgoing.statusCode = response.status;
    response.headers.forEach((value, name) => {
      outgoing.setHeader(name, value);
    });
    outgoing.end(Buffer.from(await response.arrayBuffer()));

    const requestId =
      response.headers.get("x-request-id") ?? "unknown";
    console.info(
      `${incoming.method} ${requestURL(incoming).pathname}`
      + ` ${response.status} ${requestId}`
    );
  } catch {
    outgoing.statusCode = 400;
    outgoing.setHeader(
      "content-type",
      "application/json; charset=utf-8"
    );
    outgoing.setHeader("cache-control", "no-store");
    outgoing.end(
      JSON.stringify({
        error: {
          code: "invalid_request",
          message: "The HTTP request could not be read."
        }
      })
    );
  }
});

server.listen(port, "127.0.0.1", () => {
  console.info(
    `G.I.A. gateway listening on http://127.0.0.1:${port}`
  );
});

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => {
    server.close(() => process.exit(0));
  });
}

async function makeRequest(incoming) {
  const method = incoming.method ?? "GET";
  const hasBody = method !== "GET" && method !== "HEAD";
  const body = hasBody ? await readBody(incoming) : undefined;

  return new Request(requestURL(incoming), {
    method,
    headers: incoming.headers,
    body
  });
}

function requestURL(incoming) {
  const host = incoming.headers.host ?? "127.0.0.1";
  return new URL(incoming.url ?? "/", `http://${host}`);
}

async function readBody(incoming) {
  const chunks = [];
  let totalBytes = 0;

  for await (const chunk of incoming) {
    totalBytes += chunk.length;
    if (totalBytes > 64 * 1024) {
      throw new Error("Request body exceeded the gateway limit.");
    }
    chunks.push(chunk);
  }

  return Buffer.concat(chunks);
}

function readPort(value) {
  const parsed = Number.parseInt(value ?? "8787", 10);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > 65_535) {
    throw new Error("PORT must be between 1 and 65535.");
  }
  return parsed;
}
