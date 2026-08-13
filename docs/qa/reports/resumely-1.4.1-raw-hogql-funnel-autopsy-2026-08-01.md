# Resumely 1.4.1 Raw HogQL Funnel Autopsy - Follow-up Read - 2026-08-01

## Decision

**The 1.4.1 picker cohort remains unreadable: 0 of 0 clean picker openers selected a file within one hour.** The read ran in PostHog project `270848` through `2026-08-01T11:36:11.021440Z` (UTC) with the person-level coverage confirmation through `2026-08-01T11:36:51.735929Z`.

All 13 raw people remain excluded under the deferred-read contract. The observed raw 3 of 5 picker result is audit-only, not customer conversion. The read is **underpowered** against the required minimum of 10 clean picker openers. Defer product changes and do not update Portfolio HQ manual metrics.

The July 18 checkpoint remains preserved as underpowered. The July 25 report remains the definitive scheduled rerun; this follow-up confirms that no later matching 1.4.1 activity has made the cohort usable.

## Deferred-read contract applied

- Window: `2026-07-11T00:00:00Z` through query execution time.
- Cohort: `properties.app = 'resumely_ios'` and `toString(properties.marketing_version) = '1.4.1'`.
- Person-level exclusions: remove a person from every step if any matching event has Boolean or string `is_internal_tester=true`, an ID beginning `067544b5`, `761e5b1b`, `a6441489`, or `712cf425`, virtual bot/Automation traffic, or an observed emulator or sideload signal.
- Ordered outcome: first `resume_file_picker_opened` per person; count `resume_file_selected` within one hour. Count `resume_file_picker_cancelled` only when it precedes selection in that hour. Count neither when neither terminal event occurs in that hour.

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

Counts are non-additive. The virtual bot or Automation indicator excludes every raw person. No emulator or sideload signal was observed, which is limited evidence rather than proof those conditions never occurred. No IDs, emails, resume content, or job text are retained here.

## Ordered picker diagnostic

| Outcome after first picker open | Raw people | Clean people |
|---|---:|---:|
| Picker opened | 5 | 0 |
| File selected within one hour | 3 | 0 |
| Conversion | 60% | N/A |
| Cancelled before selection within one hour | 2 | 0 |
| Neither selected nor cancelled within one hour | 0 | 0 |

The raw stream contains 10 picker-open rows, 7 file-selected rows, and 2 picker-cancelled rows. The first-open ordered calculation is the required person-level result, and all five raw openers are excluded.

The prior `13 -> 6` (46%) baseline is **not comparable**. A comparison requires a clean denominator and preferably at least 10 clean picker openers; this cohort has zero.

## Coverage

| Check | Raw | Clean |
|---|---:|---:|
| Matching event rows | 335 | 0 |
| Rows with `$session_id` | 0 / 335 (0%) | 0 / 0 (N/A) |
| People with `$session_id` | 0 / 13 (0%) | 0 / 0 (N/A) |
| Rows with `$lib=resumely-ios-urlsession` | 335 / 335 (100%) | 0 / 0 (N/A) |
| People with expected `$lib` | 13 / 13 (100%) | 0 / 0 (N/A) |

The missing `$session_id` values do not invalidate the one-hour same-person definition, but they prevent a session-based diagnostic. Expected-library coverage confirms instrumentation source only, not clean production traffic.

## Method and uncertainty

The query used the exact aggregate HogQL from the [July 25 definitive report](resumely-1.4.1-raw-hogql-funnel-autopsy-2026-07-25.md#exact-hogql), unchanged except for execution time. PostHog schema discovery confirmed the three picker events and their `app`, `marketing_version`, `is_internal_tester`, `$lib`, and virtual-traffic properties. The warehouse-schema helper was still unavailable.

PostHog emitted taxonomy warnings for legacy virtual-traffic, emulator, and sideload properties. The narrow query nevertheless continued to return the established bot/Automation exclusion for all 13 people. Therefore, bot/Automation exclusion is observed; the zero emulator and sideload counts remain limited evidence.

## Re-read condition

Re-read only after at least 10 clean 1.4.1 picker openers exist, or after an explicit version/cohort contract supersedes this one. Do not infer a broken picker from this zero-clean cohort.

PostHog project: https://us.posthog.com/project/270848
