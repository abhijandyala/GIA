import { GatewayError } from "../gateway.mjs";

const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const UNDERSTANDINGS = new Set(["understood", "unclear"]);

export const GIA_INTERPRET_REPLY_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "understanding",
    "spokenText",
    "destination",
    "origin",
    "dateStart",
    "dateEnd",
    "durationDays",
    "travelerCount",
    "budgetAmount",
    "budgetCurrency"
  ],
  properties: {
    understanding: {
      type: "string",
      enum: ["understood", "unclear"]
    },
    spokenText: {
      type: ["string", "null"]
    },
    destination: {
      type: ["string", "null"]
    },
    origin: {
      type: ["string", "null"]
    },
    dateStart: {
      type: ["string", "null"]
    },
    dateEnd: {
      type: ["string", "null"]
    },
    durationDays: {
      type: ["integer", "null"]
    },
    travelerCount: {
      type: ["integer", "null"]
    },
    budgetAmount: {
      type: ["number", "null"]
    },
    budgetCurrency: {
      type: ["string", "null"]
    }
  }
};

const INSTRUCTIONS = `
You interpret a traveler's spoken reply to GIA, a trip-planning assistant.

askedField is what GIA just asked, but the person may answer a different
trip detail. If the reply is about the trip in any way: destination,
origin, dates, duration, travelers, budget, preferences, dietary needs,
accessibility, or a yes/no about continuing: set understanding to
"understood" and fill every field you can.

Resolve relative dates using the supplied today value as YYYY-MM-DD.
"now", "today", and "tonight" start today.
"a week" / "for a week" is 7 days.
If they give a leave window and a stay length, such as "now till next
week I can go, and stay for a week", start as soon as today and make
dateEnd the inclusive last day of that stay.
dateStart and dateEnd must be YYYY-MM-DD. dateEnd is inclusive.
Never invent a destination, origin, or budget they did not mention.

If the reply literally does not connect to the trip or the question:
random talk, a joke with no travel meaning, unrelated questions:
set understanding to "unclear", set every trip field to null, and put
a short spoken question in spokenText such as "What do you mean?" or
"I don't follow. What do you mean by that?"

When understanding is "understood", spokenText should be null.
Use one or two short sentences if unclear, under 240 characters.
Never claim anything was booked.
`.trim();

export function createOpenAIReplyInterpreter({
  apiKey,
  model = "gpt-5.4-mini",
  fetchImplementation = globalThis.fetch
}) {
  return async function interpretReply(input, context = {}) {
    if (!apiKey) {
      throw new GatewayError(
        503,
        "openai_not_configured",
        "Assistant responses are not configured."
      );
    }
    const validatedInput = validateInterpretReplyInput(input);
    const response = await callOpenAI({
      apiKey,
      model,
      input: validatedInput,
      signal: context.signal,
      fetchImplementation
    });
    const outputText = extractOutputText(response);
    let output;
    try {
      output = JSON.parse(outputText);
    } catch {
      throw new GatewayError(
        502,
        "invalid_reply_interpretation",
        "The assistant returned an invalid interpretation."
      );
    }
    return validateInterpretReplyOutput(output);
  };
}

export function validateInterpretReplyInput(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new GatewayError(
      422,
      "invalid_reply_context",
      "Reply interpretation context must be an object."
    );
  }

  const utterance = String(input.utterance ?? "").trim();
  if (utterance.length < 1 || utterance.length > 500) {
    throw new GatewayError(
      422,
      "invalid_reply_utterance",
      "The spoken reply is missing or too long."
    );
  }

  const askedField = String(input.askedField ?? "").trim();
  if (askedField.length > 40) {
    throw new GatewayError(
      422,
      "invalid_reply_field",
      "The asked field is invalid."
    );
  }

  const today = String(input.today ?? "").trim();
  if (!DATE_PATTERN.test(today)) {
    throw new GatewayError(
      422,
      "invalid_reply_today",
      "today must be an ISO date."
    );
  }

  const requestSummary = String(input.requestSummary ?? "").trim();
  if (requestSummary.length > 600) {
    throw new GatewayError(
      422,
      "reply_summary_too_long",
      "Reply interpretation context is too long."
    );
  }

  const rawFacts = Array.isArray(input.knownFacts)
    ? input.knownFacts
    : [];
  if (rawFacts.length > 12) {
    throw new GatewayError(
      422,
      "too_many_reply_facts",
      "Reply interpretation context contains too many facts."
    );
  }
  const knownFacts = rawFacts.map((value) => {
    if (typeof value !== "string" || value.trim().length > 240) {
      throw new GatewayError(
        422,
        "invalid_reply_fact",
        "Reply facts must be short text."
      );
    }
    return value.trim();
  }).filter(Boolean);

  return {
    utterance,
    askedField,
    today,
    requestSummary,
    knownFacts
  };
}

export function validateInterpretReplyOutput(output) {
  if (!output || typeof output !== "object" || Array.isArray(output)) {
    throw invalidOutput();
  }

  const understanding = String(output.understanding ?? "");
  if (!UNDERSTANDINGS.has(understanding)) {
    throw invalidOutput();
  }

  const spokenText = normalizeOptionalString(output.spokenText, 240);
  const destination = normalizeOptionalString(output.destination, 80);
  const origin = normalizeOptionalString(output.origin, 80);
  const dateStart = normalizeOptionalDate(output.dateStart);
  const dateEnd = normalizeOptionalDate(output.dateEnd);
  const durationDays = normalizeOptionalInteger(
    output.durationDays,
    1,
    90
  );
  const travelerCount = normalizeOptionalInteger(
    output.travelerCount,
    1,
    30
  );
  const budgetAmount = normalizeOptionalNumber(
    output.budgetAmount,
    1,
    1_000_000
  );
  const budgetCurrency = normalizeCurrency(output.budgetCurrency);

  if (understanding === "unclear") {
    return {
      understanding,
      spokenText: spokenText || "What do you mean?",
      destination: null,
      origin: null,
      dateStart: null,
      dateEnd: null,
      durationDays: null,
      travelerCount: null,
      budgetAmount: null,
      budgetCurrency: null
    };
  }

  return {
    understanding,
    spokenText: null,
    destination,
    origin,
    dateStart,
    dateEnd,
    durationDays,
    travelerCount,
    budgetAmount,
    budgetCurrency
  };
}

function normalizeOptionalString(value, maximumLength) {
  if (value == null) {
    return null;
  }
  const text = String(value).trim();
  if (!text) {
    return null;
  }
  return text.slice(0, maximumLength);
}

function normalizeOptionalDate(value) {
  if (value == null) {
    return null;
  }
  const text = String(value).trim();
  return DATE_PATTERN.test(text) ? text : null;
}

function normalizeOptionalInteger(value, minimum, maximum) {
  if (value == null || value === "") {
    return null;
  }
  const number = Number(value);
  if (!Number.isInteger(number) || number < minimum || number > maximum) {
    return null;
  }
  return number;
}

function normalizeOptionalNumber(value, minimum, maximum) {
  if (value == null || value === "") {
    return null;
  }
  const number = Number(value);
  if (!Number.isFinite(number) || number < minimum || number > maximum) {
    return null;
  }
  return number;
}

function normalizeCurrency(value) {
  if (value == null) {
    return null;
  }
  const text = String(value).trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(text)) {
    return null;
  }
  return text;
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
          effort: "none"
        },
        instructions: INSTRUCTIONS,
        input: JSON.stringify(input),
        text: {
          format: {
            type: "json_schema",
            name: "gia_interpret_reply",
            strict: true,
            schema: GIA_INTERPRET_REPLY_SCHEMA
          }
        }
      }),
      signal
    });
  } catch (error) {
    if (signal?.aborted || error?.name === "AbortError") {
      throw new GatewayError(
        504,
        "reply_interpretation_timeout",
        "The assistant interpretation timed out."
      );
    }
    throw new GatewayError(
      502,
      "reply_interpretation_unavailable",
      "The assistant interpretation is temporarily unavailable."
    );
  }
  if (!response.ok) {
    if (response.status === 429) {
      throw new GatewayError(
        429,
        "reply_interpretation_rate_limited",
        "The assistant is busy. Try again shortly."
      );
    }
    if (response.status === 401 || response.status === 403) {
      throw new GatewayError(
        503,
        "reply_interpretation_authorization_failed",
        "Assistant responses are not configured correctly."
      );
    }
    throw new GatewayError(
      502,
      "reply_interpretation_failed",
      "The assistant could not interpret the reply."
    );
  }
  try {
    return await response.json();
  } catch {
    throw invalidOutput();
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
  throw invalidOutput();
}

function invalidOutput() {
  return new GatewayError(
    502,
    "invalid_reply_interpretation",
    "The assistant returned an invalid interpretation."
  );
}
