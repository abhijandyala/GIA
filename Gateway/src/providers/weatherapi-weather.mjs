import { createHash } from "node:crypto";

import { GatewayError } from "../gateway.mjs";

const WEATHERAPI_URL =
  "https://api.weatherapi.com/v1/forecast.json";
const RESULT_TTL_MILLISECONDS = 900_000;

export function createWeatherAPIProvider({
  apiKey,
  forecastDaysLimit = 3,
  fetchImplementation = globalThis.fetch,
  now = () => new Date()
}) {
  const supportedDays = boundedInteger(
    forecastDaysLimit,
    1,
    14,
    3
  );

  return async function getWeather(criteria, context = {}) {
    if (!apiKey) {
      throw new GatewayError(
        503,
        "weatherapi_not_configured",
        "Weather intelligence is not configured."
      );
    }

    const retrievedAt = now();
    const validated = validateWeatherCriteria(
      criteria,
      retrievedAt
    );
    const requestWindow = forecastRequestWindow(
      validated,
      retrievedAt,
      supportedDays
    );
    if (!requestWindow) {
      return {
        snapshots: []
      };
    }

    const url = buildWeatherURL(
      validated,
      requestWindow.days,
      apiKey
    );
    const payload = await fetchWeatherAPI(
      url,
      context.signal,
      fetchImplementation
    );
    return {
      snapshots: mapWeatherResults(
        payload,
        validated,
        retrievedAt
      )
    };
  };
}

export function validateWeatherCriteria(criteria, now = new Date()) {
  requireObject(criteria, "invalid_weather_request");
  requireObject(criteria.location, "missing_weather_location");
  requireObject(criteria.dateRange, "missing_weather_dates");

  const coordinate = requireCoordinate(
    criteria.location.coordinate,
    "missing_weather_coordinate"
  );
  requireString(criteria.location.id, "missing_weather_location_id");
  requireString(
    criteria.location.name,
    "missing_weather_location_name"
  );
  const timeZone = requireTimeZone(
    criteria.location.timeZoneIdentifier
      ?? criteria.dateRange.timeZoneIdentifier,
    "missing_weather_time_zone"
  );
  const start = requireDate(
    criteria.dateRange.start,
    "invalid_weather_start"
  );
  const end = requireDate(
    criteria.dateRange.end,
    "invalid_weather_end"
  );
  if (end < start) {
    throw new GatewayError(
      422,
      "reversed_weather_dates",
      "Weather dates are reversed."
    );
  }

  const today = dateOnly(now, timeZone);
  if (dateOnly(end, timeZone) < today) {
    throw new GatewayError(
      422,
      "past_weather_trip",
      "Forecast weather is unavailable for a completed trip."
    );
  }

  return {
    ...criteria,
    location: {
      ...criteria.location,
      coordinate,
      timeZoneIdentifier: timeZone
    },
    dateRange: {
      ...criteria.dateRange,
      start,
      end,
      timeZoneIdentifier: timeZone
    },
    includeAlerts: criteria.includeAlerts === true
  };
}

export function forecastRequestWindow(criteria, now, supportedDays) {
  const timeZone = criteria.dateRange.timeZoneIdentifier;
  const today = dateOnly(now, timeZone);
  const requestedStart = dateOnly(criteria.dateRange.start, timeZone);
  const requestedEnd = dateOnly(criteria.dateRange.end, timeZone);
  const horizonEnd = addCalendarDays(today, supportedDays - 1);

  if (requestedStart > horizonEnd || requestedEnd < today) {
    return null;
  }

  const includedEnd =
    requestedEnd < horizonEnd ? requestedEnd : horizonEnd;
  return {
    days: calendarDayDifference(today, includedEnd) + 1,
    today,
    horizonEnd
  };
}

export function buildWeatherURL(criteria, days, apiKey) {
  const coordinate = criteria.location.coordinate;
  const url = new URL(WEATHERAPI_URL);
  url.searchParams.set("key", apiKey);
  url.searchParams.set(
    "q",
    `${coordinate.latitude},${coordinate.longitude}`
  );
  url.searchParams.set("days", String(days));
  url.searchParams.set("aqi", "no");
  url.searchParams.set(
    "alerts",
    criteria.includeAlerts ? "yes" : "no"
  );
  return url;
}

export function mapWeatherResults(payload, criteria, retrievedAt) {
  requireObject(payload, "invalid_weatherapi_response");
  if (payload.error) {
    throw new GatewayError(
      502,
      "weatherapi_provider_error",
      "The weather provider could not complete the forecast."
    );
  }
  requireObject(payload.location, "missing_weatherapi_location");

  const providerTimeZone = requireTimeZone(
    payload.location.tz_id
      ?? criteria.location.timeZoneIdentifier,
    "invalid_weatherapi_time_zone"
  );
  const coordinate = requireCoordinate(
    {
      latitude:
        payload.location.lat
        ?? criteria.location.coordinate.latitude,
      longitude:
        payload.location.lon
        ?? criteria.location.coordinate.longitude
    },
    "invalid_weatherapi_coordinate"
  );
  if (!Array.isArray(payload.forecast?.forecastday)) {
    throw new GatewayError(
      502,
      "weatherapi_missing_forecast",
      "Weather data did not include a forecast."
    );
  }
  const forecastDays = payload.forecast.forecastday;
  const periods = [];
  let sourceHourCount = 0;
  const rangeStart = criteria.dateRange.start.getTime();
  const rangeEnd =
    criteria.dateRange.end.getTime() + 86_400_000;

  for (const day of forecastDays) {
    const hours = Array.isArray(day.hour) ? day.hour : [];
    sourceHourCount += hours.length;

    for (const hour of hours) {
      const epochSeconds = Number(hour.time_epoch);
      if (!Number.isFinite(epochSeconds) || epochSeconds <= 0) {
        continue;
      }
      const start = new Date(epochSeconds * 1_000);
      const end = new Date(start.getTime() + 3_600_000);
      if (end.getTime() <= rangeStart || start.getTime() >= rangeEnd) {
        continue;
      }

      const description = String(hour.condition?.text ?? "").trim();
      if (!description) {
        continue;
      }
      const conditionCode = integerOrNull(hour.condition?.code);
      const precipitationProbability = probability(
        finiteOrNull(hour.chance_of_rain),
        finiteOrNull(hour.chance_of_snow)
      );
      const signature =
        `${criteria.location.id}:${epochSeconds}:${conditionCode}`;

      periods.push({
        id: deterministicUUID(`weather-period:${signature}`),
        start: start.toISOString(),
        end: end.toISOString(),
        condition: conditionCategory(description),
        providerConditionCode: conditionCode,
        providerDescription: description,
        temperatureCelsius: finiteOrNull(hour.temp_c),
        feelsLikeCelsius: finiteOrNull(hour.feelslike_c),
        precipitationProbability,
        windKilometersPerHour: finiteOrNull(hour.wind_kph)
      });
    }
  }

  if (sourceHourCount > 0 && periods.length === 0) {
    const overlapsRequest = forecastDays.some((day) => (
      typeof day.date === "string"
      && day.date >= dateOnly(criteria.dateRange.start, providerTimeZone)
      && day.date <= dateOnly(criteria.dateRange.end, providerTimeZone)
    ));
    if (overlapsRequest) {
      throw new GatewayError(
        502,
        "weatherapi_unusable_forecast",
        "Weather data was returned in an unsupported format."
      );
    }
  }

  const alerts = criteria.includeAlerts
    ? mapAlerts(payload.alerts?.alert, retrievedAt)
    : [];
  if (periods.length === 0 && alerts.length === 0) {
    return [];
  }

  const providerLocation = {
    id: criteria.location.id,
    name:
      stringOrNull(payload.location.name)
      ?? criteria.location.name,
    city:
      stringOrNull(payload.location.name)
      ?? criteria.location.city
      ?? null,
    region:
      stringOrNull(payload.location.region)
      ?? criteria.location.region
      ?? null,
    country:
      stringOrNull(payload.location.country)
      ?? criteria.location.country
      ?? null,
    countryCode: criteria.location.countryCode ?? null,
    iataCode: criteria.location.iataCode ?? null,
    coordinate,
    timeZoneIdentifier: providerTimeZone
  };
  const snapshotSignature =
    `${criteria.location.id}:${periods[0]?.start ?? "alerts"}`
    + `:${providerTimeZone}`;

  return [
    {
      id: deterministicUUID(`weather-snapshot:${snapshotSignature}`),
      location: providerLocation,
      timeZoneIdentifier: providerTimeZone,
      periods,
      alerts,
      provenance: {
        provider: "weatherapi",
        providerIdentifier:
          deterministicUUID(`weather-source:${snapshotSignature}`),
        origin: "live",
        retrievedAt: retrievedAt.toISOString(),
        expiresAt: new Date(
          retrievedAt.getTime() + RESULT_TTL_MILLISECONDS
        ).toISOString(),
        sourceURL: "https://www.weatherapi.com/"
      }
    }
  ];
}

async function fetchWeatherAPI(url, signal, fetchImplementation) {
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
        "weatherapi_timeout",
        "Weather intelligence timed out."
      );
    }
    throw new GatewayError(
      502,
      "weatherapi_transport_failed",
      "Weather intelligence could not reach its provider."
    );
  }

  if (response.status === 429) {
    throw new GatewayError(
      429,
      "weatherapi_rate_limited",
      "Weather intelligence is busy. Try again shortly."
    );
  }
  if (response.status === 401 || response.status === 403) {
    throw new GatewayError(
      503,
      "weatherapi_authorization_failed",
      "Weather intelligence is not configured correctly."
    );
  }
  if (!response.ok) {
    throw new GatewayError(
      502,
      "weatherapi_request_failed",
      "Weather intelligence could not be completed."
    );
  }

  try {
    return await response.json();
  } catch {
    throw new GatewayError(
      502,
      "weatherapi_invalid_response",
      "Weather intelligence returned invalid data."
    );
  }
}

function mapAlerts(values, retrievedAt) {
  if (!Array.isArray(values)) {
    return [];
  }

  const alerts = [];
  const seen = new Set();
  for (const value of values) {
    const headline = String(
      value?.headline ?? value?.event ?? ""
    ).trim();
    if (!headline) {
      continue;
    }
    const expiresAt = optionalDate(value.expires);
    if (expiresAt && expiresAt <= retrievedAt) {
      continue;
    }

    const signature = JSON.stringify({
      headline,
      effective: value.effective,
      expires: value.expires,
      areas: value.areas
    });
    if (seen.has(signature)) {
      continue;
    }
    seen.add(signature);

    alerts.push({
      id: deterministicUUID(`weather-alert:${signature}`),
      headline,
      reportingAgency:
        stringOrNull(value.sender_name)
        ?? stringOrNull(value.msgtype),
      severity: alertSeverity(value.severity),
      effectiveAt: optionalDate(value.effective)?.toISOString() ?? null,
      expiresAt: expiresAt?.toISOString() ?? null,
      instructions:
        stringOrNull(value.instruction)
        ?? stringOrNull(value.note),
      sourceURL: safeURL(value.uri)
    });
  }
  return alerts;
}

function conditionCategory(description) {
  const value = description.toLowerCase();
  if (value.includes("thunder") || value.includes("storm")) {
    return "storm";
  }
  if (
    value.includes("snow")
    || value.includes("sleet")
    || value.includes("ice")
    || value.includes("blizzard")
  ) {
    return "snow";
  }
  if (
    value.includes("rain")
    || value.includes("drizzle")
    || value.includes("shower")
  ) {
    return "rain";
  }
  if (
    value.includes("fog")
    || value.includes("mist")
  ) {
    return "fog";
  }
  if (
    value.includes("cloud")
    || value.includes("overcast")
  ) {
    return "cloudy";
  }
  if (
    value.includes("wind")
    || value.includes("gale")
  ) {
    return "wind";
  }
  if (
    value.includes("clear")
    || value.includes("sunny")
  ) {
    return "clear";
  }
  return "unknown";
}

function alertSeverity(value) {
  switch (String(value ?? "").toLowerCase()) {
    case "minor":
      return "minor";
    case "moderate":
      return "moderate";
    case "severe":
      return "severe";
    case "extreme":
      return "extreme";
    default:
      return "unknown";
  }
}

function probability(rain, snow) {
  if (rain === null && snow === null) {
    return null;
  }
  return Math.min(
    Math.max(Math.max(rain ?? 0, snow ?? 0) / 100, 0),
    1
  );
}

function optionalDate(value) {
  if (typeof value !== "string" || value.length === 0) {
    return null;
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function addCalendarDays(date, days) {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}

function calendarDayDifference(start, end) {
  return Math.round(
    (
      Date.parse(`${end}T00:00:00.000Z`)
      - Date.parse(`${start}T00:00:00.000Z`)
    ) / 86_400_000
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
      "Invalid weather request data."
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
      "A valid weather coordinate is required."
    );
  }
  return {
    latitude,
    longitude
  };
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
      "A valid weather time zone is required."
    );
  }
}

function requireDate(value, code) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new GatewayError(
      422,
      code,
      "A valid weather date is required."
    );
  }
  return date;
}

function requireString(value, code) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new GatewayError(
      422,
      code,
      "A weather location name and identifier are required."
    );
  }
  return value;
}

function boundedInteger(value, minimum, maximum, fallback) {
  const number = Number(value);
  if (!Number.isInteger(number)) {
    return fallback;
  }
  return Math.min(Math.max(number, minimum), maximum);
}

function finiteOrNull(value) {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function integerOrNull(value) {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const number = Number(value);
  return Number.isInteger(number) ? number : null;
}

function stringOrNull(value) {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
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
