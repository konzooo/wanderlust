import { ConvexError } from "convex/values";
import { DAY, HOUR, MINUTE, RateLimiter } from "@convex-dev/rate-limiter";
import { components } from "../_generated/api";

/**
 * Application-layer guardrails for public, anonymous entry points.
 *
 * Install-scoped limits prevent accidental loops and ordinary scripted abuse.
 * Global limits remain underneath them because an install token is deliberately
 * self-minted and therefore is not a security credential.
 */
export const RATE_LIMITS = {
  groupCreateInstall: { kind: "fixed window", rate: 10, period: DAY },
  groupCreateGlobal: { kind: "fixed window", rate: 1_000, period: DAY, shards: 10 },

  groupMembership: { kind: "token bucket", rate: 30, period: HOUR, capacity: 30 },
  groupMembershipGlobal: {
    kind: "fixed window",
    rate: 3_000,
    period: HOUR,
    shards: 10,
  },

  sharedPublishInstall: { kind: "fixed window", rate: 20, period: DAY },
  sharedPublishGlobal: {
    kind: "fixed window",
    rate: 2_000,
    period: DAY,
    shards: 10,
  },

  generationBurstInstall: {
    kind: "token bucket",
    rate: 12,
    period: MINUTE,
    capacity: 8,
  },
  generationBurstGlobal: {
    kind: "fixed window",
    rate: 300,
    period: MINUTE,
    shards: 10,
  },
} as const;

export const rateLimiter = new RateLimiter(components.rateLimiter, RATE_LIMITS);

export function requireRateLimit(status: { ok: boolean; retryAfter?: number }) {
  if (!status.ok) {
    // Keep the public error payload stable and content-free. Clients do not
    // need internal bucket names or traffic information to back off.
    throw new ConvexError("rate_limited");
  }
}
