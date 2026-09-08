import { spawnSync } from "node:child_process";

const files = [
  "src/gateway.mjs",
  "src/provider-environment.mjs",
  "src/provider-queue.mjs",
  "src/server.mjs",
  "src/planning/plan-blueprint.mjs",
  "src/speech-prefetch-cache.mjs",
  "src/providers/openai-conversation.mjs",
  "src/providers/openai-interpret-reply.mjs",
  "src/providers/openai-planner.mjs",
  "src/providers/serpapi-flights.mjs",
  "src/providers/serpapi-hotels.mjs",
  "src/providers/place-discovery.mjs",
  "src/providers/serpapi-events.mjs",
  "src/providers/geoapify-location.mjs",
  "src/providers/geoapify-routes.mjs",
  "src/providers/weatherapi-weather.mjs",
  "src/providers/elevenlabs-speech.mjs",
  "src/providers/translation-provider.mjs",
  "scripts/live-smoke.mjs"
];

for (const file of files) {
  const result = spawnSync(
    process.execPath,
    ["--check", file],
    {
      encoding: "utf8",
      stdio: "pipe"
    }
  );

  if (result.status !== 0) {
    process.stderr.write(result.stderr);
    process.exit(result.status ?? 1);
  }
}

console.info(`Syntax checked ${files.length} gateway modules.`);
