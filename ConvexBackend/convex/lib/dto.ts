import { Doc, Id } from "../_generated/dataModel";
import { MIN_MEMBERS_TO_GENERATE } from "./validators";
import { componentsNeedingRetry, currentStates } from "../generate";

/**
 * Client-facing shapes. These are the ONLY things any query returns to a
 * device. They deliberately omit `adminTokenHash`, `memberTokenHash`, and every
 * member's raw `preferences` — a device ID is never stored and secrets never
 * leave the server.
 */

export type MemberDTO = {
  memberId: string;
  name: string;
  role: "admin" | "member";
  status: "pending" | "completed" | "skipped";
  claimed: boolean;
  isYou: boolean;
};

/**
 * What happened to one generated component. A bare `null` payload could not
 * distinguish "never generated" from "failed", so the client had nothing to
 * offer a retry on.
 */
export type ComponentStateDTO =
  | { state: "absent" }
  | { state: "generating" }
  | { state: "failed"; code: string }
  | { state: "ready" };

export type GroupDTO = {
  groupId: string;
  code: string;
  name: string;
  destination: string;
  durationDays: number;
  startMonth: string;
  status: "collecting" | "generating" | "ready" | "error";
  viewerIsAdmin: boolean;
  canAutoGenerate: boolean;
  completedCount: number;
  memberCount: number;
  members: MemberDTO[];
  itinerary: unknown | null;
  suggestions: unknown | null;
  knowBeforeYouGo: unknown | null;
  worthItItems: unknown | null;
  whereToStay: unknown | null;
  interestPrompts: unknown | null;
  /** Per-component state, keyed by component name. */
  componentStates: Record<string, ComponentStateDTO>;
  /** Whether anything is worth retrying — drives the admin's retry affordance. */
  canRetry: boolean;
  imageUrl: string | null;
  errorCode: string | null;
};

export function toMemberDTO(
  m: Doc<"members">,
  viewerMemberId: Id<"members"> | null,
): MemberDTO {
  return {
    memberId: m._id,
    name: m.name,
    role: m.role,
    status: m.status,
    claimed: m.memberTokenHash !== undefined,
    isYou: viewerMemberId !== null && viewerMemberId === m._id,
  };
}

export type SharedTripDTO = {
  code: string;
  title: string;
  destination: string;
  durationDays: number;
  startMonth: string;
  groupType: string;
  itinerary: unknown;
  suggestions: unknown | null;
  knowBeforeYouGo: unknown | null;
  favorites: unknown | null;
  deepDives: unknown | null;
  /** Content only — see the `sharedTrips` schema on why decisions are absent. */
  worthItItems: unknown | null;
  whereToStay: unknown | null;
  interestPrompts: unknown | null;
  imageUrl: string | null;
};

/** Never includes `ownerTokenHash` — the code alone is the read capability. */
export function toSharedTripDTO(doc: Doc<"sharedTrips">): SharedTripDTO {
  return {
    code: doc.code,
    title: doc.title,
    destination: doc.destination,
    durationDays: doc.durationDays,
    startMonth: doc.startMonth,
    groupType: doc.groupType,
    itinerary: doc.itinerary,
    suggestions: doc.suggestions ?? null,
    knowBeforeYouGo: doc.knowBeforeYouGo ?? null,
    favorites: doc.favorites ?? null,
    deepDives: doc.deepDives ?? null,
    worthItItems: doc.worthItItems ?? null,
    whereToStay: doc.whereToStay ?? null,
    interestPrompts: doc.interestPrompts ?? null,
    imageUrl: doc.imageUrl ?? null,
  };
}

export function toGroupDTO(
  group: Doc<"groups">,
  members: Doc<"members">[],
  viewerMemberId: Id<"members"> | null,
): GroupDTO {
  const completedCount = members.filter((m) => m.status === "completed").length;
  const allDone = members.every(
    (m) => m.status === "completed" || m.status === "skipped",
  );
  const viewer = viewerMemberId
    ? members.find((m) => m._id === viewerMemberId)
    : undefined;

  return {
    groupId: group._id,
    code: group.code,
    name: group.name,
    destination: group.destination,
    durationDays: group.durationDays,
    startMonth: group.startMonth,
    status: group.status,
    viewerIsAdmin: viewer?.role === "admin",
    canAutoGenerate:
      group.status === "collecting" &&
      allDone &&
      members.length >= MIN_MEMBERS_TO_GENERATE,
    completedCount,
    memberCount: members.length,
    members: members.map((m) => toMemberDTO(m, viewerMemberId)),
    itinerary: group.itinerary ?? null,
    suggestions: group.suggestions ?? null,
    knowBeforeYouGo: group.knowBeforeYouGo ?? null,
    worthItItems: envelopeField(group.worthIt, "items"),
    whereToStay: envelopeField(group.whereToStay, "areas"),
    interestPrompts: envelopeField(group.suggestions, "interestPrompts"),
    componentStates: currentStates(group),
    canRetry:
      group.status !== "collecting" &&
      group.status !== "generating" &&
      componentsNeedingRetry(group).length > 0,
    imageUrl: group.imageUrl ?? null,
    errorCode: group.errorCode ?? null,
  };
}

/** Focused component calls return an envelope; clients consume its collection. */
function envelopeField(value: unknown, field: string): unknown | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return null;
  return (value as Record<string, unknown>)[field] ?? null;
}
