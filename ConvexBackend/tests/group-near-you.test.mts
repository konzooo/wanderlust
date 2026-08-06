import assert from "node:assert/strict";
import { test } from "node:test";
import {
  groupNearYouRejection,
  materializeGroupNearYou,
  modelCandidate,
} from "../convex/groupNearYou";

const candidate = {
  id: "11111111-1111-4111-8111-111111111111",
  name: "Grounded Cafe",
  category: "Cafe",
  latitude: 41.385,
  longitude: 2.173,
  distanceMetres: 430,
  walkingMinutes: 6,
  mapURL: "https://maps.apple.com/?q=Grounded%20Cafe",
};

test("group model candidate strips coordinates and map link", () => {
  const payload = JSON.stringify(modelCandidate(candidate));
  assert.equal(payload.includes("latitude"), false);
  assert.equal(payload.includes("longitude"), false);
  assert.equal(payload.includes("mapURL"), false);
  assert.match(payload, /distanceMetres/);
});

test("group materialization uses supplied grounded facts and stable IDs", () => {
  const output = materializeGroupNearYou(
    {
      sections: [{
        title: "A good morning",
        picks: [{ candidateID: candidate.id, explanation: "Fits a slow start." }],
      }],
      sparseMessage: null,
    },
    [candidate],
    [],
    [],
    () => "22222222-2222-4222-8222-222222222222",
  ) as any;
  assert.equal(output.sections[0].id, "22222222-2222-4222-8222-222222222222");
  assert.equal(output.sections[0].picks[0].candidate.distanceMetres, 430);
  assert.equal(output.sections[0].picks[0].candidate.walkingMinutes, 6);
  assert.match(output.sparseMessage, /intentionally short/);
});

test("group Near You allows one successful replacement only", () => {
  assert.equal(groupNearYouRejection(0, false), null);
  assert.equal(groupNearYouRejection(1, false), "near_you_replace_confirmation_required");
  assert.equal(groupNearYouRejection(1, true), null);
  assert.equal(groupNearYouRejection(2, true), "near_you_replacement_used");
});
