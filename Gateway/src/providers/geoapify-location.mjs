import { createHash } from "node:crypto";

import { GatewayError } from "../gateway.mjs";

const GEOCODE_URL = "https://api.geoapify.com/v1/geocode/search";
const PLACES_URL = "https://api.geoapify.com/v2/places";

export function createGeoapifyLocationResolver({
  apiKey,
  fetchImplementation = globalThis.fetch
}) {
  return async function resolveLocation(criteria, context = {}) {
    if (!apiKey) {
      throw new GatewayError(
        503,
        "location_resolution_not_configured",
        "Location resolution is not configured."
      );
    }
    const validated = validateLocationCriteria(criteria);
    const geocode = await fetchJSON(
      buildGeocodeURL(validated.query, apiKey),
      context.signal,
      fetchImplementation
    );
    const result = geocode.results?.[0];
    if (!result) {
      throw new GatewayError(
        404,
        "location_not_found",
        "The requested location could not be resolved."
      );
    }
    const coordinate = coordinateFrom(result);
    const timeZoneIdentifier =
      stringOrNull(result.timezone?.name);
    let iataCode = null;
    if (validated.includeNearestAirport && coordinate) {
      iataCode = await nearestAirportCode({
        coordinate,
        apiKey,
        signal: context.signal,
        fetchImplementation
      });
    }

    const name = stringOrNull(result.city)
      ?? stringOrNull(result.name)
      ?? stringOrNull(result.formatted)
      ?? validated.query;
    return {
      id: stableUUID(
        [
          name,
          coordinate?.latitude,
          coordinate?.longitude
        ].join("|")
      ),
      name,
      city: stringOrNull(result.city),
      region:
        stringOrNull(result.state)
        ?? stringOrNull(result.county),
      country: stringOrNull(result.country),
      countryCode:
        stringOrNull(result.country_code)?.toUpperCase() ?? null,
      iataCode,
      coordinate,
      timeZoneIdentifier
    };
  };
}

export function validateLocationCriteria(criteria) {
  if (!criteria || typeof criteria !== "object"
      || Array.isArray(criteria)) {
    throw new GatewayError(
      422,
      "invalid_location_request",
      "Location resolution requires a request object."
    );
  }
  const query = String(criteria.query ?? "").trim();
  if (query.length < 2 || query.length > 120) {
    throw new GatewayError(
      422,
      "invalid_location_query",
      "A location name between 2 and 120 characters is required."
    );
  }
  return {
    query,
    includeNearestAirport:
      criteria.includeNearestAirport === true
  };
}

export function buildGeocodeURL(query, apiKey) {
  const url = new URL(GEOCODE_URL);
  url.searchParams.set("text", query);
  url.searchParams.set("format", "json");
  url.searchParams.set("limit", "1");
  url.searchParams.set("lang", "en");
  url.searchParams.set("apiKey", apiKey);
  return url;
}

async function nearestAirportCode({
  coordinate,
  apiKey,
  signal,
  fetchImplementation
}) {
  const url = new URL(PLACES_URL);
  url.searchParams.set("categories", "airport");
  url.searchParams.set(
    "filter",
    `circle:${coordinate.longitude},${coordinate.latitude},120000`
  );
  url.searchParams.set(
    "bias",
    `proximity:${coordinate.longitude},${coordinate.latitude}`
  );
  url.searchParams.set("limit", "10");
  url.searchParams.set("apiKey", apiKey);

  try {
    const payload = await fetchJSON(
      url,
      signal,
      fetchImplementation
    );
    const candidates = [];
    for (const feature of payload.features ?? []) {
      const properties = feature.properties ?? {};
      const rawCode =
        properties.iata
        ?? properties.datasource?.raw?.iata
        ?? properties.datasource?.raw?.iata_code;
      const code = stringOrNull(rawCode)?.toUpperCase();
      if (/^[A-Z]{3}$/u.test(code ?? "")) {
        candidates.push({
          code,
          score: airportScore(properties)
        });
      }
    }
    candidates.sort((left, right) => right.score - left.score);
    return candidates[0]?.code ?? null;
  } catch (error) {
    if (signal?.aborted) {
      throw error;
    }
  }
  return null;
}

function airportScore(properties) {
  const name = String(properties.name ?? "").toLowerCase();
  const categories = Array.isArray(properties.categories)
    ? properties.categories
    : [];
  const distance = Number(properties.distance);
  let score = 0;

  if (/\binternational airport\b/u.test(name)) {
    score += 100;
  }
  if (categories.includes("internet_access.free")) {
    score += 12;
  } else if (categories.includes("internet_access")) {
    score += 6;
  }
  if (
    /\b(?:military|air reserve|air force|airstrip|private)\b/u
      .test(name)
  ) {
    score -= 100;
  }
  if (
    /\b(?:county|municipal|regional|executive|field)\b/u
      .test(name)
  ) {
    score -= 25;
  }
  if (Number.isFinite(distance)) {
    score -= Math.min(distance / 10_000, 12);
  }
  return score;
}

async function fetchJSON(url, signal, fetchImplementation) {
  let response;
  try {
    response = await fetchImplementation(url, {
      headers: {
        accept: "application/json"
      },
      signal
    });
  } catch (error) {
    if (signal?.aborted || error?.name === "AbortError") {
      throw error;
    }
    throw new GatewayError(
      502,
      "location_provider_unavailable",
      "Location resolution is temporarily unavailable."
    );
  }
  if (!response.ok) {
    if (response.status === 401 || response.status === 403) {
      throw new GatewayError(
        502,
        "location_provider_authorization_failed",
        "Location resolution is temporarily unavailable."
      );
    }
    throw new GatewayError(
      502,
      "location_provider_failed",
      "Location resolution is temporarily unavailable."
    );
  }
  try {
    return await response.json();
  } catch {
    throw new GatewayError(
      502,
      "invalid_location_response",
      "Location resolution returned an invalid response."
    );
  }
}

function coordinateFrom(result) {
  const latitude = Number(result.lat);
  const longitude = Number(result.lon);
  if (
    !Number.isFinite(latitude)
    || !Number.isFinite(longitude)
    || latitude < -90
    || latitude > 90
    || longitude < -180
    || longitude > 180
  ) {
    return null;
  }
  return { latitude, longitude };
}

function stringOrNull(value) {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function stableUUID(value) {
  const hex = createHash("sha256")
    .update(String(value))
    .digest("hex")
    .slice(0, 32)
    .split("");
  hex[12] = "4";
  hex[16] = ["8", "9", "a", "b"][
    Number.parseInt(hex[16], 16) % 4
  ];
  return [
    hex.slice(0, 8).join(""),
    hex.slice(8, 12).join(""),
    hex.slice(12, 16).join(""),
    hex.slice(16, 20).join(""),
    hex.slice(20, 32).join("")
  ].join("-");
}
