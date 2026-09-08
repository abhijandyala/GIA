import assert from "node:assert/strict";
import test from "node:test";

import {
  buildEventSearchURL,
  createSerpApiEventSearch,
  mapEventResults,
  validateEventCriteria
} from "../src/providers/serpapi-events.mjs";

test("event criteria map to a destination and trip-date query", () => {
  const criteria = validateEventCriteria(validCriteria());
  const url = buildEventSearchURL(criteria, "serp-test-key");

  assert.equal(url.searchParams.get("engine"), "google_events");
  assert.equal(url.searchParams.get("api_key"), "serp-test-key");
  assert.match(url.searchParams.get("q"), /music events/);
  assert.match(url.searchParams.get("q"), /Lisbon/);
  assert.match(url.searchParams.get("q"), /2027-06-10 to 2027-06-17/);
});

test("events map fixed timing, tickets, venue, and provenance", () => {
  const criteria = validateEventCriteria(validCriteria());
  const retrievedAt = new Date("2026-09-06T08:00:00.000Z");
  const first = mapEventResults(
    serpApiFixture(),
    criteria,
    retrievedAt
  );
  const second = mapEventResults(
    serpApiFixture(),
    criteria,
    new Date("2026-09-06T09:00:00.000Z")
  );

  assert.equal(first.length, 2);
  assert.equal(first[0].id, second[0].id);
  assert.equal(first[0].title, "Lisbon River Festival");
  assert.equal(first[0].start, "2027-06-12T18:30:00.000Z");
  assert.equal(first[0].end, "2027-06-12T21:00:00.000Z");
  assert.ok(first[0].schedulingTraits.includes("fixedTime"));
  assert.ok(first[0].schedulingTraits.includes("ticketRequired"));
  assert.ok(first[0].schedulingTraits.includes("outdoor"));
  assert.ok(first[0].schedulingTraits.includes("weatherDependent"));
  assert.equal(first[0].venueRating, 4.6);
  assert.equal(first[0].venueRatingScale, 5);
  assert.equal(first[0].ticketURLs.length, 1);
  assert.match(first[0].ticketURLs[0], /^https:/);
  assert.equal(first[0].provenance.provider, "serpapi");
  assert.equal(
    first[0].provenance.expiresAt,
    "2026-09-06T08:30:00.000Z"
  );

  assert.equal(first[1].title, "Lisbon Design Exhibition");
  assert.equal(first[1].start, null);
  assert.equal(first[1].end, null);
  assert.equal(
    first[1].schedulingTraits.includes("fixedTime"),
    false
  );
  assert.equal(first[1].rawDateText, "Sun, Jun 13");
});

test("cancelled, expired, out-of-range, and duplicate events are removed", () => {
  const payload = serpApiFixture();
  payload.events_results.push(
    JSON.parse(JSON.stringify(payload.events_results[0]))
  );
  payload.events_results.push({
    title: "Cancelled Concert",
    status: "cancelled",
    date: {
      start_date: "Jun 14",
      when: "Mon, Jun 14, 7:00 PM–9:00 PM"
    },
    link: "https://events.example/cancelled"
  });
  payload.events_results.push({
    title: "Outside Trip",
    date: {
      start_date: "Jun 20",
      when: "Sun, Jun 20, 7:00 PM–9:00 PM"
    },
    link: "https://events.example/outside"
  });

  const events = mapEventResults(
    payload,
    validateEventCriteria(validCriteria()),
    new Date("2026-09-06T08:00:00.000Z")
  );
  assert.equal(events.length, 2);
});

test("postponed events retain evidence without fixed schedule", () => {
  const payload = {
    events_results: [
      {
        title: "Postponed Lisbon Show",
        status: "postponed",
        date: {
          start_date: "Jun 15",
          when: "Tue, Jun 15, 8:00 PM–10:00 PM"
        },
        link: "https://events.example/postponed"
      }
    ]
  };
  const events = mapEventResults(
    payload,
    validateEventCriteria(validCriteria()),
    new Date("2026-09-06T08:00:00.000Z")
  );

  assert.equal(events.length, 1);
  assert.equal(events[0].status, "postponed");
  assert.equal(events[0].start, null);
  assert.equal(events[0].end, null);
  assert.equal(
    events[0].schedulingTraits.includes("fixedTime"),
    false
  );
});

test("invalid time zones and date ranges fail before provider calls", async () => {
  const invalidZone = validCriteria();
  invalidZone.destination.timeZoneIdentifier = "Invalid/Zone";
  const reversed = validCriteria();
  reversed.dateRange.end = "2027-06-01T00:00:00.000Z";
  let called = false;
  const search = createSerpApiEventSearch({
    apiKey: "test-key",
    fetchImplementation: async () => {
      called = true;
      return Response.json(serpApiFixture());
    }
  });

  await assert.rejects(
    () => search(invalidZone),
    (error) => error.code === "missing_event_time_zone"
  );
  await assert.rejects(
    () => search(reversed),
    (error) => error.code === "reversed_event_dates"
  );
  assert.equal(called, false);
});

test("empty event results differ from malformed event data", () => {
  const criteria = validateEventCriteria(validCriteria());
  const retrievedAt = new Date("2026-09-06T08:00:00.000Z");

  assert.deepEqual(
    mapEventResults({}, criteria, retrievedAt),
    []
  );
  assert.throws(
    () => mapEventResults(
      {
        events_results: [
          {
            title: "Missing Date"
          }
        ]
      },
      criteria,
      retrievedAt
    ),
    (error) => error.code === "serpapi_unusable_event_results"
  );
});

test("event adapter sanitizes provider authorization failures", async () => {
  const search = createSerpApiEventSearch({
    apiKey: "invalid-key",
    fetchImplementation: async () => Response.json(
      {
        error: "sensitive provider account details"
      },
      {
        status: 403
      }
    )
  });

  await assert.rejects(
    () => search(validCriteria()),
    (error) => (
      error.status === 503
      && error.code === "serpapi_authorization_failed"
      && !error.message.includes("sensitive")
    )
  );
});

test("missing event configuration fails closed", async () => {
  const search = createSerpApiEventSearch({
    apiKey: ""
  });

  await assert.rejects(
    () => search(validCriteria()),
    (error) => (
      error.status === 503
      && error.code === "serpapi_not_configured"
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
      timeZoneIdentifier: "Europe/Lisbon"
    },
    dateRange: {
      start: "2027-06-10T00:00:00.000Z",
      end: "2027-06-17T00:00:00.000Z",
      timeZoneIdentifier: "Europe/Lisbon"
    },
    query: null,
    interests: ["nightlife"],
    limit: 20
  };
}

function serpApiFixture() {
  return {
    search_metadata: {
      google_events_url:
        "https://www.google.com/search?q=events+Lisbon"
    },
    events_results: [
      {
        title: "Lisbon River Festival",
        date: {
          start_date: "Jun 12",
          when: "Sat, Jun 12, 7:30 PM–10:00 PM"
        },
        address: [
          "River Stage, Lisbon"
        ],
        link: "https://events.example/river-festival",
        description: "Outdoor music festival beside the river.",
        ticket_info: [
          {
            source: "Official Tickets",
            link: "https://tickets.example/river-festival",
            link_type: "tickets"
          },
          {
            source: "Information",
            link: "https://events.example/info",
            link_type: "details"
          }
        ],
        venue: {
          name: "River Stage",
          rating: 4.6,
          reviews: 320
        },
        image: "https://images.example/river-festival.jpg"
      },
      {
        title: "Lisbon Design Exhibition",
        date: {
          start_date: "Jun 13",
          when: "Sun, Jun 13"
        },
        address: [
          "Design Museum, Lisbon"
        ],
        link: "https://events.example/design",
        description: "Indoor design exhibition.",
        venue: {
          name: "Design Museum"
        },
        thumbnail: "https://images.example/design.jpg"
      }
    ]
  };
}
