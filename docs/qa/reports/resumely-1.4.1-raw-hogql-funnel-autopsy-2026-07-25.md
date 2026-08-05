# Resumely 1.4.1 Raw HogQL Funnel Autopsy - Definitive Rerun - 2026-07-25

## Decision

**No clean 1.4.1 picker cohort exists: 0 of 0 eligible picker openers selected a file within one hour.** The definitive query ran through `2026-07-25T15:38:21.093082Z` in PostHog project `270848` (UTC). All 13 raw people meet one or more required exclusion, so the raw 3 of 5 picker result is audit-only and not customer conversion.

This result is **underpowered** against the minimum of 10 clean picker openers. Defer product changes. Portfolio HQ manual metrics were not updated because the usable-evidence gate is not met. The July 18 underpowered checkpoint remains preserved as the earlier checkpoint; this report is the definitive July 25 rerun.

## Contract

- Window: `2026-07-11T00:00:00Z` through query execution time.
- Canonical cohort: `properties.app = 'resumely_ios'` and `toString(properties.marketing_version) = '1.4.1'`.
- Remove a person from **every** step when any matching event has `is_internal_tester=true` in Boolean or string form, one of the four established founder/QA/bot ID prefixes, virtual bot or automation traffic, or an emulator or sideload signal.
- Picker outcome: each person's first `resume_file_picker_opened`, followed by `resume_file_selected` within one hour. `resume_file_picker_cancelled` is a side exit only when it occurs before selection in that hour. Neither means neither terminal event occurs in that window.

## Cohort audit

| Measure | People |
|---|---:|
| Raw distinct people | 13 |
| Removed: `is_internal_tester` | 9 |
| Removed: established founder/QA/bot ID prefix | 2 |
| Removed: virtual bot or Automation traffic | 13 |
| Removed: observed emulator signal | 0 |
| Removed: observed sideload signal | 0 |
| People with two or more exclusion reasons | 9 |
| Clean distinct people | **0** |

Counts are non-additive. Virtual bot or Automation traffic excludes every raw person. No emulator or sideload signal was observed, which is not proof that none occurred. No IDs, emails, resume content, or job text are retained in this report.

## Ordered picker diagnostic

| Outcome after first picker open | Raw people | Clean people |
|---|---:|---:|
| Picker opened | 5 | 0 |
| File selected within one hour | 3 | 0 |
| Conversion | 60% | N/A |
| Cancelled before selection within one hour | 2 | 0 |
| Neither selected nor cancelled within one hour | 0 | 0 |

The raw stream contained 10 picker-open event rows, 7 file-selected rows, and 2 picker-cancelled rows. The ordered first-open calculation above is the contracted person-level result. It finds 3 selectors and 2 cancellations among 5 raw openers, while every one is excluded.

The prior 60-day `13 -> 6` (46%) baseline is **not comparable**. A valid comparison requires a clean denominator and preferably at least 10 clean picker openers. This cohort has zero.

## Coverage

| Check | Raw | Clean |
|---|---:|---:|
| Matching event rows | 335 | 0 |
| Rows with `$session_id` | 0 / 335 (0%) | 0 / 0 (N/A) |
| People with `$session_id` | 0 / 13 (0%) | 0 / 0 (N/A) |
| Rows with `$lib=resumely-ios-urlsession` | 335 / 335 (100%) | 0 / 0 (N/A) |
| People with expected `$lib` | 13 / 13 (100%) | 0 / 0 (N/A) |

`$session_id` cannot support a session-based diagnostic for this cohort. The specified one-hour same-person definition remains valid without it. All raw rows use the expected `resumely-ios-urlsession` library, but that is instrumentation coverage, not proof of clean production traffic.

## Uncertainty and next condition

- This is an exclusion-complete, not a product-complete, read. It cannot establish picker health or a clean bottleneck because there are no clean people.
- PostHog returned taxonomy warnings for the legacy virtual-traffic and emulator/sideload property names. The contracted narrow query still returned virtual bot or Automation exclusions for all 13 people. Treat the observed zero emulator/sideload counts as limited evidence only.
- The warehouse-schema helper remains unavailable in this connection. Event names and key picker properties were first verified with `read-data-schema`; the event table was then queried directly.
- Re-read only after there are at least 10 clean 1.4.1 picker openers, or after an explicit version/cohort contract supersedes this one. Do not change the picker based on this result.

## Exact HogQL

The final aggregate query returned:

`2026-07-25T15:38:21.093082Z | 13 | 9 | 2 | 13 | 0 | 0 | 9 | 0 | 5 | 0 | 3 | 0 | 2 | 0 | 0 | 0 | 335 | 0 | 0 | 0 | 335 | 0 | 10 | 7 | 2`

```sql
WITH cohort_events AS (
  SELECT
    toString(person_id) AS person_key,
    event,
    timestamp,
    properties.$session_id AS session_id,
    properties.$lib AS lib,
    lower(toString(properties.is_internal_tester)) = 'true' AS internal_flag,
    startsWith(toString(person_id), '067544b5')
      OR startsWith(toString(person_id), '761e5b1b')
      OR startsWith(toString(person_id), 'a6441489')
      OR startsWith(toString(person_id), '712cf425') AS known_prefix_flag,
    lower(toString(properties.$virt_is_bot)) = 'true'
      OR lower(toString(properties.$virt_traffic_type)) IN ('bot', 'automation', 'ai agent') AS virtual_bot_flag,
    lower(toString(properties.is_emulator)) = 'true'
      OR lower(toString(properties.$device_type)) LIKE '%simulator%'
      OR lower(toString(properties.$model)) LIKE '%simulator%' AS emulator_flag,
    lower(toString(properties.is_sideloaded)) = 'true'
      OR lower(toString(properties.sideloaded)) = 'true' AS sideload_flag
  FROM events
  WHERE timestamp >= toDateTime('2026-07-11 00:00:00', 'UTC')
    AND timestamp <= now()
    AND properties.app = 'resumely_ios'
    AND toString(properties.marketing_version) = '1.4.1'
), person_flags AS (
  SELECT person_key,
    max(internal_flag) AS internal_flag,
    max(known_prefix_flag) AS known_prefix_flag,
    max(virtual_bot_flag) AS virtual_bot_flag,
    max(emulator_flag) AS emulator_flag,
    max(sideload_flag) AS sideload_flag
  FROM cohort_events
  GROUP BY person_key
), classified_people AS (
  SELECT *, internal_flag OR known_prefix_flag OR virtual_bot_flag OR emulator_flag OR sideload_flag AS excluded
  FROM person_flags
), event_classifications AS (
  SELECT e.*, f.excluded
  FROM cohort_events AS e
  CROSS JOIN classified_people AS f
  WHERE e.person_key = f.person_key
), openers AS (
  SELECT person_key, min(timestamp) AS opened_at
  FROM cohort_events
  WHERE event = 'resume_file_picker_opened'
  GROUP BY person_key
), picker_status AS (
  SELECT
    o.person_key,
    nullIf(minIf(e.timestamp, e.event = 'resume_file_selected'
      AND e.timestamp >= o.opened_at
      AND e.timestamp <= o.opened_at + INTERVAL 1 HOUR),
      toDateTime('1970-01-01 00:00:00', 'UTC')) AS selected_at,
    nullIf(minIf(e.timestamp, e.event = 'resume_file_picker_cancelled'
      AND e.timestamp >= o.opened_at
      AND e.timestamp <= o.opened_at + INTERVAL 1 HOUR),
      toDateTime('1970-01-01 00:00:00', 'UTC')) AS cancelled_at
  FROM cohort_events AS e
  CROSS JOIN openers AS o
  WHERE e.person_key = o.person_key
  GROUP BY o.person_key
), picker_classifications AS (
  SELECT s.*, f.excluded
  FROM picker_status AS s
  CROSS JOIN classified_people AS f
  WHERE s.person_key = f.person_key
)
SELECT
  now() AS queried_through_utc,
  (SELECT count() FROM classified_people) AS raw_distinct_people,
  (SELECT countIf(internal_flag) FROM classified_people) AS people_removed_internal_tester,
  (SELECT countIf(known_prefix_flag) FROM classified_people) AS people_removed_known_prefix,
  (SELECT countIf(virtual_bot_flag) FROM classified_people) AS people_removed_virtual_bot_automation,
  (SELECT countIf(emulator_flag) FROM classified_people) AS people_removed_emulator,
  (SELECT countIf(sideload_flag) FROM classified_people) AS people_removed_sideload,
  (SELECT countIf((internal_flag + known_prefix_flag + virtual_bot_flag + emulator_flag + sideload_flag) >= 2) FROM classified_people) AS people_with_any_exclusion_overlap,
  (SELECT countIf(NOT excluded) FROM classified_people) AS clean_distinct_people,
  (SELECT count() FROM picker_classifications) AS raw_picker_openers,
  (SELECT countIf(NOT excluded) FROM picker_classifications) AS clean_picker_openers,
  (SELECT countIf(selected_at IS NOT NULL) FROM picker_classifications) AS raw_selected_within_one_hour,
  (SELECT countIf(selected_at IS NOT NULL AND NOT excluded) FROM picker_classifications) AS clean_selected_within_one_hour,
  (SELECT countIf(cancelled_at IS NOT NULL AND (selected_at IS NULL OR cancelled_at < selected_at)) FROM picker_classifications) AS raw_cancelled_before_selection,
  (SELECT countIf(cancelled_at IS NOT NULL AND (selected_at IS NULL OR cancelled_at < selected_at) AND NOT excluded) FROM picker_classifications) AS clean_cancelled_before_selection,
  (SELECT countIf(selected_at IS NULL AND cancelled_at IS NULL) FROM picker_classifications) AS raw_neither_selected_nor_cancelled,
  (SELECT countIf(selected_at IS NULL AND cancelled_at IS NULL AND NOT excluded) FROM picker_classifications) AS clean_neither_selected_nor_cancelled,
  (SELECT count() FROM event_classifications) AS raw_matching_event_rows,
  (SELECT countIf(session_id IS NOT NULL AND toString(session_id) != '') FROM event_classifications) AS raw_rows_with_session_id,
  (SELECT countIf(NOT excluded) FROM event_classifications) AS clean_matching_event_rows,
  (SELECT countIf(NOT excluded AND session_id IS NOT NULL AND toString(session_id) != '') FROM event_classifications) AS clean_rows_with_session_id,
  (SELECT countIf(lib = 'resumely-ios-urlsession') FROM event_classifications) AS raw_rows_with_expected_lib,
  (SELECT countIf(NOT excluded AND lib = 'resumely-ios-urlsession') FROM event_classifications) AS clean_rows_with_expected_lib,
  (SELECT countIf(event = 'resume_file_picker_opened') FROM event_classifications) AS raw_picker_open_event_rows,
  (SELECT countIf(event = 'resume_file_selected') FROM event_classifications) AS raw_file_selected_event_rows,
  (SELECT countIf(event = 'resume_file_picker_cancelled') FROM event_classifications) AS raw_picker_cancelled_event_rows
```

The immediate coverage confirmation also returned `13 | 0 | 13` for raw people, raw people with `$session_id`, and raw people with the expected `$lib`, respectively.

PostHog project: https://us.posthog.com/project/270848
