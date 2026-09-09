import assert from "node:assert/strict";
import test from "node:test";

import {
  createOpenAIReplyInterpreter,
  validateInterpretReplyInput,
  validateInterpretReplyOutput
} from "../src/providers/openai-interpret-reply.mjs";

test("reply interpretation input is bounded", () => {
  const input = validateInterpretReplyInput({
    utterance: "now till next week I can go and stay for a week",
    askedField: "dates",
    today: "2026-09-07",
    requestSummary: "Destination is Paris",
    knownFacts: ["Travel dates are missing"]
  });
  assert.equal(input.askedField, "dates");
  assert.equal(input.today, "2026-09-07");

  assert.throws(
    () => validateInterpretReplyInput({
      utterance: "",
      askedField: "dates",
      today: "2026-09-07"
    }),
    (error) => error.code === "invalid_reply_utterance"
  );
  assert.throws(
    () => validateInterpretReplyInput({
      utterance: "next week",
      askedField: "dates",
      today: "09/07/2026"
    }),
    (error) => error.code === "invalid_reply_today"
  );
});

test("understood replies keep extracted trip fields", () => {
  const output = validateInterpretReplyOutput({
    understanding: "understood",
    spokenText: null,
    destination: null,
    origin: null,
    dateStart: "2026-09-07",
    dateEnd: "2026-09-13",
    durationDays: 7,
    travelerCount: null,
    budgetAmount: null,
    budgetCurrency: null
  });
  assert.equal(output.understanding, "understood");
  assert.equal(output.dateStart, "2026-09-07");
  assert.equal(output.durationDays, 7);
  assert.equal(output.spokenText, null);
});

test("unclear replies drop fields and ask what the user meant", () => {
  const output = validateInterpretReplyOutput({
    understanding: "unclear",
    spokenText: "What do you mean?",
    destination: "Paris",
    origin: null,
    dateStart: "2026-09-07",
    dateEnd: null,
    durationDays: 7,
    travelerCount: 2,
    budgetAmount: 100,
    budgetCurrency: "USD"
  });
  assert.equal(output.understanding, "unclear");
  assert.equal(output.spokenText, "What do you mean?");
  assert.equal(output.destination, null);
  assert.equal(output.dateStart, null);
  assert.equal(output.travelerCount, null);
});

test("OpenAI interpreter requests strict structured output", async () => {
  let capturedBody;
  const interpret = createOpenAIReplyInterpreter({
    apiKey: "server-key",
    model: "gpt-test",
    fetchImplementation: async (_url, options) => {
      capturedBody = JSON.parse(options.body);
      return Response.json({
        output_text: JSON.stringify({
          understanding: "understood",
          spokenText: null,
          destination: null,
          origin: null,
          dateStart: "2026-09-07",
          dateEnd: "2026-09-13",
          durationDays: 7,
          travelerCount: null,
          budgetAmount: null,
          budgetCurrency: null
        })
      });
    }
  });
  const response = await interpret({
    utterance: "stay for a week starting now",
    askedField: "dates",
    today: "2026-09-07",
    requestSummary: "Paris",
    knownFacts: []
  });

  assert.equal(response.understanding, "understood");
  assert.equal(response.durationDays, 7);
  assert.equal(capturedBody.store, false);
  assert.equal(
    capturedBody.text.format.name,
    "gia_interpret_reply"
  );
  assert.equal(
    capturedBody.instructions.includes("What do you mean?"),
    true
  );
});

test("interpreter defaults to gpt-5.4-mini with none reasoning", async () => {
  let capturedBody;
  const interpret = createOpenAIReplyInterpreter({
    apiKey: "server-key",
    fetchImplementation: async (_url, options) => {
      capturedBody = JSON.parse(options.body);
      return Response.json({
        output_text: JSON.stringify({
          understanding: "understood",
          spokenText: null,
          destination: "Paris",
          origin: null,
          dateStart: null,
          dateEnd: null,
          durationDays: null,
          travelerCount: 3,
          budgetAmount: null,
          budgetCurrency: null
        })
      });
    }
  });
  await interpret({
    utterance: "me and two buddies",
    askedField: "travelers",
    today: "2026-09-07",
    requestSummary: "Paris",
    knownFacts: []
  });

  assert.equal(capturedBody.model, "gpt-5.4-mini");
  assert.equal(capturedBody.reasoning.effort, "none");
});
