import { createHash } from "node:crypto";

import { GatewayError } from "../gateway.mjs";

const RESULT_TTL_MILLISECONDS = 86_400_000;
const SUPPORTED_CONTENT_KINDS = new Set([
  "plainText",
  "placeDescription",
  "address",
  "travelMessage",
  "identifier"
]);

export function createTranslationProvider({
  provider,
  apiKey,
  baseURL,
  fetchImplementation = globalThis.fetch,
  now = () => new Date()
}) {
  return async function translate(criteria, context = {}) {
    const validated = validateTranslationCriteria(criteria);

    if (
      validated.contentKind === "identifier"
      || validated.contentKind === "address"
    ) {
      return unchangedTranslation(
        validated,
        now(),
        [
          {
            text: validated.text,
            protected: true
          }
        ]
      );
    }
    if (
      languagesMatch(
        validated.sourceLanguageCode,
        validated.targetLanguageCode
      )
    ) {
      return unchangedTranslation(
        validated,
        now(),
        protectedSegments(
          validated.text,
          validated.protectedTerms
        )
      );
    }

    const providerConfiguration = translationProviderConfiguration({
      provider,
      apiKey,
      baseURL
    });
    const segmented = protectedSegments(
      validated.text,
      validated.protectedTerms
    );
    const translationJobs = segmented
      .map((segment, index) => translationJob(segment, index))
      .filter(Boolean);
    if (translationJobs.length === 0) {
      return unchangedTranslation(validated, now(), segmented);
    }

    const translated = await callProvider({
      configuration: providerConfiguration,
      texts: translationJobs.map((job) => job.text),
      sourceLanguageCode: validated.sourceLanguageCode,
      targetLanguageCode: validated.targetLanguageCode,
      signal: context.signal,
      fetchImplementation
    });
    if (translated.texts.length !== translationJobs.length) {
      throw new GatewayError(
        502,
        "translation_count_mismatch",
        "Translation returned an invalid number of segments."
      );
    }
    if (
      translated.texts.some(
        (value) => (
          typeof value !== "string"
          || value.trim().length === 0
        )
      )
    ) {
      throw new GatewayError(
        502,
        "translation_empty_segment",
        "Translation returned an empty segment."
      );
    }

    const translatedBySegment = new Map(
      translationJobs.map((job, index) => [
        job.segmentIndex,
        `${job.leading}${translated.texts[index]}${job.trailing}`
      ])
    );
    const translatedText = segmented.map((segment, index) => {
      if (!translatedBySegment.has(index)) {
        return segment.text;
      }
      return translatedBySegment.get(index);
    }).join("");
    const retrievedAt = now();

    return {
      originalText: validated.text,
      translatedText,
      requestedSourceLanguageCode:
        validated.sourceLanguageCode,
      detectedSourceLanguageCode:
        translated.detectedSourceLanguageCode,
      targetLanguageCode: validated.targetLanguageCode,
      contentKind: validated.contentKind,
      protectedTerms: segmented
        .filter((segment) => segment.protected)
        .map((segment) => segment.text),
      isMachineTranslated: true,
      provenance: {
        provider: providerConfiguration.providerIdentifier,
        providerIdentifier: null,
        origin: "live",
        retrievedAt: retrievedAt.toISOString(),
        expiresAt: new Date(
          retrievedAt.getTime() + RESULT_TTL_MILLISECONDS
        ).toISOString(),
        sourceURL: providerConfiguration.sourceURL
      }
    };
  };
}

export function validateTranslationCriteria(criteria) {
  requireObject(criteria, "invalid_translation_request");
  const text = String(criteria.text ?? "");
  if (text.length < 1 || text.length > 5_000) {
    throw new GatewayError(
      422,
      "invalid_translation_text",
      "Translation text must contain between 1 and 5,000 characters."
    );
  }

  const sourceLanguageCode =
    criteria.sourceLanguageCode === null
    || criteria.sourceLanguageCode === undefined
      ? null
      : requireLanguageCode(
          criteria.sourceLanguageCode,
          "invalid_source_language"
        );
  const targetLanguageCode = requireLanguageCode(
    criteria.targetLanguageCode,
    "invalid_target_language"
  );
  const contentKind = String(
    criteria.contentKind ?? "plainText"
  );
  if (!SUPPORTED_CONTENT_KINDS.has(contentKind)) {
    throw new GatewayError(
      422,
      "invalid_translation_content_kind",
      "Translation content type is unsupported."
    );
  }

  const terms = Array.isArray(criteria.protectedTerms)
    ? criteria.protectedTerms
    : [];
  if (terms.length > 50) {
    throw new GatewayError(
      422,
      "too_many_protected_terms",
      "Too many protected translation terms were supplied."
    );
  }
  const protectedTerms = [
    ...new Set(
      terms.map((term) => String(term).trim()).filter(
        (term) => term.length > 0 && term.length <= 200
      )
    )
  ];

  return {
    text,
    sourceLanguageCode,
    targetLanguageCode,
    contentKind,
    protectedTerms
  };
}

export function protectedSegments(text, suppliedTerms = []) {
  const ranges = [];
  const automaticPatterns = [
    /https?:\/\/[^\s]+/giu,
    /\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b/gu,
    /\b[A-Z0-9]{6,}\b/gu,
    /\b\d{4}-\d{2}-\d{2}\b/gu,
    /[$€£¥]\s?\d[\d,.]*/gu,
    /\bG\.?I\.?A\.?\b/giu
  ];

  for (const pattern of automaticPatterns) {
    for (const match of text.matchAll(pattern)) {
      ranges.push({
        start: match.index,
        end: match.index + match[0].length
      });
    }
  }

  const lowerText = text.toLocaleLowerCase("en-US");
  for (
    const term of [...suppliedTerms].sort(
      (left, right) => right.length - left.length
    )
  ) {
    const lowerTerm = term.toLocaleLowerCase("en-US");
    let start = 0;
    while (start < text.length) {
      const index = lowerText.indexOf(lowerTerm, start);
      if (index < 0) {
        break;
      }
      ranges.push({
        start: index,
        end: index + term.length
      });
      start = index + term.length;
    }
  }

  const merged = mergeRanges(ranges, text.length);
  if (merged.length === 0) {
    return [
      {
        text,
        protected: false
      }
    ];
  }

  const segments = [];
  let cursor = 0;
  for (const range of merged) {
    if (range.start > cursor) {
      segments.push({
        text: text.slice(cursor, range.start),
        protected: false
      });
    }
    segments.push({
      text: text.slice(range.start, range.end),
      protected: true
    });
    cursor = range.end;
  }
  if (cursor < text.length) {
    segments.push({
      text: text.slice(cursor),
      protected: false
    });
  }
  return segments;
}

function translationProviderConfiguration({
  provider,
  apiKey,
  baseURL
}) {
  if (!apiKey) {
    throw new GatewayError(
      503,
      "translation_not_configured",
      "Translation is not configured."
    );
  }

  switch (String(provider ?? "").toLowerCase()) {
    case "google":
      return {
        type: "google",
        endpoint: validatedProviderURL(
          baseURL
            ?? "https://translation.googleapis.com/language/translate/v2",
          ["translation.googleapis.com"]
        ),
        apiKey,
        providerIdentifier: "google_translation",
        sourceURL:
          "https://cloud.google.com/translate/docs"
      };
    case "deepl":
      return {
        type: "deepl",
        endpoint: validatedProviderURL(
          baseURL
            ?? "https://api-free.deepl.com/v2/translate",
          ["api-free.deepl.com", "api.deepl.com"]
        ),
        apiKey,
        providerIdentifier: "deepl",
        sourceURL: "https://developers.deepl.com/docs"
      };
    case "libretranslate":
      if (!baseURL) {
        throw new GatewayError(
          503,
          "translation_endpoint_missing",
          "LibreTranslate requires a configured HTTPS endpoint."
        );
      }
      return {
        type: "libretranslate",
        endpoint: validatedProviderURL(baseURL),
        apiKey,
        providerIdentifier: "libretranslate",
        sourceURL: safeSourceURL(baseURL)
      };
    default:
      throw new GatewayError(
        503,
        "translation_provider_not_configured",
        "Choose a supported translation provider."
      );
  }
}

async function callProvider({
  configuration,
  texts,
  sourceLanguageCode,
  targetLanguageCode,
  signal,
  fetchImplementation
}) {
  let request;
  switch (configuration.type) {
    case "google": {
      const endpoint = new URL(configuration.endpoint);
      endpoint.searchParams.set("key", configuration.apiKey);
      request = {
        url: endpoint,
        options: {
          method: "POST",
          headers: {
            "content-type": "application/json"
          },
          body: JSON.stringify({
            q: texts,
            target: targetLanguageCode,
            format: "text",
            ...(sourceLanguageCode
              ? { source: sourceLanguageCode }
              : {})
          }),
          signal
        }
      };
      break;
    }
    case "deepl":
      request = {
        url: configuration.endpoint,
        options: {
          method: "POST",
          headers: {
            authorization:
              `DeepL-Auth-Key ${configuration.apiKey}`,
            "content-type": "application/json"
          },
          body: JSON.stringify({
            text: texts,
            target_lang: deeplLanguage(targetLanguageCode),
            ...(sourceLanguageCode
              ? { source_lang: deeplLanguage(sourceLanguageCode) }
              : {})
          }),
          signal
        }
      };
      break;
    case "libretranslate":
      request = {
        url: configuration.endpoint,
        options: {
          method: "POST",
          headers: {
            "content-type": "application/json"
          },
          body: JSON.stringify({
            q: texts,
            source: sourceLanguageCode ?? "auto",
            target: targetLanguageCode,
            format: "text",
            api_key: configuration.apiKey
          }),
          signal
        }
      };
      break;
    default:
      throw new GatewayError(
        503,
        "translation_provider_not_configured",
        "Translation is not configured."
      );
  }

  let response;
  try {
    response = await fetchImplementation(
      request.url,
      request.options
    );
  } catch (error) {
    if (signal?.aborted || error?.name === "AbortError") {
      throw new GatewayError(
        504,
        "translation_timeout",
        "Translation timed out."
      );
    }
    throw new GatewayError(
      502,
      "translation_transport_failed",
      "Translation could not reach its provider."
    );
  }

  if (response.status === 429) {
    throw new GatewayError(
      429,
      "translation_rate_limited",
      "Translation is busy. Try again shortly."
    );
  }
  if (response.status === 401 || response.status === 403) {
    throw new GatewayError(
      503,
      "translation_authorization_failed",
      "Translation is not configured correctly."
    );
  }
  if (!response.ok) {
    throw new GatewayError(
      502,
      "translation_request_failed",
      "Translation could not be completed."
    );
  }

  let payload;
  try {
    payload = await response.json();
  } catch {
    throw new GatewayError(
      502,
      "translation_invalid_response",
      "Translation returned invalid data."
    );
  }

  return parseProviderResponse(configuration.type, payload);
}

function parseProviderResponse(provider, payload) {
  if (provider === "google") {
    const values = payload.data?.translations;
    if (!Array.isArray(values)) {
      return invalidProviderResponse();
    }
    return {
      texts: values.map((value) => decodeHTMLEntities(
        String(value.translatedText ?? "")
      )),
      detectedSourceLanguageCode:
        values[0]?.detectedSourceLanguage ?? null
    };
  }

  if (provider === "deepl") {
    const values = payload.translations;
    if (!Array.isArray(values)) {
      return invalidProviderResponse();
    }
    return {
      texts: values.map((value) => String(value.text ?? "")),
      detectedSourceLanguageCode:
        values[0]?.detected_source_language?.toLowerCase() ?? null
    };
  }

  if (Array.isArray(payload?.translatedText)) {
    return {
      texts: payload.translatedText.map(String),
      detectedSourceLanguageCode:
        payload.detectedLanguage?.language ?? null
    };
  }
  const values = Array.isArray(payload) ? payload : [payload];
  return {
    texts: values.map((value) => String(
      value.translatedText ?? ""
    )),
    detectedSourceLanguageCode:
      values[0]?.detectedLanguage?.language ?? null
  };
}

function invalidProviderResponse() {
  throw new GatewayError(
    502,
    "translation_invalid_response",
    "Translation returned an unsupported response."
  );
}

function unchangedTranslation(criteria, retrievedAt, segments = []) {
  return {
    originalText: criteria.text,
    translatedText: criteria.text,
    requestedSourceLanguageCode: criteria.sourceLanguageCode,
    detectedSourceLanguageCode: criteria.sourceLanguageCode,
    targetLanguageCode: criteria.targetLanguageCode,
    contentKind: criteria.contentKind,
    protectedTerms: segments
      .filter((segment) => segment.protected)
      .map((segment) => segment.text),
    isMachineTranslated: false,
    provenance: {
      provider: "gia",
      providerIdentifier: null,
      origin: "userEntered",
      retrievedAt: retrievedAt.toISOString(),
      expiresAt: null,
      sourceURL: null
    }
  };
}

function mergeRanges(ranges, maximum) {
  const sorted = ranges
    .map((range) => ({
      start: Math.max(0, Math.min(range.start, maximum)),
      end: Math.max(0, Math.min(range.end, maximum))
    }))
    .filter((range) => range.end > range.start)
    .sort((left, right) => (
      left.start - right.start || right.end - left.end
    ));
  const merged = [];
  for (const range of sorted) {
    const previous = merged[merged.length - 1];
    if (!previous || range.start > previous.end) {
      merged.push({ ...range });
    } else {
      previous.end = Math.max(previous.end, range.end);
    }
  }
  return merged;
}

function languagesMatch(source, target) {
  if (!source) {
    return false;
  }
  return source.toLowerCase() === target.toLowerCase();
}

function containsLetters(value) {
  return /\p{L}/u.test(value);
}

function translationJob(segment, segmentIndex) {
  if (segment.protected || !containsLetters(segment.text)) {
    return null;
  }
  const leading = segment.text.match(/^\s*/u)?.[0] ?? "";
  const trailing = segment.text.match(/\s*$/u)?.[0] ?? "";
  const end = segment.text.length - trailing.length;
  const text = segment.text.slice(leading.length, end);
  if (!containsLetters(text)) {
    return null;
  }
  return {
    segmentIndex,
    leading,
    trailing,
    text
  };
}

function requireLanguageCode(value, code) {
  const normalized = String(value ?? "").trim();
  if (!/^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$/.test(normalized)) {
    throw new GatewayError(
      422,
      code,
      "A valid language code is required."
    );
  }
  return normalized;
}

function validatedProviderURL(value, allowedHosts) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new GatewayError(
      503,
      "translation_endpoint_invalid",
      "Translation endpoint is invalid."
    );
  }
  if (
    url.protocol !== "https:"
    || (
      allowedHosts
      && !allowedHosts.includes(url.hostname)
    )
  ) {
    throw new GatewayError(
      503,
      "translation_endpoint_invalid",
      "Translation endpoint is invalid."
    );
  }
  return url.toString();
}

function safeSourceURL(value) {
  try {
    const url = new URL(value);
    return `${url.protocol}//${url.host}`;
  } catch {
    return null;
  }
}

function deeplLanguage(value) {
  return value.replace("-", "_").toUpperCase();
}

function decodeHTMLEntities(value) {
  return value
    .replaceAll("&amp;", "&")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", "\"")
    .replaceAll("&#39;", "'");
}

function requireObject(value, code) {
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new GatewayError(
      422,
      code,
      "Invalid translation request."
    );
  }
  return value;
}
