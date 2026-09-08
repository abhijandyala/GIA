import assert from "node:assert/strict";
import test from "node:test";

import {
  buildGeoapifyURL,
  buildSerpApiMapsURL,
  createPlaceDiscovery,
  mapGeoapifyResults,
  mapSerpApiMapsResults,
  validatePlaceCriteria
} from "../src/providers/place-discovery.mjs";

test("place criteria map to bounded Geoapify queries", () => {
  const criteria = validatePlaceCriteria(validCriteria());
  const url = buildGeoapifyURL(criteria, "geo-test-key");

  assert.equal(url.hostname, "api.geoapify.com");
  assert.equal(url.searchParams.get("apiKey"), "geo-test-key");
  assert.equal(url.searchParams.get("limit"), "12");
  assert.equal(
    url.searchParams.get("filter"),
    "circle:-9.1393,38.7223,12000"
  );
  assert.match(
    url.searchParams.get("categories"),
    /catering\.restaurant/
  );
  assert.match(
    url.searchParams.get("categories"),
    /entertainment\.museum/
  );
});

test("Geoapify features map evidence without invented ratings", () => {
  const criteria = validatePlaceCriteria(validCriteria());
  const retrievedAt = new Date("2026-09-06T08:00:00.000Z");
  const first = mapGeoapifyResults(
    geoapifyFixture(),
    criteria,
    retrievedAt
  );
  const second = mapGeoapifyResults(
    geoapifyFixture(),
    criteria,
    new Date("2026-09-06T09:00:00.000Z")
  );

  assert.equal(first.length, 1);
  assert.equal(first[0].id, second[0].id);
  assert.equal(first[0].name, "Lisbon Garden Kitchen");
  assert.ok(first[0].categories.includes("restaurant"));
  assert.ok(first[0].dietaryOptions.includes("vegetarian"));
  assert.ok(
    first[0].accessibilityFeatures.includes("wheelchairAccess")
  );
  assert.equal(first[0].rating, null);
  assert.equal(first[0].reviewCount, null);
  assert.equal(first[0].openingHours.rawText.length, 1);
  assert.equal(first[0].openingHours.isOpenAtRetrieval, true);
  assert.equal(first[0].provenance.provider, "geoapify");
  assert.equal(
    first[0].provenance.expiresAt,
    "2026-09-06T14:00:00.000Z"
  );
  assert.equal(
    first[0].provenance.sourceURL.includes("geo-test-key"),
    false
  );
});

test("duplicate provider place identifiers are removed", () => {
  const payload = geoapifyFixture();
  payload.features.push(
    JSON.parse(JSON.stringify(payload.features[0]))
  );
  const places = mapGeoapifyResults(
    payload,
    validatePlaceCriteria(validCriteria()),
    new Date("2026-09-06T08:00:00.000Z")
  );

  assert.equal(places.length, 1);
});

test("SerpApi fallback maps ratings, hours, images, and links", () => {
  const criteria = validatePlaceCriteria(validCriteria());
  const url = buildSerpApiMapsURL(criteria, "serp-test-key");
  assert.equal(url.searchParams.get("engine"), "google_maps");
  assert.match(url.searchParams.get("q"), /Lisbon/);
  assert.equal(url.searchParams.get("type"), "search");

  const places = mapSerpApiMapsResults(
    serpApiMapsFixture(),
    criteria,
    new Date("2026-09-06T08:00:00.000Z")
  );
  assert.equal(places.length, 1);
  assert.equal(places[0].name, "Lisbon Art Museum");
  assert.equal(places[0].rating, 4.8);
  assert.equal(places[0].reviewCount, 820);
  assert.equal(places[0].priceLevel, 2);
  assert.equal(places[0].openingHours.isOpenAtRetrieval, true);
  assert.equal(places[0].imageURLs.length, 1);
  assert.match(places[0].bookingURL, /^https:/);
  assert.equal(places[0].provenance.provider, "serpapi");
});

test("Geoapify failure falls back to SerpApi", async () => {
  const calls = [];
  const search = createPlaceDiscovery({
    geoapifyKey: "geo-key",
    serpApiKey: "serp-key",
    fetchImplementation: async (url) => {
      calls.push(url.hostname);
      if (url.hostname === "api.geoapify.com") {
        return Response.json(
          {
            error: "temporary"
          },
          {
            status: 503
          }
        );
      }
      return Response.json(serpApiMapsFixture());
    },
    now: () => new Date("2026-09-06T08:00:00.000Z")
  });
  const result = await search(validCriteria());

  assert.deepEqual(calls, [
    "api.geoapify.com",
    "serpapi.com"
  ]);
  assert.equal(result.places.length, 1);
  assert.equal(result.places[0].provenance.provider, "serpapi");
});

test("strict place search exposes Geoapify failure", async () => {
  const calls = [];
  const search = createPlaceDiscovery({
    geoapifyKey: "geo-key",
    serpApiKey: "serp-key",
    strictProviderErrors: true,
    fetchImplementation: async (url) => {
      calls.push(url.hostname);
      return Response.json(
        { error: "temporary" },
        { status: 503 }
      );
    }
  });

  await assert.rejects(
    () => search(validCriteria()),
    (error) => error.code === "geoapify_request_failed"
  );
  assert.deepEqual(calls, ["api.geoapify.com"]);
});

test("missing coordinates use SerpApi without calling Geoapify", async () => {
  const criteria = validCriteria();
  criteria.destination.coordinate = null;
  const calls = [];
  const search = createPlaceDiscovery({
    geoapifyKey: "geo-key",
    serpApiKey: "serp-key",
    fetchImplementation: async (url) => {
      calls.push(url.hostname);
      return Response.json(serpApiMapsFixture());
    }
  });
  const result = await search(criteria);

  assert.deepEqual(calls, ["serpapi.com"]);
  assert.equal(result.places.length, 1);
});

test("empty place results differ from malformed provider data", () => {
  const criteria = validatePlaceCriteria(validCriteria());
  const retrievedAt = new Date("2026-09-06T08:00:00.000Z");

  assert.deepEqual(
    mapGeoapifyResults({}, criteria, retrievedAt),
    []
  );
  assert.throws(
    () => mapGeoapifyResults(
      {
        features: [
          {
            properties: {
              place_id: "missing-location",
              name: "Missing Location"
            }
          }
        ]
      },
      criteria,
      retrievedAt
    ),
    (error) => error.code === "geoapify_unusable_results"
  );
});

test("invalid limits fail before provider calls", async () => {
  const criteria = validCriteria();
  criteria.limit = 0;
  let called = false;
  const search = createPlaceDiscovery({
    geoapifyKey: "geo-key",
    serpApiKey: "serp-key",
    fetchImplementation: async () => {
      called = true;
      return Response.json({});
    }
  });

  await assert.rejects(
    () => search(criteria),
    (error) => error.code === "invalid_place_limit"
  );
  assert.equal(called, false);
});

test("missing place providers fail closed", async () => {
  const search = createPlaceDiscovery({
    geoapifyKey: "",
    serpApiKey: ""
  });

  await assert.rejects(
    () => search(validCriteria()),
    (error) => (
      error.status === 503
      && error.code === "place_search_not_configured"
    )
  );
});

function validCriteria() {
  return {
    destination: {
      id: "destination-id",
      name: "Lisbon",
      city: "Lisbon",
      country: "Portugal",
      countryCode: "PT",
      coordinate: {
        latitude: 38.7223,
        longitude: -9.1393
      },
      timeZoneIdentifier: "Europe/Lisbon"
    },
    categories: ["restaurant", "museum"],
    interests: ["food", "museums"],
    dietaryRequirements: ["vegetarian"],
    accessibilityRequirements: ["wheelchairAccess"],
    radiusMeters: 12000,
    limit: 12
  };
}

function geoapifyFixture() {
  return {
    type: "FeatureCollection",
    features: [
      {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [-9.14, 38.72]
        },
        properties: {
          name: "Lisbon Garden Kitchen",
          place_id: "geo-place-1",
          formatted: "1 Garden Street, Lisbon",
          city: "Lisbon",
          country: "Portugal",
          country_code: "pt",
          categories: [
            "catering.restaurant",
            "vegetarian",
            "wheelchair.yes"
          ],
          opening_hours: "Mo-Su 11:00-22:00",
          open_now: true,
          website: "https://garden.example"
        }
      }
    ]
  };
}

function serpApiMapsFixture() {
  return {
    search_metadata: {
      google_maps_url:
        "https://www.google.com/maps/search/museums+Lisbon"
    },
    local_results: [
      {
        title: "Lisbon Art Museum",
        place_id: "serp-place-1",
        type: "Museum",
        address: "2 Museum Avenue, Lisbon",
        description: "Modern and historic Portuguese art.",
        rating: 4.8,
        reviews: 820,
        price: "€€",
        open_state: "Open",
        hours: {
          monday: "10 AM–6 PM",
          tuesday: "10 AM–6 PM"
        },
        gps_coordinates: {
          latitude: 38.71,
          longitude: -9.13
        },
        thumbnail: "https://images.example/museum.jpg",
        website: "https://museum.example",
        booking_link: "https://museum.example/tickets"
      }
    ]
  };
}
