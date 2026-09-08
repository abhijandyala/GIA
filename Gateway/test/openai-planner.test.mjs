import assert from "node:assert/strict";
import test from "node:test";

import { createOpenAIPlanner } from "../src/providers/openai-planner.mjs";
import {
  plannerContext,
  validateAndSanitizeBlueprint
} from "../src/planning/plan-blueprint.mjs";

test("valid blueprints retain only sourced identifiers", () => {
  const blueprint = validBlueprint();
  blueprint.selectedFlightOfferIDs.push("flight-1");

  const validated = validateAndSanitizeBlueprint(
    blueprint,
    validInput()
  );

  assert.deepEqual(
    validated.selectedFlightOfferIDs,
    ["flight-1"]
  );
  assert.equal(validated.days[0].items[0].sourceIdentifier, "place-1");
  assert.equal("price" in validated, false);
  assert.equal("bookingStatus" in validated, false);
});

test("unknown source identifiers are rejected", () => {
  const blueprint = validBlueprint();
  blueprint.days[0].items[0].sourceIdentifier = "invented-place";

  assert.throws(
    () => validateAndSanitizeBlueprint(blueprint, validInput()),
    (error) => error.code === "unknown_source_identifier"
  );
});

test("overlapping itinerary items are rejected", () => {
  const blueprint = validBlueprint();
  blueprint.days[0].items.push({
    sourceKind: "free_time",
    sourceIdentifier: null,
    start: "2027-06-10T10:30:00.000Z",
    end: "2027-06-10T12:30:00.000Z",
    rationale: "Unstructured group time."
  });

  assert.throws(
    () => validateAndSanitizeBlueprint(blueprint, validInput()),
    (error) => error.code === "overlapping_items"
  );
});

test("impossible calendar dates are rejected", () => {
  const blueprint = validBlueprint();
  blueprint.days[0].date = "2027-99-99";

  assert.throws(
    () => validateAndSanitizeBlueprint(blueprint, validInput()),
    (error) => error.code === "invalid_plan_day_date"
  );
});

test("unknown recommendation identifiers are rejected", () => {
  const blueprint = validBlueprint();
  blueprint.recommendationRationales[0].sourceIdentifier =
    "invented-flight";

  assert.throws(
    () => validateAndSanitizeBlueprint(blueprint, validInput()),
    (error) => error.code === "unknown_source_identifier"
  );
});

test("model context removes transcript and booking URLs", () => {
  const input = validInput();
  const context = plannerContext(input);
  const serialized = JSON.stringify(context);

  assert.equal(serialized.includes("private spoken request"), false);
  assert.equal(serialized.includes("checkout.example"), false);
  assert.equal(context.flightOffers[0].id, "flight-1");
  assert.equal(context.hotelOffers[0].totalPrice.amount, 1200);
});

test("planning accepts an omitted optional budget", () => {
  const input = validInput();
  input.request.totalBudget = null;

  const context = plannerContext(input);

  assert.equal(context.request.totalBudget, null);
});

test("OpenAI planner uses Responses structured output", async () => {
  let capturedRequest;
  const planner = createOpenAIPlanner({
    apiKey: "test-openai-key",
    model: "gpt-test",
    fetchImplementation: async (url, options) => {
      capturedRequest = {
        url,
        options
      };
      return Response.json({
        output_text: JSON.stringify(validBlueprint())
      });
    }
  });

  const result = await planner(validInput());
  const body = JSON.parse(capturedRequest.options.body);

  assert.equal(
    capturedRequest.url,
    "https://api.openai.com/v1/responses"
  );
  assert.equal(
    capturedRequest.options.headers.authorization,
    "Bearer test-openai-key"
  );
  assert.equal(body.model, "gpt-test");
  assert.equal(body.store, false);
  assert.equal(body.reasoning.effort, "low");
  assert.equal(body.text.format.type, "json_schema");
  assert.equal(body.text.format.strict, true);
  assert.equal(body.text.format.schema.additionalProperties, false);
  assert.equal(result.title, "Lisbon Together");
});

test("missing OpenAI configuration fails closed", async () => {
  const planner = createOpenAIPlanner({
    apiKey: "",
    fetchImplementation: async () => {
      throw new Error("must not run");
    }
  });

  await assert.rejects(
    () => planner(validInput()),
    (error) => (
      error.status === 503
      && error.code === "openai_not_configured"
    )
  );
});

test("OpenAI authorization errors are sanitized", async () => {
  const planner = createOpenAIPlanner({
    apiKey: "invalid-key",
    fetchImplementation: async () => Response.json(
      {
        error: {
          message: "sensitive upstream details"
        }
      },
      {
        status: 401
      }
    )
  });

  await assert.rejects(
    () => planner(validInput()),
    (error) => (
      error.status === 503
      && error.code === "openai_authorization_failed"
      && !error.message.includes("sensitive")
    )
  );
});

function validInput() {
  return {
    request: {
      rawTranscript: "private spoken request",
      origin: {
        id: "origin-1",
        name: "Atlanta"
      },
      destinations: [
        {
          id: "destination-1",
          name: "Lisbon",
          timeZoneIdentifier: "Europe/Lisbon"
        }
      ],
      dateRange: {
        start: "2027-06-10T00:00:00.000Z",
        end: "2027-06-17T00:00:00.000Z",
        timeZoneIdentifier: "Europe/Lisbon"
      },
      durationDays: 8,
      travelerCount: 4,
      totalBudget: {
        amount: 6000,
        currencyCode: "USD"
      },
      interests: ["food", "museums"],
      dietaryRequirements: ["vegetarian"],
      accessibilityRequirements: [],
      preferredPace: "balanced",
      flightPreferences: {},
      hotelPreferences: {}
    },
    flightOffers: [
      {
        id: "flight-1",
        outboundSegments: [],
        returnSegments: [],
        totalDuration: 20_000,
        totalPrice: {
          amount: 900,
          currencyCode: "USD"
        },
        bookingURL: "https://checkout.example/flight"
      }
    ],
    hotelOffers: [
      {
        id: "hotel-1",
        name: "Lisbon Hotel",
        location: {
          id: "hotel-location",
          name: "Lisbon"
        },
        lodgingType: "hotel",
        totalPrice: {
          amount: 1200,
          currencyCode: "USD"
        },
        bookingURL: "https://checkout.example/hotel"
      }
    ],
    places: [
      {
        id: "place-1",
        name: "Art Museum",
        location: {
          id: "place-location",
          name: "Lisbon"
        },
        categories: ["museum"],
        estimatedDuration: 7200
      }
    ],
    routes: [
      {
        id: "route-1",
        origin: {
          id: "hotel-location",
          name: "Lisbon Hotel"
        },
        destination: {
          id: "place-location",
          name: "Art Museum"
        },
        mode: "transit",
        duration: 1200,
        confidence: "estimated"
      }
    ],
    weather: []
  };
}

function validBlueprint() {
  return {
    title: "Lisbon Together",
    summary: "A balanced sourced plan for four travelers.",
    selectedFlightOfferIDs: ["flight-1"],
    selectedHotelOfferIDs: ["hotel-1"],
    days: [
      {
        date: "2027-06-10",
        timeZoneIdentifier: "Europe/Lisbon",
        items: [
          {
            sourceKind: "place",
            sourceIdentifier: "place-1",
            start: "2027-06-10T10:00:00.000Z",
            end: "2027-06-10T12:00:00.000Z",
            rationale: "Matches the group's interest in museums."
          }
        ]
      }
    ],
    recommendationRationales: [
      {
        sourceKind: "flight",
        sourceIdentifier: "flight-1",
        reasons: [
          "Balances price and total travel duration."
        ]
      },
      {
        sourceKind: "hotel",
        sourceIdentifier: "hotel-1",
        reasons: [
          "Fits the stated group budget."
        ]
      }
    ],
    warnings: [
      "Availability must be rechecked before external checkout."
    ]
  };
}
