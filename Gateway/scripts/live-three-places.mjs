import assert from "node:assert/strict";

const gatewayURL = new URL(
  process.env.GIA_GATEWAY_BASE_URL ?? "http://127.0.0.1:8787"
);
const gatewayToken =
  process.env.GIA_GATEWAY_ACCESS_TOKEN
  ?? process.env.GATEWAY_ACCESS_TOKEN;

if (!gatewayToken) {
  throw new Error("GATEWAY_ACCESS_TOKEN is required.");
}

const places = [
  {
    kind: "country",
    query: "Japan",
    utterance: "I want to go to Japan"
  },
  {
    kind: "europeanCity",
    query: "Lisbon, Portugal",
    utterance: "Plan a trip to Lisbon"
  },
  {
    kind: "usCity",
    query: "New York, New York",
    utterance: "I want to go to New York"
  }
];

const healthResponse = await timedFetch(new URL("/health", gatewayURL));
assert.equal(healthResponse.status, 200, "Gateway is not healthy.");
assert.equal(healthResponse.data?.status, "ok", "Gateway is not healthy.");

const summaries = [];

for (const place of places) {
  const reply = await post("/v1/respond", {
    intent: "clarificationNeeded",
    requestSummary: `Destination is ${place.query}. Travel dates are missing.`,
    groundedFacts: [
      `User said: ${place.utterance}`,
      "Missing or invalid: Which dates work?",
      "Ask for travel dates next. Do not ask what to keep, change, or remove."
    ]
  });
  assert.equal(reply.status, 200, `${place.query} conversation failed.`);
  const spoken = String(reply.data?.data?.spokenText ?? "");
  const display = String(reply.data?.data?.displayText ?? "");
  const combined = `${spoken} ${display}`.toLowerCase();
  assert.equal(
    reply.data?.data?.shouldContinueListening,
    true,
    `${place.query} did not keep listening.`
  );
  assert.match(
    combined,
    /date/,
    `${place.query} did not ask for dates.`
  );
  assert.doesNotMatch(
    combined,
    /\b(keep|change|remove)\b/,
    `${place.query} used edit-command copy.`
  );

  const location = await post("/v1/resolve/location", {
    query: place.query,
    includeNearestAirport: true
  });
  assert.equal(location.status, 200, `${place.query} location failed.`);
  const resolved = location.data?.data ?? {};
  assert.ok(resolved.coordinate, `${place.query} has no coordinate.`);
  assert.ok(
    resolved.timeZoneIdentifier,
    `${place.query} has no time zone.`
  );

  const discovered = await post("/v1/search/places", {
    destination: resolved,
    categories: ["restaurant", "museum", "park"],
    interests: ["food", "museums"],
    dietaryRequirements: [],
    accessibilityRequirements: [],
    radiusMeters: 12_000,
    limit: 8
  });
  assert.equal(discovered.status, 200, `${place.query} places failed.`);
  const found = discovered.data?.data?.places ?? [];
  assert.ok(
    found.length > 0,
    `${place.query} returned no live places.`
  );

  summaries.push({
    kind: place.kind,
    query: place.query,
    spokenPreview: spoken.slice(0, 80),
    placeCount: found.length,
    firstPlace: found[0]?.name ?? null,
    hasAirport: Boolean(resolved.iataCode)
  });
}

console.log(JSON.stringify({ ok: true, destinations: summaries }, null, 2));

async function post(path, body) {
  return timedFetch(new URL(path, gatewayURL), {
    method: "POST",
    headers: {
      authorization: `Bearer ${gatewayToken}`,
      "content-type": "application/json",
      accept: "application/json"
    },
    body: JSON.stringify(body)
  });
}

async function timedFetch(url, options = {}) {
  const response = await fetch(url, options);
  const data = await response.json().catch(() => ({}));
  return {
    status: response.status,
    data
  };
}
