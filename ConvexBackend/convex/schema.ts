import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import {
  groupComponentStates,
  groupStatus,
  memberPreferences,
  memberRole,
  memberStatus,
} from "./lib/validators";
import {
  generationComponent,
  suggestionsVariant,
  tripMode,
} from "./lib/components";

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
    /** Mirrors CoreModels `Trip.KnowBeforeYouGo`. Absent on older groups. */
    knowBeforeYouGo: v.optional(v.any()),
    /** Shared content; each member's verdict remains device-local. */
    worthIt: v.optional(v.any()),
    /** Shared neighbourhood guide used by the group's Near You setup. */
    whereToStay: v.optional(v.any()),
    /**
     * What happened to each component, alongside the payloads above. Absent on
     * groups generated before per-component state existed; `dto.ts` derives
     * those from whether the payload is there.
     */
    componentStates: v.optional(groupComponentStates),
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
    /**
     * Know Before You Go travels with a share: it is destination-wide content
     * about the trip, not part of the sender's personal layer (§4). Absent on
     * trips published before it existed, and on any trip whose KBYG call failed.
     */
    knowBeforeYouGo: v.optional(v.any()),
    /** `Trip.Favorites` — shown read-only-but-editable on the recipient's local copy. */
    favorites: v.optional(v.any()),
    /** Interest deep dives generated before this solo trip was published. */
    deepDives: v.optional(v.any()),
    /**
     * Worth-it/Skip cards. CONTENT ONLY — `worthItDecisions` is deliberately
     * not a column here and never will be. Whether the sender skipped Park
     * Güell is their business, and a recipient who receives it pre-decided has
     * been handed a verdict instead of a question (§4).
     */
    worthItItems: v.optional(v.any()),
    /** The where-to-stay guide (D10). */
    whereToStay: v.optional(v.any()),
    /** Model-picked interest chip labels (D8). */
    interestPrompts: v.optional(v.any()),
    /** The destination photo the app already resolved while generating. */
    imageUrl: v.optional(v.string()),
    /** OG-card-sized (1200x630) photo, cached by the /t endpoint. */
    shareImageUrl: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_code", ["code"]),

  /**
   * One row per app install, keyed by the SHA-256 hash of an install token the
   * device mints on first launch and keeps in its Keychain (same discipline as
   * the group capability tokens — the raw value never lands here).
   *
   * This is IDENTITY FOR RATE LIMITING, not authorization. A determined caller
   * can mint fresh install tokens, which is exactly why `globalBudget` exists
   * underneath it. Nothing here grants access to anyone else's data.
   */
  installs: defineTable({
    installHash: v.string(),
    createdAt: v.number(),
    /** Start of the current rolling 24h counting window. */
    windowStart: v.number(),
    /**
     * Model calls ATTEMPTED in the current window. Attempts, not commits: a
     * failing call still costs money and still needs throttling. The per-trip
     * caps below deliberately count the other way.
     */
    windowCount: v.number(),
    totalCount: v.number(),
  }).index("by_hash", ["installHash"]),

  /**
   * One row per generation of a component that carries a per-trip cap (today
   * only `deepDive`, capped at 3 — D9). Uncapped components are throttled by
   * the install window alone and write nothing here.
   *
   * A row is inserted as `reserved` before the model call and promoted to
   * `committed` after it succeeds; a failed call deletes its row, so failures
   * never consume the cap. Stale `reserved` rows (an action that died mid-call)
   * age out of the count — see RESERVATION_TTL_MS.
   */
  generationSlots: defineTable({
    installHash: v.string(),
    /** Opaque, client-minted, stable-per-trip key. Never a user identifier. */
    tripKey: v.string(),
    component: generationComponent,
    /** Normalised interest label, for rejecting the same deep dive twice. */
    label: v.optional(v.string()),
    status: v.union(v.literal("reserved"), v.literal("committed")),
    createdAt: v.number(),
  }).index("by_trip_component", ["installHash", "tripKey", "component"]),

  /**
   * Single-row rolling backstop on total model calls per day across all
   * installs. Install tokens are self-minted, so this is the only limit an
   * abusive caller cannot walk around by re-installing. It protects the API
   * key's bill; it is not a fairness mechanism.
   */
  globalBudget: defineTable({
    windowStart: v.number(),
    windowCount: v.number(),
  }),

  /**
   * Per-call telemetry from the Responses adapter. This table is the ONLY
   * admissible source for a cost or latency claim about generation — §6 of the
   * plan withdraws every estimate made before it existed. No prompt text, no
   * trip content, no install hash: counts, codes and durations only.
   */
  generationTelemetry: defineTable({
    component: generationComponent,
    mode: tripMode,
    inputTokens: v.number(),
    cachedInputTokens: v.number(),
    outputTokens: v.number(),
    durationMs: v.number(),
    /** Absent on success; a stable `OpenAIError` code otherwise. */
    errorCode: v.optional(v.string()),
    /**
     * Which arm of the D15 experiment produced this row. Optional because rows
     * written before the experiment existed have no answer — and inventing one
     * for them would corrupt the very comparison this column exists to make.
     */
    variant: v.optional(suggestionsVariant),
    /**
     * The ceiling this call ran under. Recorded next to `outputTokens` because
     * neither number means anything alone: "3,900 tokens" is comfortable under
     * 8,192 and a truncation waiting to happen under 4,096.
     */
    maxOutputTokens: v.optional(v.number()),
    /**
     * Post-decode repairs applied (§3). A rising repair rate is how a prompt
     * that has quietly stopped obeying its own counts becomes visible.
     */
    repairs: v.optional(v.number()),
    createdAt: v.number(),
  }).index("by_component", ["component", "createdAt"]),
});
