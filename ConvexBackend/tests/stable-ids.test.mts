import assert from "node:assert/strict";
import { test } from "node:test";
import { stampMissingStableIds } from "../convex/lib/stableIds";

const ids = [
  "11111111-1111-4111-8111-111111111111",
  "22222222-2222-4222-8222-222222222222",
  "33333333-3333-4333-8333-333333333333",
  "44444444-4444-4444-8444-444444444444",
  "55555555-5555-4555-8555-555555555555",
  "66666666-6666-4666-8666-666666666666",
];

test("shared generated items receive server-stable IDs", () => {
  let next = 0;
  const stamped = stampMissingStableIds(
    {
      itinerary: { secretTips: [{ text: "Try the side entrance", locations: [] }] },
      suggestions: [{ title: "Eat", texts: [{ text: "Cafe", locations: [] }] }],
      worthIt: [
        { place: "Museum", theCase: "Great", theCatch: "Busy", verdict: "Go early" },
      ],
      whereToStay: [
        { area: "North", theCase: "Quiet", bestFor: "Sleep", watchOut: "Few buses" },
      ],
      knowBeforeYouGo: [
        { bucket: "money", title: "Cash", body: "Carry some", bullets: [] },
      ],
    },
    () => ids[next++],
  ) as any;

  assert.equal(stamped.itinerary.secretTips[0].id, ids[0]);
  assert.equal(stamped.suggestions[0].texts[0].id, ids[1]);
  assert.equal(stamped.suggestions[0].id, ids[2]);
  assert.equal(stamped.worthIt[0].id, ids[3]);
  assert.equal(stamped.whereToStay[0].id, ids[4]);
  assert.equal(stamped.knowBeforeYouGo[0].id, ids[5]);

  const firstDecode = JSON.parse(JSON.stringify(stamped));
  const secondDecode = JSON.parse(JSON.stringify(stamped));
  assert.deepEqual(firstDecode, secondDecode);
});

test("valid existing IDs survive while invalid IDs are repaired", () => {
  const existing = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
  const repaired = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
  const stamped = stampMissingStableIds(
    {
      title: "Two picks",
      texts: [
        { id: existing, text: "Keep me", locations: [] },
        { id: "not-a-uuid", text: "Repair me", locations: [] },
      ],
    },
    () => repaired,
  ) as any;

  assert.equal(stamped.texts[0].id, existing);
  assert.equal(stamped.texts[1].id, repaired);
});
