import assert from "node:assert/strict";
import test from "node:test";

import { createGateway } from "../src/gateway.mjs";

test("health reports configuration without exposing secrets", async () => {
  const secret = "serp-secret-value";
  const handle = createGateway({
    env: {
      GATEWAY_ACCESS_TOKEN: "gateway-token",
      SERPAPI_API_KEY: secret
    }
  });

  const response = await handle(
    new Request("http://localhost/health")
  );
  const text = await response.text();
  const payload = JSON.parse(text);

  assert.equal(response.status, 200);
  assert.equal(payload.providers.serpApi, true);
  assert.equal(payload.providers.openAI, false);
  assert.deepEqual(payload.configurationIssues, []);
  assert.equal(text.includes(secret), false);
});

test("health reports incomplete translation configuration safely", async () => {
  const secret = "translation-secret-value";
  const handle = createGateway({
    env: {
      GATEWAY_ACCESS_TOKEN: "gateway-token",
      TRANSLATION_API_KEY: secret
    }
  });

  const response = await handle(
    new Request("http://localhost/health")
  );
  const text = await response.text();
  const payload = JSON.parse(text);

  assert.equal(response.status, 200);
  assert.equal(payload.providers.translation, false);
  assert.deepEqual(
    payload.configurationIssues,
    ["translation_provider_missing"]
  );
  assert.equal(text.includes(secret), false);
});

test("provider routes fail closed without gateway authentication", async () => {
  const handle = createGateway({ env: {} });
  const response = await handle(jsonRequest("/v1/plan"));
  const payload = await response.json();

  assert.equal(response.status, 503);
  assert.equal(
    payload.error.code,
    "gateway_authentication_not_configured"
  );
});

test("provider routes reject an invalid bearer token", async () => {
  const handle = createGateway({
    env: {
      GATEWAY_ACCESS_TOKEN: "correct-token"
    }
  });
  const response = await handle(
    jsonRequest("/v1/plan", {
      token: "incorrect-token"
    })
  );

  assert.equal(response.status, 401);
});

test("unconnected providers return a structured response", async () => {
  const handle = createGateway({
    env: {
      GATEWAY_ACCESS_TOKEN: "correct-token"
    }
  });
  const response = await handle(
    jsonRequest("/v1/search/flights", {
      token: "correct-token"
    })
  );
  const payload = await response.json();

  assert.equal(response.status, 501);
  assert.equal(payload.error.code, "provider_not_connected");
  assert.ok(response.headers.get("x-request-id"));
});

test("connected handlers return data through the gateway envelope", async () => {
  const handle = createGateway({
    env: {
      GATEWAY_ACCESS_TOKEN: "correct-token"
    },
    handlers: {
      plan: async (body) => ({
        acceptedDestination: body.destination
      })
    }
  });
  const response = await handle(
    jsonRequest("/v1/plan", {
      token: "correct-token",
      body: {
        destination: "Lisbon"
      }
    })
  );
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.deepEqual(payload.data, {
    acceptedDestination: "Lisbon"
  });
});

test("location resolution uses its authenticated gateway route", async () => {
  const handle = createGateway({
    env: {
      GATEWAY_ACCESS_TOKEN: "correct-token"
    },
    handlers: {
      resolveLocation: async (body) => ({
        id: "11111111-1111-4111-8111-111111111111",
        name: body.query,
        city: body.query,
        coordinate: {
          latitude: 64.1466,
          longitude: -21.9426
        },
        timeZoneIdentifier: "Atlantic/Reykjavik",
        iataCode: null
      })
    }
  });
  const response = await handle(
    jsonRequest("/v1/resolve/location", {
      token: "correct-token",
      body: {
        query: "Reykjavík",
        includeNearestAirport: true
      }
    })
  );
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.data.name, "Reykjavík");
  assert.equal(
    payload.data.timeZoneIdentifier,
    "Atlantic/Reykjavik"
  );
});

test("conversation responses use the secured JSON envelope", async () => {
  const handle = createGateway({
    env: {
      GATEWAY_ACCESS_TOKEN: "correct-token"
    },
    handlers: {
      generateResponse: async (body) => ({
        spokenText: "Okay—I've got it.",
        displayText: "Request captured.",
        intent: body.intent,
        shouldContinueListening: false
      })
    }
  });
  const response = await handle(
    jsonRequest("/v1/respond", {
      token: "correct-token",
      body: {
        intent: "requestCaptured"
      }
    })
  );
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.data.intent, "requestCaptured");
  assert.equal(payload.data.shouldContinueListening, false);
});

test("reply interpretation uses the secured JSON envelope", async () => {
  const handle = createGateway({
    env: {
      GATEWAY_ACCESS_TOKEN: "correct-token"
    },
    handlers: {
      interpretReply: async (body) => ({
        understanding: "understood",
        spokenText: null,
        destination: null,
        origin: null,
        dateStart: "2026-09-07",
        dateEnd: "2026-09-13",
        durationDays: 7,
        travelerCount: null,
        budgetAmount: null,
        budgetCurrency: null,
        utterance: body.utterance
      })
    }
  });
  const response = await handle(
    jsonRequest("/v1/interpret-reply", {
      token: "correct-token",
      body: {
        utterance: "stay a week",
        askedField: "dates",
        today: "2026-09-07"
      }
    })
  );
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.data.understanding, "understood");
  assert.equal(payload.data.durationDays, 7);
});

test("speech handlers can return secured binary responses", async () => {
  const handle = createGateway({
    env: {
      GATEWAY_ACCESS_TOKEN: "correct-token"
    },
    handlers: {
      generateSpeech: async () => new Response(
        new Uint8Array([0x49, 0x44, 0x33]),
        {
          headers: {
            "content-type": "audio/mpeg",
            "x-provider-secret": "must-not-pass-through"
          }
        }
      )
    }
  });
  const response = await handle(
    jsonRequest("/v1/speech", {
      token: "correct-token"
    })
  );

  assert.equal(response.status, 200);
  assert.equal(
    response.headers.get("content-type"),
    "audio/mpeg"
  );
  assert.equal(
    response.headers.get("cache-control"),
    "no-store"
  );
  assert.equal(
    response.headers.has("x-provider-secret"),
    false
  );
  assert.deepEqual(
    new Uint8Array(await response.arrayBuffer()),
    new Uint8Array([0x49, 0x44, 0x33])
  );
});

test("browser origins are denied unless explicitly allowed", async () => {
  const handle = createGateway({
    env: {
      ALLOWED_ORIGINS: "https://gia.example"
    }
  });
  const response = await handle(
    new Request("http://localhost/health", {
      headers: {
        origin: "https://attacker.example"
      }
    })
  );

  assert.equal(response.status, 403);
  assert.equal(
    response.headers.has("access-control-allow-origin"),
    false
  );
});

test("rate limiting is applied before provider execution", async () => {
  const handle = createGateway({
    env: {
      GATEWAY_ACCESS_TOKEN: "correct-token",
      RATE_LIMIT_MAX: "1"
    },
    handlers: {
      plan: async () => ({ status: "accepted" })
    }
  });
  const first = await handle(
    jsonRequest("/v1/plan", {
      token: "correct-token"
    }),
    {
      clientIdentifier: "test-client"
    }
  );
  const second = await handle(
    jsonRequest("/v1/plan", {
      token: "correct-token"
    }),
    {
      clientIdentifier: "test-client"
    }
  );

  assert.equal(first.status, 200);
  assert.equal(second.status, 429);
});

test("unexpected provider errors never expose internal details", async () => {
  const sensitiveMessage = "provider key was secret-value";
  const handle = createGateway({
    env: {
      GATEWAY_ACCESS_TOKEN: "correct-token"
    },
    handlers: {
      plan: async () => {
        throw new Error(sensitiveMessage);
      }
    }
  });
  const response = await handle(
    jsonRequest("/v1/plan", {
      token: "correct-token"
    })
  );
  const text = await response.text();

  assert.equal(response.status, 500);
  assert.equal(text.includes(sensitiveMessage), false);
  assert.equal(text.includes("secret-value"), false);
});

function jsonRequest(
  path,
  {
    token,
    body = {}
  } = {}
) {
  const headers = new Headers({
    "content-type": "application/json"
  });
  if (token) {
    headers.set("authorization", `Bearer ${token}`);
  }

  return new Request(`http://localhost${path}`, {
    method: "POST",
    headers,
    body: JSON.stringify(body)
  });
}
