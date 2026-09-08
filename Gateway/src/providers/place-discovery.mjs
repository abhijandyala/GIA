import { createHash } from "node:crypto";

import { GatewayError } from "../gateway.mjs";

const GEOAPIFY_URL = "https://api.geoapify.com/v2/places";
const SERPAPI_URL = "https://serpapi.com/search.json";
const RESULT_TTL_MILLISECONDS = 21_600_000;

export function createPlaceDiscovery({
  geoapifyKey,
  serpApiKey,
  strictProviderErrors = false,
  fetchImplementation = globalThis.fetch,
  now = () => new Date()
}) {
  return async function searchPlaces(criteria, context = {}) {
    const validated = validatePlaceCriteria(criteria);
    let primaryFailure;

    if (geoapifyKey && validated.destination.coordinate) {
      try {
        const places = await searchGeoapify({
          criteria: validated,
          apiKey: geoapifyKey,
          signal: context.signal,
          fetchImplementation,
          retrievedAt: now()
        });
        if (
          strictProviderErrors
          || places.length > 0
          || !serpApiKey
        ) {
          return { places };
        }
      } catch (error) {
        if (context.signal?.aborted) {
          throw error;
        }
        if (strictProviderErrors) {
          throw error;
        }
        primaryFailure = error;
      }
    }

    if (strictProviderErrors) {
      if (!geoapifyKey) {
        throw new GatewayError(
          503,
          "geoapify_place_search_not_configured",
          "Strict local testing requires Geoapify place search."
        );
      }
      throw new GatewayError(
        422,
        "place_coordinate_required",
        "A destination coordinate is required for place discovery."
      );
    }

    if (serpApiKey) {
      const places = await searchSerpApi({
        criteria: validated,
        apiKey: serpApiKey,
        signal: context.signal,
        fetchImplementation,
        retrievedAt: now()
      });
      return { places };
    }

    if (primaryFailure) {
      throw primaryFailure;
    }
    if (!geoapifyKey) {
      throw new GatewayError(
        503,
        "place_search_not_configured",
        "Place discovery is not configured."
      );
    }
    throw new GatewayError(
      422,
      "place_coordinate_required",
      "A destination coordinate is required for place discovery."
    );
  };
}

export function validatePlaceCriteria(criteria) {
  requireObject(criteria, "invalid_place_request");
  requireObject(criteria.destination, "missing_place_destination");

  const destinationName = String(
    criteria.destination.city
    ?? criteria.destination.name
    ?? ""
  ).trim();
  if (destinationName.length < 2 || destinationName.length > 100) {
    throw new GatewayError(
      422,
      "invalid_place_destination",
      "A valid destination is required."
    );
  }

  const limit = requireInteger(
    criteria.limit,
    1,
    50,
    "invalid_place_limit"
  );
  const radiusMeters = requireInteger(
    criteria.radiusMeters ?? 15_000,
    100,
    50_000,
    "invalid_place_radius"
  );
  const categories = normalizedCategories(
    criteria.categories,
    criteria.interests
  );
  if (categories.length === 0) {
    throw new GatewayError(
      422,
      "missing_place_categories",
      "At least one place category is required."
    );
  }

  const coordinate = normalizeCoordinate(
    criteria.destination.coordinate
  );

  return {
    ...criteria,
    destination: {
      ...criteria.destination,
      name: destinationName,
      coordinate
    },
    categories,
    limit,
    radiusMeters
  };
}

export function buildGeoapifyURL(criteria, apiKey) {
  const coordinate = criteria.destination.coordinate;
  if (!coordinate) {
    throw new GatewayError(
      422,
      "place_coordinate_required",
      "A destination coordinate is required for Geoapify."
    );
  }

  const url = new URL(GEOAPIFY_URL);
  const longitude = coordinate.longitude;
  const latitude = coordinate.latitude;
  url.searchParams.set(
    "categories",
    geoapifyCategories(criteria.categories).join(",")
  );
  url.searchParams.set(
    "filter",
    `circle:${longitude},${latitude},${criteria.radiusMeters}`
  );
  url.searchParams.set(
    "bias",
    `proximity:${longitude},${latitude}`
  );
  url.searchParams.set("limit", String(criteria.limit));
  url.searchParams.set("apiKey", apiKey);
  return url;
}

export function buildSerpApiMapsURL(criteria, apiKey) {
  const url = new URL(SERPAPI_URL);
  url.searchParams.set("engine", "google_maps");
  url.searchParams.set(
    "q",
    `${queryTerms(criteria.categories)} in ${criteria.destination.name}`
  );
  url.searchParams.set("type", "search");
  url.searchParams.set("hl", "en");
  url.searchParams.set("api_key", apiKey);

  const coordinate = criteria.destination.coordinate;
  if (coordinate) {
    url.searchParams.set(
      "ll",
      `@${coordinate.latitude},${coordinate.longitude},14z`
    );
  }
  return url;
}

export function mapGeoapifyResults(payload, criteria, retrievedAt) {
  requireObject(payload, "invalid_geoapify_response");
  const features = Array.isArray(payload.features)
    ? payload.features
    : [];
  const mapped = [];
  const seen = new Set();
  let usableCount = 0;

  for (const feature of features) {
    try {
      const properties = requireObject(
        feature.properties,
        "invalid_geoapify_feature"
      );
      const name = requireString(
        properties.name
        ?? properties.address_line1,
        "missing_geoapify_name"
      );
      const providerID = requireString(
        properties.place_id,
        "missing_geoapify_place_id"
      );
      if (seen.has(providerID)) {
        continue;
      }
      const coordinate = coordinateFromGeoapify(feature);
      if (!coordinate) {
        continue;
      }
      seen.add(providerID);
      const categories = mapPlaceCategories(
        properties.categories,
        criteria.categories
      );
      usableCount += 1;

      mapped.push({
        id: deterministicUUID(`geoapify:${providerID}`),
        providerPlaceIdentifier: providerID,
        name,
        location: {
          id: deterministicUUID(`geoapify-location:${providerID}`),
          name,
          city:
            properties.city
            ?? criteria.destination.city
            ?? criteria.destination.name,
          region:
            properties.state
            ?? criteria.destination.region
            ?? null,
          country:
            properties.country
            ?? criteria.destination.country
            ?? null,
          countryCode:
            String(
              properties.country_code
              ?? criteria.destination.countryCode
              ?? ""
            ).toUpperCase() || null,
          iataCode: null,
          coordinate,
          timeZoneIdentifier:
            criteria.destination.timeZoneIdentifier ?? null
        },
        categories,
        summary:
          properties.formatted
          ?? properties.address_line2
          ?? null,
        rating: null,
        reviewCount: null,
        priceLevel: null,
        estimatedCostPerTraveler: null,
        estimatedDuration: null,
        openingHours: mapGeoapifyHours(properties),
        imageURLs: [],
        websiteURL: safeURL(
          properties.website
          ?? properties.datasource?.raw?.website
        ),
        bookingURL: null,
        dietaryOptions: mapDietaryOptions(
          properties.categories
        ),
        accessibilityFeatures: mapAccessibility(
          properties.categories,
          properties.wheelchair
        ),
        indoor: null,
        reservationRequired: null,
        provenance: provenance(
          "geoapify",
          providerID,
          retrievedAt,
          "https://www.geoapify.com/places-api/"
        )
      });
    } catch {
      continue;
    }

    if (mapped.length >= criteria.limit) {
      break;
    }
  }

  if (features.length > 0 && usableCount === 0) {
    throw new GatewayError(
      502,
      "geoapify_unusable_results",
      "Place discovery returned an unsupported result format."
    );
  }
  return mapped;
}

export function mapSerpApiMapsResults(payload, criteria, retrievedAt) {
  requireObject(payload, "invalid_serpapi_maps_response");
  if (payload.error) {
    throw new GatewayError(
      502,
      "serpapi_maps_error",
      "The fallback place provider could not complete the search."
    );
  }

  const results = Array.isArray(payload.local_results)
    ? payload.local_results
    : [];
  const mapped = [];
  const seen = new Set();
  let usableCount = 0;

  for (const result of results) {
    try {
      const name = requireString(
        result.title,
        "missing_serpapi_place_name"
      );
      const providerID = requireString(
        result.place_id
        ?? result.data_id
        ?? result.data_cid,
        "missing_serpapi_place_id"
      );
      if (seen.has(providerID)) {
        continue;
      }
      const coordinate = normalizeCoordinate(
        result.gps_coordinates
      );
      if (!coordinate) {
        continue;
      }
      seen.add(providerID);
      usableCount += 1;

      mapped.push({
        id: deterministicUUID(`serpapi-map:${providerID}`),
        providerPlaceIdentifier: providerID,
        name,
        location: {
          id: deterministicUUID(`serpapi-map-location:${providerID}`),
          name,
          city: criteria.destination.city
            ?? criteria.destination.name,
          region: criteria.destination.region ?? null,
          country: criteria.destination.country ?? null,
          countryCode:
            criteria.destination.countryCode ?? null,
          iataCode: null,
          coordinate,
          timeZoneIdentifier:
            criteria.destination.timeZoneIdentifier ?? null
        },
        categories: mapPlaceCategories(
          [
            result.type,
            ...(Array.isArray(result.types) ? result.types : [])
          ],
          criteria.categories
        ),
        summary:
          result.description
          ?? result.address
          ?? null,
        rating: boundedNumber(result.rating, 0, 5),
        reviewCount: nonnegativeInteger(result.reviews),
        priceLevel: mapPriceLevel(result.price),
        estimatedCostPerTraveler: null,
        estimatedDuration: null,
        openingHours: mapSerpApiHours(result),
        imageURLs: [safeURL(result.thumbnail)].filter(Boolean),
        websiteURL: safeURL(result.website),
        bookingURL: safeURL(result.booking_link),
        dietaryOptions: mapDietaryOptions(
          [
            result.type,
            ...(Array.isArray(result.types) ? result.types : []),
            ...(Array.isArray(result.extensions)
              ? result.extensions
              : [])
          ]
        ),
        accessibilityFeatures: [],
        indoor: null,
        reservationRequired: null,
        provenance: provenance(
          "serpapi",
          providerID,
          retrievedAt,
          payload.search_metadata?.google_maps_url
            ?? "https://www.google.com/maps"
        )
      });
    } catch {
      continue;
    }

    if (mapped.length >= criteria.limit) {
      break;
    }
  }

  if (results.length > 0 && usableCount === 0) {
    throw new GatewayError(
      502,
      "serpapi_unusable_maps_results",
      "Fallback place discovery returned unsupported results."
    );
  }
  return mapped;
}

async function searchGeoapify({
  criteria,
  apiKey,
  signal,
  fetchImplementation,
  retrievedAt
}) {
  const payload = await fetchJSON({
    url: buildGeoapifyURL(criteria, apiKey),
    signal,
    fetchImplementation,
    provider: "geoapify"
  });
  return mapGeoapifyResults(payload, criteria, retrievedAt);
}

async function searchSerpApi({
  criteria,
  apiKey,
  signal,
  fetchImplementation,
  retrievedAt
}) {
  const payload = await fetchJSON({
    url: buildSerpApiMapsURL(criteria, apiKey),
    signal,
    fetchImplementation,
    provider: "serpapi"
  });
  return mapSerpApiMapsResults(payload, criteria, retrievedAt);
}

async function fetchJSON({
  url,
  signal,
  fetchImplementation,
  provider
}) {
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
        "place_search_timeout",
        "Place discovery timed out."
      );
    }
    throw new GatewayError(
      502,
      `${provider}_transport_failed`,
      "Place discovery could not reach its provider."
    );
  }

  if (response.status === 429) {
    throw new GatewayError(
      429,
      `${provider}_rate_limited`,
      "Place discovery is busy. Try again shortly."
    );
  }
  if (response.status === 401 || response.status === 403) {
    throw new GatewayError(
      503,
      `${provider}_authorization_failed`,
      "Place discovery is not configured correctly."
    );
  }
  if (!response.ok) {
    throw new GatewayError(
      502,
      `${provider}_request_failed`,
      "Place discovery could not be completed."
    );
  }

  try {
    return await response.json();
  } catch {
    throw new GatewayError(
      502,
      `${provider}_invalid_response`,
      "Place discovery returned invalid data."
    );
  }
}

function normalizedCategories(categories, interests) {
  const values = new Set(
    Array.isArray(categories) ? categories : []
  );
  const interestSet = new Set(
    Array.isArray(interests) ? interests : []
  );

  if (interestSet.has("food")) {
    values.add("restaurant");
    values.add("cafe");
  }
  if (interestSet.has("museums") || interestSet.has("art")) {
    values.add("museum");
  }
  if (interestSet.has("nature")) {
    values.add("park");
  }
  if (interestSet.has("shopping")) {
    values.add("shopping");
  }
  if (interestSet.has("nightlife")) {
    values.add("nightlife");
  }
  if (interestSet.has("sports")) {
    values.add("sports");
  }

  if (values.size === 0) {
    values.add("restaurant");
    values.add("attraction");
  }

  return [...values].filter((value) => (
    [
      "activity",
      "attraction",
      "cafe",
      "entertainment",
      "landmark",
      "museum",
      "nightlife",
      "park",
      "restaurant",
      "shopping",
      "sports"
    ].includes(value)
  ));
}

function geoapifyCategories(categories) {
  const mappings = {
    activity: ["tourism.attraction", "entertainment"],
    attraction: ["tourism.attraction"],
    cafe: ["catering.cafe"],
    entertainment: ["entertainment"],
    landmark: ["tourism.sights"],
    museum: ["entertainment.museum"],
    nightlife: ["catering.bar"],
    park: ["leisure.park"],
    restaurant: ["catering.restaurant"],
    shopping: ["commercial.shopping_mall"],
    sports: ["sport"]
  };
  return [
    ...new Set(categories.flatMap((value) => mappings[value] ?? []))
  ];
}

function queryTerms(categories) {
  const mappings = {
    activity: "activities",
    attraction: "attractions",
    cafe: "cafes",
    entertainment: "entertainment",
    landmark: "landmarks",
    museum: "museums",
    nightlife: "nightlife",
    park: "parks",
    restaurant: "restaurants",
    shopping: "shopping",
    sports: "sports activities"
  };
  return categories
    .slice(0, 4)
    .map((value) => mappings[value] ?? value)
    .join(" or ");
}

function mapPlaceCategories(values, requestedCategories) {
  const text = (Array.isArray(values) ? values : [values])
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
  const mapped = new Set();

  if (text.includes("restaurant")) mapped.add("restaurant");
  if (text.includes("cafe")) mapped.add("cafe");
  if (text.includes("museum")) mapped.add("museum");
  if (text.includes("attraction")) mapped.add("attraction");
  if (text.includes("park")) mapped.add("park");
  if (text.includes("shopping") || text.includes("commercial")) {
    mapped.add("shopping");
  }
  if (text.includes("bar") || text.includes("nightclub")) {
    mapped.add("nightlife");
  }
  if (text.includes("sport")) mapped.add("sports");
  if (text.includes("sight") || text.includes("landmark")) {
    mapped.add("landmark");
  }
  if (text.includes("entertainment")) mapped.add("entertainment");

  if (mapped.size === 0) {
    for (const category of requestedCategories) {
      mapped.add(category);
    }
  }
  return [...mapped];
}

function mapDietaryOptions(values) {
  const text = (Array.isArray(values) ? values : [values])
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
  const mapped = [];
  if (text.includes("vegetarian")) mapped.push("vegetarian");
  if (text.includes("vegan")) mapped.push("vegan");
  if (text.includes("halal")) mapped.push("halal");
  if (text.includes("kosher")) mapped.push("kosher");
  if (text.includes("gluten")) mapped.push("glutenFree");
  return mapped;
}

function mapAccessibility(categories, wheelchair) {
  const text = (Array.isArray(categories) ? categories : [])
    .join(" ")
    .toLowerCase();
  if (
    wheelchair === "yes"
    || text.includes("wheelchair.yes")
  ) {
    return ["wheelchairAccess"];
  }
  return [];
}

function mapGeoapifyHours(properties) {
  const values = [];
  if (typeof properties.opening_hours === "string") {
    values.push(properties.opening_hours);
  }
  if (Array.isArray(properties.opening_hours_raw)) {
    values.push(
      ...properties.opening_hours_raw.filter(
        (value) => typeof value === "string"
      )
    );
  }
  if (values.length === 0) {
    return null;
  }
  return {
    rawText: values,
    isOpenAtRetrieval:
      typeof properties.open_now === "boolean"
        ? properties.open_now
        : null
  };
}

function mapSerpApiHours(result) {
  const values = [];
  if (result.hours && typeof result.hours === "object") {
    for (const [day, hours] of Object.entries(result.hours)) {
      if (typeof hours === "string") {
        values.push(`${day}: ${hours}`);
      }
    }
  }
  if (values.length === 0 && typeof result.open_state !== "string") {
    return null;
  }
  const openState = String(result.open_state ?? "").toLowerCase();
  return {
    rawText: values,
    isOpenAtRetrieval:
      openState.startsWith("open")
        ? true
        : openState.startsWith("closed")
          ? false
          : null
  };
}

function mapPriceLevel(value) {
  if (typeof value !== "string") {
    return null;
  }
  const symbols = value.match(/[$€£¥]/g)?.length;
  if (symbols && symbols >= 1 && symbols <= 4) {
    return symbols;
  }
  return null;
}

function coordinateFromGeoapify(feature) {
  const propertiesCoordinate = normalizeCoordinate({
    latitude: feature.properties?.lat,
    longitude: feature.properties?.lon
  });
  if (propertiesCoordinate) {
    return propertiesCoordinate;
  }
  const coordinates = feature.geometry?.coordinates;
  if (
    Array.isArray(coordinates)
    && coordinates.length >= 2
  ) {
    return normalizeCoordinate({
      latitude: coordinates[1],
      longitude: coordinates[0]
    });
  }
  return null;
}

function normalizeCoordinate(value) {
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
    return null;
  }
  return {
    latitude,
    longitude
  };
}

function provenance(
  provider,
  providerIdentifier,
  retrievedAt,
  sourceURL
) {
  return {
    provider,
    providerIdentifier,
    origin: "live",
    retrievedAt: retrievedAt.toISOString(),
    expiresAt: new Date(
      retrievedAt.getTime() + RESULT_TTL_MILLISECONDS
    ).toISOString(),
    sourceURL: safeURL(sourceURL)
  };
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

function safeURL(value) {
  if (typeof value !== "string") {
    return null;
  }
  try {
    const url = new URL(value);
    return url.protocol === "https:" ? url.toString() : null;
  } catch {
    return null;
  }
}

function boundedNumber(value, minimum, maximum) {
  const number = Number(value);
  if (
    !Number.isFinite(number)
    || number < minimum
    || number > maximum
  ) {
    return null;
  }
  return number;
}

function nonnegativeInteger(value) {
  const number = Number(value);
  return Number.isInteger(number) && number >= 0
    ? number
    : null;
}

function requireObject(value, code) {
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new GatewayError(
      422,
      code,
      "Invalid place discovery data."
    );
  }
  return value;
}

function requireString(value, code) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new GatewayError(
      422,
      code,
      "Invalid place discovery data."
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
      "Place search limits are invalid."
    );
  }
  return value;
}
