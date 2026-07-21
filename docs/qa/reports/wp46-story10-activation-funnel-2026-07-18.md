# WP-46 Story 10 Canonical Activation Funnel

**Date:** 2026-07-18
**PostHog project:** 270848, ResumeBuilder AI
**Purpose:** Reproduce the first-session activation path without selecting résumé text, job text, URLs, names, email, or generated content.

## Measurement contract

The activation milestone is `optimized_preview_rendered`, not backend completion. It fires once per optimization only after `WKWebView` reports a successful visible HTML navigation and the markup that loaded carries visible résumé text.

### Amendment 2026-07-21 (WP-51) — emission repaired; all pre-1.4.4 readings of this event are invalid

The milestone was gated on `OptimizedResumeViewModel.hasVisibleAppliedChanges`, which inspects the separately fetched `sections` array. That was never a valid proxy for "the user sees a résumé": the preview's primary path renders from the backend using `optimization_id` alone (`resumeData: nil`), so whenever the optimization-detail fetch was slow, empty, or failing, a real résumé was on screen while `sections` was empty and the milestone was suppressed. Export runs off the same rendered HTML, which is how the 2026-07-21 read returned a non-monotonic funnel — 12 `resume_file_selected` → 7 `optimization_completed` → **1** `optimized_preview_rendered`, with **3** `export_success`.

The gate now judges visibility from the markup actually displayed (`PreviewActivationPolicy.hasVisibleRenderedContent`), which strips `<style>`/`<script>`/`<head>` content and requires ≥40 visible characters, so a chrome-only render still does not count. The once-per-optimization guarantee and the `optimization_id` correlation field are unchanged.

**This gate shipped with the event's original 1.4.1 form (`738da5a`, 2026-07-14); Story 10 (`31b73b6`/`8277cba`) only added `optimization_id` and moved emission onto `didFinish`. The event has therefore never fired reliably, and no activation figure computed on it before 1.4.4 is trustworthy — including any prior preview-based rate.** The WP-50 denominator decision (`resume_file_selected`) is unaffected and remains settled.

Success signal for this repair: `optimized_preview_rendered` person-count ≥ `export_success` person-count over the same window, and the ordered funnel monotonic non-increasing on a fresh 14-day read after 1.4.4 reaches users. The tell for over-firing is its person-count exceeding `optimization_completed`.

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

> **Denominator note (amended 2026-07-20, WP-50).** The activation denominator is
> `resume_file_selected`, not `resume_upload_succeeded`.
>
> `resume_upload_succeeded` is emitted at `Features/Tailor/TailorViewModel.swift:172`, *after* the
> sign-in guard at `:146` (`guard appState.session?.accessToken != nil`). It is therefore
> unreachable for guests by construction: the step can never exceed `sign_in_completed`, and any
> rate computed against it silently excludes every guest. Using it as the denominator was WP-48
> Defect B. Its predecessor `resume_uploaded` — the event the original 12.5% baseline was computed
> on — had its call site removed by the Story 10 commit (`31b73b6` / `8277cba`) that shipped in
> 1.4.3, so that baseline is not reproducible on the current build.
>
> `resume_file_selected` fires pre-auth and is the earliest point where the user has committed a
> real résumé, which is what the funnel is trying to measure.

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
        -- Post-auth diagnostic only. Never use as a funnel denominator: see the
        -- denominator note above (WP-50 / WP-48 Defect B).
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
    -- Canonical denominator. Pre-auth, so it includes guests.
    countIf(selected_at IS NOT NULL) AS selected_people,
    -- Guest-inclusive activation numerator, measured off the same denominator.
    countIf(optimization_started_at >= selected_at) AS optimization_started_from_selected,
    -- Diagnostic: post-auth, structurally <= sign_in_completed. Not a funnel step.
    countIf(uploaded_at >= selected_at) AS uploaded_people_post_auth,
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

### Activation-cliff win rule (redesignated 2026-07-20, WP-50)

Both sides of the comparison are computed on the **same** definition —
`optimization_started` over `resume_file_selected` people — so the rule is reproducible on 1.4.3.

| | Definition | Value |
|---|---|---|
| Baseline (pre-1.4.3, same clean 90-day window) | `optimization_started` / `resume_file_selected` | **10.0%** (1 of 10) |
| Superseded baseline — do not use | `optimization_started` / `resume_uploaded` (legacy) | 11.8% (2 of 17), quoted as "2/16, 12.5%" |

**Win rule:** post-1.4.3 `optimization_started_from_selected / selected_people` exceeds 10.0%, on at
least 20 clean file-selectors.

The baseline is deliberately restated on the new denominator. Comparing an auth-gated numerator
against a guest-inclusive baseline (or the reverse) would declare a win that is pure denominator
substitution rather than a real behavior change.

**Sample is not yet mature.** Per WP-48, 0 of the required 20 clean uploaders as of 2026-07-20, at a
measured 4.7 clean file-selectors/week; projected maturity **2026-08-18**. Do not read the cohort
before then.
- Keep monetization decisions blocked until the physical journey passes and a clean cohort satisfies the sample gate.
