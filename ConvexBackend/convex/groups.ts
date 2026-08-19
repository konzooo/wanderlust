import { ConvexError, v } from "convex/values";
import { mutation, query, QueryCtx } from "./_generated/server";
import { Doc, Id } from "./_generated/dataModel";
import { randomInviteCode } from "./lib/codes";
import { hashToken, newToken, tokenMatchesHash } from "./lib/tokens";
import { toGroupDTO } from "./lib/dto";
import {
  memberPreferences,
  QUESTIONNAIRE_VERSIONS,
  TRAVELLER_DNA_VERSIONS,
} from "./lib/validators";
import { startGeneration } from "./generate";

/** Loads a group's roster, ordered oldest-first so the admin sits at the top. */
async function loadMembers(ctx: QueryCtx, groupId: Id<"groups">): Promise<Doc<"members">[]> {
  return ctx.db
    .query("members")
    .withIndex("by_group", (q) => q.eq("groupId", groupId))
    .collect();
}

/** Finds the member in `members` whose slot the presented token unlocks, if any. */
async function viewerMember(
  members: Doc<"members">[],
  memberToken: string,
): Promise<Doc<"members"> | null> {
  for (const m of members) {
    if (await tokenMatchesHash(memberToken, m.memberTokenHash)) return m;
  }
  return null;
}

/**
 * Creates a group and its admin roster slot in one step. The admin enters
 * their own name here so they appear in the dashboard like any other member
 * (Completed/Pending), rather than being an invisible creator.
 *
 * Returns the raw `adminToken` (for admin-only ops: seeding/removing members,
 * forcing generation) and the admin's own `memberToken` (for `submitPreferences`,
 * same as any other member). Neither is ever persisted in plaintext — only
 * their hashes are stored, and they are returned to the caller exactly once.
 */
export const createGroup = mutation({
  args: {
    name: v.string(),
    destination: v.string(),
    durationDays: v.number(),
    startMonth: v.string(),
  },
  handler: async (ctx, args) => {
    let code = randomInviteCode();
    for (let attempt = 0; attempt < 5; attempt++) {
      const existing = await ctx.db
        .query("groups")
        .withIndex("by_code", (q) => q.eq("code", code))
        .first();
      if (!existing) break;
      code = randomInviteCode();
    }

    const adminToken = newToken();
    const createdAt = Date.now();
    const groupId = await ctx.db.insert("groups", {
      code,
      name: args.name,
      destination: args.destination,
      durationDays: args.durationDays,
      startMonth: args.startMonth,
      adminTokenHash: await hashToken(adminToken),
      status: "collecting",
      generationVersion: 0,
      attemptCount: 0,
      createdAt,
    });

    // The admin's own roster slot is created on the members screen (addAdminSelf)
    // where they enter their name alongside the people they invite.
    return {
      groupId,
      code,
      adminToken,
      startMonth: args.startMonth,
      durationDays: args.durationDays,
      createdAt,
    };
  },
});

/**
 * The admin adds their own name — the first thing they do on the members
 * screen. Creates their claimed roster slot (role "admin") and mints the member
 * token they'll use to submit their own preferences.
 */
export const addAdminSelf = mutation({
  args: {
    groupId: v.id("groups"),
    adminToken: v.string(),
    name: v.string(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) {
      throw new ConvexError("Group not found");
    }
    if (!(await tokenMatchesHash(args.adminToken, group.adminTokenHash))) {
      throw new ConvexError("Not authorized");
    }
    if (group.status !== "collecting") {
      throw new ConvexError("Group is closed");
    }
    const members = await loadMembers(ctx, args.groupId);
    if (members.some((m) => m.role === "admin")) {
      throw new ConvexError("Organizer already added");
    }

    const memberToken = newToken();
    const memberId = await ctx.db.insert("members", {
      groupId: args.groupId,
      name: args.name,
      role: "admin",
      memberTokenHash: await hashToken(memberToken),
      status: "pending",
    });

    return { memberId, memberToken };
  },
});

/**
 * Admin seeds a placeholder roster slot for a friend who hasn't joined yet.
 * The slot stays unclaimed (no `memberTokenHash`) until someone claims it via
 * the join flow (`claimSlot`, added in M5).
 */
export const seedMember = mutation({
  args: {
    groupId: v.id("groups"),
    adminToken: v.string(),
    name: v.string(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) {
      throw new ConvexError("Group not found");
    }
    if (!(await tokenMatchesHash(args.adminToken, group.adminTokenHash))) {
      throw new ConvexError("Not authorized");
    }
    if (group.status !== "collecting") {
      throw new ConvexError("Group is closed");
    }

    const memberId = await ctx.db.insert("members", {
      groupId: args.groupId,
      name: args.name,
      role: "member",
      status: "pending",
    });

    return { memberId };
  },
});

/**
 * Reactive dashboard read. Requires a member capability token that unlocks a
 * slot in this group; anyone else gets nothing. Returns a safe DTO only.
 */
export const getGroup = query({
  args: {
    groupId: v.id("groups"),
    memberToken: v.string(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) {
      throw new ConvexError("Group not found");
    }
    const members = await loadMembers(ctx, args.groupId);
    const viewer = await viewerMember(members, args.memberToken);
    if (!viewer) {
      throw new ConvexError("Not authorized");
    }
    return toGroupDTO(group, members, viewer._id);
  },
});

/**
 * Resolves an invite code to a group's join screen. Intentionally open (no
 * token) because a code alone only reveals names + claim availability — never
 * preferences, tokens, or generated output.
 */
export const joinResolve = query({
  args: { code: v.string() },
  handler: async (ctx, args) => {
    const group = await ctx.db
      .query("groups")
      .withIndex("by_code", (q) => q.eq("code", args.code))
      .unique();
    if (!group) {
      return null;
    }
    const members = await loadMembers(ctx, group._id);
    return {
      groupId: group._id,
      code: group.code,
      name: group.name,
      destination: group.destination,
      startMonth: group.startMonth,
      durationDays: group.durationDays,
      createdAt: group.createdAt,
      status: group.status,
      members: members.map((m) => ({
        memberId: m._id,
        name: m.name,
        status: m.status,
        claimed: m.memberTokenHash !== undefined,
      })),
    };
  },
});

/**
 * Late joining is allowed through `claimSlot` only — deliberately **not**
 * through `addSelf`. The asymmetry is a security boundary, not an oversight.
 *
 * The friend who answers late is still going on the trip, and blocking them
 * used to lock them out of the result entirely: `getGroup` needs a member token
 * and only these two mutations mint one, so "you replied too slowly" meant "you
 * can never see the itinerary". That is worth fixing.
 *
 * But it may not be fixed by letting a *code* mint a token after generation.
 * An invite code is five digits — 100k combinations, enumerable in minutes —
 * and `randomInviteCode` is only safe at that length because the code alone
 * opens the join screen and never unlocks trip content (see `lib/codes.ts`,
 * which contrasts it with the 122-bit share code that *is* a read capability).
 * An open `addSelf` would have turned every invite code into exactly such a
 * capability, permanently.
 *
 * `claimSlot` does not, because it cannot invent membership: it can only take a
 * slot the admin typed a real person's name into, it works once, and taking one
 * is visible in the roster. So the late friend gets in, and a guessed code
 * still buys nothing on a group whose slots are all claimed.
 *
 * A late joiner cannot *change* the trip either — `submitPreferences` keeps its
 * `collecting`-only guard, so they land as `skipped`, the status generation
 * already gives members who did not answer in time.
 */

/**
 * Joiner claims one of the admin's pre-seeded (unclaimed) slots. Atomic: Convex
 * serializes the transaction, so of two concurrent claims exactly one wins and
 * the other sees the slot already claimed.
 */
export const claimSlot = mutation({
  args: {
    groupId: v.id("groups"),
    memberId: v.id("members"),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) {
      throw new ConvexError("Group not found");
    }
    const member = await ctx.db.get(args.memberId);
    if (!member || member.groupId !== args.groupId) {
      throw new ConvexError("Member not found");
    }
    if (member.memberTokenHash !== undefined) {
      throw new ConvexError("That name is already taken");
    }

    const memberToken = newToken();
    await ctx.db.patch(args.memberId, {
      memberTokenHash: await hashToken(memberToken),
      // A slot still marked `pending` after collecting closed can no longer be
      // filled in, so it becomes `skipped` on claim. One already marked
      // `skipped` by generation is left exactly as it is.
      ...(member.status === "pending" && group.status !== "collecting"
        ? { status: "skipped" as const }
        : {}),
    });

    return { memberId: args.memberId, memberToken };
  },
});

/**
 * Joiner adds themselves as a brand-new, already-claimed slot.
 *
 * Stays `collecting`-only. This is the mutation that could mint a membership —
 * and therefore a read token — out of nothing but a five-digit code, so it must
 * close when collecting closes. Late arrivals come in through `claimSlot`.
 */
export const addSelf = mutation({
  args: {
    groupId: v.id("groups"),
    name: v.string(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) {
      throw new ConvexError("Group not found");
    }
    if (group.status !== "collecting") {
      throw new ConvexError("Group is closed");
    }

    const memberToken = newToken();
    const memberId = await ctx.db.insert("members", {
      groupId: args.groupId,
      name: args.name,
      role: "member",
      memberTokenHash: await hashToken(memberToken),
      status: "pending",
    });

    return { memberId, memberToken };
  },
});

/** Admin removes a still-pending slot (e.g. a friend who never joined). */
export const removeMember = mutation({
  args: {
    groupId: v.id("groups"),
    adminToken: v.string(),
    memberId: v.id("members"),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) {
      throw new ConvexError("Group not found");
    }
    if (!(await tokenMatchesHash(args.adminToken, group.adminTokenHash))) {
      throw new ConvexError("Not authorized");
    }
    const member = await ctx.db.get(args.memberId);
    if (!member || member.groupId !== args.groupId) {
      throw new ConvexError("Member not found");
    }
    if (member.role === "admin") {
      throw new ConvexError("Can't remove the organizer");
    }
    if (member.status === "completed") {
      throw new ConvexError("Can't remove a member who already finished");
    }
    await ctx.db.delete(args.memberId);
    return { removed: true };
  },
});

/**
 * A member submits their completed questionnaire. Validates the answers against
 * the group's questionnaire version (exact question-ID match) so a stale or
 * malformed payload can never mark someone complete. Then runs the generation
 * gate: if everyone is done and there are at least the minimum members, it
 * kicks off generation.
 */
export const submitPreferences = mutation({
  args: {
    groupId: v.id("groups"),
    memberId: v.id("members"),
    memberToken: v.string(),
    preferences: memberPreferences,
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) {
      throw new ConvexError("Group not found");
    }
    if (group.status !== "collecting") {
      throw new ConvexError("Group is closed");
    }
    const member = await ctx.db.get(args.memberId);
    if (!member || member.groupId !== args.groupId) {
      throw new ConvexError("Member not found");
    }
    if (!(await tokenMatchesHash(args.memberToken, member.memberTokenHash))) {
      throw new ConvexError("Not authorized");
    }

    const expected = QUESTIONNAIRE_VERSIONS[args.preferences.questionnaireVersion];
    if (!expected) {
      throw new ConvexError("Unsupported questionnaire version");
    }
    const answered = args.preferences.answers.map((a) => a.questionID);
    const answeredSet = new Set(answered);
    if (
      answered.length !== expected.length ||
      answeredSet.size !== expected.length ||
      !expected.every((id) => answeredSet.has(id))
    ) {
      throw new ConvexError("Answers don't match the questionnaire");
    }

    const profile = args.preferences.profile;
    if (profile) {
      const expectedDNA = TRAVELLER_DNA_VERSIONS[profile.questionnaireVersion];
      const dimensions = profile.scaleAnswers.map((answer) => answer.dimension);
      const dimensionSet = new Set(dimensions);
      const hasValidScaleValues = profile.scaleAnswers.every(
        (answer) =>
          Number.isInteger(answer.value) &&
          answer.value >= 1 &&
          answer.value <= 5,
      );
      const hasValidText =
        profile.usuallySkip.length <= 5 &&
        profile.mustHaves.length <= 5 &&
        profile.usuallySkip.every((value) => value.length <= 100) &&
        profile.mustHaves.every((value) => value.length <= 100) &&
        (profile.additionalNotes == null ||
          profile.additionalNotes.length <= 500);
      const hasValidAge =
        profile.age == null ||
        (Number.isInteger(profile.age) && profile.age >= 1 && profile.age <= 120);
      const hasValidPassport =
        profile.passport == null || /^[A-Za-z]{2}$/.test(profile.passport);
      if (
        !expectedDNA ||
        dimensions.length !== expectedDNA.length ||
        dimensionSet.size !== expectedDNA.length ||
        !expectedDNA.every((id) => dimensionSet.has(id as typeof dimensions[number])) ||
        !hasValidScaleValues ||
        !hasValidText ||
        !hasValidAge ||
        !hasValidPassport
      ) {
        throw new ConvexError("Traveller DNA doesn't match the supported profile version");
      }
    }

    await ctx.db.patch(args.memberId, {
      preferences: args.preferences,
      status: "completed",
      completedAt: Date.now(),
    });

    // Generation gate — re-read the freshly patched roster.
    const members = await loadMembers(ctx, args.groupId);
    await startGeneration(ctx, group, members, { force: false });

    return { submitted: true };
  },
});
