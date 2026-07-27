import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";

/**
 * Public-safe metadata for an invite link's rich preview (Open Graph card).
 * Exposes only the group name + destination + status — never tokens, members,
 * or preferences. Used by the /join HTTP endpoint (see http.ts).
 */
export const shareMeta = internalQuery({
  args: { code: v.string() },
  handler: async (ctx, args) => {
    const group = await ctx.db
      .query("groups")
      .withIndex("by_code", (q) => q.eq("code", args.code))
      .unique();
    if (!group) return null;
    return {
      groupId: group._id,
      name: group.name,
      destination: group.destination,
      status: group.status,
      shareImageUrl: group.shareImageUrl ?? null,
    };
  },
});

/** Caches the resolved destination photo so repeat preview fetches skip Unsplash. */
export const setShareImage = internalMutation({
  args: { groupId: v.id("groups"), url: v.string() },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group || group.shareImageUrl) return;
    await ctx.db.patch(args.groupId, { shareImageUrl: args.url });
  },
});

/**
 * Public-safe metadata for a shared trip's rich preview (Open Graph card).
 * Used by the /t HTTP endpoint (see http.ts). Never exposes `ownerTokenHash`.
 */
export const sharedTripMeta = internalQuery({
  args: { code: v.string() },
  handler: async (ctx, args) => {
    const doc = await ctx.db
      .query("sharedTrips")
      .withIndex("by_code", (q) => q.eq("code", args.code))
      .unique();
    if (!doc) return null;
    return {
      tripId: doc._id,
      title: doc.title,
      destination: doc.destination,
      startMonth: doc.startMonth,
      durationDays: doc.durationDays,
      imageUrl: doc.imageUrl ?? null,
      shareImageUrl: doc.shareImageUrl ?? null,
    };
  },
});

/** Caches the resolved OG-card photo for a shared trip. */
export const setSharedTripImage = internalMutation({
  args: { tripId: v.id("sharedTrips"), url: v.string() },
  handler: async (ctx, args) => {
    const doc = await ctx.db.get(args.tripId);
    if (!doc || doc.shareImageUrl) return;
    await ctx.db.patch(args.tripId, { shareImageUrl: args.url });
  },
});
