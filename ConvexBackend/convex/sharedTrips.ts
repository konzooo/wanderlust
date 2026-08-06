import { ConvexError, v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { randomShareCode } from "./lib/codes";
import { hashToken, newToken } from "./lib/tokens";
import { toSharedTripDTO } from "./lib/dto";

const MAX_TITLE_LENGTH = 200;
const MAX_DESTINATION_LENGTH = 160;

/**
 * Publishes a generated solo trip. Nothing is published until the user taps
 * Share (see `TripOutputStore.shareTrip`) — this is the ONLY way a solo trip's
 * data reaches the server. Public reads use the returned `code`; there is no
 * write/update/revoke mutation in v1.
 */
export const publishTrip = mutation({
  args: {
    title: v.string(),
    destination: v.string(),
    durationDays: v.number(), // Swift MUST send Double — int64 wire format ≠ v.number()
    startMonth: v.string(),
    groupType: v.string(),
    itinerary: v.any(),
    suggestions: v.optional(v.any()),
    knowBeforeYouGo: v.optional(v.any()),
    favorites: v.optional(v.any()),
    /** Append-only interest deep dives generated before publication. */
    deepDives: v.optional(v.any()),
    /**
     * Worth-it/Skip **content** travels; the sender's **decisions** never do
     * (§4). The recipient gets the four cards undecided, because deciding is
     * the point of the section — a card that arrives pre-skipped is just a card
     * with a stranger's opinion stamped on it.
     */
    worthItItems: v.optional(v.any()),
    /** The where-to-stay guide. Shared content, no personal layer in it. */
    whereToStay: v.optional(v.any()),
    /** The model-picked interest chips, so a recipient sees the same three. */
    interestPrompts: v.optional(v.any()),
    // The Swift client's ConvexEncodable dictionary sends a `nil` value as
    // JSON `null` (an absent Swift Optional, not an absent key) — so this
    // must accept `null`, not just "key omitted", or a real user sharing a
    // trip before its destination photo finishes loading would get a hard
    // failure here.
    imageUrl: v.optional(v.union(v.string(), v.null())),
  },
  handler: async (ctx, args) => {
    if (args.title.length > MAX_TITLE_LENGTH || args.destination.length > MAX_DESTINATION_LENGTH) {
      throw new ConvexError("Trip metadata too long");
    }

    let code = randomShareCode();
    // 122 bits of entropy makes a real collision astronomically unlikely —
    // this loop is belt-and-braces, mirroring the invite-code collision check.
    for (let attempt = 0; attempt < 3; attempt++) {
      const clash = await ctx.db
        .query("sharedTrips")
        .withIndex("by_code", (q) => q.eq("code", code))
        .first();
      if (!clash) break;
      code = randomShareCode();
    }

    const ownerToken = newToken();
    await ctx.db.insert("sharedTrips", {
      code,
      ownerTokenHash: await hashToken(ownerToken),
      title: args.title,
      destination: args.destination,
      durationDays: args.durationDays,
      startMonth: args.startMonth,
      groupType: args.groupType,
      itinerary: args.itinerary,
      suggestions: args.suggestions,
      knowBeforeYouGo: args.knowBeforeYouGo,
      favorites: args.favorites,
      deepDives: args.deepDives,
      worthItItems: args.worthItItems,
      whereToStay: args.whereToStay,
      interestPrompts: args.interestPrompts,
      imageUrl: args.imageUrl ?? undefined,
      createdAt: Date.now(),
    });

    // ownerToken is minted+hashed for a future revoke feature but not
    // returned here in v1 — nothing client-side stores or uses it yet.
    return { code };
  },
});

/**
 * Public read. `null` = unknown code. No auth needed — the code itself is the
 * read capability, same trust model as a group invite code.
 */
export const getSharedTrip = query({
  args: { code: v.string() },
  handler: async (ctx, args) => {
    const doc = await ctx.db
      .query("sharedTrips")
      .withIndex("by_code", (q) => q.eq("code", args.code))
      .unique();
    return doc ? toSharedTripDTO(doc) : null;
  },
});
