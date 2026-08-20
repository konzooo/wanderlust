# Wanderlust project instructions

## Simulator / preview verification

Don't build, launch, or screenshot in the iOS Simulator (or a browser preview) unless the user explicitly asks you to verify, test, or check something visually. For routine code edits (SwiftUI views, backend logic, refactors), just make the change and describe what changed in text — the user will check it themselves when ready.

Exceptions where verification is still expected without being asked:
- The user says "test this," "verify," "show me," or similar.
- You're specifically debugging a crash, layout bug, or runtime error that can't be confirmed by reading code alone.

## Convex deployment handoff

Git commit and push do not deploy the Convex backend. The user's standing
preference is that completed, verified backend implementation work is deployed
to both environments unless they explicitly ask not to:

- From `ConvexBackend/`, run `npm run check` first.
- Deploy Debug/dev with `npx convex dev --once --tail-logs disable`.
- Deploy Release/TestFlight/production with `npx convex deploy`.
- Debug uses `affable-pika-176`; Release uses `clean-bulldog-349`.
- Always report dev and production deployment status explicitly. For a review
  or diagnosis-only request, do not deploy; remind the user if deployment is
  still required for an already-implemented backend change to become visible.
