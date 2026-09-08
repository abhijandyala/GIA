import { createHash } from "node:crypto";

import { GatewayError } from "../gateway.mjs";

const GEOAPIFY_ROUTING_URL =
  "https://api.geoapify.com/v1/routing";
const RESULT_TTL_MILLISECONDS = 900_000;
const MAX_GEOMETRY_POINTS = 1_000;

export function createGeoapifyRoutePlanning({
  apiKey,
  strictProviderErrors = false,
  fetchImplementation = globalThis.fetch,
  now = () => new Date()
}) {
  return async function planRoutes(criteria, context = {}) {
    if (!apiKey) {
      throw new GatewayError(
        503,
        "geoapify_not_configured",
        "Route planning is not configured."
      );
    }

    const validated = validateRouteCriteria(criteria);
    const routes = [];
    let firstFailure;

    for (const requestedMode of validated.modes) {
      try {
        let providerMode = providerModeFor(requestedMode);
        let payload = await fetchGeoapify(
          buildRouteURL(validated, providerMode, apiKey),
          context.signal,
          fetchImplementation
        );
        let mapped = mapRouteResults(
          payload,
          validated,
          requestedMode,
          providerMode,
          now()
        );

        if (
          requestedMode === "transit"
          && mapped.length === 0
          && !strictProviderErrors
        ) {
          providerMode = "approximated_transit";
          payload = await fetchGeoapify(
            buildRouteURL(validated, providerMode, apiKey),
            context.signal,
            fetchImplementation
          );
          mapped = mapRouteResults(
            payload,
            validated,
            requestedMode,
            providerMode,
            now()
          );
        }

        if (strictProviderErrors && mapped.length === 0) {
          throw new GatewayError(
            502,
            "route_mode_empty",
            "A requested route mode returned no live result."
          );
        }
        routes.push(...mapped);
      } catch (error) {
        if (context.signal?.aborted) {
          throw error;
        }
        if (strictProviderErrors) {
          throw error;
        }
        firstFailure = firstFailure ?? error;
      }
    }

    if (routes.length === 0 && firstFailure) {
      throw firstFailure;
    }
    return {
      routes
    };
  };
}

export function validateRouteCriteria(criteria) {
  requireObject(criteria, "invalid_route_request");
  requireObject(criteria.origin, "missing_route_origin");
  requireObject(criteria.destination, "missing_route_destination");

  const origin = requireCoordinate(
    criteria.origin.coordinate,
    "missing_route_origin_coordinate"
  );
  const destination = requireCoordinate(
    criteria.destination.coordinate,
    "missing_route_destination_coordinate"
  );
  requireString(criteria.origin.id, "missing_route_origin_id");
  requireString(criteria.origin.name, "missing_route_origin_name");
  requireString(
    criteria.destination.id,
    "missing_route_destination_id"
  );
  requireString(
    criteria.destination.name,
    "missing_route_destination_name"
  );
  if (
    origin.latitude === destination.latitude
    && origin.longitude === destination.longitude
  ) {
    throw new GatewayError(
      422,
      "identical_route_points",
      "Route origin and destination must be different."
    );
  }

  const modes = Array.isArray(criteria.modes)
    ? [...new Set(criteria.modes)]
    : [];
  if (modes.length < 1 || modes.length > 4) {
    throw new GatewayError(
      422,
      "invalid_route_modes",
      "Choose between one and four route modes."
    );
  }
  const supportedModes = new Set([
    "walking",
    "bicycle",
    "car",
    "rideshare",
    "transit"
  ]);
  const unsupported = modes.find(
    (mode) => !supportedModes.has(mode)
  );
  if (unsupported) {
    throw new GatewayError(
      422,
      "unsupported_route_mode",
      "The requested transportation mode cannot be routed reliably."
    );
  }

  const departure = criteria.departure
    ? requireDate(criteria.departure, "invalid_route_departure")
    : null;
  const currencyCode = requireCurrency(criteria.currencyCode);

  return {
    ...criteria,
    origin: {
      ...criteria.origin,
      coordinate: origin
    },
    destination: {
      ...criteria.destination,
      coordinate: destination
    },
    modes,
    departure,
    currencyCode
  };
}

export function buildRouteURL(criteria, providerMode, apiKey) {
  const origin = criteria.origin.coordinate;
  const destination = criteria.destination.coordinate;
  const url = new URL(GEOAPIFY_ROUTING_URL);
  url.searchParams.set(
    "waypoints",
    `${origin.latitude},${origin.longitude}`
      + `|${destination.latitude},${destination.longitude}`
  );
  url.searchParams.set("mode", providerMode);
  url.searchParams.set("units", "metric");
  url.searchParams.set("lang", "en");
  url.searchParams.set("details", "instruction_details");
  url.searchParams.set("apiKey", apiKey);

  if (providerMode === "drive") {
    url.searchParams.set("traffic", "approximated");
  }
  return url;
}

export function mapRouteResults(
  payload,
  criteria,
  requestedMode,
  providerMode,
  retrievedAt
) {
  requireObject(payload, "invalid_geoapify_route_response");
  const features = Array.isArray(payload.features)
    ? payload.features
    : [];
  const routes = [];
  let usableCount = 0;

  for (const feature of features.slice(0, 3)) {
    try {
      const properties = requireObject(
        feature.properties,
        "invalid_geoapify_route"
      );
      const duration = requirePositiveNumber(
        properties.time,
        "invalid_route_duration"
      );
      const distance = requirePositiveNumber(
        properties.distance,
        "invalid_route_distance"
      );
      const geometry = routeGeometry(feature.geometry);
      if (geometry.length < 2) {
        continue;
      }
      usableCount += 1;

      const signature = JSON.stringify({
        requestedMode,
        providerMode,
        origin: criteria.origin.coordinate,
        destination: criteria.destination.coordinate,
        duration,
        distance,
        geometry
      });
      const plannedDeparture =
        criteria.departure?.toISOString() ?? null;
      const plannedArrival = criteria.departure
        ? new Date(
            criteria.departure.getTime() + (duration * 1_000)
          ).toISOString()
        : null;

      routes.push({
        id: deterministicUUID(`geoapify-route:${signature}`),
        origin: criteria.origin,
        destination: criteria.destination,
        mode: requestedMode,
        plannedDeparture,
        plannedArrival,
        duration,
        distanceMeters: distance,
        estimatedCost: null,
        routeGeometry: geometry,
        instructions: routeInstructions(properties),
        bufferDuration: bufferForMode(requestedMode),
        confidence:
          providerMode === "approximated_transit"
            ? "approximated"
            : providerMode === "transit"
              ? "scheduled"
              : "estimated",
        externalBookingURL: null,
        provenance: {
          provider: "geoapify",
          providerIdentifier:
            deterministicUUID(`geoapify-route-source:${signature}`),
          origin: "live",
          retrievedAt: retrievedAt.toISOString(),
          expiresAt: new Date(
            retrievedAt.getTime() + RESULT_TTL_MILLISECONDS
          ).toISOString(),
          sourceURL: "https://www.geoapify.com/routing-api/"
        }
      });
    } catch {
      continue;
    }
  }

  if (features.length > 0 && usableCount === 0) {
    throw new GatewayError(
      502,
      "geoapify_unusable_route_results",
      "Route planning returned an unsupported result format."
    );
  }
  return routes;
}

async function fetchGeoapify(url, signal, fetchImplementation) {
  let response;
  try {
    response = await fetchImplementation(url, {
      method: "GET",
      headers: {
        accept: "application/json"
      },
      signal
    });
  } catch (error) {
    if (signal?.aborted || error?.name === "AbortError") {
      throw new GatewayError(
        504,
        "geoapify_route_timeout",
        "Route planning timed out."
      );
    }
    throw new GatewayError(
      502,
      "geoapify_route_transport_failed",
      "Route planning could not reach its provider."
    );
  }

  if (response.status === 429) {
    throw new GatewayError(
      429,
      "geoapify_route_rate_limited",
      "Route planning is busy. Try again shortly."
    );
  }
  if (response.status === 401 || response.status === 403) {
    throw new GatewayError(
      503,
      "geoapify_authorization_failed",
      "Route planning is not configured correctly."
    );
  }
  if (!response.ok) {
    throw new GatewayError(
      502,
      "geoapify_route_request_failed",
      "Route planning could not be completed."
    );
  }

  try {
    return await response.json();
  } catch {
    throw new GatewayError(
      502,
      "geoapify_route_invalid_response",
      "Route planning returned invalid data."
    );
  }
}

function routeGeometry(geometry) {
  const coordinates = [];
  collectCoordinatePairs(geometry?.coordinates, coordinates);
  if (coordinates.length <= MAX_GEOMETRY_POINTS) {
    return coordinates;
  }

  const stride = Math.ceil(
    coordinates.length / MAX_GEOMETRY_POINTS
  );
  const reduced = coordinates.filter(
    (_, index) => index % stride === 0
  );
  const finalPoint = coordinates[coordinates.length - 1];
  if (reduced[reduced.length - 1] !== finalPoint) {
    reduced.push(finalPoint);
  }
  return reduced;
}

function collectCoordinatePairs(value, output) {
  if (!Array.isArray(value)) {
    return;
  }
  if (
    value.length >= 2
    && Number.isFinite(Number(value[0]))
    && Number.isFinite(Number(value[1]))
  ) {
    const coordinate = {
      latitude: Number(value[1]),
      longitude: Number(value[0])
    };
    if (
      coordinate.latitude >= -90
      && coordinate.latitude <= 90
      && coordinate.longitude >= -180
      && coordinate.longitude <= 180
    ) {
      output.push(coordinate);
    }
    return;
  }
  for (const nested of value) {
    collectCoordinatePairs(nested, output);
  }
}

function routeInstructions(properties) {
  const instructions = [];
  for (const leg of properties.legs ?? []) {
    for (const step of leg.steps ?? []) {
      const value =
        step.instruction?.text
        ?? step.instruction
        ?? step.name;
      if (
        typeof value === "string"
        && value.trim().length > 0
      ) {
        instructions.push(value.trim());
      }
    }
  }
  return [...new Set(instructions)].slice(0, 100);
}

function providerModeFor(mode) {
  switch (mode) {
    case "walking":
      return "walk";
    case "bicycle":
      return "bicycle";
    case "car":
    case "rideshare":
      return "drive";
    case "transit":
      return "transit";
    default:
      throw new GatewayError(
        422,
        "unsupported_route_mode",
        "The requested transportation mode is unsupported."
      );
  }
}

function bufferForMode(mode) {
  switch (mode) {
    case "walking":
    case "bicycle":
      return 300;
    case "transit":
      return 600;
    case "car":
    case "rideshare":
      return 600;
    default:
      return 0;
  }
}

function deterministicUUID(value) {
  const bytes = Buffer.from(
    createHash("sha256").update(value).digest().subarray(0, 16)
  );
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20)
  ].join("-");
}

function requireObject(value, code) {
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new GatewayError(
      422,
      code,
      "Invalid route planning data."
    );
  }
  return value;
}

function requireCoordinate(value, code) {
  const latitude = Number(value?.latitude);
  const longitude = Number(value?.longitude);
  if (
    !Number.isFinite(latitude)
    || !Number.isFinite(longitude)
    || latitude < -90
    || latitude > 90
    || longitude < -180
    || longitude > 180
  ) {
    throw new GatewayError(
      422,
      code,
      "A valid route coordinate is required."
    );
  }
  return {
    latitude,
    longitude
  };
}

function requirePositiveNumber(value, code) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) {
    throw new GatewayError(
      422,
      code,
      "Route duration and distance must be positive."
    );
  }
  return number;
}

function requireDate(value, code) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new GatewayError(
      422,
      code,
      "A valid route departure is required."
    );
  }
  return date;
}

function requireString(value, code) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new GatewayError(
      422,
      code,
      "A route location name and identifier are required."
    );
  }
  return value;
}

function requireInteger(value, minimum, maximum, code) {
  if (
    !Number.isInteger(value)
    || value < minimum
    || value > maximum
  ) {
    throw new GatewayError(
      422,
      code,
      "The number of route modes is invalid."
    );
  }
  return value;
}

function requireCurrency(value) {
  const normalized = String(value ?? "").trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(normalized)) {
    throw new GatewayError(
      422,
      "invalid_route_currency",
      "A three-letter currency code is required."
    );
  }
  return normalized;
}
