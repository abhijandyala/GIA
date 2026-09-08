import assert from "node:assert/strict";
import test from "node:test";

import {
  buildFlightSearchURL,
  buildReturnFlightSearchURL,
  createSerpApiFlightSearch,
  createSerpApiRoundTripCompletion,
  mapFlightResults,
  mapRoundTripResults,
  validateFlightCriteria,
  validateRoundTripCompletionCriteria
} from "../src/providers/serpapi-flights.mjs";

test("flight criteria map to documented SerpApi parameters", () => {
  const criteria = validateFlightCriteria(validCriteria());
  const url = buildFlightSearchURL(criteria, "test-serp-key");

  assert.equal(url.searchParams.get("engine"), "google_flights");
  assert.equal(url.searchParams.get("departure_id"), "LAX");
  assert.equal(url.searchParams.get("arrival_id"), "NRT");
  assert.equal(url.searchParams.get("outbound_date"), "2027-06-10");
  assert.equal(url.searchParams.get("return_date"), "2027-06-17");
  assert.equal(url.searchParams.get("type"), "1");
  assert.equal(url.searchParams.get("travel_class"), "1");
  assert.equal(url.searchParams.get("stops"), "2");
  assert.equal(url.searchParams.get("adults"), "4");
  assert.equal(url.searchParams.get("currency"), "USD");

  const oneWayInput = validCriteria();
  oneWayInput.returnDate = null;
  const oneWayURL = buildFlightSearchURL(
    validateFlightCriteria(oneWayInput),
    "test-serp-key"
  );
  assert.equal(oneWayURL.searchParams.get("type"), "2");
  assert.equal(oneWayURL.searchParams.has("return_date"), false);
});

test("flight results map to stable sourced domain offers", () => {
  const criteria = validateFlightCriteria(validCriteria());
  const retrievedAt = new Date("2026-09-06T08:00:00.000Z");
  const first = mapFlightResults(
    serpApiFixture(),
    criteria,
    retrievedAt
  );
  const second = mapFlightResults(
    serpApiFixture(),
    criteria,
    new Date("2026-09-06T09:00:00.000Z")
  );

  assert.equal(first.length, 2);
  assert.equal(first[0].id, second[0].id);
  assert.equal(first[0].outboundSegments.length, 1);
  assert.equal(first[0].returnSegments.length, 0);
  assert.equal(first[0].continuationToken, "best-departure-token");
  assert.equal(
    first[0].outboundSegments[0].departure,
    "2027-06-10T17:00:00.000Z"
  );
  assert.equal(
    first[0].outboundSegments[0].arrival,
    "2027-06-11T05:00:00.000Z"
  );
  assert.equal(
    first[0].outboundSegments[0].departureLocalTimeText,
    "2027-06-10 10:00"
  );
  assert.equal(first[0].totalPrice.amount, 900);
  assert.equal(first[0].totalPrice.currencyCode, "USD");
  assert.equal(first[0].baggage.carryOnBags, 1);
  assert.equal(first[0].priceInsight.level, "low");
  assert.equal(
    first[0].priceInsight.typicalLow.amount,
    1050
  );
  assert.ok(first[0].badges.includes("lowestPrice"));
  assert.ok(first[0].badges.includes("fastest"));
  assert.ok(first[0].badges.includes("fewestStops"));
  assert.ok(first[0].badges.includes("lowerEmissions"));
  assert.equal(first[0].badges.includes("giaRecommended"), false);
  assert.equal(first[0].provenance.origin, "live");
  assert.equal(first[0].provenance.provider, "serpapi");
  assert.match(first[0].bookingURL, /^https:/);
  assert.equal(
    first[0].provenance.expiresAt,
    "2026-09-06T08:03:00.000Z"
  );
});

test("selected outbound token retrieves grounded return options", async () => {
  const criteria = validateFlightCriteria(validCriteria());
  const outbound = mapFlightResults(
    serpApiFixture(),
    criteria,
    new Date("2026-09-06T08:00:00.000Z")
  )[0];
  const completionCriteria = validateRoundTripCompletionCriteria({
    searchCriteria: validCriteria(),
    outboundOffer: outbound
  });
  const returnURL = buildReturnFlightSearchURL(
    completionCriteria.searchCriteria,
    completionCriteria.outboundOffer.continuationToken,
    "test-serp-key"
  );

  assert.equal(
    returnURL.searchParams.get("departure_token"),
    "best-departure-token"
  );

  let capturedURL;
  const complete = createSerpApiRoundTripCompletion({
    apiKey: "test-serp-key",
    fetchImplementation: async (url) => {
      capturedURL = new URL(url);
      return Response.json(returnFlightFixture());
    },
    now: () => new Date("2026-09-06T08:01:00.000Z")
  });
  const result = await complete({
    searchCriteria: validCriteria(),
    outboundOffer: outbound
  });

  assert.equal(result.offers.length, 2);
  assert.equal(
    capturedURL.searchParams.get("departure_token"),
    "best-departure-token"
  );
  assert.deepEqual(
    result.offers[0].outboundSegments,
    outbound.outboundSegments
  );
  assert.equal(result.offers[0].returnSegments.length, 1);
  assert.equal(
    result.offers[0].returnSegments[0].origin.iataCode,
    "NRT"
  );
  assert.equal(
    result.offers[0].returnSegments[0].destination.iataCode,
    "LAX"
  );
  assert.equal(result.offers[0].continuationToken, null);
  assert.equal(
    result.offers[0].providerOfferIdentifier,
    "return-booking-token"
  );
  assert.equal(result.offers[0].provenance.origin, "live");
  assert.match(result.offers[0].bookingURL, /^https:/);
});

test("round-trip completion rejects one-way and tokenless offers", () => {
  const criteria = validateFlightCriteria(validCriteria());
  const outbound = mapFlightResults(
    serpApiFixture(),
    criteria,
    new Date("2026-09-06T08:00:00.000Z")
  )[0];
  const oneWay = validCriteria();
  oneWay.returnDate = null;

  assert.throws(
    () => validateRoundTripCompletionCriteria({
      searchCriteria: oneWay,
      outboundOffer: outbound
    }),
    (error) => error.code === "round_trip_return_date_required"
  );
  assert.throws(
    () => validateRoundTripCompletionCriteria({
      searchCriteria: validCriteria(),
      outboundOffer: {
        ...outbound,
        continuationToken: null
      }
    }),
    (error) => error.code === "missing_departure_token"
  );
});

test("connection airport clocks remain explicitly unresolved", () => {
  const payload = serpApiFixture();
  payload.best_flights[0].flights = [
    {
      ...payload.best_flights[0].flights[0],
      arrival_airport: {
        name: "Dallas Fort Worth International Airport",
        id: "DFW",
        time: "2027-06-10 15:00"
      },
      duration: 180,
      flight_number: "GA 10"
    },
    {
      ...payload.best_flights[0].flights[0],
      departure_airport: {
        name: "Dallas Fort Worth International Airport",
        id: "DFW",
        time: "2027-06-10 17:00"
      },
      duration: 780,
      flight_number: "GA 11"
    }
  ];

  const offers = mapFlightResults(
    payload,
    validateFlightCriteria(validCriteria()),
    new Date("2026-09-06T08:00:00.000Z")
  );

  assert.equal(
    offers[0].outboundSegments[0].arrivalTimeZoneIsResolved,
    false
  );
  assert.equal(
    offers[0].outboundSegments[0].arrivalTimeZoneIdentifier,
    "UTC"
  );
  assert.equal(
    offers[0].outboundSegments[1].departureTimeZoneIsResolved,
    false
  );
  assert.equal(
    offers[0].outboundSegments[1].departureLocalTimeText,
    "2027-06-10 17:00"
  );
});

test("empty searches differ from unusable provider results", () => {
  const criteria = validateFlightCriteria(validCriteria());
  const retrievedAt = new Date("2026-09-06T08:00:00.000Z");

  assert.deepEqual(
    mapFlightResults({}, criteria, retrievedAt),
    []
  );
  assert.throws(
    () => mapFlightResults(
      {
        best_flights: [
          {
            flights: [],
            price: 900,
            total_duration: 600
          }
        ]
      },
      criteria,
      retrievedAt
    ),
    (error) => error.code === "serpapi_unusable_flight_results"
  );
});

test("missing airport time zones fail before provider calls", async () => {
  const criteria = validCriteria();
  criteria.origin.timeZoneIdentifier = null;
  let called = false;
  const search = createSerpApiFlightSearch({
    apiKey: "test-key",
    fetchImplementation: async () => {
      called = true;
      return Response.json(serpApiFixture());
    }
  });

  await assert.rejects(
    () => search(criteria),
    (error) => (
      error.status === 422
      && error.code === "missing_origin_time_zone"
    )
  );
  assert.equal(called, false);
});

test("adapter calls SerpApi without exposing upstream errors", async () => {
  let capturedURL;
  const search = createSerpApiFlightSearch({
    apiKey: "test-key",
    fetchImplementation: async (url) => {
      capturedURL = url;
      return Response.json(serpApiFixture());
    },
    now: () => new Date("2026-09-06T08:00:00.000Z")
  });
  const result = await search(validCriteria());

  assert.equal(result.offers.length, 2);
  assert.equal(
    capturedURL.searchParams.get("api_key"),
    "test-key"
  );

  const failingSearch = createSerpApiFlightSearch({
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
    () => failingSearch(validCriteria()),
    (error) => (
      error.status === 503
      && error.code === "serpapi_authorization_failed"
      && !error.message.includes("sensitive")
    )
  );
});

test("missing SerpApi configuration fails closed", async () => {
  const search = createSerpApiFlightSearch({
    apiKey: "",
    fetchImplementation: async () => {
      throw new Error("must not run");
    }
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
    origin: {
      id: "origin-id",
      name: "Los Angeles International Airport",
      iataCode: "LAX",
      timeZoneIdentifier: "America/Los_Angeles"
    },
    destination: {
      id: "destination-id",
      name: "Narita International Airport",
      iataCode: "NRT",
      timeZoneIdentifier: "Asia/Tokyo"
    },
    departureDate: "2027-06-10T07:00:00.000Z",
    returnDate: "2027-06-17T07:00:00.000Z",
    adults: 4,
    children: 0,
    currencyCode: "usd",
    preferences: {
      travelClass: "economy",
      stopPreference: "atMostOne",
      preferredAirlines: [],
      excludedAirlines: [],
      checkedBagRequired: false,
      refundablePreferred: false
    }
  };
}

function serpApiFixture() {
  return {
    search_metadata: {
      google_flights_url:
        "https://www.google.com/travel/flights/search"
    },
    price_insights: {
      lowest_price: 900,
      price_level: "low",
      typical_price_range: [1050, 1400]
    },
    best_flights: [
      {
        flights: [
          {
            departure_airport: {
              name: "Los Angeles International Airport",
              id: "LAX",
              time: "2027-06-10 10:00"
            },
            arrival_airport: {
              name: "Narita International Airport",
              id: "NRT",
              time: "2027-06-11 14:00"
            },
            duration: 660,
            airplane: "Boeing 787",
            airline: "GIA Airways",
            airline_logo: "https://example.com/airline.png",
            travel_class: "Economy",
            flight_number: "GA 101",
            extensions: [
              "1 free carry-on bag"
            ]
          }
        ],
        total_duration: 660,
        carbon_emissions: {
          this_flight: 650000,
          typical_for_this_route: 700000,
          difference_percent: -7
        },
        price: 900,
        type: "Round trip",
        departure_token: "best-departure-token"
      }
    ],
    other_flights: [
      {
        flights: [
          {
            departure_airport: {
              name: "Los Angeles International Airport",
              id: "LAX",
              time: "2027-06-10 12:00"
            },
            arrival_airport: {
              name: "Narita International Airport",
              id: "NRT",
              time: "2027-06-11 17:30"
            },
            duration: 690,
            airplane: "Airbus A350",
            airline: "Example Air",
            airline_logo: "https://example.com/example.png",
            travel_class: "Economy",
            flight_number: "EA 22",
            extensions: []
          }
        ],
        total_duration: 690,
        carbon_emissions: {
          this_flight: 720000
        },
        price: 980,
        type: "Round trip",
        departure_token: "other-flight-token"
      }
    ]
  };
}

function returnFlightFixture() {
  const returnFlight = {
    flights: [
      {
        departure_airport: {
          name: "Narita International Airport",
          id: "NRT",
          time: "2027-06-17 16:00"
        },
        arrival_airport: {
          name: "Los Angeles International Airport",
          id: "LAX",
          time: "2027-06-17 09:30"
        },
        duration: 630,
        airplane: "Boeing 787",
        airline: "GIA Airways",
        travel_class: "Economy",
        flight_number: "GA 102",
        extensions: ["1 free carry-on bag"]
      }
    ],
    total_duration: 630,
    price: 940,
    type: "Round trip",
    booking_token: "return-booking-token"
  };
  return {
    search_metadata: {
      google_flights_url:
        "https://www.google.com/travel/flights/search?selected=true"
    },
    best_flights: [returnFlight],
    other_flights: [
      {
        ...returnFlight,
        flights: [
          {
            ...returnFlight.flights[0],
            departure_airport: {
              ...returnFlight.flights[0].departure_airport,
              time: "2027-06-17 18:00"
            },
            arrival_airport: {
              ...returnFlight.flights[0].arrival_airport,
              time: "2027-06-17 11:30"
            },
            flight_number: "GA 104"
          }
        ],
        price: 980,
        booking_token: "return-booking-token-2"
      }
    ]
  };
}
