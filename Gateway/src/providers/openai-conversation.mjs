import { GatewayError } from "../gateway.mjs";

const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const INTENTS = new Set([
  "requestCaptured",
  "clarificationNeeded",
  "resultsReady",
  "timingConflict",
  "providerUnavailable"
]);

export const GIA_CONVERSATION_RESPONSE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "spokenText",
    "displayText",
    "intent",
    "shouldContinueListening"
  ],
  properties: {
    spokenText: {
      type: "string",
      minLength: 1,
      maxLength: 240
    },
    displayText: {
      type: "string",
      minLength: 1,
      maxLength: 300
    },
    intent: {
      type: "string",
      enum: [...INTENTS]
    },
    shouldContinueListening: {
      type: "boolean"
    }
  }
};

const INSTRUCTIONS = `
You write GIA's short spoken travel-assistant replies. You are a real person
in the room, not a kiosk, not a status bot, and not a corporate script.

Sound warm, quick, and human. Use contractions, natural punctuation, and
varied openings. React to THIS turn, not a generic script.

Use one short reaction plus one question when clarification is needed.
The reaction must match what they just said: dates, party size, budget,
origin, a joke, or a preference, not an earlier fact.

If they joke, tease, are sarcastic, or say something funny or weird, react
first with a genuine short laugh or amused line in spoken English, then get
back to the trip. Write laughter as speech people can hear: "Ha!", "Haha,",
"That's funny,", or "Okay, I like that." Never write stage directions or
tags such as [laughs], (laughs), or *laughs*. If User said and Recent turns
show no joke, do not joke.

When they are sincere, skip the joke and just help. When they just gave
you a destination and groundedFacts say "Already complimented destination:
no", add one short sincere remark such as "{destination} is beautiful"
before the next question. If groundedFacts say "Already complimented
destination: yes", never compliment the place again. Do not repeat the
same compliment, opening, or question.

If Recent turns are supplied, stay consistent with them and do not repeat
a line you already said.

When clarification is needed, ask one direct human question instead of
listing fields.
Never say "as an AI", repeat the whole request, over-explain, use "um"/"uh",
stack filler, or fake hesitation.
Use one or two sentences and remain under 240 characters.

If the user went quiet, check in like a person:
"Hello? You still there?" or "Hey, are you still with me?"
If the request is ready and facts list things not mentioned, briefly
acknowledge what you have, ask "Anything else?", mention one or two of
those examples, and say they can reply "that's it."

Use only facts explicitly supplied in groundedFacts or requestSummary.
Never invent a destination, date, traveler count, budget, price, rating,
availability, schedule, provider result, booking, or confirmation.
Never claim that anything was booked or purchased.

spokenText is optimized for speech, including any laugh.
displayText communicates the same meaning without filler.
Never use em dashes or en dashes. Use a comma or period instead.
Write every word in full spoken English. Never abbreviate words.
Contractions such as I'm, we're, and that's are allowed.
Write September, not Sep. Monday, not Mon. hours, not hrs.
approximately, not approx. Airport codes such as JFK may stay as codes.
intent must exactly match the supplied intent.
shouldContinueListening is true only for clarificationNeeded.
`.trim();

export function sanitizeConversationCopy(text) {
  let value = String(text ?? "");
  value = value.replaceAll(" — ", ". ").replaceAll(" – ", ". ");
  value = value.replaceAll("—", ". ").replaceAll("–", ". ");
  value = value.replace(
    /(^|[.!?]\s+)([a-z])/g,
    (_, prefix, letter) => prefix + letter.toUpperCase()
  );
  value = value.replace(/w\/o/gi, "without").replace(/w\//gi, "with");
  value = value.replaceAll(" & ", " and ");
  value = value.replace(/e\.g\./gi, "for example");
  value = value.replace(/i\.e\./gi, "that is");
  const abbreviations = [
    [/\bapprox\.?\b/gi, "approximately"],
    [/\bintl\.?\b/gi, "international"],
    [/\bblvd\.?\b/gi, "Boulevard"],
    [/\bdept\.?\b/gi, "department"],
    [/\binfo\.?\b/gi, "information"],
    [/\bincl\.?\b/gi, "including"],
    [/\bexcl\.?\b/gi, "excluding"],
    [/\basap\.?\b/gi, "as soon as possible"],
    [/\bthru\.?\b/gi, "through"],
    [/\bnite\.?\b/gi, "night"],
    [/\bmins\.?\b/gi, "minutes"],
    [/\bsecs\.?\b/gi, "seconds"],
    [/\bhrs\.?\b/gi, "hours"],
    [/\bwks\.?\b/gi, "weeks"],
    [/\bppl\.?\b/gi, "people"],
    [/\bavg\.?\b/gi, "average"],
    [/\bthx\.?\b/gi, "thanks"],
    [/\bpls\.?\b/gi, "please"],
    [/\bbtw\.?\b/gi, "by the way"],
    [/\bhwy\.?\b/gi, "Highway"],
    [/\betc\.?\b/gi, "and so on"],
    [/\bvs\.?\b/gi, "versus"],
    [/\bSept\.?\b/gi, "September"],
    [/\bSep\.?\b/gi, "September"],
    [/\bJan\.?\b/gi, "January"],
    [/\bFeb\.?\b/gi, "February"],
    [/\bMar\.?\b/gi, "March"],
    [/\bApr\.?\b/gi, "April"],
    [/\bJun\.?\b/gi, "June"],
    [/\bJul\.?\b/gi, "July"],
    [/\bAug\.?\b/gi, "August"],
    [/\bOct\.?\b/gi, "October"],
    [/\bNov\.?\b/gi, "November"],
    [/\bDec\.?\b/gi, "December"],
    [/\bThurs\.?\b/gi, "Thursday"],
    [/\bThur\.?\b/gi, "Thursday"],
    [/\bThu\.?\b/gi, "Thursday"],
    [/\bTues\.?\b/gi, "Tuesday"],
    [/\bTue\.?\b/gi, "Tuesday"],
    [/\bMon\.?\b/gi, "Monday"],
    [/\bFri\.?\b/gi, "Friday"],
    [/\bWed\.?\b/g, "Wednesday"],
    [/\bWED\.?\b/g, "Wednesday"],
    [/\bSat\.?\b/g, "Saturday"],
    [/\bSAT\.?\b/g, "Saturday"],
    [/\bSun\.?\b/g, "Sunday"],
    [/\bSUN\.?\b/g, "Sunday"],
    [/\bAve\.?\b/g, "Avenue"],
    [/\bAVE\.?\b/g, "Avenue"],
    [/\bRd\.?\b/g, "Road"]
  ];
  for (const [pattern, name] of abbreviations) {
    value = value.replace(pattern, name);
  }
  return value.replace(/\s{2,}/g, " ").trim();
}

export function spokenTextFromPartialOutput(outputText) {
  const source = String(outputText ?? "");
  const marker = '"spokenText"';
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) {
    return null;
  }
  const colonIndex = source.indexOf(":", markerIndex + marker.length);
  if (colonIndex < 0) {
    return null;
  }
  let index = colonIndex + 1;
  while (index < source.length && /\s/.test(source[index])) {
    index += 1;
  }
  if (source[index] !== '"') {
    return null;
  }
  index += 1;
  let text = "";
  while (index < source.length) {
    const character = source[index];
    if (character === "\\") {
      if (index + 1 >= source.length) {
        return { text, closed: false };
      }
      text += unescapeJsonCharacter(source[index + 1]);
      index += 2;
      continue;
    }
    if (character === '"') {
      return { text, closed: true };
    }
    text += character;
    index += 1;
  }
  return { text, closed: false };
}

export function firstSpokenPhrase(text) {
  const trimmed = String(text ?? "").trim();
  if (!trimmed) {
    return "";
  }
  const match = trimmed.match(
    /^([\s\S]{12,}?[.!?])(?:\s+[A-Z0-9“"‘]|$)/u
  );
  if (match?.[1] && match[1].length < trimmed.length) {
    return match[1].trim();
  }
  return trimmed;
}

export function createOpenAIConversationResponder({
  apiKey,
  model = "gpt-5.4-mini",
  fetchImplementation = globalThis.fetch,
  prefetchSpeech
}) {
  return async function generateResponse(input, context = {}) {
    if (!apiKey) {
      throw new GatewayError(
        503,
        "openai_not_configured",
        "Assistant responses are not configured."
      );
    }
    const validatedInput = validateConversationContext(input);
    const prefetcher = createSpokenPrefetcher(prefetchSpeech);
    const outputText = await readOpenAIOutputText({
      apiKey,
      model,
      input: validatedInput,
      signal: context.signal,
      fetchImplementation,
      onPartialOutputText: prefetcher.observe
    });
    let output;
    try {
      output = JSON.parse(outputText);
    } catch {
      throw new GatewayError(
        502,
        "invalid_assistant_response",
        "The assistant returned an invalid response."
      );
    }
    const validated = validateConversationResponse(
      output,
      validatedInput
    );
    prefetcher.finish(validated.spokenText);
    return validated;
  };
}

function createSpokenPrefetcher(prefetchSpeech) {
  let prefetched = false;
  const prefetch = (text) => {
    const phrase = firstSpokenPhrase(text);
    if (!phrase || prefetched || typeof prefetchSpeech !== "function") {
      return;
    }
    prefetched = true;
    try {
      prefetchSpeech(phrase);
    } catch {
      prefetched = false;
    }
  };

  return {
    observe(outputText) {
      const extracted = spokenTextFromPartialOutput(outputText);
      if (!extracted?.text) {
        return;
      }
      const cleaned = sanitizeConversationCopy(extracted.text);
      const phrase = firstSpokenPhrase(cleaned);
      const hasRemainder =
        phrase.length < cleaned.trim().length;
      if (extracted.closed || hasRemainder) {
        prefetch(phrase);
      }
    },
    finish(spokenText) {
      prefetch(sanitizeConversationCopy(spokenText));
    }
  };
}

function unescapeJsonCharacter(character) {
  switch (character) {
    case "n":
      return "\n";
    case "r":
      return "\r";
    case "t":
      return "\t";
    case '"':
    case "\\":
    case "/":
      return character;
    default:
      return character;
  }
}

export function validateConversationContext(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new GatewayError(
      422,
      "invalid_conversation_context",
      "Assistant response context must be an object."
    );
  }
  const intent = String(input.intent ?? "");
  if (!INTENTS.has(intent)) {
    throw new GatewayError(
      422,
      "invalid_conversation_intent",
      "Assistant response intent is unsupported."
    );
  }
  const requestSummary = String(input.requestSummary ?? "").trim();
  if (requestSummary.length > 600) {
    throw new GatewayError(
      422,
      "conversation_summary_too_long",
      "Assistant response context is too long."
    );
  }
  const rawFacts = Array.isArray(input.groundedFacts)
    ? input.groundedFacts
    : [];
  if (rawFacts.length > 12) {
    throw new GatewayError(
      422,
      "too_many_conversation_facts",
      "Assistant response context contains too many facts."
    );
  }
  const groundedFacts = rawFacts.map((value) => {
    if (typeof value !== "string" || value.trim().length > 240) {
      throw new GatewayError(
        422,
        "invalid_conversation_fact",
        "Assistant response facts must be short text."
      );
    }
    return value.trim();
  }).filter(Boolean);

  return {
    intent,
    requestSummary,
    groundedFacts
  };
}

export function validateConversationResponse(output, input) {
  if (!output || typeof output !== "object" || Array.isArray(output)) {
    throw invalidOutput();
  }
  const keys = Object.keys(output).sort();
  const expectedKeys = [
    "displayText",
    "intent",
    "shouldContinueListening",
    "spokenText"
  ];
  if (JSON.stringify(keys) !== JSON.stringify(expectedKeys)) {
    throw invalidOutput();
  }
  const spokenText = String(output.spokenText ?? "").trim();
  const displayText = String(output.displayText ?? "").trim();
  if (
    spokenText.length < 1
    || spokenText.length > 240
    || displayText.length < 1
    || displayText.length > 300
    || output.intent !== input.intent
    || typeof output.shouldContinueListening !== "boolean"
  ) {
    throw invalidOutput();
  }
  const shouldContinue = input.intent === "clarificationNeeded";
  if (output.shouldContinueListening !== shouldContinue) {
    throw invalidOutput();
  }
  const combinedOutput = `${spokenText} ${displayText}`;
  if (
    /\b(?:booked|purchase complete|reservation confirmed)\b/iu.test(
      combinedOutput
    )
  ) {
    throw new GatewayError(
      502,
      "unsupported_booking_claim",
      "The assistant returned an unsupported booking claim."
    );
  }
  const contextText = [
    input.requestSummary,
    ...input.groundedFacts
  ].join(" ");
  const outputNumbers = combinedOutput.match(
    /(?:[$€£¥]\s*)?\d[\d,.]*/gu
  ) ?? [];
  if (
    outputNumbers.some(
      (value) => !contextText.includes(value.trim())
    )
  ) {
    throw new GatewayError(
      502,
      "unsupported_numeric_claim",
      "The assistant returned an unsupported numeric claim."
    );
  }

  return {
    spokenText: sanitizeConversationCopy(spokenText),
    displayText: sanitizeConversationCopy(displayText),
    intent: output.intent,
    shouldContinueListening: output.shouldContinueListening
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
          effort: "none"
        },
        instructions: INSTRUCTIONS,
        input: JSON.stringify(input),
        stream: true,
        text: {
          format: {
            type: "json_schema",
            name: "gia_conversation_response",
            strict: true,
            schema: GIA_CONVERSATION_RESPONSE_SCHEMA
          }
        }
      }),
      signal
    });
  } catch (error) {
    if (signal?.aborted || error?.name === "AbortError") {
      throw new GatewayError(
        504,
        "assistant_response_timeout",
        "The assistant response timed out."
      );
    }
    throw new GatewayError(
      502,
      "assistant_response_unavailable",
      "The assistant response is temporarily unavailable."
    );
  }
  if (!response.ok) {
    const errorText = await response.text().catch(() => "");
    console.error(
      `OpenAI conversation HTTP ${response.status}: `
      + errorText.slice(0, 1200)
    );
    if (response.status === 429) {
      throw new GatewayError(
        429,
        "assistant_response_rate_limited",
        "The assistant is busy. Try again shortly."
      );
    }
    if (response.status === 401 || response.status === 403) {
      throw new GatewayError(
        503,
        "assistant_response_authorization_failed",
        "Assistant responses are not configured correctly."
      );
    }
    throw new GatewayError(
      502,
      "assistant_response_failed",
      "The assistant could not create a response."
    );
  }
  const contentType = (
    response.headers.get("content-type") ?? ""
  ).toLowerCase();
  if (contentType.includes("text/event-stream")) {
    return response;
  }
  try {
    return await response.json();
  } catch {
    throw invalidOutput();
  }
}

async function readOpenAIOutputText({
  apiKey,
  model,
  input,
  signal,
  fetchImplementation,
  onPartialOutputText
}) {
  const response = await callOpenAI({
    apiKey,
    model,
    input,
    signal,
    fetchImplementation
  });
  if (response instanceof Response) {
    return consumeOpenAIStream(response, {
      signal,
      onPartialOutputText
    });
  }
  const outputText = extractOutputText(response);
  onPartialOutputText?.(outputText);
  return outputText;
}

async function consumeOpenAIStream(
  response,
  { signal, onPartialOutputText } = {}
) {
  if (!response.body) {
    throw invalidOutput();
  }
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let outputText = "";
  try {
    while (true) {
      if (signal?.aborted) {
        throw new GatewayError(
          504,
          "assistant_response_timeout",
          "The assistant response timed out."
        );
      }
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      buffer += decoder.decode(value, { stream: true });
      const parts = buffer.split("\n\n");
      buffer = parts.pop() ?? "";
      for (const part of parts) {
        const payload = parseSSEPayload(part);
        if (!payload) {
          continue;
        }
        if (
          payload.type === "response.failed"
          || payload.type === "error"
        ) {
          console.error(
            "OpenAI conversation stream error: "
            + JSON.stringify(payload).slice(0, 1200)
          );
          throw new GatewayError(
            502,
            "assistant_response_failed",
            "The assistant could not create a response."
          );
        }
        if (
          payload.type === "response.output_text.delta"
          && typeof payload.delta === "string"
        ) {
          outputText += payload.delta;
          onPartialOutputText?.(outputText);
        }
        if (
          payload.type === "response.output_text.done"
          && typeof payload.text === "string"
        ) {
          outputText = payload.text;
          onPartialOutputText?.(outputText);
        }
        if (
          (
            payload.type === "response.completed"
            || payload.type === "response.incomplete"
          )
          && payload.response
        ) {
          try {
            outputText = extractOutputText(payload.response);
          } catch {
            // Keep streamed text if the completed payload is incomplete.
          }
        }
      }
    }
  } finally {
    reader.releaseLock();
  }
  if (!outputText) {
    throw invalidOutput();
  }
  return outputText;
}

function parseSSEPayload(chunk) {
  const dataLines = String(chunk ?? "")
    .split("\n")
    .filter((line) => line.startsWith("data:"))
    .map((line) => line.slice(5).trim());
  if (dataLines.length === 0) {
    return null;
  }
  const data = dataLines.join("");
  if (!data || data === "[DONE]") {
    return null;
  }
  try {
    return JSON.parse(data);
  } catch {
    return null;
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
    "invalid_assistant_response",
    "The assistant returned an invalid response."
  );
}
