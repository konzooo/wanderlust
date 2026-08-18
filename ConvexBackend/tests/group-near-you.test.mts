import assert from "node:assert/strict";
import { test } from "node:test";
import { groupNearYouRejection } from "../convex/groupNearYou";

test("group Near You allows one successful replacement only", () => {
  assert.equal(groupNearYouRejection(0, false), null);
  assert.equal(groupNearYouRejection(1, false), "near_you_replace_confirmation_required");
  assert.equal(groupNearYouRejection(1, true), null);
  assert.equal(groupNearYouRejection(2, true), "near_you_replacement_used");
});
