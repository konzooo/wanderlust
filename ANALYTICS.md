# Wanderlust analytics contract

This file is the source of truth for product analytics schema version `2`.

## Delivery, identity, and privacy

- Provider: Amplitude Swift `1.18.6`, EU server zone.
- The app does not set an account user ID. Amplitude's pseudonymous device ID
  is used for sessions, funnels, retention, and trips per install.
- Autocapture is limited to sessions and app lifecycle. Remote autocapture and
  diagnostics are disabled.
- IP address, IDFV, location, city, region, country, DMA, and carrier collection
  are disabled in the app configuration.
- Debug and UI-test builds are offline unless Debug explicitly launches with
  `-analytics-live`.
- Every custom event receives `schema_version = 2` and
  `distribution_channel = debug|testflight|app_store`.
- Event properties use an exact per-event allowlist and primitive types. An
  event with an unknown, missing, or wrongly typed property is rejected.
- Analytics never receives destinations, names, local or server IDs,
  invite/share codes, tokens, URLs, raw errors, free-form text, notes,
  generated content, or profile list contents.
- Exact ages are forbidden. Errors use only `network`, `timeout`,
  `rate_limited`, `authentication`, `validation`, `not_found`, `conflict`,
  `decoding`, `storage`, `service`, or `unknown`.

## Anonymous install properties

These are updated at launch and after relevant local changes. They are state,
not increment-only counters.

| Property | Type |
|---|---:|
| `has_profile` | boolean |
| `profile_count` | integer |
| `attach_profile_by_default` | boolean |
| `saved_solo_trip_count` | integer |
| `group_trip_count` | integer |
| `received_trip_count` | integer |

## Canonical events

### Navigation and onboarding

| Event | Required properties |
|---|---|
| `screen_viewed` | `screen_name`; optional `entry_point` |
| `onboarding_completed` | `flow`, `page` |
| `onboarding_skipped` | `flow`, `page` |

Profile screens are deliberately distinct: `profile_tab`,
`profile_management`, and `profile_editor`. Other canonical screens are
`home`, `basic_info`, `questionnaire`, `trip_output`, `saved_trips`,
`feedback`, `group_create`, `group_members`, `group_join`,
`group_questionnaire`, `group_dashboard`, `shared_trip`, `welcome`,
`group_intro`, `joiner_intro`, and `traveller_dna_intro`.

### Traveller DNA

| Event | Required properties |
|---|---|
| `profile_flow_started` | `entry_point`, `operation=create|edit` |
| `profile_step_viewed` | start fields plus `step_name`, zero-based `step_index` |
| `traveller_profile_saved` | `entry_point`, `operation`, `profile_count`, five DNA scores, list counts, `has_notes` |
| `traveller_profile_deleted` | `profile_count`, five DNA scores, list counts, `has_notes` |
| `traveller_profile_selected` | `entry_point`, `selection=profile|none`, `profile_count` |

The editor steps are `identity`, the five stable DNA dimension names,
`usually_skip`, `must_haves`, and `additional_notes`. DNA scores are integers
from `1...5`; lists contribute counts only.

### Solo and group questionnaire

| Event | Required properties |
|---|---|
| `questionnaire_started` | `trip_mode`, `questionnaire_version`, `question_count` |
| `questionnaire_limit_reached` | `trip_mode`, `questionnaire_version` |
| `questionnaire_answered` | `trip_mode`, `questionnaire_version`, `question_key`, `step_index`, `choice` |
| `questionnaire_completed` | start fields, `duration_ms`, `undo_count`, final attachment state; optional `q01_choice`–`q07_choice` and DNA summary |
| `group_preferences_submitted` | version/count, `has_profile`, final attachment state, `outcome`; optional choices, DNA summary, `error_category` |

`choice` and every final `qNN_choice` are exactly `left`, `right`, or `both`.
`questionnaire_answered` measures partial progress; the completion event is the
canonical final answer distribution.

### Trip creation, generation, and engagement

| Event | Required properties |
|---|---|
| `trip_planning_started` | `entry_point`; `trip_mode=solo|group` |
| `trip_details_submitted` | duration/month/party fields, `profile_usage`; optional attachment source/count |
| `trip_created` | `trip_mode=solo`, `profile_attached`, `profile_attachment_source`; optional duration/count |
| `trip_generation_started` | `component`, `attempt`, `trip_mode` |
| `trip_generation_succeeded` | start fields plus `duration_ms` |
| `trip_generation_failed` | start fields plus `duration_ms`, `error_category` |
| `trip_result_viewed`, `group_result_viewed` | `trip_type`; optional duration |
| `trip_section_viewed` | `trip_mode`, `trip_context`, `section`; optional `subsection`, duration |
| `worth_it_decided` | `trip_mode`, `trip_context`, `decision`, one-based `item_position` |
| `trip_saved`, `trip_deleted` | `outcome`, `trip_type`; optional duration/error |
| `favorite_changed` | `action`, `favorite_count`, `trip_type`; optional duration |
| `trip_share_requested` | `trip_type`; optional duration |
| `trip_share_succeeded`, `trip_share_failed` | `outcome`, `trip_type`; optional duration/error |

`trip_created` fires once when a newly generated solo itinerary arrives;
reopening a saved or received trip never creates one. Generation components
are `itinerary`, `suggestions`, `know_before_you_go`, `worth_it`,
`where_to_stay`, `deep_dive`, `near_you`, and `image`.

Top-level output sections are `discover`, `know_before_you_go`, and
`near_you`; Discover subsections are `suggestions`, `worth_it`, and
`itinerary`. Each is counted once per screen visit. Worth It decisions are
`keep`, `skip`, or `undo` and never include item IDs or content.

### Saved, shared, and group collaboration

| Event | Required properties |
|---|---|
| `saved_trips_viewed` | `personal_count`, `group_count`, `received_count` |
| `saved_trip_opened` | `trip_type` |
| `shared_trip_opened` | `source`, `outcome`; optional `error_category` |
| `group_trip_creation_started` | duration/month/profile fields |
| `group_trip_created`, `group_trip_creation_failed` | creation fields plus `outcome`; optional error |
| `group_member_added` | `role`, `roster_count`, `outcome`; optional error |
| `group_invite_shared` | `method`, `roster_count` |
| `group_join_started` | `source`, `method` |
| `group_join_succeeded`, `group_join_failed` | join fields plus `outcome`; optional error |
| `group_generation_requested` | `action`; optional roster/completion counts |
| `group_generation_state_observed` | previous/current state and roster/completion counts; optional error |

`group_generation_state_observed` is diagnostic client observation and may be
emitted by multiple members. Authoritative attempt conversion and reliability
come from Convex `groupGenerationRuns`, keyed by group and generation version,
with initial/retry, start/finish timestamps, outcome, and stable error code.
Component cost, duration, token, and error reporting comes from Convex
`generationTelemetry`.

### Feedback and health

| Event | Required properties |
|---|---|
| `near_you_verified` | `proposed`, `resolved`, `survived` |
| `feedback_submitted` | `outcome`, populated-field booleans, length buckets; optional error |

## Dashboards and funnels

1. **Solo activation:** `trip_planning_started(trip_mode=solo)` →
   `trip_details_submitted` → `questionnaire_started` →
   `questionnaire_completed` → `trip_created` → `trip_result_viewed`.
2. **Profile creation:** `screen_viewed(profile_tab)` →
   `profile_flow_started(operation=create)` → ordered `profile_step_viewed` →
   `traveller_profile_saved`. Break down by `entry_point`.
3. **Profile adoption:** installs with `has_profile=true` →
   `trip_created(profile_attached=true)`. Break down by
   `profile_attachment_source=default|manual`.
4. **Questionnaire choices:** unique installs and answer counts by
   `question_key` × `choice`; compare partial `questionnaire_answered` with
   final `questionnaire_completed` distributions.
5. **Output engagement:** result view → each `trip_section_viewed` →
   `worth_it_decided` / `favorite_changed` / successful save/share.
6. **Group organizer:** group creation started → created → admin member added →
   invite shared → generation requested → authoritative backend run ready →
   `group_result_viewed`.
7. **Group joiner:** join started → succeeded → questionnaire started →
   preferences submitted → group result viewed. Do not combine this with the
   organizer funnel as if one device performs every step.
8. **Frequency and retention:** `trip_created` per pseudonymous install by
   day/week, solo/group mix, local trip-count properties, and Amplitude weekly
   returning installs.
9. **Reliability/cost:** client generation success and p50/p95 duration by
   normalized component, plus backend telemetry and group runs.

Schema changes require updating this file, the typed event contract, and tests
in the same change.
