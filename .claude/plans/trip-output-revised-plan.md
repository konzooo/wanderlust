# Wanderlust Trip Output — revised plan

## Context

The output section today has three tabs — Itinerary, Suggestions, Favourites — fed by two OpenAI calls from one trip-summary string. The itinerary was the MVP; the product was always **inspiration**: what a well-informed local friend would tell you.

This plan restructures the output and adds new content, but the review passes found the current implementation cannot safely carry more calls. So the order is: **fix the call boundary, the persistence contract and the generation lifecycle first; add features after.**

Two decisions arrived from separate review and are treated as settled here: **model calls move behind the backend**, and **sharing will be redesigned**. Neither is re-argued below.

**Companion document:** `wanderlust-output-features-and-prompts.md` (session scratchpad) holds feature rationale and prompt drafts. It is now **partly superseded** — its KBYG sections, its cost arithmetic, its "lazy vs eager" language and its Swift-side prompt structure are all overridden by this plan. Use it for voice and prompt *style*, not for architecture.

---

# 1. Canonical decisions

One table. Where this disagrees with any earlier document or the companion doc, **this wins.**

| # | Decision | Status |
|---|---|---|
| D1 | Model calls move behind Convex; no key in the app | Approved |
| D2 | One backend source of truth for prompts and schemas; iOS owns typed contracts only | Approved |
| D3 | Tabs become **Discover · Near You**, with **Know Before You Go as a placeholder tab** | Approved |
| D4 | Discover holds sticky pill chips: *Suggestions for you · Worth it or skip · Sample itinerary* | Approved |
| D5 | Favourites leaves the tab bar → header pill + full-screen sheet, titled **"Your Favourites in {destination}"** | Approved |
| D6 | Itinerary reused untouched (`ItineraryCard`), relabelled "Sample itinerary" | Approved |
| D7 | Worth-it/Skip: **4 items**, own segment, no counter/progress bar, `Skip it` / `♡ Add to favourites`, Undo | Approved |
| D8 | Interest chips: **3 model-picked + 3 fixed client-side** (`Running routes`, `Remote-work cafés`, `Climbing gyms`) | Approved |
| D9 | Interest deep dives capped at **3 per trip**, enforced server-side | Approved |
| D10 | Where-to-stay guide generated with the trip; powers "Don't have a place booked yet?" | Approved |
| D11 | Near You is **address-grounded via MapKit**, not neighbourhood-string-based | Approved |
| D12 | Near You sections are **adaptive**, not a fixed seven-slot list; a small deterministic practical layer stays separate | Approved |
| D13 | Exact accommodation address stays device-side; never published or shared by default | Approved |
| D14 | KBYG ships as **v1** in this build — same taxonomy as designed, explicitly provisional, revisited after real usage + deeper research | Approved (provisional) |
| D15 | Whether Worth-it/Skip + chips + where-to-stay stay in the suggestions call or split out | **Measure (Session 6)** |
| D16 | Whether parallel generation actually reduces wall-clock | **Measure (Session 2)** |
| D17 | `alreadyRecommended` is **derived at call time**, never persisted as the source of truth | Approved |

**Contradictions from earlier drafts, now resolved:** deep-dive cap is **3** (not 4). Fixed chips include **Climbing gyms**, not Live music. Favourites title is **"Your Favourites in {destination}"**. KBYG ships as v1 with **eager generation by default** (third parallel call, same as everything else) — revisit only if measured latency (D16) argues for lazy-on-open. "What to skip" stays out of any KBYG list. Group generation **is currently sequential** and the plan no longer describes it as parallel. Nothing that adds output tokens is described as "free".

---

# 2. Verified defects in the current code

Each confirmed by reading the source. These are the reason for the build order.

| # | Defect | Evidence |
|---|---|---|
| V1 | API key ships in the app; `oa.enc` + `InstallerSecret.reveal()` both in the binary | `OAInstallerDecrypter.swift:15` |
| V2 | **Schema contradiction causing fabrication pressure.** Swift declares `latitude/longitude` as `["string","null"]`; Convex declares them as plain `string` while listing them in `required`, under `strict: true`. Both prompts instruct the model to emit `null` when unknown. | `TripPlanningService.swift:241`, `generate.ts:441`, `generate.ts:317` |
| V3 | No single-flight. `.onAppear` guards on `!isLoaded`, and `.loading` is not loaded → duplicate paid calls on re-appear | `TripOutputStore.swift:89-94`, `:304`, `:344` |
| V4 | No task handles, no cancellation, no attempt ID → a stale response can overwrite a newer retry | `TripOutputStore.swift:309`, `:349` |
| V5 | Retry re-runs only the itinerary | `TripOutputStore.swift:99-102` |
| V6 | Save writes `suggestionsResponse.data ?? .init()` — an **empty Suggestions persisted as if real**, indistinguishable from a genuine empty result | `TripOutputStore.swift:457` |
| V7 | Share publishes with only an itinerary guard; suggestions may be `nil` | `TripOutputStore.swift:572`, `:586` |
| V8 | Whole screen blocks on `itineraryResponse.isLoading`; no per-component recovery UI | `TripOutputScreen.swift:29` |
| V9 | Group generation is **sequential** (`await` itinerary, then suggestions), single commit at the end | `generate.ts:188-211` |
| V10 | Favourites drop `locations`, so place links never render in the favourites list | `Favorites.swift:57`, `TripOutputStore.swift:285` |
| V11 | `Favorites.liked` is a `Set` but `favouriteTexts` documents "in the order they were added" — ordering is not preserved | `Favorites.swift:86-89` |
| V12 | Dead duplicate `LocationLinkBuilder` in the app target, missing `searchURL` and the encoding fix | `Wanderlust/Screens/Output/Tools/LocationLinkBuilder.swift` |
| V13 | Suggestions call capped at `maxOutputTokens: 4_096` — the proposed additions push against this | `TripPlanningService.swift:50` |

**V9 is worth keeping, not discarding.** The existing server behaviour already encodes a useful policy: itinerary failure aborts the generation; suggestions failure ships `null` and the trip still becomes ready. That required/best-effort split should be **formalised and reused**, not replaced.

---

# 3. Two meanings of "optional"

These are different and must not be conflated.

**Storage optionality** — Swift models. `Trip` is JSON on disk read with `try? decode`; a new non-optional field makes every saved trip silently vanish with no error. New fields are `Optional` + `decodeIfPresent`, following `shareCode` (`Trip.swift:16-22`).

**Schema optionality** — OpenAI strict Structured Outputs. Both clients run `strict: true`. Under strict mode **every object needs `additionalProperties: false` and every declared property must appear in `required`.** There is no `?`. Semantic optionality is expressed as a nullable union.

So `source?`, `bullets[]?`, `locations[]?` are **not implementable as written**. Real form:

```jsonc
{
  "type": "object",
  "additionalProperties": false,
  "required": ["place", "theCase", "theCatch", "verdict", "locations"],
  "properties": {
    "place":    { "type": "string" },
    "theCase":  { "type": "string" },
    "theCatch": { "type": "string" },
    "verdict":  { "type": "string" },
    "locations": { "type": "array", "items": { "$ref": "#/$defs/location" } }
  }
}
```

Arrays that may be empty are **required with `[]`**, never absent. Values that may be absent are `{"type": ["string","null"]}`. Conditional rules ("`source` is required when `volatility == "verify"`") cannot be expressed in strict JSON Schema at all and must be **validated in application code after decode**, with a defined fallback.

**Canonical location definition** — fixes V2, must be identical on both platforms:

```jsonc
"location": {
  "type": "object",
  "additionalProperties": false,
  "required": ["linkSubstring", "placeName", "latitude", "longitude", "placeID"],
  "properties": {
    "linkSubstring": { "type": "string" },
    "placeName":     { "type": "string" },
    "latitude":      { "type": ["string", "null"] },
    "longitude":     { "type": ["string", "null"] },
    "placeID":       { "type": ["string", "null"] }
  }
}
```

---

# 4. Persistence model

Trip contexts: **NS** new solo · **SS** saved solo · **G** group · **PS** published/shared (sender) · **RS** received shared (recipient).

| Field | Persisted on | NS | SS | G | PS | RS | Personal or shared | Regen on reopen | Missing on old trips | Editable |
|---|---|---|---|---|---|---|---|---|---|---|
| Itinerary | `Trip` | ✓ | ✓ | server | ✓ | ✓ | shared | no | no | no |
| Suggestions | `Trip` | ✓ | ✓ | server | ✓ | ✓ | shared | no | no | no |
| Know Before You Go (v1) | `Trip` | ✓ | ✓ | server | ✓ | ✓ | shared | no | yes | no |
| Worth-it/Skip **content** | `Trip` | ✓ | ✓ | server | ✓ | ✓ | shared | no | **yes** | no |
| Worth-it/Skip **decisions** | `Trip` | ✓ | ✓ | ✗ | **✗** | ✓ (own) | **personal** | no | yes | yes |
| Interest prompts (chips) | `Trip` | ✓ | ✓ | server | ✗ | ✗ | shared | no | yes (fixed 3 still render) | no |
| Completed deep dives | `Trip` | ✓ | ✓ | ✗ | ✓ | ✓ (read-only) | shared content, personal act | **no** | yes | no |
| Where-to-stay | `Trip` | ✓ | ✓ | server | ✓ | ✓ | shared | no | yes | no |
| Selected accommodation | `Trip`, **coarse only** | ✓ | ✓ | ✗ | **✗** | ✗ | **personal** | no | yes | yes |
| Near You results | `Trip` | ✓ | ✓ | ✗ | **✗** | ✗ | **personal** | **no** | yes | replaceable |
| Favourites | `Trip` | ✓ | ✓ | ✗ (discarded) | ✓ (sender's) | ✓ (own copy) | personal | — | no | yes |
| `alreadyRecommended` | **not persisted** | — | — | — | — | — | derived | computed per call | n/a | n/a |

**Rules this encodes:**

- **A saved trip must never lose a deep dive or a Near You result and then charge again on reopen.** Both are persisted and never regenerated automatically. Regeneration is always an explicit user action.
- **Accommodation and Near You never leave the device in a share.** Where the sender sleeps is not where the recipient sleeps, and it is personal data. D13.
- **Accommodation is stored coarse.** Persist a display label plus a rounded centre (≈3 decimal places, ~100m), *not* the resolved `MKMapItem` and not the street address. Sufficient to re-run Near You; not a record of where someone slept.
- **Worth-it/Skip decisions do not travel in a share.** The recipient gets the four cards undecided — deciding is the point.
- **Group trips get no personal layer.** Near You, deep dives and decisions are absent by design; the tabs/segments hide accordingly.

**Versioning.** `Trip` gains `schemaVersion: Int`. Every generated component persists as an explicit state, so *loading*, *failed*, *absent* and *genuinely empty* stay distinct — this is what fixes V6:

```swift
enum ComponentState<T: Codable & Hashable>: Codable, Hashable {
    case absent            // never requested
    case failed(code: String)
    case ready(T)
}
```

An empty-but-successful result is `.ready(T())` and is not the same value as `.absent`. **Never write a placeholder to stand in for an unfinished call.**

**Save policy (choose one — recommended: merge-on-complete).** Permit save once the baseline (itinerary) is `.ready`; components still generating write as `.absent`; when a later component completes, **automatically re-save and merge into the existing file**. This preserves today's fast-save behaviour without the V6 data loss. The alternative — blocking save until everything is terminal — is simpler but degrades a flow users already have.

---

# 5. Backend boundary

```
today:  app --(bundled sk-…)--> OpenAI
after:  app --(install token)--> Convex --(server env key)--> OpenAI
```

`generate.ts` already holds the server-side half: `callOpenAI` (`:291`), `process.env.OPENAI_API_KEY` (`:297`), `internalAction` + `commit`/`fail`, and a `generationVersion` guard. Extend it; do not write a second OpenAI client.

**Single prompt/schema source.** Prompts and JSON schemas live **only** in the backend. Solo/group differences are expressed as **composed context blocks** (`ROLE / VOICE / INPUT / TASK / STYLE`, with a solo-or-group INPUT block), not as two hand-copied prompt families. This is what actually fixes the Swift↔Convex drift; Swift-side `sharedContext` constants would not. iOS keeps typed request/response contracts and **owns no production prompt text**.

**Orchestration — one design for solo and group.** Replace the sequential `await`-then-`await` with `Promise.allSettled` over the component set, and decide explicitly:

- **Required:** itinerary. If it fails, generation fails (preserves current group behaviour).
- **Best-effort:** everything else. Failure commits `failed(code)` for that component; the trip still becomes ready.
- **Commit:** incrementally per component, each guarded by `generationVersion`, so a stale run can never overwrite a newer one and partial results are visible as they land.
- **Retry:** re-runs only components in `failed`, bumping the version.
- **`GroupDTO`** carries per-component state, not a bare optional, so the client can tell "not generated" from "failed" and offer retry.

**Quota.** Install ID minted on first launch, stored in Keychain (the group capability-token pattern is the model). Server enforces per-install daily generation limits and the **3 deep dives per trip** cap (D9) in the mutation. Failed calls **do not** consume the cap; the cap counts committed results.

**Telemetry on the Responses adapter** — required before any cost claim: input tokens, cached input tokens, output tokens, incomplete-response reason, per-component duration, retry count, schema-decode failures.

**Key rotation sequencing.** The shipped key is compromised, but rotating it breaks every installed app (old clients call OpenAI directly). Order: ship the Convex path → force-upgrade or wait for adoption → rotate → confirm no direct device traffic. Keep an account-level spend cap on the old key until then.

---

# 6. Cost and latency — what we do not yet know

Previous drafts claimed "no extra calls, therefore free" and "near-zero added wait". **Both are withdrawn.**

- **Call count is not the billing unit.** Worth-it/Skip (4 × 3 prose fields), interest prompts, and 4–6 neighbourhood comparisons (each with 3 prose fields) materially increase *output* tokens on the suggestions call — the expensive half. This is a cost increase and a latency increase even though the call count is unchanged.
- **It pushes against `maxOutputTokens: 4_096`** (V13). Risk: truncated responses and strict-schema decode failures. The ceiling must be re-derived from measured output, not raised blindly.
- **Prompt caching is not a given.** It needs a long exact shared prefix. Five different system prompts with five different schemas share little. It helps **repeated deep-dive calls**, which do share a prefix; it does little for five unrelated prompt types.
- **Parallelism is an assumption, not a result** (D16). Parallel calls contend for network, backend resources and provider rate limits, and each tab needs its own loading state regardless.

**All cost and latency figures in this plan are to be produced from the Session 2 telemetry, not estimated.**

---

# 7. Near You — address-grounded

**Target experience:** *"I'm staying at Calle Mallorca 166 for a weekend — given what I like, what around here would I actually care about?"*

A neighbourhood name cannot support "nearest", "on your doorstep" or "seven minutes away". So the address does real work before the model is involved.

```
address or hotel
  → MapKit resolves a real location (MKLocalSearchCompleter → MKMapItem)
  → MapKit retrieves nearby candidates by category
  → walking distance/time computed from map data (MKDirections / MKMapItem)
  → backend receives CANDIDATES + trip preferences (not the address)
  → model selects, orders and explains what matters for this traveller
```

**Responsibility split — enforced, not advisory:**

| MapKit owns | Model owns |
|---|---|
| Whether a venue exists | Which candidates fit this traveller |
| Where it is | Why it fits, in Wanderlust's voice |
| Walking distance and time | How to order and group them |
| The map link | What to warn against |

**The model must never invent distance, walking time, or the existence of a venue.** It receives a candidate list and may only select from it. Distances are rendered from MapKit values, never from model text.

**Privacy.** The exact address stays device-side. The backend receives candidate names, categories and distances — enough to choose, not enough to locate the traveller. Persisted accommodation is coarse (§4).

**Adaptive sections, not fixed slots.** Preferences determine which of these appear and in what order — a family, an active solo traveller and a couple must get materially different output from the same address:

*Your kind of morning · An easy dinner near home · Worth crossing the neighbourhood for · A nearby interest-specific find · Your easiest route into the city · One nearby option that is not worth it*

**A separate deterministic practical layer** — nearest transport, grocery, pharmacy — is rendered straight from MapKit with no model involvement and no editorial voice. It is always correct and always present. Keep it visually distinct from the editorial picks.

**Neighbourhood-level fallback.** "Don't have a place booked yet?" → where-to-stay guide (D10) → "I'm staying here" opens Near You with the neighbourhood centroid as a coarse search centre, **explicitly labelled as neighbourhood-level rather than address-level**. Distances are approximate and the UI must say so.

**Sparse-area behaviour** is a first-class case, not an edge case: rural and island destinations will return few candidates. The design must degrade to "here is what is actually near you, which is not much, and here is the nearest thing that is worth the drive" rather than padding with invented options.

---

# 8. Worth-it/Skip decision state

Favourites is a `Set<UUID>`. It cannot express undecided/kept/skipped. This is **not** zero plumbing.

```swift
enum WorthItDecision: String, Codable, Hashable { case kept, skipped }
// on Trip: var worthItDecisions: [UUID: WorthItDecision]?   // absent == undecided
```

**Invariants:**

| Action | Decision | Favourites |
|---|---|---|
| Add to favourites | `.kept` | insert |
| Undo from `.kept` | removed (undecided) | remove |
| Skip it | `.skipped` | unchanged |
| Undo from `.skipped` | removed (undecided) | unchanged |
| Remove from the **favourites screen** | must clear to undecided | remove |

That last row is the one that breaks if the two stores are updated independently. Route both through a single method on the store; never mutate `favorites` and `worthItDecisions` at separate call sites.

Ordinary suggestion favourites keep working exactly as they do — they have no decision state and need none.

---

# 9. Favourites plumbing

`Trip.allFavouriteCandidatesWithContext` (`Favorites.swift:57`) walks itinerary segments and suggestion categories only. New content types are **not** discovered automatically. Each heartable type must explicitly define:

| Concern | Requirement |
|---|---|
| Candidate lookup | An arm in `allFavouriteCandidates` **and** `allFavouriteCandidatesWithContext` |
| Context label | The group heading in the sheet (e.g. "Worth it or skip", "Near you") |
| Stable IDs | `LocationLinkableText.id` is encoded and must survive a round-trip; ids must not be regenerated on decode |
| Removal | Routed through the store, clearing any decision state (§8) |
| Persistence | Present in all `Trip(...)` rebuild sites |
| Old trips | A `nil` section contributes no candidates and must not crash |

**Heartable:** suggestions, itinerary items, secret tips, deep-dive results, Near You editorial picks, Worth-it/Skip (via `.kept`).
**Not heartable:** the Near You deterministic practical layer, where-to-stay options.

**Ordering (V11).** `Favorites.liked` is a `Set`; `favouriteTexts`'s "in the order they were added" comment is wrong. The full-screen list needs a defined order. Either persist an explicit ordered array, or define a deterministic display order (grouped by context, then by source-document order) — but **choose one and fix the misleading comment.**

**Also fix here:** V10 (carry the whole `LocationLinkableText` so place links render) and V12 (delete the dead `LocationLinkBuilder`).

---

# 10. Deep dives — real append semantics

`Trip.Suggestions.dynamicSuggestions` is a `let`. Appending requires reconstructing the value, and the resulting category must survive save, share and reopen. Define:

- **Storage:** a separate `deepDives: [Trip.Suggestions.Category]?` on `Trip`, **not** silently merged into `dynamicSuggestions` — so they can be counted against the cap, shown with their own provenance, and migrated independently. Rendered inline in the feed as if they were categories.
- **Stable IDs:** category id + per-text ids generated once at decode and persisted (same discipline as `LocationLinkableText`).
- **Duplicates:** the same interest twice is rejected client-side (chip removed) and server-side (normalised label compared against committed dives).
- **Cap:** 3 per trip (D9), enforced in the Convex mutation against committed results.
- **Failures:** do not consume the cap; the chip returns.
- **Retry:** re-request with the same interest label; the version guard prevents a double-commit.
- **Group/shared:** deep dives are not offered in read-only modes. A sender's dives travel in a share as read-only content.
- **Favourites and context:** dives are heartable (§9) and their places join `alreadyRecommended` (§11).

---

# 11. `alreadyRecommended` — derived, never stored

**Do not persist a flattened string.** It goes stale the moment a dive is added, Near You runs, a component is retried, or content is migrated.

Compute it at call time from the currently persisted structured output: flatten `placeName` across itinerary + suggestions + deep dives + Near You picks, plus segment titles. It is cheap and always correct.

If profiling later shows it matters, a cached digest may be added — but only as an explicitly **derived, versioned** value invalidated whenever any source component changes.

---

# 12. Know Before You Go — v1, explicitly provisional

**Product decision:** KBYG ships end-to-end in this build, at the design already worked out — four buckets, six always-present sections, model chooses the rest up to 8–14 total, no web search, volatility-flagged sections carry a source line instead of a badge. The goal of v1 is a complete, testable feature, not a perfect taxonomy.

**What is explicitly NOT claimed:** that this taxonomy is researched or final. Analysis of seven "everything to know before you go" videos suggests the real version of this feature wants a proper product pass — which questions actually matter, how much is universal versus destination-specific, how personal it should be, which facts need live verification. That pass has not happened. **v1 is a placeholder-with-working-content**, not the researched end state, and it should be treated as disposable: expect the taxonomy, and possibly the whole section structure, to be substantially reworked once real usage and that research land (§16, KBYG v2).

**Boundary (unchanged):** destination-wide practical preparation — not another place-recommendation feed. Places may still appear where genuinely contextual (an airport, a metro line, a market as an institution) — the earlier "KBYG names no places" rule was reverted; it names places naturally, the way a friend would, without being a second suggestions feed.

**Structure — four buckets, 8–14 sections total:**

| Bucket | Always-present | Model may add |
|---|---|---|
| Before you leave | Entry & documents · what the month is practically like | Health/vaccinations, insurance, packing specifics, apps |
| Money | How people pay + daily cost | Tipping, tourist taxes, bargaining |
| Getting around | Airport transfer · getting around locally | Intercity travel, driving, traffic norms |
| On the ground | Food & drink basics incl. when people eat | Etiquette, language, safety, SIM/water/electricity, natural hazards |

**"What to skip" stays excluded** from this list — that's Worth-it/Skip's and What-to-Avoid's lane, not KBYG's (§ duplication rules below).

**Volatility, not a badge.** Each section: `{ title, body, bullets[], volatility: stable|verify, sourceLead, source, locations[] }` under the strict-schema rules in §3 (nullable unions, not `?`). `stable` sections read with full confidence, no hedging. `verify` sections (expect ~3 of 12 — entry rules, taxes, prices) get one tinted line naming the authority to check, opened in-app. No global disclaimer. The prompt pushes hard against over-hedging; **check the stable/verify ratio on real output** — this is exactly the kind of thing the evaluation matrix (§13) should catch before it ships broadly.

**Measured in S9** (six §13 cases — large European city, small Nordic city, island, multi-region country, rural/mountain, group — fixtures in `ConvexBackend/tools/fixtures/kbyg/`, harness in `tools/kbyg-eval.ts`): 9–12 sections, all four buckets and all six always-present sections present in every run, **1–2 `verify` sections per briefing (8–18%)**, every one of them sourced, 944–1,522 output tokens, 12–17s. The ratio came in *below* the ~3-in-12 this section guessed, and the first run's real defect was the opposite of over-hedging — entry rules flagged `stable` and hedged inside the prose instead. The prompt now pins entry-and-documents to `verify`. Remaining known v1 characteristics: bullet coverage varies 25–100% between runs, and only 1–2 sections per briefing name a linkable place.

**No web search in v1.** Search pricing runs 20–30× the cost of a normal call to improve ~3 sections of 12; the source-link mechanism gets most of the value for near-zero cost. Revisit only if v1 usage shows the source-link approach isn't good enough.

**Generation:** third parallel call alongside itinerary and suggestions (D14), same lifecycle, retry and persistence treatment as every other component (§4, §10 of the coordinator). Own prompt and schema, server-side only (§5) — no Swift-side prompt text.

**Duplication hygiene, carried over from earlier design work (cheap, keep it):**
- A short "stay out of their lane" block in every prompt naming what the others own.
- The month split: suggestions' `month` category covers **what's on**; KBYG's month section covers **what it's like** (heat, closures, packing). One sentence in each prompt.
- Places recurring between itinerary and suggestions is fine and expected — only repeated *sentences* across components are a bug (checked in the evaluation matrix).

---

# 13. Evaluation plan

One Barcelona generation proves nothing. **No prompt or schema is approved without running the matrix.**

**Destinations:** large European city · small Nordic city (where scams are not a topic) · island · multi-island country · rural/mountain · high transport friction · real natural hazards.
**Travellers:** solo · couple · family · group; budget and high-spend; weekend and multi-week; at least two seasons.
**Failure cases:** old saved-trip decoding · partial failure and retry · missing coordinates · ambiguous address · Near You in a sparse area · truncated output at the token ceiling.

**Scored per run:** factuality · repetition across components · personalisation (would a different traveller get different output?) · named-place accuracy · map resolution success rate · output completeness · schema decode reliability · latency · cost · **lane correctness** (is this content in the right product surface?).

Keep the fixtures in the repo so runs are comparable over time.

---

# 14. Build order and per-session guide

Each row is a unit of dependency-ordered work; they do **not** need to be one chat each. Git commits, not chat boundaries, are what give you clean reviewable/revertable history — you get that either way. The reason to start a fresh chat at all is attention dilution across unrelated subsystems (Convex/TS security work reads very differently from SwiftUI card layouts) and, more importantly, **giving yourself a review checkpoint** before the next phase builds on top of the last one.

**Recommended grouping — 5 chats, not 11, drawn at natural boundaries rather than an arbitrary split:**

| Chat | Sessions | Why grouped |
|---|---|---|
| 1 | S0 + S1 + S2 | Already one dependency lineage — backend boundary, persistence, coordinator. |
| 2 | S3 + S4 | Both UI: shell, then favourites. |
| 3 | S5 + S6 + S7 | One story: the suggestions-call experiment, its evaluation (D15), and the derived context that follows from the decision. Don't split this arc — S6 wants S5's actual experiment fresh, not reloaded from a summary. |
| 4 | S8 + S9 | Both "new content type, mostly additive": deep dives, KBYG v1. |
| 5 | S10 | Complex enough alone (MapKit grounding, address privacy) to deserve a clean session. |

S11 (KBYG v2) is standalone and product-led — whenever the research is done.

Paste this plan file plus the named sessions at the start of each chat.

| S | Work | Model / effort | Depends on | Done when |
|---|---|---|---|---|
| **0** | Backend model-call boundary; prompts + schemas moved server-side as the single source; install-ID identity; server quotas; **fix V2 lat/lng schema drift** | **Opus 5 / extra** | `OPENAI_API_KEY` set in Convex | No `api.openai.com` traffic from device; `oa.enc` absent from the built `.app`; 4th deep dive rejected server-side; group generation still works |
| **1** | Versioned persistence contracts (§3, §4); `ComponentState`; `schemaVersion`; migration tests | **Opus 5 / hard** | S0 | Old saved trips still decode; empty ≠ absent ≠ failed is provable in a test |
| **2** | Generation coordinator: single-flight, task ownership, attempt IDs, per-component retry, required-vs-best-effort, `Promise.allSettled` orchestration for solo **and** group; usage telemetry | **Opus 5 / extra** | S1 | Re-appear during generation produces exactly one call per component; stale retry cannot overwrite; telemetry lands for every component |
| **3** | Output shell: tabs, sticky pill chips, navigation, per-tab loading and error states, KBYG placeholder | **Sonnet 5 / hard** | none (parallel with S0–S2) | All four entry points land correctly; every tab has its own loading + retry |
| **4** | Favourites UI + explicit candidate/decision plumbing (§8, §9); fix V10, V11, V12 | **Sonnet 5 / hard** | S1, S3 | Place links render in favourites; ordering is deterministic; removal clears decisions |
| **5** | Worth-it/Skip + interest prompts + where-to-stay (**experiment**, instrumented) | **Sonnet 5 / hard** | S2, S4 | Content renders; token/latency/failure telemetry captured for S6 |
| **6** | **Evaluation gate (D15):** does the enlarged suggestions call stay combined, or split into focused parallel calls? Run the §13 matrix | **Opus 5 / hard** | S5 | A decision backed by measured tokens, latency, truncation rate and decode failures — not call count |
| **7** | `alreadyRecommended` derived context (§11) | **Sonnet 5 / medium** | S5 | Correct after a dive, a retry and a migration |
| **8** | Interest deep dives (§10) | **Sonnet 5 / hard** | S6, S7 | Survives save/reopen without re-charging; cap holds server-side; failures don't consume it |
| **9** | Know Before You Go v1 (§12) | **Sonnet 5 / hard** | S2 only — runs in parallel with S4–S8 | Renders end-to-end for a real trip; stable/verify ratio checked against real output |
| **10** | Grounded Near You (§7) | **Opus 5 / extra** | S6, S7 | Distances come from MapKit only; address never leaves the device; sparse areas degrade honestly |
| **11** *(later, product-led)* | KBYG v2 — taxonomy revision from real usage + deeper research | product, then Opus 5 | S9 shipped and used | n/a |

**Critical path:** 0 → 1 → 2 → 5 → 6 → {7,8} → 10. **S3 and S9 (KBYG) both only need S0–S2**, so both can run alongside the S4–S8 chain rather than waiting behind it. S4 joins after S1.

**Merge discipline:** S3 can be built early but should not ship a *live* Near You tab before S10, or a live Know Before You Go tab before S9 has real content wired (not just the placeholder shell) — feature-flag closed, or hold the merge, until each is actually ready.

**Running sessions in parallel.** The table above shows dependency order, not edit-collision safety — those are different things. Almost every phase touches `TripOutputStore.swift`, so two chats can be logically independent and still overwrite each other if they share a live working directory. **Use a git worktree per concurrent chat**, not just a second chat window on the same folder:

```bash
git worktree add ../wanderlust-s3 -b feature/output-s3-shell
git worktree add ../wanderlust-s9 -b feature/output-s9-kbyg
```

- **Keep 0 → 1 → 2 strictly sequential**, one lineage. They reshape the same core files in ways that build on each other; parallelizing trades a small time saving for correctness bugs hiding in a merge.
- **Safe to start immediately, own worktree:** S3 (works against `Mock*Service`, barely touches what S0–S2 touch) and the Convex/TS half of S0 (`ConvexBackend/`, a different language and folder from the Swift persistence/coordinator work).
- **Parallel-safe to *draft* once 0–2 land, but merge one at a time:** S4, S5, S9 all add new files plus a few insertion points in `TripOutputStore.swift`. Draft in parallel worktrees; land branches sequentially (S9 first — mostly additive — then rebase S4 onto it, then S5) rather than merging all three blind.
- **S6, S7, S8, S10** have real data dependencies, not just file overlap — keep these waiting their turn regardless of worktree setup.

---

# 15. Design coherence

`DESIGN_SYSTEM.md` at repo root is the maintained spec and matches the code.

**Typography is content-type, not hierarchy.** **Kanit** for chrome and labels — titles (`DS.Typography.displayMedium`), section headers (`.kanitMedium(18)`), segment titles (`.kanitMedium(19)`), eyebrows (`.kanitMediumItalic(15)`), context labels (`.kanitItalic(14)`). **SF Pro Rounded** for anything the model generated — `.system(size: 15.5, design: .rounded)` for list items and favourites, `15` for card bodies. `DS.ContentTabBar` currently follows neither; fix it while there.

**Icons:** SF Symbols, `Color.appTint`, ~13–21pt, `.semibold`. The nine `section-N` PNGs are the only custom icon assets and are rendered `.renderingMode(.template)` tinted appTint — deliberately symbol-like. New surfaces use SF Symbols: `sparkles` (Discover), `location` (Near You), `lightbulb` (Know Before You Go).

**Cards — reuse the three that exist:**

| Use | Radius | Fill | Stroke | Shadow |
|---|---|---|---|---|
| Small content card | `.Radius.cardSmall` | `.regularMaterial` | `.black.opacity(0.06)` 1pt | `.black.opacity(0.08)` r10 y4 |
| Large container | `.Radius.cardLarge` | `.thinMaterial` | `.white.opacity(0.35)` 1pt | `.black.opacity(0.10)` r16 y8 |
| Tinted accent | `.Radius.cardSmall` | `appTint.opacity(0.07)` | `appTint.opacity(0.18)` 1pt | none |

All `style: .continuous`. References: `TravelTipsView.swift:154`, `ItineraryCard.swift:76`, `SegmentItineraryView.swift:129`.

**Spacing:** use `.Padding.*` / `.Spacing.*` / `.Radius.*`; the existing Output code leaks raw literals — don't copy that. **Buttons:** `PrimaryButtonStyle` / `SecondaryButtonStyle` exist. **Reuse:** `DS.GlassCard`, `DS.CardsCarousel` + `TextCard`, `HeartIcon`, `Chip`, `.toast(...)`, `LoadingView`, `RetryErrorView`, `PageIndicator`. **Colors:** `appTint` #586FF2; `suggestionTintA/B` are dead. **No localization exists** — new copy is inline `Text(...)`.

**Place links:** `LocationLinkable`'s `linkedText` extension handles markdown parsing, substring matching, Maps URL fallback and styling; taps are handled natively with no `openURL` interception. **Every new content type stores `LocationLinkableText`, not `String`.**

**`OutputTab`** is a public `Int`-raw enum in the DesignSystem *package*, rendered from `allCases` at equal width. Adding per-mode visibility needs `init(selection:tabs:)`; long titles need the icon stacked above the label.

---

# 16. Open questions

| Q | Owner | Blocks |
|---|---|---|
| KBYG v2: refined taxonomy + volatile-fact grounding strategy, from real usage and deeper research (the 7-video analysis) | product | S11 only — does not block shipping v1 (S9) |
| Combined vs split suggestions call (D15) | measurement | S6 → S8, S9 |
| Does parallel generation actually reduce wall-clock (D16)? | measurement | S2 sizing |
| Correct `maxOutputTokens` per component after the additions | measurement | S5 |
| Save policy: merge-on-complete (recommended) vs block-until-terminal | product + eng | S1 |
| Favourites ordering: explicit array vs deterministic derived order | eng | S4 |
| Does the sender's Near You result have any value to a recipient? (assumed no) | product | S9 |
