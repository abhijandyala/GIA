import assert from "node:assert/strict";
import test from "node:test";

import {
  createOpenAIConversationResponder,
  firstSpokenPhrase,
  sanitizeConversationCopy,
  spokenTextFromPartialOutput,
  validateConversationContext,
  validateConversationResponse
} from "../src/providers/openai-conversation.mjs";
import {
  createSpeechPrefetchCache
} from "../src/speech-prefetch-cache.mjs";

test("conversation copy expands abbreviations and strips dashes", () => {
  assert.equal(
    sanitizeConversationCopy("Meet Mon, Sep 8. 4 hrs approx."),
    "Meet Monday, September 8. 4 hours approximately."
  );
  assert.equal(
    sanitizeConversationCopy("Okay—so, your request is ready."),
    "Okay. So, your request is ready."
  );
});

test("conversation context is bounded and intent-typed", () => {
  const context = validateConversationContext({
    intent: "requestCaptured",
    requestSummary: "Tokyo, four travelers",
    groundedFacts: ["Dates are April 3 through April 10"]
  });
  assert.equal(context.intent, "requestCaptured");
  assert.equal(context.groundedFacts.length, 1);

  assert.throws(
    () => validateConversationContext({
      intent: "inventSomething",
      requestSummary: ""
    }),
    (error) => error.code === "invalid_conversation_intent"
  );
});

test("response validation enforces intent, listening, and grounding", () => {
  const context = {
    intent: "clarificationNeeded",
    requestSummary: "Destination is Paris",
    groundedFacts: ["Travel dates are missing"]
  };
  const response = validateConversationResponse({
    spokenText: "Okay—I just need your travel dates.",
    displayText: "I need your travel dates before continuing.",
    intent: "clarificationNeeded",
    shouldContinueListening: true
  }, context);
  assert.equal(response.shouldContinueListening, true);

  assert.throws(
    () => validateConversationResponse({
      ...response,
      shouldContinueListening: false
    }, context),
    (error) => error.code === "invalid_assistant_response"
  );
  assert.throws(
    () => validateConversationResponse({
      spokenText: "Your reservation is confirmed.",
      displayText: "Reservation confirmed.",
      intent: "clarificationNeeded",
      shouldContinueListening: true
    }, context),
    (error) => error.code === "unsupported_booking_claim"
  );
  assert.throws(
    () => validateConversationResponse({
      spokenText: "I found 12 options.",
      displayText: "I found 12 options.",
      intent: "clarificationNeeded",
      shouldContinueListening: true
    }, context),
    (error) => error.code === "unsupported_numeric_claim"
  );
});

test("OpenAI responder requests strict non-stored structured output", async () => {
  let capturedBody;
  const responder = createOpenAIConversationResponder({
    apiKey: "server-key",
    model: "gpt-test",
    fetchImplementation: async (_url, options) => {
      capturedBody = JSON.parse(options.body);
      return Response.json({
        output_text: JSON.stringify({
          spokenText: "Okay—I've got it.",
          displayText: "Your request is captured.",
          intent: "requestCaptured",
          shouldContinueListening: false
        })
      });
    }
  });
  const response = await responder({
    intent: "requestCaptured",
    requestSummary: "A group trip request was captured",
    groundedFacts: []
  });

  assert.equal(response.intent, "requestCaptured");
  assert.equal(capturedBody.store, false);
  assert.equal(capturedBody.stream, true);
  assert.equal(
    capturedBody.text.format.name,
    "gia_conversation_response"
  );
  assert.equal(capturedBody.text.format.strict, true);
  assert.equal(
    capturedBody.instructions.includes("Never claim"),
    true
  );
  assert.equal(
    capturedBody.instructions.includes("genuine short laugh"),
    true
  );
  assert.equal(
    capturedBody.instructions.includes("Anything else?"),
    true
  );
  assert.equal(
    capturedBody.instructions.includes("is beautiful"),
    true
  );
  assert.equal(
    capturedBody.instructions.includes("THIS turn"),
    true
  );
  assert.equal(
    capturedBody.instructions.includes("Already complimented"),
    true
  );
});

test("conversation defaults to gpt-5.4-mini with none reasoning", async () => {
  let capturedBody;
  const responder = createOpenAIConversationResponder({
    apiKey: "server-key",
    fetchImplementation: async (_url, options) => {
      capturedBody = JSON.parse(options.body);
      return Response.json({
        output_text: JSON.stringify({
          spokenText: "That's great — Paris is beautiful.",
          displayText: "That's great — Paris is beautiful.",
          intent: "clarificationNeeded",
          shouldContinueListening: true
        })
      });
    }
  });
  await responder({
    intent: "clarificationNeeded",
    requestSummary: "Destination: Paris",
    groundedFacts: ["Ask next: travel dates."]
  });

  assert.equal(capturedBody.model, "gpt-5.4-mini");
  assert.equal(capturedBody.reasoning.effort, "none");
});

test("missing OpenAI configuration fails closed", async () => {
  const responder = createOpenAIConversationResponder({});
  await assert.rejects(
    () => responder({
      intent: "requestCaptured",
      requestSummary: "",
      groundedFacts: []
    }),
    (error) => error.code === "openai_not_configured"
  );
});

test("first spoken phrase splits after a complete sentence", () => {
  assert.equal(
    firstSpokenPhrase(
      "Nice — mid-May works. How many people are traveling?"
    ),
    "Nice — mid-May works."
  );
  assert.equal(
    firstSpokenPhrase("Okay, I've got it."),
    "Okay, I've got it."
  );
  assert.equal(
    firstSpokenPhrase("Ha! Paris is beautiful. What dates work?"),
    "Ha! Paris is beautiful."
  );
});

test("streaming talk prefetches the first spoken sentence before JSON closes", async () => {
  const prefetched = [];
  const spokenJSON =
    '{"spokenText":"Nice, that window works. How many people are traveling?","displayText":"Nice, that window works. How many people are traveling?","intent":"clarificationNeeded","shouldContinueListening":true}';
  const firstSentence = "Nice, that window works.";
  const responder = createOpenAIConversationResponder({
    apiKey: "server-key",
    prefetchSpeech: (text) => {
      prefetched.push(text);
    },
    fetchImplementation: async () => new Response(
      [
        sseEvent("response.output_text.delta", {
          type: "response.output_text.delta",
          delta: '{"spokenText":"Nice, that window works. How many pe'
        }),
        sseEvent("response.output_text.delta", {
          type: "response.output_text.delta",
          delta: spokenJSON.slice(
            '{"spokenText":"Nice, that window works. How many pe'.length
          )
        }),
        sseEvent("response.completed", {
          type: "response.completed"
        })
      ].join(""),
      {
        headers: {
          "content-type": "text/event-stream"
        }
      }
    )
  });

  const response = await responder({
    intent: "clarificationNeeded",
    requestSummary: "Destination: Paris",
    groundedFacts: ["Ask next: how many people are traveling."]
  });

  assert.equal(
    response.spokenText,
    "Nice, that window works. How many people are traveling?"
  );
  assert.equal(prefetched[0], firstSentence);
  assert.equal(
    prefetched.includes(
      "Nice, that window works. How many people are traveling?"
    ),
    true
  );
});

test("partial JSON yields a spoken prefix before the object closes", () => {
  const partial = spokenTextFromPartialOutput(
    '{"spokenText":"Nice — mid-May works. How many pe'
  );
  assert.equal(partial.closed, false);
  assert.equal(
    firstSpokenPhrase(partial.text),
    "Nice — mid-May works."
  );
  const closed = spokenTextFromPartialOutput(
    '{"spokenText":"Okay, I\'ve got it.","displayText":"Ready."}'
  );
  assert.equal(closed.closed, true);
  assert.equal(closed.text, "Okay, I've got it.");
});

test("streaming talk prefetches the complete spoken reply", async () => {
  const prefetched = [];
  const spokenJSON =
    '{"spokenText":"Nice — mid-May works. How many people are traveling?","displayText":"Nice — mid-May works. How many people are traveling?","intent":"clarificationNeeded","shouldContinueListening":true}';
  const responder = createOpenAIConversationResponder({
    apiKey: "server-key",
    prefetchSpeech: (text) => {
      prefetched.push(text);
    },
    fetchImplementation: async () => new Response(
      [
        sseEvent("response.output_text.delta", {
          type: "response.output_text.delta",
          delta: spokenJSON.slice(0, 42)
        }),
        sseEvent("response.output_text.delta", {
          type: "response.output_text.delta",
          delta: spokenJSON.slice(42)
        }),
        sseEvent("response.completed", {
          type: "response.completed"
        })
      ].join(""),
      {
        headers: {
          "content-type": "text/event-stream"
        }
      }
    )
  });

  const response = await responder({
    intent: "clarificationNeeded",
    requestSummary: "Destination: Paris",
    groundedFacts: ["Ask next: how many people are traveling."]
  });

  assert.equal(
    response.spokenText,
    "Nice. Mid-May works. How many people are traveling?"
  );
  assert.equal(
    prefetched.includes(
      "Nice. Mid-May works. How many people are traveling?"
    ),
    true
  );
});

test("output_text.done prefetches the complete spoken reply", async () => {
  const prefetched = [];
  const spokenJSON =
    '{"spokenText":"Nice — mid-May works. How many people are traveling?","displayText":"Nice — mid-May works. How many people are traveling?","intent":"clarificationNeeded","shouldContinueListening":true}';
  const responder = createOpenAIConversationResponder({
    apiKey: "server-key",
    prefetchSpeech: (text) => {
      prefetched.push(text);
    },
    fetchImplementation: async () => new Response(
      sseEvent("response.output_text.done", {
        type: "response.output_text.done",
        text: spokenJSON
      }),
      {
        headers: {
          "content-type": "text/event-stream"
        }
      }
    )
  });

  const response = await responder({
    intent: "clarificationNeeded",
    requestSummary: "Destination: Paris",
    groundedFacts: ["Ask next: how many people are traveling."]
  });

  assert.equal(
    response.spokenText,
    "Nice. Mid-May works. How many people are traveling?"
  );
  assert.deepEqual(prefetched, [
    "Nice. Mid-May works. How many people are traveling?"
  ]);
});

test("failed streamed talk responses do not return partial JSON", async () => {
  const responder = createOpenAIConversationResponder({
    apiKey: "server-key",
    fetchImplementation: async () => new Response(
      sseEvent("response.failed", {
        type: "response.failed"
      }),
      {
        headers: {
          "content-type": "text/event-stream"
        }
      }
    )
  });

  await assert.rejects(
    () => responder({
      intent: "clarificationNeeded",
      requestSummary: "Destination: Paris",
      groundedFacts: ["Ask next: travel dates."]
    }),
    (error) => error.code === "assistant_response_failed"
  );
});

test("speech prefetch cache is one-shot and expires unused audio", async () => {
  const cache = createSpeechPrefetchCache({
    ttlMilliseconds: 20
  });
  cache.store(
    "Nice — mid-May works.",
    Promise.resolve("audio-a")
  );
  assert.equal(
    await cache.take("Nice — mid-May works."),
    "audio-a"
  );
  assert.equal(cache.take("Nice — mid-May works."), null);

  cache.store("later", Promise.resolve("audio-b"));
  await new Promise((resolve) => setTimeout(resolve, 30));
  assert.equal(cache.take("later"), null);

  cache.store(
    "  Nice — mid-May works.  ",
    Promise.resolve("audio-c")
  );
  assert.equal(
    await cache.take("Nice — mid-May works."),
    "audio-c"
  );
});

function sseEvent(event, data) {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}
