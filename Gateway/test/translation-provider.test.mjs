import assert from "node:assert/strict";
import test from "node:test";

import {
  createTranslationProvider,
  protectedSegments,
  validateTranslationCriteria
} from "../src/providers/translation-provider.mjs";

test("translation criteria validate language, size, and content kind", () => {
  const criteria = validateTranslationCriteria(validCriteria());
  assert.equal(criteria.targetLanguageCode, "es");
  assert.equal(criteria.contentKind, "travelMessage");

  assert.throws(
    () => validateTranslationCriteria({
      ...validCriteria(),
      targetLanguageCode: "not a language"
    }),
    (error) => error.code === "invalid_target_language"
  );
  assert.throws(
    () => validateTranslationCriteria({
      ...validCriteria(),
      text: ""
    }),
    (error) => error.code === "invalid_translation_text"
  );
});

test("protected segmentation preserves names, dates, URLs, and identifiers", () => {
  const text =
    "Meet at Museu Nacional on 2027-06-10. "
    + "Code ABC12345. https://example.com";
  const segments = protectedSegments(
    text,
    ["Museu Nacional"]
  );
  const protectedValues = segments
    .filter((segment) => segment.protected)
    .map((segment) => segment.text);

  assert.ok(protectedValues.includes("Museu Nacional"));
  assert.ok(protectedValues.includes("2027-06-10"));
  assert.ok(protectedValues.includes("ABC12345"));
  assert.ok(protectedValues.includes("https://example.com"));
});

test("Google translation recombines protected text exactly", async () => {
  let capturedURL;
  let capturedBody;
  const translate = createTranslationProvider({
    provider: "google",
    apiKey: "google-test-key",
    fetchImplementation: async (url, options) => {
      capturedURL = new URL(url);
      capturedBody = JSON.parse(options.body);
      const translations = capturedBody.q.map((text) => ({
        translatedText: {
          "Meet at": "Encuentro en",
          "on": "el",
          ". Code": ". Código"
        }[text] ?? `translated:${text}`,
        detectedSourceLanguage: "en"
      }));
      return Response.json({
        data: {
          translations
        }
      });
    },
    now: () => new Date("2026-09-06T08:00:00.000Z")
  });
  const result = await translate(validCriteria());

  assert.equal(
    result.translatedText,
    "Encuentro en Museu Nacional el 2027-06-10. Código ABC12345."
  );
  assert.equal(result.originalText, validCriteria().text);
  assert.equal(result.detectedSourceLanguageCode, "en");
  assert.equal(result.targetLanguageCode, "es");
  assert.equal(result.isMachineTranslated, true);
  assert.ok(result.protectedTerms.includes("Museu Nacional"));
  assert.equal(result.provenance.provider, "google_translation");
  assert.equal(
    result.provenance.expiresAt,
    "2026-09-07T08:00:00.000Z"
  );
  assert.equal(capturedURL.searchParams.get("key"), "google-test-key");
  assert.equal(
    capturedBody.q.some((text) => text.includes("Museu Nacional")),
    false
  );
  assert.equal(
    result.provenance.sourceURL.includes("google-test-key"),
    false
  );
});

test("DeepL uses header authentication and supported payload", async () => {
  let captured;
  const translate = createTranslationProvider({
    provider: "deepl",
    apiKey: "deepl-test-key",
    fetchImplementation: async (url, options) => {
      captured = {
        url: String(url),
        options,
        body: JSON.parse(options.body)
      };
      return Response.json({
        translations: [
          {
            text: "Hola",
            detected_source_language: "EN"
          }
        ]
      });
    }
  });
  const result = await translate({
    text: "Hello",
    sourceLanguageCode: "en",
    targetLanguageCode: "es",
    contentKind: "plainText",
    protectedTerms: []
  });

  assert.equal(
    captured.url,
    "https://api-free.deepl.com/v2/translate"
  );
  assert.equal(
    captured.options.headers.authorization,
    "DeepL-Auth-Key deepl-test-key"
  );
  assert.deepEqual(captured.body.text, ["Hello"]);
  assert.equal(captured.body.target_lang, "ES");
  assert.equal(result.translatedText, "Hola");
  assert.equal(result.detectedSourceLanguageCode, "en");
  assert.equal(result.provenance.provider, "deepl");
});

test("addresses and identifiers bypass machine translation", async () => {
  let called = false;
  const translate = createTranslationProvider({
    provider: "google",
    apiKey: "test-key",
    fetchImplementation: async () => {
      called = true;
      return Response.json({});
    }
  });
  const address = await translate({
    text: "123 Rua Augusta, Lisboa",
    sourceLanguageCode: "pt",
    targetLanguageCode: "en",
    contentKind: "address",
    protectedTerms: []
  });
  const identifier = await translate({
    text: "ABC12345",
    sourceLanguageCode: null,
    targetLanguageCode: "en",
    contentKind: "identifier",
    protectedTerms: []
  });

  assert.equal(address.translatedText, address.originalText);
  assert.equal(address.isMachineTranslated, false);
  assert.deepEqual(address.protectedTerms, [address.originalText]);
  assert.equal(identifier.isMachineTranslated, false);
  assert.equal(called, false);
});

test("same-language text bypasses provider access", async () => {
  let called = false;
  const translate = createTranslationProvider({
    provider: "google",
    apiKey: "test-key",
    fetchImplementation: async () => {
      called = true;
      return Response.json({});
    }
  });
  const result = await translate({
    text: "Hello GIA",
    sourceLanguageCode: "en",
    targetLanguageCode: "en",
    contentKind: "plainText",
    protectedTerms: []
  });

  assert.equal(result.translatedText, "Hello GIA");
  assert.equal(result.isMachineTranslated, false);
  assert.equal(called, false);
});

test("translation count mismatch and authorization failures are sanitized", async () => {
  const mismatch = createTranslationProvider({
    provider: "google",
    apiKey: "test-key",
    fetchImplementation: async () => Response.json({
      data: {
        translations: []
      }
    })
  });
  await assert.rejects(
    () => mismatch(validCriteria()),
    (error) => error.code === "translation_count_mismatch"
  );

  const unauthorized = createTranslationProvider({
    provider: "google",
    apiKey: "invalid-key",
    fetchImplementation: async () => Response.json(
      {
        error: "sensitive provider details"
      },
      {
        status: 403
      }
    )
  });
  await assert.rejects(
    () => unauthorized(validCriteria()),
    (error) => (
      error.status === 503
      && error.code === "translation_authorization_failed"
      && !error.message.includes("sensitive")
    )
  );
});

test("translation provider and endpoints fail closed", async () => {
  const missingProvider = createTranslationProvider({
    provider: "",
    apiKey: "test-key"
  });
  await assert.rejects(
    () => missingProvider(validCriteria()),
    (error) => error.code === "translation_provider_not_configured"
  );

  const insecureLibre = createTranslationProvider({
    provider: "libretranslate",
    apiKey: "test-key",
    baseURL: "http://localhost/translate"
  });
  await assert.rejects(
    () => insecureLibre(validCriteria()),
    (error) => error.code === "translation_endpoint_invalid"
  );
});

function validCriteria() {
  return {
    text:
      "Meet at Museu Nacional on 2027-06-10. "
      + "Code ABC12345.",
    sourceLanguageCode: "en",
    targetLanguageCode: "es",
    contentKind: "travelMessage",
    protectedTerms: ["Museu Nacional"]
  };
}
