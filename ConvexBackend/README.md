# Wanderlust — Convex Backend (Group Trips)

Real-time backend for the **Group Trips** feature. Reactive queries power the
live dashboard; a Convex action generates the group itinerary server-side (the
OpenAI key lives here, never on-device).

## Layout

```
ConvexBackend/
  package.json
  convex/
    schema.ts            # groups + members tables (data model)
    lib/
      validators.ts      # shared validators, questionnaire versions, constants
      codes.ts           # 5-digit invite code generation/normalization
      tokens.ts          # capability-token minting + SHA-256 hashing
    # added in M1+:
    #   groups.ts        # createGroup / joinResolve / getGroup / add / claim / remove / submit
    #   generate.ts      # idempotent generation job + ported prompts/schemas
    #   lib/dto.ts       # safe client-facing DTO mappers (never leak deviceId/preferences)
```

## First-time setup (do this to unblock M1)

From `ConvexBackend/`:

```bash
npm install
npx convex dev          # prompts a login, creates a dev deployment, watches convex/
```

`convex dev` prints your **deployment URL** (e.g. `https://<name>.convex.cloud`) and
writes `convex/_generated/`. Note that URL — the iOS app needs it to connect.

Set the OpenAI key as a server-side env var (used by the generation action in M6):

```bash
npx convex env set OPENAI_API_KEY sk-...
```

## Design invariants (enforced as the functions land)

- **Authorization = capability tokens, not device IDs.** Raw tokens live in each
  device's Keychain; only SHA-256 hashes are stored here. Device IDs are never
  stored or returned. Every sensitive op verifies a presented token.
- **Client-facing DTOs only.** Queries never return `adminTokenHash`,
  `memberTokenHash`, or any member's `preferences` — only names + status.
- **Idempotent generation.** A `collecting → generating` status transition plus a
  monotonic `generationVersion` guarantees exactly one generation even under
  concurrent final submissions; a commit writes results only if the version still
  matches.
- **No premature generation.** Auto-generate only when every listed member is
  `completed` AND `memberCount >= MIN_MEMBERS_TO_GENERATE` (2). The admin can
  always force generation, which closes the group.
- **Invite codes** are 5-digit text (leading zeros preserved), collision-checked
  on creation, rate-limited on join, and rejected once the group leaves
  `collecting`.

## What still needs YOU (external prerequisites)

1. **Convex account + `npx convex dev`** (above) — gives the deployment URL.
2. **`OPENAI_API_KEY`** set in the Convex env (above).
3. **A domain** for Universal Links (M7) — to host
   `/.well-known/apple-app-site-association` and the `/join/<code>` fallback page.
   Start early; Apple's CDN can delay AASA availability.
