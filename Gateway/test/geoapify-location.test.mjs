import assert from "node:assert/strict";
import test from "node:test";

import {
  buildGeocodeURL,
  createGeoapifyLocationResolver,
  validateLocationCriteria
} from "../src/providers/geoapify-location.mjs";

test("location criteria and geocode URL are bounded", () => {
  const criteria = validateLocationCriteria({
    query: "São Paulo",
    includeNearestAirport: true
  });
  const url = buildGeocodeURL(criteria.query, "server-key");

  assert.equal(criteria.query, "São Paulo");
  assert.equal(criteria.includeNearestAirport, true);
  assert.equal(url.searchParams.get("text"), "São Paulo");
  assert.equal(url.searchParams.get("limit"), "1");
  assert.throws(
    () => validateLocationCriteria({
      query: "",
      includeNearestAirport: false
    }),
    (error) => error.code === "invalid_location_query"
  );
});

test("Geoapify resolves coordinates, timezone, and nearest IATA", async () => {
  const requestedURLs = [];
  const resolve = createGeoapifyLocationResolver({
    apiKey: "server-key",
    fetchImplementation: async (url) => {
      const parsed = new URL(url);
      requestedURLs.push(parsed);
      if (parsed.pathname.includes("/geocode/")) {
        return Response.json({
          results: [{
            name: "Chicago",
            city: "Chicago",
            state: "Illinois",
            country: "United States",
            country_code: "us",
            lat: 41.8781,
            lon: -87.6298,
            timezone: {
              name: "America/Chicago"
            }
          }]
        });
      }
      return Response.json({
        features: [{
          properties: {
            name: "O'Hare International Airport",
            iata: "ORD"
          }
        }]
      });
    }
  });
  const location = await resolve({
    query: "Chicago",
    includeNearestAirport: true
  });

  assert.equal(location.name, "Chicago");
  assert.equal(location.city, "Chicago");
  assert.equal(location.countryCode, "US");
  assert.equal(location.iataCode, "ORD");
  assert.equal(location.timeZoneIdentifier, "America/Chicago");
  assert.equal(location.coordinate.latitude, 41.8781);
  assert.match(location.id, /^[0-9a-f-]{36}$/u);
  assert.equal(requestedURLs.length, 2);
  assert.equal(
    requestedURLs[1].searchParams.get("categories"),
    "airport"
  );
});

test("commercial airport ranking avoids a closer county field", async () => {
  const resolve = createGeoapifyLocationResolver({
    apiKey: "server-key",
    fetchImplementation: async (url) => {
      const parsed = new URL(url);
      if (parsed.pathname.includes("/geocode/")) {
        return Response.json({
          results: [{
            name: "Atlanta",
            city: "Atlanta",
            lat: 33.749,
            lon: -84.388,
            timezone: {
              name: "America/New_York"
            }
          }]
        });
      }
      return Response.json({
        features: [
          {
            properties: {
              name: "Fulton County Airport-Brown Field",
              iata: "FTY",
              distance: 12_672,
              categories: ["airport", "airport.international"]
            }
          },
          {
            properties: {
              name:
                "Hartsfield-Jackson Atlanta International Airport",
              iata: "ATL",
              distance: 12_839,
              categories: [
                "airport",
                "airport.international",
                "internet_access.free"
              ]
            }
          }
        ]
      });
    }
  });

  const location = await resolve({
    query: "Atlanta",
    includeNearestAirport: true
  });

  assert.equal(location.iataCode, "ATL");
});

test("location resolution remains useful when no airport code exists", async () => {
  const resolve = createGeoapifyLocationResolver({
    apiKey: "server-key",
    fetchImplementation: async (url) => {
      const parsed = new URL(url);
      if (parsed.pathname.includes("/geocode/")) {
        return Response.json({
          results: [{
            name: "Reykjavík",
            city: "Reykjavík",
            country: "Iceland",
            country_code: "is",
            lat: 64.1466,
            lon: -21.9426,
            timezone: {
              name: "Atlantic/Reykjavik"
            }
          }]
        });
      }
      return Response.json({ features: [] });
    }
  });
  const location = await resolve({
    query: "Reykjavík",
    includeNearestAirport: true
  });

  assert.equal(location.city, "Reykjavík");
  assert.equal(location.iataCode, null);
  assert.equal(location.coordinate.longitude, -21.9426);
});

test("missing location configuration fails closed", async () => {
  const resolve = createGeoapifyLocationResolver({});
  await assert.rejects(
    () => resolve({
      query: "Chicago",
      includeNearestAirport: true
    }),
    (error) => error.code === "location_resolution_not_configured"
  );
});
