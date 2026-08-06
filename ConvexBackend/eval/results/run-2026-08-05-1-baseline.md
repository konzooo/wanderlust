# D15 evaluation — 2026-08-05

Model: `gpt-4o-mini` · 8 fixtures · 40 calls

## Per-arm totals (the suggestions lane only — the itinerary is shared)

| arm | calls | ok | out tokens (mean) | in tokens (mean) | cost/trip | wall-clock/trip | truncations | decode fails | repairs |
|---|---|---|---|---|---|---|---|---|---|
| combined | 8 | 8 | 1509 | 2497 | $0.00126 | 20665 ms | 0 | 0 | 0 |
| split | 24 | 24 | 587 | 1632 | $0.00179 | 13338 ms | 0 | 0 | 0 |

*Wall-clock is the slowest call in the arm, because the device runs them in parallel; it excludes the itinerary, which runs alongside both arms identically.*

## Headroom against the ceiling

| arm | component | ceiling | max out | p50 out | headroom at max |
|---|---|---|---|---|---|
| combined | suggestions | 8192 | 1770 | 1518 | 78% |
| split | suggestions | 4608 | 903 | 666 | 80% |
| split | worthIt | 2048 | 547 | 486 | 73% |
| split | whereToStay | 2048 | 854 | 664 | 58% |

## Content quality

| arm | link resolution | with coords | worth-it items (mean) | stay areas (mean) | chips (mean) | unfindable suggestions | repeated sentences | lane violations |
|---|---|---|---|---|---|---|---|---|
| combined | 41% | 5% | 4.0 | 4.1 | 3.0 | 24 | 0 | 0 |
| split | 30% | 9% | 4.0 | 4.9 | 3.0 | 25 | 0 | 0 |

## Personalisation

Overlap of named places between two travellers in the SAME destination. Lower is better: it means the preferences reached the output.

| pair | arm | place overlap |
|---|---|---|
| barcelona-couple-weekend vs barcelona-family-summer | combined | 20% |
| barcelona-couple-weekend vs barcelona-family-summer | split | 9% |

## Induced failure

Truncation probe at 1024 output tokens: **caught cleanly** as `incomplete_max_output_tokens`.
