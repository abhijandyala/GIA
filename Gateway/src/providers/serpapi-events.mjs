import { createHash } from "node:crypto";

import { GatewayError } from "../gateway.mjs";

const SERPAPI_URL = "https://serpapi.com/search.json";
const RESULT_TTL_MILLISECONDS = 1_800_000;

export function createSerpApiEventSearch({
  apiKey,
  fetchImplementation = globalThis.fetch,
  now = () => new Date()
}) {
  return async function searchEvents(criteria, context = {}) {
    if (!apiKey) {
      throw new GatewayError(
        503,
        "serpapi_not_configured",
        "Event search is not configured."
      );
    }

    const validated = validateEventCriteria(criteria);
    const requestURL = buildEventSearchURL(validated, apiKey);
    const payload = await fetchSerpApi(
      requestURL,
      context.signal,
      fetchImplementation
    );
    return {
      events: mapEventResults(payload, validated, now())
    };
  };
}

export function validateEventCriteria(criteria) {
  requireObject(criteria, "invalid_event_request");
  requireObject(criteria.destination, "missing_event_destination");
  requireObject(criteria.dateRange, "missing_event_dates");

  const destinationName = String(
    criteria.destination.city
    ?? criteria.destination.name
    ?? ""
  ).trim();
  if (destinationName.length < 2 || destinationName.length > 100) {
    throw new GatewayError(
      422,
      "invalid_event_destination",
      "A valid event destination is required."
    );
  }
  const timeZone = requireTimeZone(
    criteria.destination.timeZoneIdentifier
      ?? criteria.dateRange.timeZoneIdentifier,
    "missing_event_time_zone"
  );
  const start = requireDate(
    criteria.dateRange.start,
    "invalid_event_start"
  );
  const end = requireDate(
    criteria.dateRange.end,
    "invalid_event_end"
  );
  if (end < start) {
    throw new GatewayError(
      422,
      "reversed_event_dates",
      "Event search dates are reversed."
    );
  }
  const limit = requireInteger(
    criteria.limit,
    1,
    50,
    "invalid_event_limit"
  );
  const query = String(criteria.query ?? "").trim();
  if (query.length > 120) {
    throw new GatewayError(
      422,
      "invalid_event_query",
      "The event query is too long."
    );
  }

  return {
    ...criteria,
    destination: {
      ...criteria.destination,
      name: destinationName,
      timeZoneIdentifier: timeZone
    },
    dateRange: {
      ...criteria.dateRange,
      start,
      end,
      timeZoneIdentifier: timeZone
    },
    query,
    limit
  };
}

export function buildEventSearchURL(criteria, apiKey) {
  const url = new URL(SERPAPI_URL);
  const dateRange = [
    dateOnly(
      criteria.dateRange.start,
      criteria.dateRange.timeZoneIdentifier
    ),
    dateOnly(
      criteria.dateRange.end,
      criteria.dateRange.timeZoneIdentifier
    )
  ].join(" to ");
  const topic = criteria.query || eventQuery(criteria.interests);

  url.searchParams.set("engine", "google_events");
  url.searchParams.set(
    "q",
    `${topic} in ${criteria.destination.name} ${dateRange}`
  );
  url.searchParams.set("hl", "en");
  url.searchParams.set("api_key", apiKey);
  return url;
}

export function mapEventResults(payload, criteria, retrievedAt) {
  requireObject(payload, "invalid_serpapi_event_response");
  if (payload.error) {
    throw new GatewayError(
      502,
      "serpapi_event_error",
      "The event provider could not complete the search."
    );
  }

  const rawEvents = Array.isArray(payload.events_results)
    ? payload.events_results
    : [];
  const mapped = [];
  const seen = new Set();
  let usableCount = 0;

  for (const rawEvent of rawEvents) {
    if (mapped.length >= criteria.limit) {
      break;
    }

    try {
      const title = requireString(
        rawEvent.title,
        "missing_event_title"
      );
      const rawDateText = requireString(
        rawEvent.date?.when
        ?? rawEvent.date?.start_date,
        "missing_event_date"
      );
      const status = eventStatus(rawEvent, title);
      usableCount += 1;
      if (status === "cancelled") {
        continue;
      }

      const signature = eventSignature(rawEvent);
      if (seen.has(signature)) {
        continue;
      }
      seen.add(signature);

      const parsedTiming = parseEventTiming(rawEvent, criteria);
      const timing =
        status === "postponed"
          ? {
              ...parsedTiming,
              start: null,
              end: null
            }
          : parsedTiming;
      if (
        timing.calendarDate
        && !calendarDateWithinRange(
          timing.calendarDate,
          criteria.dateRange,
          criteria.dateRange.timeZoneIdentifier
        )
      ) {
        continue;
      }
      if (
        timing.end
        && timing.end.getTime() < retrievedAt.getTime()
      ) {
        continue;
      }

      const providerID = deterministicUUID(
        `serpapi-event-source:${signature}`
      );
      const ticketURLs = mapTicketURLs(rawEvent.ticket_info);
      const sourceURL = safeURL(rawEvent.link);
      const venueName =
        typeof rawEvent.venue?.name === "string"
          ? rawEvent.venue.name
          : firstAddressValue(rawEvent.address);
      const locationName =
        venueName || criteria.destination.name;
      const venueRating = boundedNumber(
        rawEvent.venue?.rating,
        0,
        5
      );

      mapped.push({
        id: deterministicUUID(`serpapi-event:${signature}`),
        providerEventIdentifier: providerID,
        title,
        summary:
          typeof rawEvent.description === "string"
            ? rawEvent.description
            : null,
        venueName: venueName || null,
        location: {
          id: deterministicUUID(`event-location:${signature}`),
          name: locationName,
          city:
            criteria.destination.city
            ?? criteria.destination.name,
          region: criteria.destination.region ?? null,
          country: criteria.destination.country ?? null,
          countryCode:
            criteria.destination.countryCode ?? null,
          iataCode: null,
          coordinate: null,
          timeZoneIdentifier:
            criteria.destination.timeZoneIdentifier
        },
        start: timing.start?.toISOString() ?? null,
        end: timing.end?.toISOString() ?? null,
        rawDateText,
        timeZoneIdentifier:
          criteria.destination.timeZoneIdentifier,
        timeZoneIsResolved: true,
        status,
        schedulingTraits: schedulingTraits(
          timing,
          ticketURLs,
          rawEvent
        ),
        venueRating,
        venueRatingScale: venueRating === null ? null : 5,
        venueReviewCount:
          nonnegativeInteger(rawEvent.venue?.reviews),
        imageURL: safeURL(
          rawEvent.image ?? rawEvent.thumbnail
        ),
        sourceURL,
        ticketURLs,
        provenance: {
          provider: "serpapi",
          providerIdentifier: providerID,
          origin: "live",
          retrievedAt: retrievedAt.toISOString(),
          expiresAt: new Date(
            retrievedAt.getTime() + RESULT_TTL_MILLISECONDS
          ).toISOString(),
          sourceURL:
            sourceURL
            ?? safeURL(
              payload.search_metadata?.google_events_url
            )
            ?? "https://www.google.com/search"
        }
      });
    } catch {
      continue;
    }
  }

  if (rawEvents.length > 0 && usableCount === 0) {
    throw new GatewayError(
      502,
      "serpapi_unusable_event_results",
      "Event search returned results in an unsupported format."
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
        "serpapi_event_timeout",
        "Event search timed out."
      );
    }
    throw new GatewayError(
      502,
      "serpapi_event_transport_failed",
      "Event search could not reach its provider."
    );
  }

  if (response.status === 429) {
    throw new GatewayError(
      429,
      "serpapi_event_rate_limited",
      "Event search is busy. Try again shortly."
    );
  }
  if (response.status === 401 || response.status === 403) {
    throw new GatewayError(
      503,
      "serpapi_authorization_failed",
      "Event search is not configured correctly."
    );
  }
  if (!response.ok) {
    throw new GatewayError(
      502,
      "serpapi_event_request_failed",
      "Event search could not be completed."
    );
  }

  try {
    return await response.json();
  } catch {
    throw new GatewayError(
      502,
      "serpapi_event_invalid_response",
      "Event search returned invalid data."
    );
  }
}

function parseEventTiming(rawEvent, criteria) {
  const dateText = String(
    rawEvent.date?.start_date
    ?? rawEvent.date?.when
    ?? ""
  );
  const calendarDate = parseCalendarDate(
    dateText,
    criteria.dateRange,
    criteria.dateRange.timeZoneIdentifier
  );
  if (!calendarDate) {
    return {
      calendarDate: null,
      start: null,
      end: null
    };
  }

  const timeRange = parseTimeRange(
    rawEvent.date?.when
    ?? rawEvent.date?.start_time
    ?? ""
  );
  if (!timeRange) {
    return {
      calendarDate,
      start: null,
      end: null
    };
  }

  const components = calendarDate.split("-").map(Number);
  const start = zonedDateTime(
    components[0],
    components[1],
    components[2],
    timeRange.startHour,
    timeRange.startMinute,
    criteria.dateRange.timeZoneIdentifier
  );
  let end = zonedDateTime(
    components[0],
    components[1],
    components[2],
    timeRange.endHour,
    timeRange.endMinute,
    criteria.dateRange.timeZoneIdentifier
  );
  if (end <= start) {
    end = new Date(end.getTime() + 86_400_000);
  }

  return {
    calendarDate,
    start,
    end
  };
}

function parseCalendarDate(value, dateRange, timeZone) {
  const iso = String(value).match(
    /\b(\d{4})-(\d{2})-(\d{2})\b/
  );
  if (iso) {
    const result = `${iso[1]}-${iso[2]}-${iso[3]}`;
    return isValidDateOnly(result) ? result : null;
  }

  const monthNames = {
    jan: 1, january: 1,
    feb: 2, february: 2,
    mar: 3, march: 3,
    apr: 4, april: 4,
    may: 5,
    jun: 6, june: 6,
    jul: 7, july: 7,
    aug: 8, august: 8,
    sep: 9, sept: 9, september: 9,
    oct: 10, october: 10,
    nov: 11, november: 11,
    dec: 12, december: 12
  };
  const match = String(value).toLowerCase().match(
    /\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2})\b/
  );
  if (!match) {
    return null;
  }

  const month = monthNames[match[1]];
  const day = Number(match[2]);
  const startYear = Number(
    dateOnly(dateRange.start, timeZone).slice(0, 4)
  );
  const endYear = Number(
    dateOnly(dateRange.end, timeZone).slice(0, 4)
  );
  for (const year of new Set([startYear, endYear])) {
    const candidate = [
      year,
      String(month).padStart(2, "0"),
      String(day).padStart(2, "0")
    ].join("-");
    if (
      isValidDateOnly(candidate)
      && calendarDateWithinRange(
        candidate,
        dateRange,
        timeZone
      )
    ) {
      return candidate;
    }
  }

  const fallback = [
    startYear,
    String(month).padStart(2, "0"),
    String(day).padStart(2, "0")
  ].join("-");
  return isValidDateOnly(fallback) ? fallback : null;
}

function parseTimeRange(value) {
  const match = String(value).match(
    /(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?\s*[–-]\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?/i
  );
  if (!match) {
    return null;
  }

  const endMeridiem = match[6]?.toUpperCase() ?? null;
  const startMeridiem =
    match[3]?.toUpperCase() ?? endMeridiem;
  const start = normalizedClock(
    Number(match[1]),
    Number(match[2] ?? 0),
    startMeridiem
  );
  const end = normalizedClock(
    Number(match[4]),
    Number(match[5] ?? 0),
    endMeridiem
  );
  if (!start || !end) {
    return null;
  }

  return {
    startHour: start.hour,
    startMinute: start.minute,
    endHour: end.hour,
    endMinute: end.minute
  };
}

function normalizedClock(hour, minute, meridiem) {
  if (
    !Number.isInteger(hour)
    || !Number.isInteger(minute)
    || minute < 0
    || minute > 59
  ) {
    return null;
  }
  if (meridiem) {
    if (hour < 1 || hour > 12) {
      return null;
    }
    const normalizedHour =
      hour % 12 + (meridiem === "PM" ? 12 : 0);
    return {
      hour: normalizedHour,
      minute
    };
  }
  if (hour < 0 || hour > 23) {
    return null;
  }
  return {
    hour,
    minute
  };
}

function zonedDateTime(
  year,
  month,
  day,
  hour,
  minute,
  timeZone
) {
  const base = Date.UTC(year, month - 1, day, hour, minute);
  let instant = base;
  for (let iteration = 0; iteration < 2; iteration += 1) {
    instant = base - timeZoneOffsetMilliseconds(
      new Date(instant),
      timeZone
    );
  }
  return new Date(instant);
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
  return Date.UTC(
    Number(values.year),
    Number(values.month) - 1,
    Number(values.day),
    Number(values.hour),
    Number(values.minute),
    Number(values.second)
  ) - date.getTime();
}

function schedulingTraits(timing, ticketURLs, event) {
  const traits = new Set();
  if (timing.start) {
    traits.add("fixedTime");
  }
  if (ticketURLs.length > 0) {
    traits.add("ticketRequired");
    traits.add("reservationAvailable");
  }

  const text = `${event.title ?? ""} ${event.description ?? ""}`
    .toLowerCase();
  if (
    text.includes("outdoor")
    || text.includes("festival")
    || text.includes("park")
  ) {
    traits.add("outdoor");
    traits.add("weatherDependent");
  }
  if (
    text.includes("museum")
    || text.includes("theater")
    || text.includes("theatre")
    || text.includes("indoor")
  ) {
    traits.add("indoor");
  }
  return [...traits];
}

function eventStatus(event, title) {
  const value = String(event.status ?? title).toLowerCase();
  if (value.includes("cancel")) {
    return "cancelled";
  }
  if (value.includes("postpon")) {
    return "postponed";
  }
  return "upcoming";
}

function mapTicketURLs(ticketInfo) {
  if (!Array.isArray(ticketInfo)) {
    return [];
  }
  return [
    ...new Set(
      ticketInfo
        .filter((item) => (
          String(item?.link_type ?? "").toLowerCase()
            .includes("ticket")
        ))
        .map((item) => safeURL(item.link))
        .filter(Boolean)
    )
  ].slice(0, 10);
}

function eventSignature(event) {
  return JSON.stringify({
    title: event.title,
    date: event.date,
    venue: event.venue?.name,
    link: event.link
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

function eventQuery(interests) {
  const values = Array.isArray(interests) ? interests : [];
  if (values.includes("sports")) return "sports events";
  if (values.includes("art")) return "art events";
  if (values.includes("food")) return "food events";
  if (values.includes("nightlife")) return "music events";
  return "events";
}

function calendarDateWithinRange(date, range, timeZone) {
  const start = dateOnly(range.start, timeZone);
  const end = dateOnly(range.end, timeZone);
  return date >= start && date <= end;
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

function isValidDateOnly(value) {
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return (
    !Number.isNaN(parsed.getTime())
    && parsed.toISOString().slice(0, 10) === value
  );
}

function firstAddressValue(address) {
  if (!Array.isArray(address)) {
    return null;
  }
  return address.find(
    (value) => typeof value === "string" && value.length > 0
  ) ?? null;
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
      "Invalid event search data."
    );
  }
  return value;
}

function requireString(value, code) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new GatewayError(
      422,
      code,
      "Invalid event search data."
    );
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
      "A valid event time zone is required."
    );
  }
}

function requireDate(value, code) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new GatewayError(
      422,
      code,
      "A valid event date is required."
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
      "The event result limit is invalid."
    );
  }
  return value;
}
