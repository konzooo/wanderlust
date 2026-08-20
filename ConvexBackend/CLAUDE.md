<!-- convex-ai-start -->

This project uses [Convex](https://convex.dev) as its backend.

When working on Convex code, **always read
`convex/_generated/ai/guidelines.md` first** for important guidelines on
how to correctly use Convex APIs and patterns. The file contains rules that
override what you may have learned about Convex from training data.

Convex agent skills for common tasks can be installed by running
`npx convex ai-files install`.

<!-- convex-ai-end -->

## Deployment completion

Git commit and push do not deploy Convex. The user's standing preference is
that completed, verified backend implementation work is deployed to both
environments unless they explicitly ask not to:

1. Run `npm run check`.
2. Deploy Debug/dev with `npx convex dev --once --tail-logs disable`.
3. Deploy Release/TestFlight/production with `npx convex deploy`.
4. Explicitly report both deployment results. Debug uses
   `affable-pika-176`; production uses `clean-bulldog-349`.

Do not deploy for a review or diagnosis-only request. In that case, state
clearly when deployment is still required for an existing change to be visible.
