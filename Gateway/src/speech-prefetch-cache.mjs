const DEFAULT_TTL_MS = 12_000;

export function normalizeSpeechCacheKey(text) {
  return String(text ?? "").trim().replace(/\s+/g, " ");
}

export function createSpeechPrefetchCache({
  ttlMilliseconds = DEFAULT_TTL_MS
} = {}) {
  const entries = new Map();

  function prune(now = Date.now()) {
    for (const [key, entry] of entries) {
      if (now - entry.storedAt > ttlMilliseconds) {
        entries.delete(key);
      }
    }
  }

  return {
    store(text, promise) {
      const key = normalizeSpeechCacheKey(text);
      if (!key || !promise) {
        return;
      }
      prune();
      entries.set(key, {
        promise,
        storedAt: Date.now()
      });
    },

    take(text) {
      const key = normalizeSpeechCacheKey(text);
      if (!key) {
        return null;
      }
      prune();
      const entry = entries.get(key);
      if (!entry) {
        return null;
      }
      entries.delete(key);
      return entry.promise;
    }
  };
}

export async function bufferSpeechResponse(response) {
  const audio = Buffer.from(await response.arrayBuffer());
  const contentType =
    response.headers.get("content-type") ?? "audio/mpeg";
  return new Response(audio, {
    status: response.status,
    headers: {
      "content-type": contentType,
      "cache-control": "no-store"
    }
  });
}
