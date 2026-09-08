import assert from "node:assert/strict";
import test from "node:test";

import {
  createSerialProviderQueue
} from "../src/provider-queue.mjs";

test("provider queue runs operations one at a time", async () => {
  const queue = createSerialProviderQueue();
  const events = [];
  let releaseFirst;
  const firstGate = new Promise((resolve) => {
    releaseFirst = resolve;
  });

  const first = queue.run(async () => {
    events.push("first-start");
    await firstGate;
    events.push("first-end");
    return 1;
  });
  const second = queue.run(async () => {
    events.push("second-start");
    events.push("second-end");
    return 2;
  });

  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(events, ["first-start"]);
  releaseFirst();
  assert.deepEqual(await Promise.all([first, second]), [1, 2]);
  assert.deepEqual(events, [
    "first-start",
    "first-end",
    "second-start",
    "second-end"
  ]);
});

test("provider queue continues after a failed operation", async () => {
  const queue = createSerialProviderQueue();
  const failure = queue.run(async () => {
    throw new Error("expected failure");
  });
  const success = queue.run(async () => "ready");

  await assert.rejects(failure, /expected failure/u);
  assert.equal(await success, "ready");
});
