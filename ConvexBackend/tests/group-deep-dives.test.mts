import assert from "node:assert/strict";
import { test } from "node:test";
import {
  collectAlreadyRecommended,
  groupDeepDiveRejection,
} from "../convex/groupDeepDives";

test("group deep dives enforce a group-scoped cap and duplicate label", () => {
  const now = 1_000_000;
  const slots = [
    { status: "committed" as const, label: "food halls", createdAt: now - 100 },
    { status: "committed" as const, label: "running", createdAt: now - 100 },
  ];
  assert.equal(groupDeepDiveRejection(slots, "food halls", now), "duplicate_deep_dive");
  assert.equal(groupDeepDiveRejection(slots, "climbing", now), null);
  assert.equal(
    groupDeepDiveRejection(
      [...slots, { status: "reserved", label: "climbing", createdAt: now }],
      "music",
      now,
    ),
    "quota_component_cap",
  );
});

test("expired failed reservations do not consume the group cap", () => {
  assert.equal(
    groupDeepDiveRejection(
      [{ status: "reserved", label: "running", createdAt: 0 }],
      "running",
      1_000_000,
    ),
    null,
  );
});

test("group alreadyRecommended is live and deduplicated", () => {
  assert.deepEqual(
    collectAlreadyRecommended([
      { locations: [{ placeName: "Mercado Central" }] },
      { place: "City Museum" },
      { locations: [{ placeName: "mercado central" }] },
    ]),
    ["Mercado Central", "City Museum"],
  );
});
