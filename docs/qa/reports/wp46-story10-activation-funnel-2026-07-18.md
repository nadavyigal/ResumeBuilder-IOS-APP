# WP-46 Story 10 Canonical Activation Funnel

**Date:** 2026-07-18
**PostHog project:** 270848, ResumeBuilder AI
**Purpose:** Reproduce the first-session activation path without selecting résumé text, job text, URLs, names, email, or generated content.

## Measurement contract

The activation milestone is `optimized_preview_rendered`, not backend completion. It fires once per optimization only after `WKWebView` reports a successful visible HTML navigation and the optimized résumé has visible applied changes.

The stable correlation fields are:

- `anonymous_session_id` on every event through the shared analytics envelope
- `review_id` on review and apply events
- `optimization_id` on completion, recovery, preview, save, and export events
- `item_id` on recommendation events, using a backend group ID or local UUID, never recommendation content
- `is_internal_tester` on every event, with Debug and TestFlight builds classified as internal

Canonical upload semantics are distinct:

- `resume_file_selected` means a local file passed selection/preflight.
- `resume_upload_succeeded` means the server upload completed.
- The legacy `resume_uploaded` event remains decodable for historical reports but has no production call site in this release.

The local-only WP-45 S0 commit `d53d091` was reconciled, not replayed. Its `analysis_cta_tapped` contract and versioned Fit properties are retained, while Story 10's current event taxonomy, Story 9 recommendation evidence fields, and canonical preview activation remain authoritative.

## Reproducible clean-cohort HogQL

Set `{start}` and `{end}` to the release cohort window in UTC. This query excludes an entire person when any in-window iOS event is marked internal, then counts ordered person-level milestones. It reads only event names, timestamps, IDs used for joining, and the tester flag.

```sql
WITH scoped AS (
    SELECT
        person_id,
        event,
        timestamp,
        lower(toString(properties.is_internal_tester)) = 'true' AS internal_flag
    FROM events
    WHERE timestamp >= toDateTime('{start}')
      AND timestamp < toDateTime('{end}')
      AND properties.app = 'resumely_ios'
      AND properties.$lib = 'resumely-ios-urlsession'
      AND event IN (
          'resume_file_selected',
          'resume_upload_succeeded',
          'free_ats_completed',
          'sign_in_completed',
          'analysis_cta_tapped',
          'optimization_started',
          'recommendation_included',
          'recommendation_skipped',
          'optimization_apply_started',
          'optimization_apply_succeeded',
          'optimization_completed',
          'optimization_state_recovered',
          'optimized_preview_rendered',
          'save_success',
          'export_success'
      )
),
excluded_people AS (
    SELECT person_id
    FROM scoped
    GROUP BY person_id
    HAVING max(toUInt8(internal_flag)) = 1
),
clean AS (
    SELECT *
    FROM scoped
    WHERE person_id NOT IN (SELECT person_id FROM excluded_people)
),
paths AS (
    SELECT
        person_id,
        minIf(timestamp, event = 'resume_file_selected') AS selected_at,
        minIf(timestamp, event = 'resume_upload_succeeded') AS uploaded_at,
        minIf(timestamp, event IN ('free_ats_completed', 'analysis_cta_tapped')) AS intent_at,
        minIf(timestamp, event = 'optimization_started') AS optimization_started_at,
        minIf(timestamp, event = 'optimization_apply_started') AS apply_started_at,
        minIf(timestamp, event = 'optimization_apply_succeeded') AS apply_succeeded_at,
        minIf(timestamp, event = 'optimization_completed') AS completed_at,
        minIf(timestamp, event = 'optimized_preview_rendered') AS preview_at,
        minIf(timestamp, event = 'save_success') AS saved_at,
        minIf(timestamp, event = 'export_success') AS exported_at
    FROM clean
    GROUP BY person_id
)
SELECT
    countIf(selected_at IS NOT NULL) AS selected_people,
    countIf(uploaded_at >= selected_at) AS uploaded_people,
    countIf(intent_at >= selected_at) AS intent_people,
    countIf(optimization_started_at >= intent_at) AS optimization_started_people,
    countIf(apply_started_at >= optimization_started_at) AS apply_started_people,
    countIf(apply_succeeded_at >= apply_started_at) AS apply_succeeded_people,
    countIf(completed_at >= optimization_started_at) AS completed_people,
    countIf(preview_at >= completed_at) AS activated_people,
    countIf(saved_at >= preview_at) AS saved_people,
    countIf(exported_at >= preview_at) AS exported_people
FROM paths
```

## Interpretation gates

- Primary activation rate: clean people with `optimized_preview_rendered` divided by clean people with `optimization_completed`.
- Release target: at least 90% once the cohort is meaningful.
- Do not interpret lift before at least 20 clean intent users or 14 days after release, whichever is later.
- Keep monetization decisions blocked until the physical journey passes and a clean cohort satisfies the sample gate.
