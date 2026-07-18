# Resumely 1.4.1 Raw HogQL Funnel Autopsy - 2026-07-18

## Decision

**No clean 1.4.1 picker cohort exists: 0 of 0 eligible picker openers selected a file within one hour, queried through 2026-07-18T11:38:35.338292Z.** All 13 raw people are excluded by the production-traffic contract, so this is an **underpowered, no-readable-cohort** result, not a 0% product conversion result. No product change is justified. Preserve the definitive rerun on **2026-07-25**.

Portfolio HQ was not updated: its gate requires usable clean evidence, and this read has zero clean people and zero clean picker openers.

## Scope and contract

- PostHog project: `270848` (UTC project timezone).
- Window: `2026-07-11T00:00:00Z` through each query's execution time.
- Canonical cohort: `properties.app = 'resumely_ios'` and `toString(properties.marketing_version) = '1.4.1'`.
- Person-level exclusions: `is_internal_tester=true` in either Boolean/string form; the four established founder/QA/bot person-ID prefixes; virtual bot/Automation traffic; and observed emulator/sideload signals. If any matching event meets an exclusion, that person is removed from every step.
- Canonical upload terminal: `resume_uploaded`. `resume_upload_succeeded` is reported only as newer diagnostic instrumentation.
- Picker definition: same person, first `resume_file_picker_opened` to a `resume_file_selected` within one hour. Cancellation is a side exit only when it occurs before selection in that one-hour window.

## Cohort audit

Final audit at `2026-07-18T11:20:04.961433Z`:

| Measure | People |
|---|---:|
| Raw distinct people | 13 |
| Removed: `is_internal_tester` | 9 |
| Removed: established founder/QA/bot prefix | 2 |
| Removed: virtual bot / `Automation` traffic | 13 |
| Removed: observed emulator signal | 0 |
| Removed: observed sideload signal | 0 |
| People with two or more exclusion reasons | 9 |
| Clean distinct people | **0** |

Exclusion counts are deliberately non-additive. The raw sample returned `$virt_is_bot=true` and `$virt_traffic_type=Automation` for every matching person, including non-prefixed IDs, so all 13 are removed by the bot/automation requirement. PostHog emitted taxonomy warnings because these virtual-traffic keys are absent from its current catalog, but the narrow raw event sample returned their values. Emulator and sideload fields produced no positive signal; this is “not observed,” not proof that none ever occurred.

The saved `Founder + QA exclusion` cohort (`394227`) was not substituted for this contract. The prior report established that it is email-based, while this audit requires event-level tester handling plus explicit person-ID and traffic-quality exclusions.

## Picker diagnostic

Final rerun at `2026-07-18T11:38:35.338292Z`, unchanged from the first valid calculation at `2026-07-18T10:31:37.709572Z`:

| Outcome after first picker open | Raw people | Clean people |
|---|---:|---:|
| Picker opened | 5 | 0 |
| File selected within one hour | 3 | 0 |
| Conversion | 60% | N/A |
| Cancelled before selection within one hour | 2 | 0 |
| Neither selected nor cancelled within one hour | 0 | 0 |

The raw 3/5 result is audit-only and must not be interpreted as customer behavior because all five people are excluded. The prior 60-day `13 → 6` (46%) baseline is **not comparable**: this read has no clean denominator, and the raw-only 60% value would violate the exclusion contract.

## Clean ordered funnel

No step can have an eligible entrant after the cohort audit. Rates are `N/A`, not zero.

| Step | Eligible entrants | Reached step | Lost at step | Step conversion | Cumulative conversion | Side-exit count |
|---|---:|---:|---:|---:|---:|---:|
| `app_launched` | 0 | 0 | 0 | N/A | N/A | N/A |
| `resume_upload_cta_seen` | 0 | 0 | 0 | N/A | N/A | N/A |
| `resume_upload_cta_tapped` | 0 | 0 | 0 | N/A | N/A | N/A |
| `resume_file_picker_opened` | 0 | 0 | 0 | N/A | N/A | `resume_file_picker_cancelled`: 0 |
| `resume_file_selected` | 0 | 0 | 0 | N/A | N/A | N/A |
| `resume_uploaded` | 0 | 0 | 0 | N/A | N/A | N/A |
| `job_added` | 0 | 0 | 0 | N/A | N/A | N/A |
| `optimization_started` | 0 | 0 | 0 | N/A | N/A | N/A |
| `optimization_completed` | 0 | 0 | 0 | N/A | N/A | N/A |
| `optimized_viewed` | 0 | 0 | 0 | N/A | N/A | N/A |
| `export_cta_seen` | 0 | 0 | 0 | N/A | N/A | N/A |
| `export_pdf_tapped` | 0 | 0 | 0 | N/A | N/A | N/A |
| `export_success` | 0 | 0 | 0 | N/A | N/A | `export_failed`: 0 |

There is no valid largest clean-cohort loss or product bottleneck to name. The raw event populations are preserved in the privacy-safe appendix for audit only.

## Coverage and reconciliation

| Check | Result |
|---|---:|
| Matching raw event rows | 335 |
| Rows with `$session_id` | 0 / 335 (0%) |
| Raw people with `$session_id` | 0 / 13 (0%) |
| Rows with `$lib=resumely-ios-urlsession` | 335 / 335 (100%) |
| Raw people with expected `$lib` | 13 / 13 (100%) |

Because clean people equal zero, no full-funnel 24-hour fallback is applied. The one-hour picker definition is still evaluated on the raw audit cohort and reconciles with the grouped raw event sets: 5 picker openers, 3 selectors, and 2 cancellations.

## Exact HogQL

The finalized audit was run twice. This is the exclusion query used for the final confirmation; it produced `13 | 9 | 2 | 13 | 0 | 0 | 9 | 0` for raw people, internal, prefix, virtual bot/automation, emulator, sideload, overlap, and clean people respectively.

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
)
SELECT
  now() AS queried_through_utc,
  count() AS raw_distinct_people,
  countIf(internal_flag) AS people_removed_internal_tester,
  countIf(known_prefix_flag) AS people_removed_known_prefix,
  countIf(virtual_bot_flag) AS people_removed_virtual_bot_automation,
  countIf(emulator_flag) AS people_removed_emulator,
  countIf(sideload_flag) AS people_removed_sideload,
  countIf((internal_flag + known_prefix_flag + virtual_bot_flag + emulator_flag + sideload_flag) >= 2) AS people_with_any_exclusion_overlap,
  countIf(NOT excluded) AS clean_distinct_people
FROM classified_people
```

The ordered picker continuation uses the same `cohort_events` and `classified_people` CTEs, then ensures an absent `minIf` is null rather than ClickHouse's epoch default:

```sql
WITH openers AS (
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
)
SELECT
  count() AS raw_picker_openers,
  countIf(NOT f.excluded) AS clean_picker_openers,
  countIf(s.selected_at IS NOT NULL) AS raw_selected_within_one_hour,
  countIf(s.selected_at IS NOT NULL AND NOT f.excluded) AS clean_selected_within_one_hour,
  countIf(s.cancelled_at IS NOT NULL
    AND (s.selected_at IS NULL OR s.cancelled_at < s.selected_at)) AS raw_cancelled_before_selection,
  countIf(s.selected_at IS NULL AND s.cancelled_at IS NULL) AS raw_neither_selected_nor_cancelled
FROM picker_status AS s
CROSS JOIN classified_people AS f
WHERE s.person_key = f.person_key
```

## Next read and uncertainty

This July 18 checkpoint is underpowered (`0 < 10` clean picker openers). Defer product changes and run the definitive same-contract read on **2026-07-25**, retaining the person-level exclusion audit, one-hour picker rule, `$session_id`/`$lib` coverage, and privacy-safe paths appendix. Do not infer a broken picker from the missing clean events.

PostHog project: https://us.posthog.com/project/270848
