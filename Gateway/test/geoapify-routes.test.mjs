import assert from "node:assert/strict";
import test from "node:test";

import {
  buildRouteURL,
  createGeoapifyRoutePlanning,
  mapRouteResults,
  validateRouteCriteria
} from "../src/providers/geoapify-routes.mjs";

test("route criteria map to documented Geoapify parameters", () => {
  const criteria = validateRouteCriteria(validCriteria(["car"]));
  const url = buildRouteURL(criteria, "drive", "geo-test-key");

  assert.equal(url.hostname, "api.geoapify.com");
  assert.equal(url.pathname, "/v1/routing");
  assert.equal(
    url.searchParams.get("waypoints"),
    "38.7223,-9.1393|38.7101,-9.129"
  );
  assert.equal(url.searchParams.get("mode"), "drive");
  assert.equal(url.searchParams.get("units"), "metric");
  assert.equal(url.searchParams.get("lang"), "en");
  assert.equal(
    url.searchParams.get("details"),
    "instruction_details"
  );
  assert.equal(url.searchParams.get("traffic"), "approximated");
  assert.equal(url.searchParams.get("apiKey"), "geo-test-key");
});

test("routes map geometry, instructions, timing, buffers, and provenance", () => {
  const criteria = validateRouteCriteria(validCriteria(["walking"]));
  const retrievedAt = new Date("2026-09-06T08:00:00.000Z");
  const first = mapRouteResults(
    routeFixture(),
    criteria,
    "walking",
    "walk",
    retrievedAt
  );
  const second = mapRouteResults(
    routeFixture(),
    criteria,
    "walking",
    "walk",
    new Date("2026-09-06T09:00:00.000Z")
  );

  assert.equal(first.length, 1);
  assert.equal(first[0].id, second[0].id);
  assert.equal(first[0].mode, "walking");
  assert.equal(first[0].duration, 900);
  assert.equal(first[0].distanceMeters, 1200);
  assert.equal(first[0].plannedDeparture, "2027-06-12T09:00:00.000Z");
  assert.equal(first[0].plannedArrival, "2027-06-12T09:15:00.000Z");
  assert.equal(first[0].routeGeometry.length, 3);
  assert.deepEqual(first[0].routeGeometry[0], {
    latitude: 38.7223,
    longitude: -9.1393
  });
  assert.deepEqual(first[0].instructions, [
    "Head east",
    "Turn right"
  ]);
  assert.equal(first[0].bufferDuration, 300);
  assert.equal(first[0].confidence, "estimated");
  assert.equal(first[0].estimatedCost, null);
  assert.equal(first[0].provenance.provider, "geoapify");
  assert.equal(
    first[0].provenance.expiresAt,
    "2026-09-06T08:15:00.000Z"
  );
  assert.equal(
    first[0].provenance.sourceURL.includes("geo-test-key"),
    false
  );
});

test("transit falls back to explicitly approximated routing", async () => {
  const modes = [];
  const search = createGeoapifyRoutePlanning({
    apiKey: "geo-key",
    fetchImplementation: async (url) => {
      modes.push(url.searchParams.get("mode"));
      if (url.searchParams.get("mode") === "transit") {
        return Response.json({
          type: "FeatureCollection",
          features: []
        });
      }
      return Response.json(routeFixture());
    },
    now: () => new Date("2026-09-06T08:00:00.000Z")
  });
  const result = await search(validCriteria(["transit"]));

  assert.deepEqual(modes, ["transit", "approximated_transit"]);
  assert.equal(result.routes.length, 1);
  assert.equal(result.routes[0].mode, "transit");
  assert.equal(result.routes[0].confidence, "approximated");
  assert.equal(result.routes[0].bufferDuration, 600);
});

test("strict transit routing exposes missing live results", async () => {
  const modes = [];
  const search = createGeoapifyRoutePlanning({
    apiKey: "geo-key",
    strictProviderErrors: true,
    fetchImplementation: async (url) => {
      modes.push(url.searchParams.get("mode"));
      return Response.json({
        type: "FeatureCollection",
        features: []
      });
    }
  });

  await assert.rejects(
    () => search(validCriteria(["transit"])),
    (error) => error.code === "route_mode_empty"
  );
  assert.deepEqual(modes, ["transit"]);
});

test("route geometry is bounded while preserving the final point", () => {
  const payload = routeFixture();
  payload.features[0].geometry.coordinates = [
    Array.from({ length: 1500 }, (_, index) => [
      -9.1393 + (index * 0.000001),
      38.7223 + (index * 0.000001)
    ])
  ];
  const route = mapRouteResults(
    payload,
    validateRouteCriteria(validCriteria(["bicycle"])),
    "bicycle",
    "bicycle",
    new Date("2026-09-06T08:00:00.000Z")
  )[0];

  assert.ok(route.routeGeometry.length <= 1001);
  assert.deepEqual(
    route.routeGeometry[route.routeGeometry.length - 1],
    {
      latitude: 38.723799,
      longitude: -9.137801
    }
  );
});

test("unsupported transportation modes fail before provider calls", async () => {
  let called = false;
  const search = createGeoapifyRoutePlanning({
    apiKey: "geo-key",
    fetchImplementation: async () => {
      called = true;
      return Response.json(routeFixture());
    }
  });

  await assert.rejects(
    () => search(validCriteria(["train"])),
    (error) => error.code === "unsupported_route_mode"
  );
  assert.equal(called, false);
});

test("empty routes differ from malformed nonempty routes", () => {
  const criteria = validateRouteCriteria(validCriteria(["walking"]));
  const retrievedAt = new Date("2026-09-06T08:00:00.000Z");

  assert.deepEqual(
    mapRouteResults(
      {},
      criteria,
      "walking",
      "walk",
      retrievedAt
    ),
    []
  );
  assert.throws(
    () => mapRouteResults(
      {
        features: [
          {
            properties: {
              time: 900,
              distance: 1200
            },
            geometry: {
              type: "MultiLineString",
              coordinates: []
            }
          }
        ]
      },
      criteria,
      "walking",
      "walk",
      retrievedAt
    ),
    (error) => error.code === "geoapify_unusable_route_results"
  );
});

test("route adapter sanitizes provider authorization failures", async () => {
  const search = createGeoapifyRoutePlanning({
    apiKey: "invalid-key",
    fetchImplementation: async () => Response.json(
      {
        error: "sensitive provider details"
      },
      {
        status: 403
      }
    )
  });

  await assert.rejects(
    () => search(validCriteria(["walking"])),
    (error) => (
      error.status === 503
      && error.code === "geoapify_authorization_failed"
      && !error.message.includes("sensitive")
    )
  );
});

test("missing route configuration fails closed", async () => {
  const search = createGeoapifyRoutePlanning({
    apiKey: ""
  });

  await assert.rejects(
    () => search(validCriteria(["walking"])),
    (error) => (
      error.status === 503
      && error.code === "geoapify_not_configured"
    )
  );
});

function validCriteria(modes) {
  return {
    origin: {
      id: "origin-id",
      name: "Lisbon Hotel",
      coordinate: {
        latitude: 38.7223,
        longitude: -9.1393
      },
      timeZoneIdentifier: "Europe/Lisbon"
    },
    destination: {
      id: "destination-id",
      name: "Lisbon Museum",
      coordinate: {
        latitude: 38.7101,
        longitude: -9.129
      },
      timeZoneIdentifier: "Europe/Lisbon"
    },
    modes,
    departure: "2027-06-12T09:00:00.000Z",
    currencyCode: "USD"
  };
}

function routeFixture() {
  return {
    type: "FeatureCollection",
    properties: {
      mode: "walk"
    },
    features: [
      {
        type: "Feature",
        properties: {
          distance: 1200,
          time: 900,
          legs: [
            {
              distance: 1200,
              time: 900,
              steps: [
                {
                  instruction: {
                    text: "Head east"
                  }
                },
                {
                  instruction: {
                    text: "Turn right"
                  }
                },
                {
                  instruction: {
                    text: "Turn right"
                  }
                }
              ]
            }
          ]
        },
        geometry: {
          type: "MultiLineString",
          coordinates: [
            [
              [-9.1393, 38.7223],
              [-9.135, 38.718],
              [-9.129, 38.7101]
            ]
          ]
        }
      }
    ]
  };
}
