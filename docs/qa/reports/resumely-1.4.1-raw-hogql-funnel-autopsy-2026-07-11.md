# Resumely 1.4.1 Raw HogQL Funnel Autopsy — Early Read

## Executive Summary

- **No readable cohort exists yet.** PostHog project `270848` contained zero people and zero events matching `app = resumely_ios`, `marketing_version = 1.4.1`, and the canonical window beginning July 11, 2026 at 00:00 UTC through July 11, 2026 at 14:56:47 UTC.
- **No bottleneck can be named from this window.** The absence occurs before founder, QA, bot, or internal-tester exclusions, so funnel conversion and drop-off percentages are undefined rather than 0%.
- **The scheduled re-read remains necessary.** Re-run on July 18 for the earliest seven-day read and July 25 for the preferred fourteen-day read. Product changes should remain deferred until the cohort is non-empty and, for the picker diagnostic, preferably includes at least 10 openers.

## Scope and Metric Definition

This report evaluates the clean App Store 1.4.1 iOS cohort from upload CTA exposure through successful PDF export. The canonical cohort predicate is:

- `properties.app = 'resumely_ios'`
- `toString(properties.marketing_version) = '1.4.1'`
- event timestamp from `2026-07-11T00:00:00Z` through query execution time
- exclude a person from every step if any matching row has `is_internal_tester = true`, robust to boolean/string representation
- exclude person IDs beginning `067544b5`, `761e5b1b`, `a6441489`, or `712cf425`

The PostHog project timezone is **UTC**, so the project-time and UTC bounds are identical. The final scheduled funnel will use ordered same-person occurrences, a one-hour picker-open-to-file-selected window, and either reliable `$session_id` coverage or a documented 24-hour window from first launch.

## Cohort Audit

The audit was run before funnel calculation. A person excluded once would remain excluded from all steps.

| Audit measure | People |
|---|---:|
| Raw distinct people | 0 |
| Removed: internal tester | 0 |
| Removed: known founder/QA/bot prefix | 0 |
| Overlap between exclusion reasons | 0 |
| Clean distinct people | 0 |

The saved PostHog cohort `Founder + QA exclusion` (`394227`) is not a substitute for the explicit exclusions. Its saved definition is email-property based and currently contains two people, while WP-41 additionally requires event-level tester handling and four known person-ID prefixes. Because the canonical 1.4.1 window is empty, empirical membership overlap is not measurable in this read.

## Funnel Result: No Readable Cohort

No canonical funnel table can be interpreted because there are no eligible entrants. Values below deliberately use `N/A` for rates; they must not be read as 0% conversion.

| Step | Eligible entrants | Reached step | Lost at step | Step conversion | Cumulative conversion | Side-exit count |
|---|---:|---:|---:|---:|---:|---:|
| `app_launched` | 0 | 0 | 0 | N/A | N/A | — |
| `resume_upload_cta_seen` | 0 | 0 | 0 | N/A | N/A | — |
| `resume_upload_cta_tapped` | 0 | 0 | 0 | N/A | N/A | — |
| `resume_file_picker_opened` | 0 | 0 | 0 | N/A | N/A | — |
| `resume_file_selected` | 0 | 0 | 0 | N/A | N/A | `resume_file_picker_cancelled`: 0 |
| `resume_uploaded` | 0 | 0 | 0 | N/A | N/A | — |
| `job_added` | 0 | 0 | 0 | N/A | N/A | — |
| `optimization_started` | 0 | 0 | 0 | N/A | N/A | — |
| `optimization_completed` | 0 | 0 | 0 | N/A | N/A | — |
| `optimized_viewed` | 0 | 0 | 0 | N/A | N/A | — |
| `export_cta_seen` | 0 | 0 | 0 | N/A | N/A | — |
| `export_pdf_tapped` | 0 | 0 | 0 | N/A | N/A | — |
| `export_success` | 0 | 0 | 0 | N/A | N/A | `export_failed`: 0 |

There are no absolute losses to rank and no logically valid single bottleneck to name. Session-ID and `$lib` coverage are also undefined because the raw stream contains no rows. The required `$lib = resumely-ios-urlsession` discrepancy check therefore has no observations; the app/version predicate remains canonical.

## Picker Diagnostic

| Diagnostic | Clean people |
|---|---:|
| Picker opened | 0 |
| Selected within one hour | 0 |
| Cancelled | 0 |
| Neither selected nor cancelled | 0 |

The documented 60-day baseline of 13 openers to 6 selectors (46%) is not compared with this read because the new cohort denominator is empty.

## Exact HogQL

### Raw schema and availability sample

```sql
SELECT
  person_id,
  distinct_id,
  event,
  timestamp,
  uuid,
  properties.app AS app,
  properties.marketing_version AS marketing_version,
  properties.build_number AS build_number,
  properties.is_internal_tester AS is_internal_tester,
  properties.$lib AS lib,
  properties.$session_id AS session_id,
  properties.anonymous_session_id AS anonymous_session_id
FROM events
WHERE timestamp >= toDateTime('2026-07-11 00:00:00', 'UTC')
  AND properties.app = 'resumely_ios'
  AND toString(properties.marketing_version) = '1.4.1'
ORDER BY timestamp DESC
LIMIT 20
```

Result: headers only; zero rows.

### Exclusion audit

```sql
WITH cohort_events AS (
  SELECT
    toString(person_id) AS person_key,
    lower(toString(properties.is_internal_tester)) = 'true' AS internal_flag,
    startsWith(toString(person_id), '067544b5')
      OR startsWith(toString(person_id), '761e5b1b')
      OR startsWith(toString(person_id), 'a6441489')
      OR startsWith(toString(person_id), '712cf425') AS known_prefix_flag
  FROM events
  WHERE timestamp >= toDateTime('2026-07-11 00:00:00', 'UTC')
    AND timestamp <= now()
    AND properties.app = 'resumely_ios'
    AND toString(properties.marketing_version) = '1.4.1'
)
SELECT
  now() AS queried_through_utc,
  uniqExact(person_key) AS raw_distinct_people,
  uniqExactIf(person_key, internal_flag) AS people_removed_internal,
  uniqExactIf(person_key, known_prefix_flag) AS people_removed_known_prefix,
  uniqExactIf(person_key, internal_flag AND known_prefix_flag) AS exclusion_overlap,
  uniqExactIf(person_key, NOT internal_flag AND NOT known_prefix_flag) AS clean_distinct_people
FROM cohort_events
```

First result at `2026-07-11T14:55:16.078105Z`: `0 | 0 | 0 | 0 | 0`. A second run at `2026-07-11T14:56:47.594927Z` also returned 0 matching event rows and the same five person counts. The SQL runner emitted global-taxonomy warnings for two properties on the second run, but `read-data-schema` had verified both `marketing_version` and Boolean `is_internal_tester` specifically on `app_launched`; the direct raw sample also returned zero rows.

### Saved cohort definition check

```sql
SELECT id, name, description, filters, count, last_calculation
FROM system.cohorts
WHERE id = 394227
LIMIT 1
```

This confirmed an email-based saved definition with count 2, last calculated July 11, 2026 at 07:26:01 UTC. No email values or person identifiers are stored in this report.

## Decision and Next Steps

1. Re-run the same audit on or after July 18, 2026.
2. Run the preferred definitive read on July 25, 2026.
3. Only after a non-empty clean cohort exists, pull the privacy-safe raw event stream, reconstruct ordered paths, reconcile `resume_uploaded` with the diagnostic `resume_upload_succeeded`, calculate side exits, rank absolute losses, and name exactly one bottleneck.
4. If picker openers remain below 10, label the observed result underpowered and defer product changes.

## Caveats and Open Questions

- This is an early same-day read, not the scheduled seven- or fourteen-day read.
- The connected PostHog warehouse-schema helper was advertised but unavailable at runtime. Event taxonomy and properties were instead verified with `read-data-schema` plus narrow HogQL probes.
- A zero-row window cannot validate session coverage, library consistency, event ordering, alias joins, reconciliation IDs, or path patterns.
- PostHog project link: https://us.posthog.com/project/270848
- Current PostHog cohort documentation: https://posthog.com/docs/data/cohorts
