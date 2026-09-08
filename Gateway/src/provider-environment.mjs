const ENVIRONMENT_ALIASES = Object.freeze({
  SERPAPI_API_KEY: ["SerpAPIKey"],
  OPENAI_API_KEY: ["OpenAIAPIKey"],
  ELEVENLABS_API_KEY: ["ElevenLabsAPIKey"],
  GEOAPIFY_API_KEY: ["GeoapifyAPIKey"],
  WEATHERAPI_API_KEY: ["WeatherAPIKey"],
  TRANSLATION_API_KEY: ["TranslationAPIKey"],
  TRANSLATION_PROVIDER: ["TranslationProvider"],
  TRANSLATION_BASE_URL: ["TranslationBaseURL"]
});

const TRANSLATION_PROVIDERS = new Set([
  "google",
  "deepl",
  "libretranslate"
]);

export function normalizeGatewayEnvironment(source = {}) {
  const normalized = { ...source };

  for (const [canonicalName, aliases] of Object.entries(
    ENVIRONMENT_ALIASES
  )) {
    const value = firstConfiguredValue(
      source,
      canonicalName,
      aliases
    );
    if (value !== undefined) {
      normalized[canonicalName] = value;
    }
  }

  return normalized;
}

export function configuredProviders(environment = {}) {
  const provider = normalizedTranslationProvider(environment);
  const translationConfigured =
    hasValue(environment.TRANSLATION_API_KEY)
    && TRANSLATION_PROVIDERS.has(provider)
    && (
      provider !== "libretranslate"
      || isHTTPSURL(environment.TRANSLATION_BASE_URL)
    );

  return {
    serpApi: hasValue(environment.SERPAPI_API_KEY),
    openAI: hasValue(environment.OPENAI_API_KEY),
    elevenLabs: hasValue(environment.ELEVENLABS_API_KEY),
    geoapify: hasValue(environment.GEOAPIFY_API_KEY),
    weatherAPI: hasValue(environment.WEATHERAPI_API_KEY),
    translation: translationConfigured
  };
}

export function gatewayConfigurationIssues(environment = {}) {
  const issues = [];
  const hasTranslationKey = hasValue(
    environment.TRANSLATION_API_KEY
  );
  const hasTranslationProvider = hasValue(
    environment.TRANSLATION_PROVIDER
  );
  const provider = normalizedTranslationProvider(environment);

  if (hasTranslationKey && !hasTranslationProvider) {
    issues.push("translation_provider_missing");
  } else if (!hasTranslationKey && hasTranslationProvider) {
    issues.push("translation_api_key_missing");
  } else if (
    hasTranslationProvider
    && !TRANSLATION_PROVIDERS.has(provider)
  ) {
    issues.push("translation_provider_unsupported");
  } else if (
    provider === "libretranslate"
    && !hasValue(environment.TRANSLATION_BASE_URL)
  ) {
    issues.push("translation_base_url_missing");
  } else if (
    hasValue(environment.TRANSLATION_BASE_URL)
    && !isHTTPSURL(environment.TRANSLATION_BASE_URL)
  ) {
    issues.push("translation_base_url_invalid");
  }

  return issues;
}

function firstConfiguredValue(
  source,
  canonicalName,
  aliases
) {
  for (const name of [canonicalName, ...aliases]) {
    if (hasValue(source[name])) {
      return source[name];
    }
  }
  return undefined;
}

function normalizedTranslationProvider(environment) {
  return String(
    environment.TRANSLATION_PROVIDER ?? ""
  ).trim().toLowerCase();
}

function hasValue(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isHTTPSURL(value) {
  try {
    return new URL(String(value)).protocol === "https:";
  } catch {
    return false;
  }
}
