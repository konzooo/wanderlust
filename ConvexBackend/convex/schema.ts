import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import {
  groupStatus,
  memberPreferences,
  memberRole,
  memberStatus,
} from "./lib/validators";

/**
 * Group Trips data model.
 *
 * Authorization note: `adminTokenHash` / `memberTokenHash` are the ONLY access
 * control. The raw tokens live in each device's Keychain and are never stored
 * here or returned to any client. Device IDs are intentionally NOT stored — a
 * device ID is spoofable identity, not authorization. Client-facing DTOs expose
 * names + status only (see lib/dto.ts, added with the query functions).
 */
export default defineSchema({
  groups: defineTable({
    /** 5-digit numeric invite code kept as TEXT to preserve leading zeros. */
    code: v.string(),
    name: v.string(),
    destination: v.string(),
    durationDays: v.number(),
    /** `Month` rawValue from CoreModels (e.g. "august"). */
    startMonth: v.string(),
    /** SHA-256 hash of the admin capability token; raw token in admin Keychain. */
    adminTokenHash: v.string(),
    status: groupStatus,
    /**
     * Monotonic counter guaranteeing at-most-one live generation. A commit only
     * writes results if this still matches the value captured when it started,
     * so a stale/retried action can never clobber a newer attempt.
     */
    generationVersion: v.number(),
    attemptCount: v.number(),
    errorCode: v.optional(v.string()),
    /**
     * Generated output. Typed as `any` for now (already schema-constrained by
     * OpenAI strict mode on the way in); tighten to explicit validators later.
     * Shapes mirror CoreModels `Trip.Itinerary` / `Trip.Suggestions`.
     */
    itinerary: v.optional(v.any()),
    suggestions: v.optional(v.any()),
    imageUrl: v.optional(v.string()),
    /** Destination photo for the invite link's rich preview (cached from Unsplash). */
    shareImageUrl: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_code", ["code"]),

  members: defineTable({
    groupId: v.id("groups"),
    name: v.string(),
    role: memberRole,
    /** SHA-256 hash of the member capability token; set when the slot is claimed. */
    memberTokenHash: v.optional(v.string()),
    status: memberStatus,
    /** Set only once the member completes swiping; never returned to clients. */
    preferences: v.optional(memberPreferences),
    completedAt: v.optional(v.number()),
  })
    .index("by_group", ["groupId"])
    .index("by_token", ["memberTokenHash"]),

  /**
   * A solo trip explicitly published by tapping Share. Nothing lands here
   * until then (publish-on-share only — solo trips are otherwise 100% local).
   * The public `code` grants read access; there is no write/update/revoke
   * mutation in v1 — once a recipient opens a shared trip, it becomes a
   * durable local copy on their device (see `ReceivedSharedTripStore.swift`),
   * so there is nothing to keep "live" server-side after the first fetch.
   */
  sharedTrips: defineTable({
    /** Unguessable 32-hex code — this code IS the read capability. */
    code: v.string(),
    /**
     * SHA-256 hash of an owner token, minted now so a future revoke feature
     * needs no migration. Unused client-side in v1 — nothing calls it yet.
     */
    ownerTokenHash: v.string(),
    title: v.string(),
    destination: v.string(),
    durationDays: v.number(),
    /** `Month` rawValue from CoreModels — MIXED CASE ("June", "january"). */
    startMonth: v.string(),
    /** `Trip.Details.GroupType` rawValue ("solo", "couple", …). */
    groupType: v.string(),
    /**
     * Deliberately untyped, like `groups.itinerary`/`groups.suggestions` —
     * shapes mirror CoreModels; re-validating risks breaking the app's own
     * strict decoders on a schema mismatch.
     */
    itinerary: v.any(),
    suggestions: v.optional(v.any()),
    /** `Trip.Favorites` — shown read-only-but-editable on the recipient's local copy. */
    favorites: v.optional(v.any()),
    /** The destination photo the app already resolved while generating. */
    imageUrl: v.optional(v.string()),
    /** OG-card-sized (1200x630) photo, cached by the /t endpoint. */
    shareImageUrl: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_code", ["code"]),
});
