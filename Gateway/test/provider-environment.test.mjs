import assert from "node:assert/strict";
import test from "node:test";

import {
  configuredProviders,
  gatewayConfigurationIssues,
  normalizeGatewayEnvironment
} from "../src/provider-environment.mjs";

test("legacy provider names normalize to canonical names", () => {
  const normalized = normalizeGatewayEnvironment({
    SerpAPIKey: "serp-key",
    OpenAIAPIKey: "openai-key",
    ElevenLabsAPIKey: "elevenlabs-key",
    GeoapifyAPIKey: "geoapify-key",
    WeatherAPIKey: "weather-key",
    TranslationAPIKey: "translation-key",
    TranslationProvider: "DeepL"
  });

  assert.equal(normalized.SERPAPI_API_KEY, "serp-key");
  assert.equal(normalized.OPENAI_API_KEY, "openai-key");
  assert.equal(
    normalized.ELEVENLABS_API_KEY,
    "elevenlabs-key"
  );
  assert.equal(normalized.GEOAPIFY_API_KEY, "geoapify-key");
  assert.equal(normalized.WEATHERAPI_API_KEY, "weather-key");
  assert.equal(
    normalized.TRANSLATION_API_KEY,
    "translation-key"
  );
  assert.equal(normalized.TRANSLATION_PROVIDER, "DeepL");
});

test("canonical provider names take precedence over aliases", () => {
  const normalized = normalizeGatewayEnvironment({
    OPENAI_API_KEY: "canonical-key",
    OpenAIAPIKey: "legacy-key"
  });

  assert.equal(normalized.OPENAI_API_KEY, "canonical-key");
});

test("translation health requires complete provider configuration", () => {
  const missingProvider = normalizeGatewayEnvironment({
    TranslationAPIKey: "translation-key"
  });
  assert.equal(
    configuredProviders(missingProvider).translation,
    false
  );
  assert.deepEqual(
    gatewayConfigurationIssues(missingProvider),
    ["translation_provider_missing"]
  );

  const configured = normalizeGatewayEnvironment({
    TRANSLATION_API_KEY: "translation-key",
    TRANSLATION_PROVIDER: "deepl"
  });
  assert.equal(configuredProviders(configured).translation, true);
  assert.deepEqual(gatewayConfigurationIssues(configured), []);
});

test("LibreTranslate requires an HTTPS base URL", () => {
  const missingURL = {
    TRANSLATION_API_KEY: "translation-key",
    TRANSLATION_PROVIDER: "libretranslate"
  };
  assert.equal(configuredProviders(missingURL).translation, false);
  assert.deepEqual(
    gatewayConfigurationIssues(missingURL),
    ["translation_base_url_missing"]
  );

  const insecureURL = {
    ...missingURL,
    TRANSLATION_BASE_URL: "http://translation.example"
  };
  assert.equal(configuredProviders(insecureURL).translation, false);
  assert.deepEqual(
    gatewayConfigurationIssues(insecureURL),
    ["translation_base_url_invalid"]
  );
});
