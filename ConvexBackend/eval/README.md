# Generation evaluation (§13)

> One Barcelona generation proves nothing.

This directory is the plan's evaluation matrix, made runnable. It calls the same
`convex/lib/` code the backend calls — same prompts, same schemas, same adapter,
same post-decode validation — because a harness with its own copy of the prompt
only measures the harness.

## Running it

```bash
OPENAI_API_KEY=… npx tsx eval/run.mts          # the full matrix, ~40 model calls
OPENAI_API_KEY=… npx tsx eval/run.mts --dry    # print the plan and the call count
OPENAI_API_KEY=… npx tsx eval/run.mts --only barcelona-couple-weekend
npx tsx eval/rescore.mts                       # re-score the newest saved run, free
npx tsx --test "tests/*.test.mts"              # unit tests for the validation rules
```

The key lives in the Convex deployment, not on disk:

```bash
export OPENAI_API_KEY="$(npx convex env get OPENAI_API_KEY)"
```

A full run is roughly forty `gpt-4o-mini` calls and costs a few cents.

## What's here

| | |
|---|---|
| `fixtures.ts` | The matrix. Eight destination archetypes across solo/couple/family/group, 3–14 days, five months. Two travellers share one destination so personalisation has something to be measured against. |
| `score.ts` | Everything mechanical: link resolution, cross-component sentence repetition, section completeness, lane violations, place overlap, cost. |
| `run.mts` | Runs both D15 arms, writes `results/*.json` (raw) and `results/*.md` (summary). |
| `rescore.mts` | Re-scores a saved run without calling the model. |
| `results/` | Kept runs. |

## Why the raw responses are committed

Two reasons, both learned the hard way in the first run.

**A change to the scoring has to be applicable to runs that already happened.**
The first pass scored each rendered string separately, which counted a
well-written Worth-it card — one whose body says "this masterpiece" rather than
repeating the name four times — as three link failures. Fixing the metric and
re-running would have spent money to answer an arithmetic question. Re-scoring
the saved JSON answered it for free, and produced the honest before/after that
`docs/d15-decision.md` is built on.

**Factuality is not mechanically scorable.** Nothing offline knows whether a
restaurant exists. The responses are here to be read.

Only runs a decision actually cites belong in git — `-1-baseline` is the run
that exposed the link-resolution defect, `-2-link-fix` is the run that proved
the fix. Ad-hoc runs are local.

## What this does not cover

The Swift-side failure cases §13 lists — old saved-trip decoding, partial
failure and retry, ambiguous addresses, Near You in a sparse area — are unit
tests in `WanderlustTests`, not model calls. Near You's own grounding is S10 and
has nothing here yet.
