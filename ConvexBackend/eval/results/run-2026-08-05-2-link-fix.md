# D15 evaluation — 2026-08-05

Model: `gpt-4o-mini` · 8 fixtures · 40 calls

## Per-arm totals (the suggestions lane only — the itinerary is shared)

| arm | calls | ok | out tokens (mean) | in tokens (mean) | cost/trip | wall-clock/trip | truncations | decode fails | repairs |
|---|---|---|---|---|---|---|---|---|---|
| combined | 8 | 8 | 1395 | 2572 | $0.00118 | 19943 ms | 0 | 0 | 0 |
| split | 24 | 24 | 578 | 1707 | $0.00179 | 11944 ms | 0 | 0 | 0 |

*Wall-clock is the slowest call in the arm, because the device runs them in parallel; it excludes the itinerary, which runs alongside both arms identically.*

## Headroom against the ceiling

| arm | component | ceiling | max out | p50 out | headroom at max |
|---|---|---|---|---|---|
| combined | suggestions | 8192 | 1911 | 1579 | 77% |
| split | suggestions | 4608 | 996 | 796 | 78% |
| split | worthIt | 2048 | 525 | 488 | 74% |
| split | whereToStay | 2048 | 528 | 493 | 74% |

## Content quality

| arm | link resolution | with coords | worth-it items (mean) | stay areas (mean) | chips (mean) | unfindable suggestions | repeated sentences | lane violations |
|---|---|---|---|---|---|---|---|---|
| combined | 64% | 8% | 4.0 | 4.4 | 3.0 | 43 | 0 | 0 |
| split | 63% | 13% | 4.0 | 4.8 | 3.0 | 23 | 0 | 0 |

## Personalisation

Overlap of named places between two travellers in the SAME destination. Lower is better: it means the preferences reached the output.

| pair | arm | place overlap |
|---|---|---|
| barcelona-couple-weekend vs barcelona-family-summer | combined | 0% |
| barcelona-couple-weekend vs barcelona-family-summer | split | 13% |

## Induced failure

Truncation probe at 1024 output tokens: **caught cleanly** as `incomplete_max_output_tokens`.
