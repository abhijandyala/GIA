import { createHash } from "node:crypto";

import { GatewayError } from "../gateway.mjs";

const SERPAPI_URL = "https://serpapi.com/search.json";
const MAX_OFFERS = 20;

export function createSerpApiHotelSearch({
  apiKey,
  fetchImplementation = globalThis.fetch,
  now = () => new Date()
}) {
  return async function searchHotels(criteria, context = {}) {
    if (!apiKey) {
      throw new GatewayError(
        503,
        "serpapi_not_configured",
        "Hotel search is not configured."
      );
    }

    const normalizedCriteria = validateHotelCriteria(criteria);
    const requestURL = buildHotelSearchURL(
      normalizedCriteria,
      apiKey
    );
    const payload = await fetchSerpApi(
      requestURL,
      context.signal,
      fetchImplementation
    );
    const offers = mapHotelResults(
      payload,
      normalizedCriteria,
      now()
    );

    return {
      offers
    };
  };
}

export function validateHotelCriteria(criteria) {
  requireObject(criteria, "invalid_hotel_request");
  requireObject(criteria.destination, "missing_hotel_destination");

  const destinationName = String(
    criteria.destination.city
    ?? criteria.destination.name
    ?? ""
  ).trim();
  if (destinationName.length < 2 || destinationName.length > 100) {
    throw new GatewayError(
      422,
      "invalid_hotel_destination",
      "A valid hotel destination is required."
    );
  }
  const timeZone = requireTimeZone(
    criteria.destination.timeZoneIdentifier,
    "missing_hotel_time_zone"
  );
  const checkInDate = requireDate(
    criteria.checkInDate,
    "invalid_hotel_check_in"
  );
  const checkOutDate = requireDate(
    criteria.checkOutDate,
    "invalid_hotel_check_out"
  );
  if (checkOutDate <= checkInDate) {
    throw new GatewayError(
      422,
      "invalid_hotel_date_range",
      "Hotel checkout must follow check-in."
    );
  }

  const adults = requireInteger(
    criteria.adults,
    1,
    30,
    "invalid_hotel_adults"
  );
  const rooms = requireInteger(
    criteria.rooms,
    1,
    10,
    "invalid_hotel_rooms"
  );
  if (rooms > adults) {
    throw new GatewayError(
      422,
      "invalid_hotel_occupancy",
      "Room count cannot exceed adult traveler count."
    );
  }

  const currencyCode = requireCurrency(criteria.currencyCode);
  const minimumStarRating =
    criteria.preferences?.minimumStarRating;
  if (
    minimumStarRating !== null
    && minimumStarRating !== undefined
    && (
      !Number.isInteger(minimumStarRating)
      || minimumStarRating < 2
      || minimumStarRating > 5
    )
  ) {
    throw new GatewayError(
      422,
      "invalid_hotel_class",
      "Minimum hotel class must be between two and five."
    );
  }

  const minimumGuestRating =
    criteria.preferences?.minimumGuestRating;
  if (
    minimumGuestRating !== null
    && minimumGuestRating !== undefined
    && (
      !Number.isFinite(minimumGuestRating)
      || minimumGuestRating < 0
      || minimumGuestRating > 5
    )
  ) {
    throw new GatewayError(
      422,
      "invalid_guest_rating",
      "Minimum guest rating must use the five-point scale."
    );
  }

  return {
    ...criteria,
    destination: {
      ...criteria.destination,
      name: destinationName,
      timeZoneIdentifier: timeZone
    },
    checkInDate,
    checkOutDate,
    adults,
    rooms,
    currencyCode
  };
}

export function buildHotelSearchURL(criteria, apiKey) {
  const url = new URL(SERPAPI_URL);
  const parameters = url.searchParams;
  parameters.set("engine", "google_hotels");
  parameters.set("api_key", apiKey);
  parameters.set("q", criteria.destination.name);
  parameters.set(
    "check_in_date",
    dateOnly(
      criteria.checkInDate,
      criteria.destination.timeZoneIdentifier
    )
  );
  parameters.set(
    "check_out_date",
    dateOnly(
      criteria.checkOutDate,
      criteria.destination.timeZoneIdentifier
    )
  );
  parameters.set("adults", String(criteria.adults));
  parameters.set("rooms", String(criteria.rooms));
  parameters.set("children", "0");
  parameters.set("currency", criteria.currencyCode);
  parameters.set("sort_by", "3");
  parameters.set("hl", "en");

  const minimumClass = criteria.preferences?.minimumStarRating;
  if (Number.isInteger(minimumClass)) {
    const classes = [];
    for (let value = minimumClass; value <= 5; value += 1) {
      classes.push(value);
    }
    parameters.set("hotel_class", classes.join(","));
  }

  const rating = ratingParameter(
    criteria.preferences?.minimumGuestRating
  );
  if (rating) {
    parameters.set("rating", rating);
  }

  if (criteria.preferences?.refundablePreferred === true) {
    parameters.set("free_cancellation", "true");
  }

  const maximumNightly =
    criteria.preferences?.maximumNightlyRate;
  if (
    maximumNightly
    && maximumNightly.currencyCode === criteria.currencyCode
    && Number(maximumNightly.amount) > 0
  ) {
    parameters.set(
      "max_price",
      String(Number(maximumNightly.amount))
    );
  }

  return url;
}

export function mapHotelResults(payload, criteria, retrievedAt) {
  requireObject(payload, "invalid_serpapi_hotel_response");
  if (payload.error) {
    throw new GatewayError(
      502,
      "serpapi_hotel_error",
      "The hotel provider could not complete the search."
    );
  }

  const rawProperties = Array.isArray(payload.properties)
    ? payload.properties
    : [];
  const nights = calendarDayCount(
    criteria.checkInDate,
    criteria.checkOutDate,
    criteria.destination.timeZoneIdentifier
  );
  const expiration = new Date(
    retrievedAt.getTime() + 300_000
  );
  const searchURL = safeURL(
    payload.search_metadata?.google_hotels_url
  );
  const requiredAmenities = new Set(
    criteria.preferences?.requiredAmenities ?? []
  );
  const seen = new Set();
  const mapped = [];
  let usablePropertyCount = 0;

  for (const property of rawProperties) {
    if (mapped.length >= MAX_OFFERS) {
      break;
    }

    try {
      const signature = propertySignature(property);
      if (seen.has(signature)) {
        continue;
      }
      seen.add(signature);

      const name = requireString(
        property.name,
        "missing_hotel_name"
      );
      const nightlyAmount = firstFinitePositive([
        property.rate_per_night?.extracted_lowest,
        property.extracted_price
      ]);
      const totalAmount = firstFinitePositive([
        property.total_rate?.extracted_lowest,
        nightlyAmount === null ? null : nightlyAmount * nights
      ]);
      if (totalAmount === null) {
        continue;
      }

      const amenities = mapAmenities(property.amenities);
      const lodgingType = mapLodgingType(property.type, name);
      const starRating = mapStarRating(property);
      const guestRating = boundedNumber(
        property.overall_rating,
        0,
        5
      );
      usablePropertyCount += 1;
      if (
        requiredAmenities.size > 0
        && ![...requiredAmenities].every(
          (amenity) => amenities.includes(amenity)
        )
      ) {
        continue;
      }
      const allowedTypes = new Set(
        criteria.preferences?.allowedTypes ?? []
      );
      if (
        allowedTypes.size > 0
        && !allowedTypes.has(lodgingType)
      ) {
        continue;
      }
      if (
        Number.isInteger(criteria.preferences?.minimumStarRating)
        && (
          starRating === null
          || starRating < criteria.preferences.minimumStarRating
        )
      ) {
        continue;
      }
      if (
        Number.isFinite(criteria.preferences?.minimumGuestRating)
        && (
          guestRating === null
          || guestRating < criteria.preferences.minimumGuestRating
        )
      ) {
        continue;
      }
      const maximumNightly = Number(
        criteria.preferences?.maximumNightlyRate?.amount
      );
      if (
        Number.isFinite(maximumNightly)
        && nightlyAmount !== null
        && nightlyAmount > maximumNightly
      ) {
        continue;
      }

      const coordinate = mapCoordinate(property.gps_coordinates);
      const propertyToken =
        typeof property.property_token === "string"
        && property.property_token.length > 0
          ? property.property_token
          : signature;
      const bookingURL = safeURL(property.link);
      const imageURLs = mapImages(property);
      const freeCancellation =
        property.free_cancellation === true;

      mapped.push({
        id: deterministicUUID(`hotel:${propertyToken}`),
        providerOfferIdentifier: propertyToken,
        name,
        location: {
          id: deterministicUUID(
            `hotel-location:${propertyToken}`
          ),
          name,
          city:
            criteria.destination.city
            ?? criteria.destination.name,
          region: criteria.destination.region ?? null,
          country: criteria.destination.country ?? null,
          countryCode:
            criteria.destination.countryCode ?? null,
          iataCode: null,
          coordinate,
          timeZoneIdentifier:
            criteria.destination.timeZoneIdentifier
        },
        lodgingType,
        starRating,
        guestRating,
        guestRatingScale: guestRating === null ? null : 5,
        reviewCount: nonnegativeInteger(property.reviews),
        nightlyPrice:
          nightlyAmount === null
            ? null
            : money(nightlyAmount, criteria.currencyCode),
        totalPrice: money(totalAmount, criteria.currencyCode),
        taxesAndFeesIncluded: taxesIncluded(property),
        roomDescription:
          typeof property.description === "string"
            ? property.description
            : null,
        amenities,
        imageURLs,
        checkInTime:
          typeof property.check_in_time === "string"
            ? property.check_in_time
            : null,
        checkOutTime:
          typeof property.check_out_time === "string"
            ? property.check_out_time
            : null,
        cancellationPolicy:
          freeCancellation
            ? {
                summary: "Free cancellation available",
                refundableUntil: null,
                penalty: null
              }
            : null,
        badges: freeCancellation ? ["flexible"] : [],
        bookingURL,
        provenance: {
          provider: "serpapi",
          providerIdentifier: propertyToken,
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

  applyPriceBadge(mapped);
  if (rawProperties.length > 0 && usablePropertyCount === 0) {
    throw new GatewayError(
      502,
      "serpapi_unusable_hotel_results",
      "Hotel search returned results in an unsupported format."
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
        "serpapi_hotel_timeout",
        "Hotel search timed out."
      );
    }
    throw new GatewayError(
      502,
      "serpapi_hotel_transport_failed",
      "Hotel search could not reach its provider."
    );
  }

  if (response.status === 429) {
    throw new GatewayError(
      429,
      "serpapi_hotel_rate_limited",
      "Hotel search is busy. Try again shortly."
    );
  }
  if (response.status === 401 || response.status === 403) {
    throw new GatewayError(
      503,
      "serpapi_authorization_failed",
      "Hotel search is not configured correctly."
    );
  }
  if (!response.ok) {
    throw new GatewayError(
      502,
      "serpapi_hotel_request_failed",
      "Hotel search could not be completed."
    );
  }

  try {
    return await response.json();
  } catch {
    throw new GatewayError(
      502,
      "serpapi_hotel_invalid_response",
      "Hotel search returned an invalid response."
    );
  }
}

function mapAmenities(values) {
  if (!Array.isArray(values)) {
    return [];
  }

  const mapped = new Set();
  for (const value of values) {
    const amenity = String(value).toLowerCase();
    if (amenity.includes("wi-fi") || amenity.includes("wifi")) {
      mapped.add("wifi");
    }
    if (amenity.includes("breakfast")) {
      mapped.add("breakfast");
    }
    if (amenity.includes("parking")) {
      mapped.add("parking");
    }
    if (amenity.includes("pool")) {
      mapped.add("pool");
    }
    if (amenity.includes("spa")) {
      mapped.add("spa");
    }
    if (
      amenity.includes("fitness")
      || amenity.includes("gym")
    ) {
      mapped.add("fitnessCenter");
    }
    if (amenity.includes("laundry")) {
      mapped.add("laundry");
    }
    if (
      amenity.includes("kitchen")
      || amenity.includes("kitchenette")
    ) {
      mapped.add("kitchen");
    }
    if (amenity.includes("airport shuttle")) {
      mapped.add("airportShuttle");
    }
    if (
      amenity.includes("accessible")
      || amenity.includes("wheelchair")
    ) {
      mapped.add("accessibleRoom");
    }
  }
  return [...mapped];
}

function mapImages(property) {
  const candidates = [];
  if (typeof property.thumbnail === "string") {
    candidates.push(property.thumbnail);
  }
  for (const image of property.images ?? []) {
    if (typeof image?.original_image === "string") {
      candidates.push(image.original_image);
    } else if (typeof image?.thumbnail === "string") {
      candidates.push(image.thumbnail);
    }
  }
  return [...new Set(candidates)]
    .map(safeURL)
    .filter(Boolean)
    .slice(0, 10);
}

function mapCoordinate(value) {
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

function mapLodgingType(type, name) {
  const normalized = `${type ?? ""} ${name}`.toLowerCase();
  if (normalized.includes("hostel")) {
    return "hostel";
  }
  if (normalized.includes("resort")) {
    return "resort";
  }
  if (
    normalized.includes("vacation rental")
    || normalized.includes("holiday rental")
  ) {
    return "vacationRental";
  }
  if (
    normalized.includes("apartment")
    || normalized.includes("aparthotel")
  ) {
    return "apartment";
  }
  return "hotel";
}

function mapStarRating(property) {
  const extracted = Number(property.extracted_hotel_class);
  if (Number.isInteger(extracted) && extracted >= 1 && extracted <= 5) {
    return extracted;
  }
  const match = String(property.hotel_class ?? "").match(/[1-5]/);
  return match ? Number(match[0]) : null;
}

function taxesIncluded(property) {
  const total = Number(property.total_rate?.extracted_lowest);
  const beforeTaxes = Number(
    property.total_rate?.extracted_before_taxes_fees
  );
  if (Number.isFinite(total) && Number.isFinite(beforeTaxes)) {
    return true;
  }
  return null;
}

function applyPriceBadge(offers) {
  if (offers.length === 0) {
    return;
  }
  const minimum = Math.min(
    ...offers.map((offer) => offer.totalPrice.amount)
  );
  for (const offer of offers) {
    if (offer.totalPrice.amount === minimum) {
      offer.badges.push("lowestPrice");
    }
  }
}

function propertySignature(property) {
  if (
    typeof property.property_token === "string"
    && property.property_token.length > 0
  ) {
    return property.property_token;
  }
  return JSON.stringify({
    name: property.name,
    coordinates: property.gps_coordinates,
    total: property.total_rate,
    nightly: property.rate_per_night
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

function calendarDayCount(start, end, timeZone) {
  const startDate = dateOnly(start, timeZone);
  const endDate = dateOnly(end, timeZone);
  return Math.max(
    Math.round(
      (
        Date.parse(`${endDate}T00:00:00.000Z`)
        - Date.parse(`${startDate}T00:00:00.000Z`)
      ) / 86_400_000
    ),
    1
  );
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

function ratingParameter(value) {
  if (!Number.isFinite(value)) {
    return null;
  }
  if (value >= 4.5) {
    return "9";
  }
  if (value >= 4) {
    return "8";
  }
  if (value >= 3.5) {
    return "7";
  }
  return null;
}

function firstFinitePositive(values) {
  for (const value of values) {
    const number = Number(value);
    if (Number.isFinite(number) && number > 0) {
      return number;
    }
  }
  return null;
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

function requireObject(value, code) {
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new GatewayError(422, code, "Invalid hotel search request.");
  }
  return value;
}

function requireString(value, code) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new GatewayError(422, code, "Invalid hotel search data.");
  }
  return value;
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
      "A valid destination time zone is required."
    );
  }
}

function requireDate(value, code) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new GatewayError(
      422,
      code,
      "A valid hotel date is required."
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
      "Hotel occupancy is outside the supported range."
    );
  }
  return value;
}

function requireCurrency(value) {
  const normalized = String(value ?? "").trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(normalized)) {
    throw new GatewayError(
      422,
      "invalid_hotel_currency",
      "A three-letter currency code is required."
    );
  }
  return normalized;
}
