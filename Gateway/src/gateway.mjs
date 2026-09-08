import {
  randomUUID,
  timingSafeEqual
} from "node:crypto";

import {
  configuredProviders,
  gatewayConfigurationIssues
} from "./provider-environment.mjs";

const MAX_BODY_BYTES = 64 * 1024;

const ROUTES = new Map([
  ["/v1/respond", "generateResponse"],
  ["/v1/interpret-reply", "interpretReply"],
  ["/v1/resolve/location", "resolveLocation"],
  ["/v1/plan", "plan"],
  ["/v1/search/flights", "searchFlights"],
  ["/v1/search/flights/return", "completeRoundTrip"],
  ["/v1/search/hotels", "searchHotels"],
  ["/v1/search/places", "searchPlaces"],
  ["/v1/search/events", "searchEvents"],
  ["/v1/route", "planRoute"],
  ["/v1/weather", "getWeather"],
  ["/v1/speech", "generateSpeech"],
  ["/v1/translation", "translate"]
]);

export class GatewayError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.name = "GatewayError";
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export function createGateway({
  env = process.env,
  handlers = {},
  now = () => Date.now()
} = {}) {
  const rateLimiter = new InMemoryRateLimiter({
    maximumRequests: readInteger(
      env.RATE_LIMIT_MAX,
      60,
      1,
      10_000
    ),
    windowMilliseconds: readInteger(
      env.RATE_LIMIT_WINDOW_MS,
      60_000,
      1_000,
      86_400_000
    ),
    now
  });
  const allowedOrigins = parseAllowedOrigins(
    env.ALLOWED_ORIGINS
  );
  const timeoutMilliseconds = readInteger(
    env.REQUEST_TIMEOUT_MS,
    12_000,
    1_000,
    60_000
  );

  return async function handle(request, context = {}) {
    const requestId = request.headers.get("x-request-id")
      ?? randomUUID();
    const origin = request.headers.get("origin");
    let responseOrigin;

    try {
      enforceOrigin(origin, allowedOrigins);
      responseOrigin = origin;

      if (request.method === "OPTIONS") {
        return emptyResponse(204, requestId, responseOrigin);
      }

      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/health") {
        return jsonResponse(
          {
            status: "ok",
            version: "0.1.0",
            authenticationConfigured:
              Boolean(env.GATEWAY_ACCESS_TOKEN),
            providers: configuredProviders(env),
            configurationIssues:
              gatewayConfigurationIssues(env)
          },
          200,
          requestId,
          responseOrigin
        );
      }

      const routeName = ROUTES.get(url.pathname);
      if (!routeName) {
        throw new GatewayError(
          404,
          "route_not_found",
          "The requested gateway route does not exist."
        );
      }

      if (request.method !== "POST") {
        throw new GatewayError(
          405,
          "method_not_allowed",
          "This gateway route accepts POST requests only."
        );
      }

      authenticateRequest(
        request,
        env.GATEWAY_ACCESS_TOKEN
      );

      const clientIdentifier =
        context.clientIdentifier
        ?? request.headers.get("cf-connecting-ip")
        ?? request.headers.get("x-forwarded-for")
        ?? "local";
      if (!rateLimiter.consume(clientIdentifier)) {
        throw new GatewayError(
          429,
          "rate_limit_exceeded",
          "Too many requests. Try again shortly."
        );
      }

      const body = await readJSONBody(request);
      const handler = handlers[routeName];
      if (!handler) {
        throw new GatewayError(
          501,
          "provider_not_connected",
          `The ${routeName} provider is not connected yet.`
        );
      }

      const result = await runWithTimeout(
        handler,
        body,
        {
          requestId,
          routeName
        },
        timeoutMilliseconds
      );

      if (result instanceof Response) {
        return securedProviderResponse(
          result,
          requestId,
          responseOrigin
        );
      }

      return jsonResponse(
        {
          data: result
        },
        200,
        requestId,
        responseOrigin
      );
    } catch (error) {
      const safeError = normalizeError(error);
      return jsonResponse(
        {
          error: {
            code: safeError.code,
            message: safeError.message,
            ...(safeError.details
              ? { details: safeError.details }
              : {})
          }
        },
        safeError.status,
        requestId,
        responseOrigin
      );
    }
  };
}

function securedProviderResponse(
  response,
  requestId,
  origin
) {
  const headers = responseHeaders(requestId, origin);
  const contentType = response.headers.get("content-type");
  if (contentType) {
    headers.set("content-type", contentType);
  }

  return new Response(response.body, {
    status: response.status,
    headers
  });
}

class InMemoryRateLimiter {
  constructor({
    maximumRequests,
    windowMilliseconds,
    now
  }) {
    this.maximumRequests = maximumRequests;
    this.windowMilliseconds = windowMilliseconds;
    this.now = now;
    this.clients = new Map();
  }

  consume(identifier) {
    const currentTime = this.now();
    const existing = this.clients.get(identifier);

    if (
      !existing
      || currentTime - existing.windowStartedAt
        >= this.windowMilliseconds
    ) {
      this.clients.set(identifier, {
        count: 1,
        windowStartedAt: currentTime
      });
      return true;
    }

    if (existing.count >= this.maximumRequests) {
      return false;
    }

    existing.count += 1;
    return true;
  }
}

async function readJSONBody(request) {
  const contentType =
    request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    throw new GatewayError(
      415,
      "unsupported_media_type",
      "Requests must use the application/json content type."
    );
  }

  const declaredLength = Number(
    request.headers.get("content-length")
  );
  if (
    Number.isFinite(declaredLength)
    && declaredLength > MAX_BODY_BYTES
  ) {
    throw new GatewayError(
      413,
      "payload_too_large",
      "The request body is too large."
    );
  }

  const text = await request.text();
  if (Buffer.byteLength(text, "utf8") > MAX_BODY_BYTES) {
    throw new GatewayError(
      413,
      "payload_too_large",
      "The request body is too large."
    );
  }

  try {
    const body = JSON.parse(text);
    if (!body || Array.isArray(body) || typeof body !== "object") {
      throw new Error("Expected a JSON object.");
    }
    return body;
  } catch {
    throw new GatewayError(
      400,
      "invalid_json",
      "The request body must be a valid JSON object."
    );
  }
}

async function runWithTimeout(
  handler,
  body,
  context,
  timeoutMilliseconds
) {
  const controller = new AbortController();
  let timeout;

  try {
    return await Promise.race([
      handler(body, {
        ...context,
        signal: controller.signal
      }),
      new Promise((_, reject) => {
        timeout = setTimeout(() => {
          controller.abort();
          reject(
            new GatewayError(
              504,
              "provider_timeout",
              "The travel provider did not respond in time."
            )
          );
        }, timeoutMilliseconds);
      })
    ]);
  } finally {
    clearTimeout(timeout);
  }
}

function authenticateRequest(request, expectedToken) {
  if (!expectedToken) {
    throw new GatewayError(
      503,
      "gateway_authentication_not_configured",
      "Gateway authentication must be configured before use."
    );
  }

  const authorization =
    request.headers.get("authorization") ?? "";
  const prefix = "Bearer ";
  const suppliedToken = authorization.startsWith(prefix)
    ? authorization.slice(prefix.length)
    : "";

  if (!securelyMatches(suppliedToken, expectedToken)) {
    throw new GatewayError(
      401,
      "unauthorized",
      "A valid gateway credential is required."
    );
  }
}

function securelyMatches(left, right) {
  const leftBytes = Buffer.from(left);
  const rightBytes = Buffer.from(right);
  if (
    leftBytes.length === 0
    || leftBytes.length !== rightBytes.length
  ) {
    return false;
  }
  return timingSafeEqual(leftBytes, rightBytes);
}

function enforceOrigin(origin, allowedOrigins) {
  if (!origin) {
    return;
  }

  if (!allowedOrigins.has(origin)) {
    throw new GatewayError(
      403,
      "origin_not_allowed",
      "This browser origin is not allowed."
    );
  }
}

function parseAllowedOrigins(rawValue = "") {
  return new Set(
    rawValue
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean)
  );
}

function readInteger(value, fallback, minimum, maximum) {
  const parsed = Number.parseInt(value ?? "", 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(Math.max(parsed, minimum), maximum);
}

function normalizeError(error) {
  if (error instanceof GatewayError) {
    return error;
  }

  return new GatewayError(
    500,
    "internal_error",
    "The gateway could not complete the request."
  );
}

function jsonResponse(
  payload,
  status,
  requestId,
  origin
) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: responseHeaders(requestId, origin)
  });
}

function emptyResponse(status, requestId, origin) {
  return new Response(null, {
    status,
    headers: responseHeaders(requestId, origin)
  });
}

function responseHeaders(requestId, origin) {
  const headers = new Headers({
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    "x-content-type-options": "nosniff",
    "x-request-id": requestId
  });

  if (origin) {
    headers.set("access-control-allow-origin", origin);
    headers.set(
      "access-control-allow-headers",
      "authorization, content-type, x-request-id"
    );
    headers.set(
      "access-control-allow-methods",
      "GET, POST, OPTIONS"
    );
    headers.set("vary", "Origin");
  }

  return headers;
}
