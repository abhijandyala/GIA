import { GatewayError } from "../gateway.mjs";
import {
  PLAN_BLUEPRINT_SCHEMA,
  PlanValidationError,
  plannerContext,
  validateAndSanitizeBlueprint,
  validatePlanningInput
} from "../planning/plan-blueprint.mjs";

const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";

const PLANNER_INSTRUCTIONS = `
You are GIA's constrained group-trip planning engine.

Use only source identifiers present in the supplied context.
Never invent a flight, hotel, place, route, price, rating, schedule,
availability, booking, confirmation, or weather condition.
Do not repeat prices or factual values in your output; the application
will render those values directly from sourced records.
Select options by UUID and explain tradeoffs in concise language.
Respect the trip dates, traveler count, budget, dietary needs,
accessibility needs, pace, opening information, route duration,
weather, and fixed times.
Do not overlap itinerary items.
Use free_time only when no sourced item is appropriate, and set its
sourceIdentifier to null.
Warnings must identify uncertainty or missing source coverage.
The result is a proposal, never a completed booking.
`.trim();

export function createOpenAIPlanner({
  apiKey,
  model = "gpt-5.4",
  fetchImplementation = globalThis.fetch
}) {
  return async function plan(input, context = {}) {
    if (!apiKey) {
      throw new GatewayError(
        503,
        "openai_not_configured",
        "Trip intelligence is not configured."
      );
    }
    if (typeof fetchImplementation !== "function") {
      throw new GatewayError(
        503,
        "openai_transport_unavailable",
        "Trip intelligence is temporarily unavailable."
      );
    }

    try {
      validatePlanningInput(input);
    } catch (error) {
      throw validationGatewayError(error);
    }

    const response = await callOpenAI({
      apiKey,
      model,
      input: plannerContext(input),
      signal: context.signal,
      fetchImplementation
    });
    const outputText = extractOutputText(response);

    let blueprint;
    try {
      blueprint = JSON.parse(outputText);
    } catch {
      throw new GatewayError(
        502,
        "openai_invalid_json",
        "Trip intelligence returned an invalid plan."
      );
    }

    try {
      return validateAndSanitizeBlueprint(blueprint, input);
    } catch (error) {
      throw validationGatewayError(error);
    }
  };
}

async function callOpenAI({
  apiKey,
  model,
  input,
  signal,
  fetchImplementation
}) {
  let response;
  try {
    response = await fetchImplementation(OPENAI_RESPONSES_URL, {
      method: "POST",
      headers: {
        authorization: `Bearer ${apiKey}`,
        "content-type": "application/json"
      },
      body: JSON.stringify({
        model,
        store: false,
        reasoning: {
          effort: "low"
        },
        instructions: PLANNER_INSTRUCTIONS,
        input: JSON.stringify(input),
        text: {
          format: {
            type: "json_schema",
            name: "gia_trip_plan",
            strict: true,
            schema: PLAN_BLUEPRINT_SCHEMA
          }
        }
      }),
      signal
    });
  } catch (error) {
    if (signal?.aborted || error?.name === "AbortError") {
      throw new GatewayError(
        504,
        "openai_timeout",
        "Trip intelligence timed out."
      );
    }
    throw new GatewayError(
      502,
      "openai_transport_failed",
      "Trip intelligence could not be reached."
    );
  }

  if (!response.ok) {
    if (response.status === 429) {
      throw new GatewayError(
        429,
        "openai_rate_limited",
        "Trip intelligence is busy. Try again shortly."
      );
    }
    if (response.status === 401 || response.status === 403) {
      throw new GatewayError(
        503,
        "openai_authorization_failed",
        "Trip intelligence is not configured correctly."
      );
    }
    throw new GatewayError(
      502,
      "openai_request_failed",
      "Trip intelligence could not create a plan."
    );
  }

  try {
    return await response.json();
  } catch {
    throw new GatewayError(
      502,
      "openai_invalid_response",
      "Trip intelligence returned an invalid response."
    );
  }
}

function extractOutputText(response) {
  if (
    typeof response.output_text === "string"
    && response.output_text.length > 0
  ) {
    return response.output_text;
  }

  for (const output of response.output ?? []) {
    for (const content of output.content ?? []) {
      if (
        content.type === "output_text"
        && typeof content.text === "string"
        && content.text.length > 0
      ) {
        return content.text;
      }
    }
  }

  throw new GatewayError(
    502,
    "openai_missing_output",
    "Trip intelligence returned no plan."
  );
}

function validationGatewayError(error) {
  if (error instanceof PlanValidationError) {
    return new GatewayError(
      422,
      error.code,
      "The generated plan failed source validation."
    );
  }
  return new GatewayError(
    422,
    "invalid_plan_blueprint",
    "The generated plan failed source validation."
  );
}
