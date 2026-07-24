/**
 * Capability tokens — the app's only authorization mechanism in v1.
 *
 * Flow: a token is minted server-side and returned to the creating/claiming
 * device exactly once (it stores the raw value in its Keychain). Only the
 * SHA-256 hash is persisted. Every sensitive operation re-hashes the presented
 * token and compares against the stored hash, so a DB read never leaks a usable
 * credential and a device ID is never trusted as access control.
 */

/** Unguessable capability token (2× UUID ≈ 244 bits). `crypto.randomUUID` is Convex-safe. */
export function newToken(): string {
  return `${crypto.randomUUID()}${crypto.randomUUID()}`.replace(/-/g, "");
}

/** SHA-256 hex digest. Deterministic, so safe inside queries and mutations. */
export async function hashToken(token: string): Promise<string> {
  const bytes = new TextEncoder().encode(token);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Constant-ish comparison helper for a presented token against a stored hash. */
export async function tokenMatchesHash(
  token: string | undefined,
  hash: string | undefined,
): Promise<boolean> {
  if (!token || !hash) return false;
  return (await hashToken(token)) === hash;
}
