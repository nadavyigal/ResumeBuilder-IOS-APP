# WP-45 S0 Measurement Contract and Baseline

**Date:** 2026-07-12
**PostHog project:** 270848, ResumeBuilder AI
**Project timezone:** UTC
**Query time:** 2026-07-12T18:26:39.993648Z
**Window:** trailing 60 days
**Story:** WP-45 S0, measurement only; no product-flow change

## Questions this instrumentation must answer

1. How many authenticated users explicitly tap Analyze after supplying a job?
2. Which entry surface and job-input source lead to that intent?
3. What fraction then reaches Fit Check, optimization start, optimization completion, and export?
4. Which flow and score version produced each result, without collecting resume or job content?

## Contract added in S0

`analysis_cta_tapped` records only bounded, privacy-safe dimensions:

- `source`: `home` or `tailor`
- `flow_version`: `fit_gate_v1` now; `direct_optimize_v2` is reserved for S1
- `job_input_source`: `url`, `paste`, `url_and_paste`, or `none`
- `extraction_quality`: `unknown` at tap time
- `requirement_count_bucket`: `unknown` at tap time
- `score_version`: `ats_v2_legacy`

Existing `fit_check_started` and `fit_check_completed` gain `flow_version` and `score_version`; completed checks also gain `score_bucket`. The central envelope already supplies `app`, `$lib`, platform, OS, marketing/app version, build number, anonymous session id, and internal-tester status.

No resume text, job-description text, job URL, email, token, or user identifier is added as an event property.

## Cohort definition

Included rows require:

- `properties.app = 'resumely_ios'`
- `properties.$lib = 'resumely-ios-urlsession'`
- timestamp within the trailing 60 days

A person is excluded from every step when any matching row is marked `is_internal_tester = true`, or when the established founder/QA/bot person id begins with one of these privacy-safe prefixes:

- `067544b5`
- `761e5b1b`
- `a6441489`
- `712cf425`

The query selects only event names, timestamps, aggregate counts, and the exclusion flags. It does not retrieve event-property blobs or personal/content fields.

## Pre-change result

### Cohort audit

| Measure | People |
|---|---:|
| Raw iOS people with the stable app/lib envelope | 14 |
| Marked internal tester | 8 |
| Matched established founder/QA/bot prefix | 1 |
| Clean people after person-level exclusion | 6 |

### Clean downstream funnel

| Step | Clean people |
|---|---:|
| `job_added` | 0 |
| `analysis_cta_tapped` | 0, event did not exist before S0 |
| `fit_check_started` | 0 |
| `fit_check_completed` | 0 |
| `optimization_started` | 0 |
| `optimization_completed` | 0 |
| `export_success` | 0 |

The clean pre-change downstream cohort is empty, so conversion rates and time-to-step metrics are undefined rather than 0%. S1 must not claim a measured lift until the post-release cohort reaches the packet gate of at least 20 clean `analysis_cta_tapped` users or 14 days, whichever is later.

### Raw activity explaining the discrepancy

| Event | Raw people | Internal people | Raw events |
|---|---:|---:|---:|
| `job_added` | 1 | 1 | 2 |
| `fit_check_started` | 4 | 4 | 20 |
| `fit_check_completed` | 4 | 4 | 17 |
| `fit_check_optimize_tapped` | 3 | 3 | 3 |
| `optimization_started` | 4 | 4 | 18 |
| `optimization_completed` | 4 | 4 | 12 |
| `optimized_viewed` | 1 | 1 | 6 |
| `export_success` | 1 | 0, excluded by known prefix | 2 |

This confirms that the visible legacy Fit/optimization evidence in the stable iOS envelope is internal or otherwise excluded. It cannot be used as an organic conversion baseline.

## Verification notes

- PostHog event taxonomy and event-specific properties were re-read before querying.
- The connected `read-data-warehouse-schema` helper again returned `Tool read-data-warehouse-schema not found`; the query used verified `events` fields and the narrow fallback already recorded in project lessons.
- `analysis_cta_tapped` was correctly absent from the pre-change taxonomy.
- No PostHog insight, dashboard, cohort, feature flag, or production setting was created or modified in S0.

## Readout gate

After S1 ships, re-run the same person-level exclusion and compare:

`job_added -> analysis_cta_tapped -> optimization_started -> optimization_completed -> export_success`

Primary target: at least 80% of clean `analysis_cta_tapped` people reach `optimization_started`. Directional lift against `job_added -> optimization_started` remains unscorable until a non-empty clean pre-change or suitable historical comparison cohort exists.
