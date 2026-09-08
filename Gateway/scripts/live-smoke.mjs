import {
  readdir,
  readFile
} from "node:fs/promises";
import { homedir } from "node:os";
import { extname, join, resolve } from "node:path";

const gatewayURL = new URL(
  process.env.GIA_GATEWAY_BASE_URL
    ?? "http://127.0.0.1:8787"
);
const gatewayToken =
  process.env.GIA_GATEWAY_ACCESS_TOKEN
  ?? process.env.GATEWAY_ACCESS_TOKEN;
const projectRoot = resolve(import.meta.dirname, "../..");
const results = [];

if (!gatewayToken) {
  throw new Error("GATEWAY_ACCESS_TOKEN is required.");
}

const flightPreferences = {
  travelClass: "economy",
  stopPreference: "any",
  preferredAirlines: [],
  excludedAirlines: [],
  checkedBagRequired: false,
  refundablePreferred: false
};
const hotelPreferences = {
  lodgingTypes: [],
  minimumStarRating: null,
  minimumGuestRating: null,
  requiredAmenities: [],
  refundablePreferred: false,
  maximumNightlyRate: null
};
const tripStart = futureDate(35);
const tripEnd = futureDate(39);
const weatherStart = futureDate(1);
const weatherEnd = futureDate(2);

const health = await record("gateway", async () => {
  const response = await timedFetch(new URL("/health", gatewayURL));
  assert(response.status === 200, "Health did not return HTTP 200.");
  assert(response.data?.status === "ok", "Gateway is not healthy.");
  return {
    value: response.data,
    detail: {
      milliseconds: response.milliseconds,
      configuredProviders: Object.entries(
        response.data.providers ?? {}
      )
        .filter(([, configured]) => configured)
        .map(([provider]) => provider),
      configurationIssues:
        response.data.configurationIssues ?? []
    }
  };
});

const serpApiAccount = await record("serpApiAccount", async () => {
  const url = new URL("https://serpapi.com/account.json");
  url.searchParams.set(
    "api_key",
    process.env.SERPAPI_API_KEY ?? ""
  );
  const response = await timedFetch(url);
  assert(response.status === 200, "SerpAPI account is unavailable.");
  assert(!response.data?.error, response.data?.error);
  return {
    value: response.data,
    detail: {
      planName: response.data.plan_name ?? "Unknown",
      searchesLeft: response.data.total_searches_left ?? null
    }
  };
});
const supportsStructuredEvents =
  !String(serpApiAccount?.plan_name ?? "")
    .toLowerCase()
    .includes("free");

await record("secretBoundary", async () => {
  const credentialValues = [
    process.env.SERPAPI_API_KEY,
    process.env.OPENAI_API_KEY,
    process.env.ELEVENLABS_API_KEY,
    process.env.GEOAPIFY_API_KEY,
    process.env.WEATHERAPI_API_KEY,
    process.env.TRANSLATION_API_KEY
  ].filter((value) => typeof value === "string" && value.length >= 8);
  const roots = [
    join(projectRoot, "GIA"),
    join(projectRoot, "GIA.xcodeproj")
  ];
  const appBundle = process.env.GIA_APP_BUNDLE_PATH
    ? resolve(process.env.GIA_APP_BUNDLE_PATH)
    : null;
  if (appBundle) {
    roots.push(appBundle.replace(/^~/u, homedir()));
  }
  const files = (
    await Promise.all(roots.map((root) => readableFiles(root)))
  ).flat();
  for (const file of files) {
    const data = await readFile(file);
    for (const credential of credentialValues) {
      assert(
        data.indexOf(Buffer.from(credential)) === -1,
        `A provider credential was found in ${file}.`
      );
    }
  }
  return {
    detail: {
      scannedFiles: files.length,
      appBundleScanned: Boolean(appBundle)
    }
  };
});

const destination = await record("geoapifyDestination", async () => {
  const response = await post("/v1/resolve/location", {
    query: "Chicago, Illinois",
    includeNearestAirport: true
  });
  assert(response.status === 200, providerError(response));
  assert(response.data?.data?.coordinate, "Destination has no coordinate.");
  assert(
    response.data?.data?.timeZoneIdentifier,
    "Destination has no time zone."
  );
  return {
    value: response.data.data,
    detail: {
      milliseconds: response.milliseconds,
      hasCoordinate: true,
      hasTimeZone: true,
      hasAirport: Boolean(response.data.data.iataCode)
    }
  };
});

const origin = await record("geoapifyOrigin", async () => {
  const response = await post("/v1/resolve/location", {
    query: "Atlanta, Georgia",
    includeNearestAirport: true
  });
  assert(response.status === 200, providerError(response));
  assert(response.data?.data?.iataCode, "Origin has no airport code.");
  return {
    value: response.data.data,
    detail: {
      milliseconds: response.milliseconds,
      hasAirport: true
    }
  };
});

const routeDestination = await record(
  "geoapifyRouteDestination",
  async () => {
    const response = await post("/v1/resolve/location", {
      query: "Millennium Park, Chicago",
      includeNearestAirport: false
    });
    assert(response.status === 200, providerError(response));
    assert(
      response.data?.data?.coordinate,
      "Route destination has no coordinate."
    );
    return {
      value: response.data.data,
      detail: {
        milliseconds: response.milliseconds,
        hasCoordinate: true
      }
    };
  }
);

let searchCriteria;
let request;
if (origin && destination) {
  searchCriteria = {
    origin,
    destination,
    departureDate: tripStart.toISOString(),
    returnDate: tripEnd.toISOString(),
    adults: 1,
    children: 0,
    currencyCode: "USD",
    preferences: flightPreferences
  };
  request = {
    rawTranscript: "Live provider smoke request",
    origin,
    destinations: [destination],
    dateRange: {
      start: tripStart.toISOString(),
      end: tripEnd.toISOString(),
      timeZoneIdentifier:
        destination.timeZoneIdentifier ?? "America/Chicago"
    },
    durationDays: 5,
    travelerCount: 1,
    totalBudget: null,
    interests: ["food", "museums"],
    dietaryRequirements: [],
    accessibilityRequirements: [],
    preferredPace: "balanced",
    flightPreferences,
    hotelPreferences
  };
}

const providerSearches = request
  ? await Promise.all([
      record("serpApiFlights", async () => {
        const response = await post(
          "/v1/search/flights",
          searchCriteria
        );
        assert(response.status === 200, providerError(response));
        const offers = response.data?.data?.offers ?? [];
        assert(offers.length > 0, "No live flight offers were returned.");
        assertLive(offers, "flight");
        assert(
          offers.every((offer) => offer.returnSegments.length === 0),
          "Initial flight search unexpectedly completed return legs."
        );
        return {
          value: offers,
          detail: {
            milliseconds: response.milliseconds,
            count: offers.length,
            completionReady:
              offers.filter((offer) => offer.continuationToken).length
          }
        };
      }),
      record("serpApiHotels", async () => {
        const response = await post("/v1/search/hotels", {
          destination,
          checkInDate: tripStart.toISOString(),
          checkOutDate: tripEnd.toISOString(),
          adults: 1,
          rooms: 1,
          currencyCode: "USD",
          preferences: hotelPreferences
        });
        assert(response.status === 200, providerError(response));
        const offers = response.data?.data?.offers ?? [];
        assert(offers.length > 0, "No live hotel offers were returned.");
        assertLive(offers, "hotel");
        return {
          value: offers,
          detail: {
            milliseconds: response.milliseconds,
            count: offers.length
          }
        };
      }),
      record("placeDiscovery", async () => {
        const response = await post("/v1/search/places", {
          destination,
          categories: ["restaurant", "museum", "park"],
          interests: ["food", "museums"],
          dietaryRequirements: [],
          accessibilityRequirements: [],
          radiusMeters: 10_000,
          limit: 8
        });
        assert(response.status === 200, providerError(response));
        const places = response.data?.data?.places ?? [];
        assert(places.length > 0, "No live places were returned.");
        assertLive(places, "place");
        return {
          value: places,
          detail: {
            milliseconds: response.milliseconds,
            count: places.length,
            providers: uniqueProviders(places)
          }
        };
      }),
      supportsStructuredEvents
        ? record("serpApiEvents", async () => {
            const response = await post("/v1/search/events", {
              destination,
              dateRange: request.dateRange,
              query: null,
              interests: ["food", "museums"],
              limit: 5
            });
            assert(response.status === 200, providerError(response));
            const events = response.data?.data?.events ?? [];
            assertLive(events, "event");
            return {
              value: events,
              detail: {
                milliseconds: response.milliseconds,
                count: events.length
              }
            };
          })
        : skip(
            "serpApiEvents",
            "Google Events is unavailable on the SerpAPI Free Plan."
          ),
      record("weatherAPI", async () => {
        const response = await post("/v1/weather", {
          location: destination,
          dateRange: {
            start: weatherStart.toISOString(),
            end: weatherEnd.toISOString(),
            timeZoneIdentifier:
              destination.timeZoneIdentifier ?? "America/Chicago"
          },
          includeAlerts: true
        });
        assert(response.status === 200, providerError(response));
        const snapshots = response.data?.data?.snapshots ?? [];
        assert(snapshots.length > 0, "No live weather was returned.");
        assertLive(snapshots, "weather");
        return {
          value: snapshots,
          detail: {
            milliseconds: response.milliseconds,
            count: snapshots.length
          }
        };
      })
    ])
  : [null, null, null, null, null];

let [flights, hotels, places, events, weather] = providerSearches;

if (searchCriteria && flights?.length) {
  const outbound = flights.find((offer) => offer.continuationToken);
  const completedFlights = await record(
    "serpApiReturnFlights",
    async () => {
      assert(outbound, "No outbound offer had a continuation token.");
      const response = await post(
        "/v1/search/flights/return",
        {
          searchCriteria,
          outboundOffer: outbound
        }
      );
      assert(response.status === 200, providerError(response));
      const offers = response.data?.data?.offers ?? [];
      assert(offers.length > 0, "No return flight options were returned.");
      assertLive(offers, "completed flight");
      assert(
        offers.every(
          (offer) => (
            offer.outboundSegments.length > 0
            && offer.returnSegments.length > 0
            && offer.continuationToken == null
          )
        ),
        "A completed flight is missing one of its legs."
      );
      return {
        value: offers,
        detail: {
          milliseconds: response.milliseconds,
          count: offers.length
        }
      };
    }
  );
  if (completedFlights?.length) {
    flights = completedFlights;
  }
}

const routes =
  destination && routeDestination
    ? await record("geoapifyRoutes", async () => {
        const response = await post("/v1/route", {
          origin: destination,
          destination: routeDestination,
          modes: ["walking", "transit"],
          departure: tripStart.toISOString(),
          currencyCode: "USD"
        });
        assert(response.status === 200, providerError(response));
        const values = response.data?.data?.routes ?? [];
        assert(values.length > 0, "No live routes were returned.");
        assertLive(values, "route");
        return {
          value: values,
          detail: {
            milliseconds: response.milliseconds,
            count: values.length
          }
        };
      })
    : null;

if (request) {
  await record("openAIPlan", async () => {
    const response = await post("/v1/plan", {
      request,
      flightOffers: (flights ?? []).slice(0, 4),
      hotelOffers: (hotels ?? []).slice(0, 4),
      places: (places ?? []).slice(0, 8),
      events: (events ?? []).slice(0, 5),
      routes: (routes ?? []).slice(0, 4),
      weather: (weather ?? []).slice(0, 3)
    });
    assert(response.status === 200, providerError(response));
    const plan = response.data?.data;
    assert(plan?.days?.length > 0, "OpenAI returned no itinerary days.");
    const allowed = new Set([
      ...(flights ?? []).map((value) => value.id),
      ...(hotels ?? []).map((value) => value.id),
      ...(places ?? []).map((value) => value.id),
      ...(events ?? []).map((value) => value.id),
      ...(routes ?? []).map((value) => value.id)
    ]);
    const items = plan.days.flatMap((day) => day.items);
    assert(
      items.every((item) => (
        item.sourceKind === "free_time"
          ? item.sourceIdentifier === null
          : allowed.has(item.sourceIdentifier)
      )),
      "OpenAI returned an ungrounded source identifier."
    );
    return {
      value: plan,
      detail: {
        milliseconds: response.milliseconds,
        days: plan.days.length,
        items: items.length
      }
    };
  });
}

await record("elevenLabs", async () => {
  const response = await post(
    "/v1/speech",
    {
      text: "Live provider verification complete.",
      voiceIdentifier: "3Drdg7QWqr45nZmYpXRP",
      outputFormat: "mp3_44100_128"
    },
    "audio/mpeg"
  );
  assert(response.status === 200, providerError(response));
  assert(
    response.contentType.startsWith("audio/mpeg"),
    "Speech response is not MPEG audio."
  );
  assert(response.data.byteLength > 1_000, "Speech audio is empty.");
  return {
    detail: {
      milliseconds: response.milliseconds,
      bytes: response.data.byteLength,
      contentType: response.contentType
    }
  };
});

await record("googleTranslation", async () => {
  const response = await post("/v1/translation", {
    text: "GIA found a hotel near Chicago.",
    sourceLanguageCode: "en",
    targetLanguageCode: "es",
    contentKind: "travelMessage",
    protectedTerms: ["GIA", "Chicago"]
  });
  assert(response.status === 200, providerError(response));
  const translation = response.data?.data;
  assert(translation?.isMachineTranslated, "Translation was not produced.");
  assert(
    translation.originalText === "GIA found a hotel near Chicago.",
    "Translation did not preserve the original."
  );
  assert(
    translation.translatedText.includes("GIA")
      && translation.translatedText.includes("Chicago"),
    "Translation changed a protected term."
  );
  return {
    detail: {
      milliseconds: response.milliseconds,
      provider: translation.provenance?.provider,
      targetLanguageCode: translation.targetLanguageCode
    }
  };
});

await record("noBookingClaims", async () => {
  const values = [flights, hotels, places, events, routes]
    .flat()
    .filter(Boolean);
  const serialized = JSON.stringify(values);
  assert(
    !/"(?:bookingStatus|providerConfirmationCode|purchaseComplete)"/u
      .test(serialized),
    "A live search response claimed a booking."
  );
  return {
    detail: {
      providerObjectsChecked: values.length
    }
  };
});

const summary = {
  ok: results.every((result) => result.status !== "failed"),
  passed: results.filter((result) => result.status === "passed").length,
  skipped: results.filter((result) => result.status === "skipped").length,
  failed: results.filter((result) => result.status === "failed").length,
  results
};
console.log(JSON.stringify(summary, null, 2));
if (!summary.ok) {
  process.exitCode = 1;
}

async function record(name, operation) {
  try {
    const result = await operation();
    results.push({
      name,
      status: "passed",
      ...(result?.detail ? { detail: result.detail } : {})
    });
    return result?.value ?? null;
  } catch (error) {
    results.push({
      name,
      status: "failed",
      error: safeError(error)
    });
    return null;
  }
}

function skip(name, reason) {
  results.push({
    name,
    status: "skipped",
    reason
  });
  return Promise.resolve([]);
}

async function post(path, body, accept = "application/json") {
  return timedFetch(
    new URL(path, gatewayURL),
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${gatewayToken}`,
        "content-type": "application/json",
        accept
      },
      body: JSON.stringify(body)
    },
    accept
  );
}

async function timedFetch(url, options = {}, accept = "application/json") {
  const startedAt = performance.now();
  const response = await fetch(url, options);
  const contentType = response.headers.get("content-type") ?? "";
  const data = accept.startsWith("audio/")
    ? Buffer.from(await response.arrayBuffer())
    : await response.json().catch(() => ({}));
  return {
    status: response.status,
    contentType,
    data,
    milliseconds: Math.round(performance.now() - startedAt)
  };
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function assertLive(values, label) {
  assert(Array.isArray(values), `${label} response is not an array.`);
  assert(
    values.every(
      (value) => value?.provenance?.origin === "live"
    ),
    `A ${label} result was not marked live.`
  );
  assert(
    values.every(
      (value) => value?.provenance?.provider
    ),
    `A ${label} result has no provider provenance.`
  );
}

function providerError(response) {
  const code = response.data?.error?.code ?? "unknown_error";
  const message =
    response.data?.error?.message ?? "Provider request failed.";
  return `${code}: ${message}`;
}

function safeError(error) {
  const text = String(error?.message ?? "Unknown failure");
  const credentials = [
    gatewayToken,
    process.env.SERPAPI_API_KEY,
    process.env.OPENAI_API_KEY,
    process.env.ELEVENLABS_API_KEY,
    process.env.GEOAPIFY_API_KEY,
    process.env.WEATHERAPI_API_KEY,
    process.env.TRANSLATION_API_KEY
  ].filter(Boolean);
  return credentials.reduce(
    (value, credential) => value.replaceAll(credential, "[redacted]"),
    text
  );
}

function futureDate(offset) {
  const value = new Date();
  value.setUTCHours(12, 0, 0, 0);
  value.setUTCDate(value.getUTCDate() + offset);
  return value;
}

function uniqueProviders(values) {
  return [
    ...new Set(values.map((value) => value.provenance.provider))
  ];
}

async function readableFiles(root) {
  let entries;
  try {
    entries = await readdir(root, { withFileTypes: true });
  } catch {
    return [];
  }
  const files = [];
  for (const entry of entries) {
    const path = join(root, entry.name);
    if (entry.isDirectory()) {
      files.push(...await readableFiles(path));
    } else if (
      entry.isFile()
      && shouldScan(path)
    ) {
      files.push(path);
    }
  }
  return files;
}

function shouldScan(path) {
  if (path.includes("/.git/") || path.includes("/node_modules/")) {
    return false;
  }
  if (path.includes(".env")) {
    return false;
  }
  const extension = extname(path).toLowerCase();
  return [
    "",
    ".swift",
    ".plist",
    ".pbxproj",
    ".xcconfig",
    ".json",
    ".strings",
    ".entitlements"
  ].includes(extension);
}
