/**
 * 5-digit numeric invite code, kept as a string to preserve leading zeros
 * ("00421"). 100k combinations — friendly to type and plenty for the expected
 * scale. It is safe to keep short because the code alone only opens the join
 * screen; anything sensitive requires a capability token.
 *
 * Uses `crypto.getRandomValues` (Convex disallows `Math.random()` in
 * mutations). Collision-safety (retry on an already-active code) and join-attempt
 * rate limiting live in the mutations that use this.
 */
export function randomInviteCode(): string {
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  return (buf[0] % 100_000).toString().padStart(5, "0");
}

/** Normalize user-typed codes: strip whitespace, keep digits, pad to 5. */
export function normalizeInviteCode(input: string): string {
  return input.replace(/\D/g, "").slice(0, 5).padStart(5, "0");
}

/**
 * Unguessable share code for a published trip. Unlike an invite code, nobody
 * types this — it IS the read capability for the whole trip, so 5 digits
 * (enumerable in minutes) would not be safe here. 32 hex chars, ~122 bits.
 */
export function randomShareCode(): string {
  return crypto.randomUUID().replace(/-/g, "");
}
