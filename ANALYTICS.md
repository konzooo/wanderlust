# Wanderlust analytics contract

This file is the source of truth for analytics schema version `1`.

## Privacy and delivery rules

- Provider: Amplitude Swift `1.18.6`, EU server zone.
- Production uses the Amplitude-generated device ID for pseudonymous sessions and retention. The app never sets a user ID.
- Amplitude autocapture is limited to sessions and app lifecycle. Remote autocapture configuration and diagnostics are disabled.
- IP address, IDFV, location, city, region, country, DMA, and carrier collection are disabled.
- Debug and UI-test builds do not deliver events. A Debug build can explicitly opt in with the `-analytics-live` launch argument.
- Release events include `distribution_channel = testflight|app_store`. Every custom event includes `schema_version = 1`.
- Event names and property keys use lowercase `snake_case`. Properties must be flat primitive strings, integers, doubles, or booleans.
- Never add names, IDs, invite/share codes, tokens, URLs, raw errors, free-form text, generated content, notes, feedback text, or profile list contents.
- `destination` must pass `AnalyticsSanitizer.destination`: trim and collapse spaces, lowercase, maximum 80 characters, and plausible place-name characters only.
- Exact ages are forbidden; use `party_age_bucket`.
- Errors use only: `network`, `timeout`, `rate_limited`, `authentication`, `validation`, `not_found`, `conflict`, `decoding`, `storage`, `service`, or `unknown`.

## Shared properties

| Property | Type | Meaning |
|---|---:|---|
| `schema_version` | integer | Always `1` |
| `distribution_channel` | string | `debug`, `testflight`, or `app_store` |
| `destination` | string | Optional sanitized place name |
| `outcome` | string | Controlled success/failure outcome |
| `error_category` | string | Fixed taxonomy; never a raw message |
| `duration_ms` | integer | Operation duration |
| `trip_mode` / `trip_type` | string | Controlled solo/group or storage context |

## Events

### Lifecycle and navigation

Amplitude owns install, update, app open, background, and session events.

| Event | Required properties | Optional properties |
|---|---|---|
| `screen_viewed` | `screen_name` | `entry_point` |

Canonical screens: `home`, `basic_info`, `questionnaire`, `trip_output`, `saved_trips`, `profiles`, `feedback`, `group_create`, `group_members`, `group_join`, `group_questionnaire`, `group_dashboard`, and `shared_trip`.

### Solo planning and results

| Event | Contract |
|---|---|
| `trip_planning_started` | `entry_point` |
| `trip_details_submitted` | `duration_days`, `start_month`, `party_type`, `party_age_bucket`, `party_gender`, `has_custom_notes`, `profile_usage`; optional `destination` |
| `questionnaire_started` | `trip_mode`, `questionnaire_version`, `question_count` |
| `questionnaire_limit_reached` | `trip_mode`, `questionnaire_version` |
| `questionnaire_completed` | start properties plus `duration_ms`, `undo_count`, `q01_choice`–`q07_choice`; optional Traveller DNA properties |
| `trip_generation_started` | `component`, `attempt`, `trip_mode`; optional `destination` |
| `trip_generation_succeeded` | start properties plus `duration_ms` |
| `trip_generation_failed` | start properties plus `duration_ms`, `error_category` |
| `trip_result_viewed` | `trip_type`; optional `destination`, `duration_days` |
| `trip_saved`, `trip_deleted` | `outcome`, `trip_type`; optional `destination`, `error_category` |
| `favorite_changed` | `action`, `favorite_count`, `trip_type`; optional `destination` |
| `trip_share_requested` | `trip_type`; optional `destination` |
| `trip_share_succeeded`, `trip_share_failed` | `outcome`, `trip_type`; optional `destination`, `error_category` |

`component` is one of `itinerary`, `suggestions`, or `image`; `attempt` starts at `1`.

### Saved, shared, and group trips

| Event | Contract |
|---|---|
| `saved_trips_viewed` | `personal_count`, `group_count`, `received_count` |
| `saved_trip_opened` | `trip_type`; optional `destination` |
| `shared_trip_opened` | `source`, `outcome`; optional `destination`, `error_category` |
| `group_trip_creation_started`, `group_trip_created`, `group_trip_creation_failed` | duration/month/profile fields; optional `destination`, `outcome`, `error_category` |
| `group_member_added` | `role`, `roster_count`, `outcome`; optional `error_category` |
| `group_invite_shared` | `method`, `roster_count` |
| `group_join_started`, `group_join_succeeded`, `group_join_failed` | `source`, `method`; outcome events add `outcome` and optional `error_category` |
| `group_preferences_submitted` | questionnaire version/count, choices, profile summary, `outcome`; optional `error_category` |
| `group_generation_requested` | `action`; optional roster/completion counts and `destination` |
| `group_generation_state_changed` | `previous_state`, `state`, roster/completion counts; optional `destination`, `error_category` |
| `group_result_viewed` | `trip_type`; optional `destination`, `duration_days` |

Join `source` is `deep_link` or `manual_code`; join `method` is `existing_slot` or `new_member`. Invite method currently uses `copy_link`.

### Traveller DNA and feedback

| Event | Contract |
|---|---|
| `traveller_profile_saved` | `operation`, five `dna_*` scores, `skip_count`, `must_have_count`, `has_notes`, `profile_count` |
| `traveller_profile_deleted` | five `dna_*` scores, counts, `has_notes`, `profile_count` |
| `traveller_profile_selected` | `selection`, `profile_count`; profile selection may include five scores and counts |
| `feedback_submitted` | `outcome`, populated-field booleans, length buckets; optional `error_category` |

Traveller DNA properties are the five integer scores `dna_advice_detail`, `dna_physical_energy`, `dna_experience_breadth`, `dna_day_rhythm`, and `dna_structure`, each constrained to `1...5`. Only list counts and `has_notes` are allowed.

## Dashboard definitions

1. **Activation Funnel:** `trip_planning_started` → `trip_details_submitted` → `questionnaire_completed` → successful itinerary generation → `trip_result_viewed` → successful `trip_saved`.
2. **Generation Reliability:** success rate and p50/p95 `duration_ms` by `component`, `attempt`, and `distribution_channel`; failures by `error_category`.
3. **Personalization:** questionnaire choices, profile use, Traveller DNA score distributions, favorite rate, and save rate. Do not expose cohorts with very small populations.
4. **Group Collaboration:** creation → member added/invite → join → preferences → generation ready → result viewed.
5. **Retention / Engagement:** Amplitude lifecycle sessions, weekly returning devices, saved/shared/group opens, and trips planned per pseudonymous device.

Schema changes require updating this file, typed event definitions, and tests in the same change.
