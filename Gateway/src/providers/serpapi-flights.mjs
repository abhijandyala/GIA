import { createHash } from "node:crypto";

import { GatewayError } from "../gateway.mjs";

const SERPAPI_URL = "https://serpapi.com/search.json";
const MAX_OFFERS = 20;

export function createSerpApiFlightSearch({
  apiKey,
  fetchImplementation = globalThis.fetch,
  now = () => new Date()
}) {
  return async function searchFlights(criteria, context = {}) {
    if (!apiKey) {
      throw new GatewayError(
        503,
        "serpapi_not_configured",
        "Flight search is not configured."
      );
    }

    const normalizedCriteria = validateFlightCriteria(criteria);
    const requestURL = buildFlightSearchURL(
      normalizedCriteria,
      apiKey
    );
    const payload = await fetchSerpApi(
      requestURL,
      context.signal,
      fetchImplementation
    );
    const offers = mapFlightResults(
      payload,
      normalizedCriteria,
      now()
    );

    return {
      offers
    };
  };
}

export function createSerpApiRoundTripCompletion({
  apiKey,
  fetchImplementation = globalThis.fetch,
  now = () => new Date()
}) {
  return async function completeRoundTrip(criteria, context = {}) {
    if (!apiKey) {
      throw new GatewayError(
        503,
        "serpapi_not_configured",
        "Flight search is not configured."
      );
    }

    const validated = validateRoundTripCompletionCriteria(criteria);
    const requestURL = buildReturnFlightSearchURL(
      validated.searchCriteria,
      validated.outboundOffer.continuationToken,
      apiKey
    );
    const payload = await fetchSerpApi(
      requestURL,
      context.signal,
      fetchImplementation
    );

    return {
      offers: mapRoundTripResults(
        payload,
        validated.searchCriteria,
        validated.outboundOffer,
        now()
      )
    };
  };
}

export function validateFlightCriteria(criteria) {
  requireObject(criteria, "invalid_flight_request");
  requireObject(criteria.origin, "missing_flight_origin");
  requireObject(criteria.destination, "missing_flight_destination");

  const originCode = requireIATACode(
    criteria.origin.iataCode,
    "invalid_origin_airport"
  );
  const destinationCode = requireIATACode(
    criteria.destination.iataCode,
    "invalid_destination_airport"
  );
  if (originCode === destinationCode) {
    throw new GatewayError(
      422,
      "identical_flight_airports",
      "Flight origin and destination must be different."
    );
  }

  const originTimeZone = requireTimeZone(
    criteria.origin.timeZoneIdentifier,
    "missing_origin_time_zone"
  );
  const destinationTimeZone = requireTimeZone(
    criteria.destination.timeZoneIdentifier,
    "missing_destination_time_zone"
  );
  const departureDate = requireDate(
    criteria.departureDate,
    "invalid_departure_date"
  );
  const returnDate = criteria.returnDate
    ? requireDate(criteria.returnDate, "invalid_return_date")
    : null;
  if (returnDate && returnDate < departureDate) {
    throw new GatewayError(
      422,
      "reversed_flight_dates",
      "The return date must follow departure."
    );
  }

  const adults = requireInteger(
    criteria.adults,
    1,
    9,
    "invalid_adult_count"
  );
  const children = requireInteger(
    criteria.children,
    0,
    8,
    "invalid_child_count"
  );
  const currencyCode = requireCurrency(criteria.currencyCode);

  return {
    ...criteria,
    origin: {
      ...criteria.origin,
      iataCode: originCode,
      timeZoneIdentifier: originTimeZone
    },
    destination: {
      ...criteria.destination,
      iataCode: destinationCode,
      timeZoneIdentifier: destinationTimeZone
    },
    departureDate,
    returnDate,
    adults,
    children,
    currencyCode
  };
}

export function validateRoundTripCompletionCriteria(criteria) {
  requireObject(criteria, "invalid_round_trip_request");
  const searchCriteria = validateFlightCriteria(
    criteria.searchCriteria
  );
  if (!searchCriteria.returnDate) {
    throw new GatewayError(
      422,
      "round_trip_return_date_required",
      "A return date is required to complete a round trip."
    );
  }

  const outboundOffer = requireObject(
    criteria.outboundOffer,
    "missing_outbound_offer"
  );
  const id = requireString(
    outboundOffer.id,
    "missing_outbound_offer_id"
  );
  const continuationToken = requireString(
    outboundOffer.continuationToken,
    "missing_departure_token"
  );
  if (continuationToken.length > 8_192) {
    throw new GatewayError(
      422,
      "invalid_departure_token",
      "The selected outbound flight cannot be completed."
    );
  }
  const outboundSegments = requireArray(
    outboundOffer.outboundSegments,
    "missing_outbound_segments"
  );
  const firstCode = requireIATACode(
    outboundSegments[0]?.origin?.iataCode,
    "invalid_outbound_origin"
  );
  const lastCode = requireIATACode(
    outboundSegments.at(-1)?.destination?.iataCode,
    "invalid_outbound_destination"
  );
  if (
    firstCode !== searchCriteria.origin.iataCode
    || lastCode !== searchCriteria.destination.iataCode
  ) {
    throw new GatewayError(
      422,
      "outbound_route_mismatch",
      "The selected outbound flight does not match the search."
    );
  }

  return {
    searchCriteria,
    outboundOffer: {
      ...outboundOffer,
      id,
      continuationToken,
      outboundSegments
    }
  };
}

export function buildFlightSearchURL(criteria, apiKey) {
  const url = new URL(SERPAPI_URL);
  const parameters = url.searchParams;
  parameters.set("engine", "google_flights");
  parameters.set("api_key", apiKey);
  parameters.set("departure_id", criteria.origin.iataCode);
  parameters.set("arrival_id", criteria.destination.iataCode);
  parameters.set(
    "outbound_date",
    dateOnly(criteria.departureDate, criteria.origin.timeZoneIdentifier)
  );
  parameters.set("adults", String(criteria.adults));
  parameters.set("children", String(criteria.children));
  parameters.set("currency", criteria.currencyCode);
  parameters.set(
    "travel_class",
    travelClassParameter(criteria.preferences?.travelClass)
  );
  parameters.set(
    "stops",
    stopsParameter(criteria.preferences?.stopPreference)
  );
  parameters.set("hl", "en");
  parameters.set("type", criteria.returnDate ? "1" : "2");

  if (criteria.returnDate) {
    parameters.set(
      "return_date",
      dateOnly(
        criteria.returnDate,
        criteria.destination.timeZoneIdentifier
      )
    );
  }

  return url;
}

export function buildReturnFlightSearchURL(
  criteria,
  departureToken,
  apiKey
) {
  const url = buildFlightSearchURL(criteria, apiKey);
  url.searchParams.set("departure_token", departureToken);
  return url;
}

export function mapFlightResults(payload, criteria, retrievedAt) {
  requireObject(payload, "invalid_serpapi_response");
  if (payload.error) {
    throw new GatewayError(
      502,
      "serpapi_flight_error",
      "The flight provider could not complete the search."
    );
  }

  const rawOffers = [
    ...(Array.isArray(payload.best_flights)
      ? payload.best_flights
      : []),
    ...(Array.isArray(payload.other_flights)
      ? payload.other_flights
      : [])
  ];
  const seen = new Set();
  const searchURL = safeURL(
    payload.search_metadata?.google_flights_url
  );
  const priceInsight = mapPriceInsight(
    payload.price_insights,
    criteria.currencyCode
  );
  const expiration = new Date(
    retrievedAt.getTime() + 180_000
  );
  const mapped = [];

  for (const rawOffer of rawOffers) {
    if (mapped.length >= MAX_OFFERS) {
      break;
    }

    try {
      const signature = offerSignature(rawOffer);
      if (seen.has(signature)) {
        continue;
      }
      seen.add(signature);

      const segments = requireArray(
        rawOffer.flights,
        "missing_flight_segments"
      ).map((segment, index) => mapSegment(
        segment,
        index,
        criteria,
        signature
      ));
      const price = Number(rawOffer.price);
      const durationMinutes = Number(rawOffer.total_duration);
      if (
        !Number.isFinite(price)
        || price <= 0
        || !Number.isFinite(durationMinutes)
        || durationMinutes <= 0
      ) {
        continue;
      }

      mapped.push({
        id: deterministicUUID(`offer:${signature}`),
        providerOfferIdentifier:
          rawOffer.booking_token
          ?? rawOffer.departure_token
          ?? signature,
        continuationToken:
          typeof rawOffer.departure_token === "string"
            ? rawOffer.departure_token
            : null,
        outboundSegments: segments,
        returnSegments: [],
        totalDuration: durationMinutes * 60,
        totalPrice: money(price, criteria.currencyCode),
        baggage: mapBaggage(rawOffer),
        badges:
          Number(rawOffer.carbon_emissions?.difference_percent) < 0
            ? ["lowerEmissions"]
            : [],
        carbonEmissionsGrams:
          integerOrNull(rawOffer.carbon_emissions?.this_flight),
        priceInsight,
        refundable: null,
        bookingURL: searchURL,
        provenance: {
          provider: "serpapi",
          providerIdentifier:
            rawOffer.booking_token
            ?? rawOffer.departure_token
            ?? signature,
          origin: "live",
          retrievedAt: retrievedAt.toISOString(),
          expiresAt: expiration.toISOString(),
          sourceURL: searchURL
        }
      });
    } catch {
      continue;
    }
  }

  applyDerivedBadges(mapped);
  if (rawOffers.length > 0 && mapped.length === 0) {
    throw new GatewayError(
      502,
      "serpapi_unusable_flight_results",
      "Flight search returned results in an unsupported format."
    );
  }
  return mapped;
}

export function mapRoundTripResults(
  payload,
  criteria,
  outboundOffer,
  retrievedAt
) {
  requireObject(payload, "invalid_serpapi_response");
  if (payload.error) {
    throw new GatewayError(
      502,
      "serpapi_flight_error",
      "The flight provider could not complete the search."
    );
  }

  const rawOffers = [
    ...(Array.isArray(payload.best_flights)
      ? payload.best_flights
      : []),
    ...(Array.isArray(payload.other_flights)
      ? payload.other_flights
      : [])
  ];
  const searchURL = safeURL(
    payload.search_metadata?.google_flights_url
  ) ?? outboundOffer.bookingURL ?? null;
  const expiration = new Date(
    retrievedAt.getTime() + 180_000
  );
  const seen = new Set();
  const mapped = [];

  for (const rawOffer of rawOffers) {
    if (mapped.length >= MAX_OFFERS) {
      break;
    }
    try {
      const returnSignature = offerSignature(rawOffer);
      if (seen.has(returnSignature)) {
        continue;
      }
      seen.add(returnSignature);
      const returnSegments = requireArray(
        rawOffer.flights,
        "missing_return_segments"
      ).map((segment, index) => mapSegment(
        segment,
        index,
        criteria,
        `return:${outboundOffer.id}:${returnSignature}`
      ));
      if (
        returnSegments[0]?.origin?.iataCode
          !== criteria.destination.iataCode
        || returnSegments.at(-1)?.destination?.iataCode
          !== criteria.origin.iataCode
      ) {
        continue;
      }

      const returnDurationMinutes = Number(rawOffer.total_duration);
      const returnDuration = Number.isFinite(returnDurationMinutes)
        && returnDurationMinutes > 0
          ? returnDurationMinutes * 60
          : returnSegments.reduce(
              (total, segment) => total + segment.duration,
              0
            );
      const providerPrice = Number(rawOffer.price);
      const totalPrice =
        Number.isFinite(providerPrice) && providerPrice > 0
          ? money(providerPrice, criteria.currencyCode)
          : outboundOffer.totalPrice;
      const providerIdentifier =
        rawOffer.booking_token ?? returnSignature;
      const returnBaggage = mapBaggage(rawOffer);

      mapped.push({
        ...outboundOffer,
        id: deterministicUUID(
          `roundtrip:${outboundOffer.id}:${returnSignature}`
        ),
        providerOfferIdentifier: providerIdentifier,
        continuationToken: null,
        returnSegments,
        totalDuration:
          Number(outboundOffer.totalDuration) + returnDuration,
        totalPrice,
        baggage: returnBaggage ?? outboundOffer.baggage ?? null,
        badges: Array.isArray(outboundOffer.badges)
          ? [...outboundOffer.badges]
          : [],
        bookingURL: searchURL,
        provenance: {
          provider: "serpapi",
          providerIdentifier,
          origin: "live",
          retrievedAt: retrievedAt.toISOString(),
          expiresAt: expiration.toISOString(),
          sourceURL: searchURL
        }
      });
    } catch {
      continue;
    }
  }

  applyDerivedBadges(mapped);
  if (rawOffers.length > 0 && mapped.length === 0) {
    throw new GatewayError(
      502,
      "serpapi_unusable_return_results",
      "Return flight search returned unsupported results."
    );
  }
  return mapped;
}

async function fetchSerpApi(url, signal, fetchImplementation) {
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
        "serpapi_timeout",
        "Flight search timed out."
      );
    }
    throw new GatewayError(
      502,
      "serpapi_transport_failed",
      "Flight search could not reach its provider."
    );
  }

  if (response.status === 429) {
    throw new GatewayError(
      429,
      "serpapi_rate_limited",
      "Flight search is busy. Try again shortly."
    );
  }
  if (response.status === 401 || response.status === 403) {
    throw new GatewayError(
      503,
      "serpapi_authorization_failed",
      "Flight search is not configured correctly."
    );
  }
  if (!response.ok) {
    throw new GatewayError(
      502,
      "serpapi_request_failed",
      "Flight search could not be completed."
    );
  }

  try {
    return await response.json();
  } catch {
    throw new GatewayError(
      502,
      "serpapi_invalid_response",
      "Flight search returned an invalid response."
    );
  }
}

function mapSegment(segment, index, criteria, offerSignatureValue) {
  requireObject(segment, "invalid_flight_segment");
  requireObject(
    segment.departure_airport,
    "missing_departure_airport"
  );
  requireObject(
    segment.arrival_airport,
    "missing_arrival_airport"
  );

  const departureCode = requireIATACode(
    segment.departure_airport.id,
    "invalid_segment_departure"
  );
  const arrivalCode = requireIATACode(
    segment.arrival_airport.id,
    "invalid_segment_arrival"
  );
  const departureTime = requireString(
    segment.departure_airport.time,
    "missing_segment_departure_time"
  );
  const arrivalTime = requireString(
    segment.arrival_airport.time,
    "missing_segment_arrival_time"
  );
  const departureZone = timeZoneForAirport(
    departureCode,
    criteria
  );
  const arrivalZone = timeZoneForAirport(
    arrivalCode,
    criteria
  );
  const durationMinutes = Number(segment.duration);
  if (!Number.isFinite(durationMinutes) || durationMinutes <= 0) {
    throw new Error("Invalid segment duration.");
  }

  const flightNumber = requireString(
    segment.flight_number,
    "missing_flight_number"
  );
  const airlineName = requireString(
    segment.airline,
    "missing_airline"
  );

  return {
    id: deterministicUUID(
      `segment:${offerSignatureValue}:${index}`
    ),
    airlineCode:
      flightNumber.trim().split(/\s+/)[0]?.toUpperCase() ?? "",
    airlineName,
    flightNumber,
    origin: flightLocation(
      departureCode,
      segment.departure_airport.name,
      departureZone
    ),
    destination: flightLocation(
      arrivalCode,
      segment.arrival_airport.name,
      arrivalZone
    ),
    departure: localDateTimeToISO(
      departureTime,
      departureZone.identifier
    ),
    arrival: localDateTimeToISO(
      arrivalTime,
      arrivalZone.identifier
    ),
    departureLocalTimeText: departureTime,
    arrivalLocalTimeText: arrivalTime,
    departureTimeZoneIdentifier: departureZone.identifier,
    arrivalTimeZoneIdentifier: arrivalZone.identifier,
    departureTimeZoneIsResolved: departureZone.resolved,
    arrivalTimeZoneIsResolved: arrivalZone.resolved,
    duration: durationMinutes * 60,
    aircraftName:
      typeof segment.airplane === "string"
        ? segment.airplane
        : null,
    travelClass: mapTravelClass(segment.travel_class)
  };
}

function flightLocation(code, name, zone) {
  return {
    id: deterministicUUID(`airport:${code}`),
    name:
      typeof name === "string" && name.length > 0
        ? name
        : code,
    city: null,
    region: null,
    country: null,
    countryCode: null,
    iataCode: code,
    coordinate: null,
    timeZoneIdentifier: zone.resolved ? zone.identifier : null
  };
}

function mapTravelClass(value) {
  const normalized = String(value ?? "").toLowerCase();
  if (normalized.includes("premium")) {
    return "premiumEconomy";
  }
  if (normalized.includes("business")) {
    return "business";
  }
  if (normalized.includes("first")) {
    return "first";
  }
  return "economy";
}

function mapBaggage(rawOffer) {
  const descriptions = [];
  for (const value of rawOffer.extensions ?? []) {
    if (typeof value === "string" && /bag|carry-on/i.test(value)) {
      descriptions.push(value);
    }
  }
  for (const flight of rawOffer.flights ?? []) {
    for (const value of flight.extensions ?? []) {
      if (typeof value === "string" && /bag|carry-on/i.test(value)) {
        descriptions.push(value);
      }
    }
  }
  if (descriptions.length === 0) {
    return null;
  }

  const combined = [...new Set(descriptions)].join(" · ");
  const carryOn = combined.match(/(\d+)\s+(?:free\s+)?carry-on/i);
  const checked = combined.match(/(\d+)\s+(?:free\s+)?checked/i);
  return {
    personalItems: null,
    carryOnBags: carryOn ? Number(carryOn[1]) : null,
    checkedBags: checked ? Number(checked[1]) : null,
    checkedBagFee: null,
    rawDescription: combined
  };
}

function mapPriceInsight(value, currencyCode) {
  if (!value || typeof value !== "object") {
    return null;
  }
  const range = Array.isArray(value.typical_price_range)
    ? value.typical_price_range
    : [];
  const low = Number(range[0]);
  const high = Number(range[1]);
  const lowest = Number(value.lowest_price);

  return {
    level: priceLevel(value.price_level),
    typicalLow:
      Number.isFinite(low) ? money(low, currencyCode) : null,
    typicalHigh:
      Number.isFinite(high) ? money(high, currencyCode) : null,
    observedLowest:
      Number.isFinite(lowest) ? money(lowest, currencyCode) : null
  };
}

function applyDerivedBadges(offers) {
  if (offers.length === 0) {
    return;
  }
  const minimumPrice = Math.min(
    ...offers.map((offer) => offer.totalPrice.amount)
  );
  const minimumDuration = Math.min(
    ...offers.map((offer) => offer.totalDuration)
  );
  const minimumStops = Math.min(
    ...offers.map((offer) => (
      Math.max(offer.outboundSegments.length - 1, 0)
    ))
  );

  for (const offer of offers) {
    if (offer.totalPrice.amount === minimumPrice) {
      offer.badges.push("lowestPrice");
    }
    if (offer.totalDuration === minimumDuration) {
      offer.badges.push("fastest");
    }
    if (
      Math.max(offer.outboundSegments.length - 1, 0)
        === minimumStops
    ) {
      offer.badges.push("fewestStops");
    }
  }
}

function offerSignature(offer) {
  const token = offer.booking_token ?? offer.departure_token;
  if (typeof token === "string" && token.length > 0) {
    return token;
  }
  return JSON.stringify({
    flights: offer.flights,
    price: offer.price,
    duration: offer.total_duration
  });
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

function timeZoneForAirport(code, criteria) {
  if (code === criteria.origin.iataCode) {
    return {
      identifier: criteria.origin.timeZoneIdentifier,
      resolved: true
    };
  }
  if (code === criteria.destination.iataCode) {
    return {
      identifier: criteria.destination.timeZoneIdentifier,
      resolved: true
    };
  }
  return {
    identifier: "UTC",
    resolved: false
  };
}

function localDateTimeToISO(value, timeZone) {
  const match = String(value).match(
    /^(\d{4})-(\d{2})-(\d{2})\s+(\d{1,2}):(\d{2})$/
  );
  if (!match) {
    throw new Error("Invalid local flight time.");
  }
  const components = match.slice(1).map(Number);
  let instant = Date.UTC(
    components[0],
    components[1] - 1,
    components[2],
    components[3],
    components[4]
  );

  if (timeZone !== "UTC") {
    for (let iteration = 0; iteration < 2; iteration += 1) {
      const offset = timeZoneOffsetMilliseconds(
        new Date(instant),
        timeZone
      );
      instant = Date.UTC(
        components[0],
        components[1] - 1,
        components[2],
        components[3],
        components[4]
      ) - offset;
    }
  }

  return new Date(instant).toISOString();
}

function timeZoneOffsetMilliseconds(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23"
  }).formatToParts(date);
  const values = Object.fromEntries(
    parts.map((part) => [part.type, part.value])
  );
  const representedAsUTC = Date.UTC(
    Number(values.year),
    Number(values.month) - 1,
    Number(values.day),
    Number(values.hour),
    Number(values.minute),
    Number(values.second)
  );
  return representedAsUTC - date.getTime();
}

function dateOnly(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(date);
  const values = Object.fromEntries(
    parts.map((part) => [part.type, part.value])
  );
  return `${values.year}-${values.month}-${values.day}`;
}

function travelClassParameter(value) {
  switch (value) {
    case "premiumEconomy":
      return "2";
    case "business":
      return "3";
    case "first":
      return "4";
    default:
      return "1";
  }
}

function stopsParameter(value) {
  switch (value) {
    case "nonstopOnly":
      return "1";
    case "atMostOne":
      return "2";
    default:
      return "0";
  }
}

function priceLevel(value) {
  const normalized = String(value ?? "").toLowerCase();
  if (normalized === "low") {
    return "low";
  }
  if (normalized === "high") {
    return "high";
  }
  if (normalized === "typical") {
    return "typical";
  }
  return "unknown";
}

function money(amount, currencyCode) {
  return {
    amount,
    currencyCode
  };
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

function integerOrNull(value) {
  const number = Number(value);
  return Number.isInteger(number) ? number : null;
}

function requireObject(value, code) {
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new GatewayError(422, code, "Invalid flight search request.");
  }
  return value;
}

function requireArray(value, code) {
  if (!Array.isArray(value) || value.length === 0) {
    throw new GatewayError(422, code, "Invalid flight search result.");
  }
  return value;
}

function requireString(value, code) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new GatewayError(422, code, "Invalid flight search data.");
  }
  return value;
}

function requireIATACode(value, code) {
  const normalized = String(value ?? "").trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(normalized)) {
    throw new GatewayError(
      422,
      code,
      "A three-letter airport code is required."
    );
  }
  return normalized;
}

function requireTimeZone(value, code) {
  const timeZone = String(value ?? "");
  try {
    new Intl.DateTimeFormat("en-US", {
      timeZone
    }).format();
    return timeZone;
  } catch {
    throw new GatewayError(
      422,
      code,
      "A valid airport time zone is required."
    );
  }
}

function requireDate(value, code) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new GatewayError(
      422,
      code,
      "A valid flight date is required."
    );
  }
  return date;
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
      "A passenger count is outside the supported range."
    );
  }
  return value;
}

function requireCurrency(value) {
  const normalized = String(value ?? "").trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(normalized)) {
    throw new GatewayError(
      422,
      "invalid_flight_currency",
      "A three-letter currency code is required."
    );
  }
  return normalized;
}
