import assert from "node:assert/strict";
import test from "node:test";

import { RATE_LIMITS } from "../convex/lib/rateLimits";

test("anonymous public writes have install and global limits", () => {
  assert.equal(RATE_LIMITS.groupCreateInstall.rate, 10);
  assert.equal(RATE_LIMITS.groupCreateGlobal.rate, 1_000);
  assert.equal(RATE_LIMITS.sharedPublishInstall.rate, 20);
  assert.equal(RATE_LIMITS.sharedPublishGlobal.rate, 2_000);
});

test("AI generation has burst protection", () => {
  assert.equal(RATE_LIMITS.generationBurstInstall.kind, "token bucket");
  assert.equal(RATE_LIMITS.generationBurstInstall.rate, 12);
  assert.equal(RATE_LIMITS.generationBurstInstall.capacity, 8);
  assert.equal(RATE_LIMITS.generationBurstGlobal.rate, 300);
});
