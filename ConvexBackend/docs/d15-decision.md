# D15 — combined or split suggestions call

**Decision: split.** The suggestions call keeps its pre-S5 size; Worth-it/Skip
and the where-to-stay guide run as their own focused calls in parallel. The
three model-picked interest chips ride on the suggestions call under both arms —
three short labels were never worth a call of their own, so that was not one of
the options being weighed.

Recorded 2026-08-05. Both arms are implemented and both still work; the decision
is the value of `SUGGESTIONS_VARIANT` in `convex/lib/components.ts`, mirrored by
`OutputFeatureFlags.suggestionsVariant` in the app.

## How this was measured

`eval/run.mts` against the §13 matrix in `eval/fixtures.ts`: eight destination
archetypes (large European city, small Nordic city, island, multi-island
country, rural/mountain, high transport friction, real natural hazards), across
solo/couple/family/group, budget and high-spend, 3 to 14 days, five months of
the year. Two travellers share one destination so personalisation has something
to be measured against.

It calls the same `convex/lib/` code the backend calls — same prompts, same
schemas, same adapter, same post-decode validation. Raw responses are kept in
`eval/results/` so a change to the *scoring* can be re-applied to runs that
already happened (`eval/rescore.mts`), rather than re-billing to answer an
arithmetic question.

Two full runs, 40 model calls each, `gpt-4o-mini`, kept as
`eval/results/run-2026-08-05-1-baseline.*` and `-2-link-fix.*`. Total spend for
the whole exercise was under ten cents.

## The numbers

Per trip, suggestions lane only. The itinerary is identical under both arms and
runs alongside both, so it is excluded from every figure here.

| | combined | split |
|---|---|---|
| **wall-clock** | 19,943 ms | **11,944 ms** |
| **cost** | **$0.00118** | $0.00179 |
| model calls | 1 | 3 |
| output tokens | 1,395 | 1,734 (578 × 3) |
| input tokens | 2,572 | 5,121 (1,707 × 3) |
| truncations | 0 | 0 |
| decode failures | 0 | 0 |
| validation repairs | 0 | 0 |
| link resolution | 98% | 97% |
| Worth-it cards (target 4) | 4.0 | 4.0 |
| stay areas (target 4–6) | 4.4 | **4.8** |
| interest chips (target 3) | 3.0 | 3.0 |
| suggestions naming no findable place | 43 | **23** |
| sentences repeated across components | 0 | 0 |
| lane violations | 0 | 0 |

Ceiling headroom, from observed maxima across both runs:

| | ceiling | max observed | headroom |
|---|---|---|---|
| combined suggestions | 6,144 | 1,911 | 69% |
| split suggestions | 3,072 | 996 | 68% |
| worthIt | 2,048 | 547 | 73% |
| whereToStay | 2,560 | 854 | 67% |

A deliberate truncation probe at a 1,024-token ceiling was caught cleanly as
`incomplete_max_output_tokens` in both runs — the failure is distinguishable
from a decode error, which is what §4 needs in order to store it as a distinct
component state.

## Why split, given that combined is cheaper

Combined is cheaper, and the reason is structural rather than incidental: split
pays the ~1,300-token system prompt three times. That is real and it will not go
away. It is also **$0.0006 per trip**.

Against that, split buys:

- **Eight seconds off the traveller's wait**, 40% of the suggestions lane. This
  is on the critical path of the screen they are staring at. Combined's single
  large call was the slowest thing in the run on every fixture but one.
- **Measurably better content on the axes we can score.** Suggestions that name
  no findable place at all nearly halved (43 → 23), and the stay guide lands
  closer to its asked-for 4–6 areas. The combined prompt is doing five jobs and
  attends less well to each.
- **Independent failure.** Under combined, one failed call takes out the
  suggestions feed, Worth-it/Skip and where-to-stay together, and the retry
  regenerates all three. `TripOutputStore.setFailure` makes that coupling
  explicit rather than hiding it. Under split each section fails alone, retries
  alone, and costs only itself.
- **Room at the top.** Combined ran to 1,911 output tokens on one call. Nothing
  truncated, but the tail of that distribution is where a truncation loses
  everything at once rather than one section.

**Call count is not the billing unit** — the plan's own words, and the numbers
bear it out in the direction nobody expected: tripling the call count made the
lane 40% faster and six hundredths of a cent more expensive.

### What this does not claim

- **Personalisation was not decisive.** Place overlap between the two Barcelona
  travellers was 20% combined / 9% split in the first run and 0% / 13% in the
  second. Two runs cannot separate those; the metric is in the harness and
  wants more samples before it carries any weight.
- **Factuality was not scored.** No offline check knows whether a restaurant
  exists. The raw responses are in `eval/results/` to be read.
- **These are `gpt-4o-mini` numbers.** A different model moves both the cost
  ratio and the latency ratio, and the decision should be re-run rather than
  assumed. That is what the harness is for.

## What the matrix caught along the way

The point of running it was D15. The most valuable thing it produced was not
D15.

**Place links were silently not rendering.** The app makes a place name tappable
by searching the rendered text for `linkSubstring`. Across the first run only
65–70% of location entries resolved — and in the where-to-stay guide, **16%**.
Two causes:

1. The model wrote the full searchable name into both fields, so the text said
   "Chök" and the substring said "Chök, Barcelona".
2. Worth-it cards and stay areas name their subject in the *title*, which the
   app was rendering as plain text. The one place a card is actually about was
   the one place you could not tap.

Fixed by separating the two fields explicitly in the prompt, rendering both
titles as linkable text, and adding a deterministic comma-prefix repair in
`validation.ts` as a net. Re-run: **97–98% overall, 94% for where-to-stay.** The
repair did not have to fire once — the prompt change did the work — but it stays
for the next time the model changes.

This is exactly what §13 is for, and it would not have been found by generating
Barcelona once and reading it.

## Re-running

```bash
cd ConvexBackend
OPENAI_API_KEY=… npx tsx eval/run.mts            # full matrix, ~40 calls
OPENAI_API_KEY=… npx tsx eval/run.mts --dry      # plan and call count only
npx tsx eval/rescore.mts                         # re-score the newest saved run, free
```
