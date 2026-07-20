# WP-48 — First Post-1.4.3 Activation Cohort Read

**Date:** 2026-07-20
**PostHog project:** 270848, ResumeBuilder AI
**Release under test:** 1.4.3 (13), live 2026-07-19T21:47:02Z
**Read taken at:** 2026-07-20T06:46:55Z (PostHog server clock, UTC)
**Elapsed since release:** 9 hours
**Verdict:** **NOT MATURE — do not read the cohort. Projected maturity 2026-08-18.**

This report selects no résumé text, job text, URLs, names, emails, or generated content. It reads
only event names, timestamps, join IDs, version strings, and the tester flag.

---

## 1. Headline

The cohort cannot be read, and two measurement defects were found that would have made an early
read actively misleading. Both must be fixed before the 2026-08-18 read, not after.

| Question | Answer |
|---|---|
| Do the Stories 10-12 events fire from a clean 1.4.3 install? | **Unknown — zero production 1.4.3 events exist.** |
| Is the sample mature? | **No.** 0 of 20 required clean uploaders. |
| When will it be mature? | **2026-08-18** (projected, 4.7 clean file-selectors/week). |
| Is the predeclared win rule usable as written? | **No — see Defect A.** |

---

## 2. Task 1 — do the canonical events fire? (blocked, not failed)

**There is no post-release iOS traffic at all.** Last Resumely iOS event of any kind:
`2026-07-19T16:24:01Z` — roughly 5.5 hours *before* the 21:47:02Z release. The 9-hour post-release
window contains zero events from any build.

Distinguish carefully: this is **not** evidence that the instrumentation is broken. It is evidence
that no user has opened the app since it went live. At the measured arrival rate (below) 9 hours is
well under one expected user. The packet's stop condition ("if they do not fire, everything
downstream is void") is **not** triggered — the correct status is *not yet observable*.

### The only 1.4.3 evidence that exists

One pre-release 1.4.3 session, person `c7494f9d`, `2026-07-19T13:34:57Z → 13:39:12Z`, 33 events
(the Story 13 physical-gate run, 8 hours before release). It emitted:

| Event | Count | Fires on 1.4.3? |
|---|---|---|
| `app_launched`, `guest_mode_started`, `resume_upload_cta_seen` | 1 each | confirmed |
| `resume_upload_cta_tapped`, `resume_file_picker_opened` | 10 each | confirmed |
| `resume_file_picker_cancelled` | 10 | confirmed |
| `resume_file_selected` | **0** | **unconfirmed** |
| `resume_upload_succeeded` | **0** | **unconfirmed** |
| `optimization_completed` | **0** | **unconfirmed** |
| `export_success` | **0** | **unconfirmed** |

So 1.4.3's *pre-selection* telemetry is confirmed working on a real binary. All four events the
packet named remain unconfirmed on 1.4.3, because that session opened the picker 10 times and
cancelled 10 times without ever selecting a file — it never reached the code paths that emit them.

**Defect C (flagging gap):** this session reported `is_internal_tester = false` on a build that
could only have been Debug or TestFlight (the store release was 8 hours later). The internal
classifier failed for it. Left unfixed, gate runs like this one land inside the "clean" cohort and
contaminate the very read this packet exists to produce. Note this session is a 10-open / 0-select
picker loop — exactly the shape of the picker sub-cliff — so if it is miscounted it does not merely
add noise, it drags the clean picker→select rate toward zero.

---

## 3. Task 2 — cohort maturity

**Rule:** ≥20 clean uploaders; win at ≥30% `optimization_started` vs the 12.5% baseline.
**Cohort window opens:** 2026-07-19T21:47:02Z. **Clean uploaders so far: 0.**

Arrival rate of clean, first-time `resume_file_selected` persons (internal-flagged persons excluded
at the person level, 60-day window):

| Day | New clean file-selectors |
|---|---|
| 2026-07-05 | 2 |
| 2026-07-06 | 3 |
| 2026-07-13 | 1 |
| 2026-07-17 | 1 |
| 2026-07-18 | 2 |
| 2026-07-19 | 1 |

10 persons over 15 days = **0.67/day = 4.7/week**, which independently confirms the fix plan's
"~4-5/week" estimate. 20 persons from the release timestamp projects to **2026-08-18**.

Treat 2026-08-18 as a projection at the current rate, not a commitment. Re-check the arrival rate
before reading; if traffic changes, the date moves.

### Defect A — the predeclared win rule is not reproducible on 1.4.3 (blocking)

The 12.5% baseline was computed on the **legacy `resume_uploaded` event**, and 1.4.3 no longer
emits it. Measured over the same clean 90-day window:

| Denominator event | People | → `optimization_started` | Rate |
|---|---|---|---|
| `resume_uploaded` (legacy) | 17 | 2 | 11.8% ← this is the plan's "2/16, 12.5%" |
| `resume_file_selected` | 10 | 1 | 10.0% |
| `resume_upload_succeeded` | 1 | — | n/a |

`resume_uploaded`'s call site was removed by the Story 10 commit (`31b73b6` /`8277cba`,
"feat(ios): instrument canonical activation journey") that shipped in 1.4.3. Its designated
successor is `resume_upload_succeeded` — but that event is emitted at
`Features/Tailor/TailorViewModel.swift:172`, **after the sign-in guard at line 146**:

```swift
guard appState.session?.accessToken != nil else {   // line 146
    errorMessage = NSLocalizedString("Please sign in first.", comment: "")
    return nil
}
…
AnalyticsService.shared.track(.resumeUploadSucceeded(fileType: uploadFileType))  // line 172
```

`resume_upload_succeeded` is therefore **unreachable for guests by construction**. Every clean
uploader in the 90-day funnel was a guest, which is exactly why only 1 of 10 clean file-selectors
ever emitted it.

This breaks the S1 measurement specifically. S1's whole purpose is to convert guests into
signed-in optimizers. Using an auth-gated denominator means the population is filtered to people
who *already signed in* — the denominator shrinks by the exact amount S1 is supposed to improve.
A naive post-release read would compare that inflated rate against the 12.5% guest-inclusive
baseline and declare a win that is pure denominator substitution.

**Correction to apply before the 2026-08-18 read:** use `resume_file_selected` as the denominator
(it is emitted in `cachePickedFile`, before any auth guard, and is guest-reachable), and re-baseline
against the like-for-like pre-1.4.3 figure of **1/10 = 10.0%**, not 12.5%. On a 20-person sample the
30% threshold then means **≥6 of 20**, which is unchanged in count — but it is now a comparison
between two populations that actually match.

### Defect B — `resume_upload_succeeded` is not a funnel step

Following from Defect A: the canonical Story 10 HogQL uses `resume_upload_succeeded` for its
`uploaded_people` step. Because that event sits behind the auth gate, the upload step can never
exceed the sign-in step, and every downstream rate is computed against a denominator that silently
excludes all guests. The canonical query needs the same substitution.

---

## 4. Reconciliation with Portfolio HQ

Portfolio HQ (`PROJECT-STATUS.md:147`) records: *"Resumely iOS: PostHog read blocked on calendar
(no post-live 1.4.1 traffic yet)."* This **agrees** with this read — both conclude the funnel is
calendar-blocked, not broken. No contradiction to resolve.

Two corrections to hand back to HQ:

1. HQ's next action still names a **2026-07-25 re-run on a `marketing_version=1.4.1` cohort**. That
   is stale on both counts: the build under test is now 1.4.3, and 07-25 is 24 days early. Retarget
   to 1.4.3 and 2026-08-18.
2. HQ shows Resumely iOS with substantial stranded work (11 unpushed/unmerged branches, 6 leftover
   worktrees, 8 uncommitted files in the primary tree). Out of scope here, but it is why the
   "worktree" this session ran in was a partial copy rather than a real git worktree.

---

## 5. Reproducible HogQL (content-free)

Set `{start}` = `2026-07-19 21:47:02` (the 1.4.3 release timestamp) and `{end}` = read time, UTC.

### Q1 — is there any post-release traffic at all? (run this first; if 0, stop)

```sql
SELECT
    properties.app_version AS app_version,
    count()                AS events,
    uniq(person_id)        AS people,
    min(timestamp)         AS first_seen,
    max(timestamp)         AS last_seen
FROM events
WHERE timestamp >= toDateTime('{start}')
  AND timestamp <  toDateTime('{end}')
  AND properties.$lib = 'resumely-ios-urlsession'
GROUP BY app_version
ORDER BY last_seen DESC
```

### Q2 — do the canonical events fire on 1.4.3, and for whom?

```sql
SELECT
    event,
    lower(toString(properties.is_internal_tester)) AS internal,
    count()        AS events,
    uniq(person_id) AS people,
    max(timestamp)  AS last_seen
FROM events
WHERE timestamp >= toDateTime('{start}')
  AND timestamp <  toDateTime('{end}')
  AND properties.$lib     = 'resumely-ios-urlsession'
  AND properties.app_version = '1.4.3'
  AND event IN (
      'resume_file_selected',
      'resume_upload_succeeded',
      'optimization_started',
      'optimization_completed',
      'optimized_preview_rendered',
      'export_success'
  )
GROUP BY event, internal
ORDER BY event
```

### Q3 — the S1 read, with the Defect A correction applied

Denominator is `resume_file_selected` (guest-reachable), **not** `resume_upload_succeeded`.
Baseline to beat: 1/10 = 10.0%. Win threshold: ≥30%, i.e. ≥6 of 20.

```sql
WITH scoped AS (
    SELECT
        person_id,
        event,
        timestamp,
        lower(toString(properties.is_internal_tester)) = 'true' AS internal_flag
    FROM events
    WHERE timestamp >= toDateTime('{start}')
      AND timestamp <  toDateTime('{end}')
      AND properties.$lib = 'resumely-ios-urlsession'
),
-- Exclude the whole person if ANY in-window event is internal-flagged.
excluded AS (
    SELECT person_id
    FROM scoped
    GROUP BY person_id
    HAVING max(toInt(internal_flag)) = 1
),
paths AS (
    SELECT
        person_id,
        minIf(timestamp, event = 'resume_file_selected')  AS selected_at,
        minIf(timestamp, event = 'optimization_started')   AS opt_started_at,
        minIf(timestamp, event = 'optimization_completed') AS completed_at,
        minIf(timestamp, event = 'export_success')         AS exported_at
    FROM scoped
    WHERE person_id NOT IN (SELECT person_id FROM excluded)
    GROUP BY person_id
)
SELECT
    countIf(selected_at IS NOT NULL)                AS clean_uploaders,      -- sample gate: need >= 20
    countIf(opt_started_at >= selected_at)          AS optimization_started, -- win: >= 30% of the above
    countIf(completed_at   >= opt_started_at)       AS optimization_completed,
    countIf(exported_at    >= completed_at)         AS exported
FROM paths
```

### Q4 — maturity check (run before Q3; do not read Q3 until this returns ≥20)

```sql
WITH scoped AS (
    SELECT
        person_id,
        event,
        timestamp,
        lower(toString(properties.is_internal_tester)) = 'true' AS internal_flag
    FROM events
    WHERE timestamp >= toDateTime('{start}')
      AND timestamp <  toDateTime('{end}')
      AND properties.$lib = 'resumely-ios-urlsession'
),
excluded AS (
    SELECT person_id FROM scoped GROUP BY person_id HAVING max(toInt(internal_flag)) = 1
)
SELECT uniq(person_id) AS clean_uploaders
FROM scoped
WHERE person_id NOT IN (SELECT person_id FROM excluded)
  AND event = 'resume_file_selected'
```

---

## 6. Task 3 — S2 scope for 1.4.4

Live property inspection changes the S2 estimate: the picker **outcome** events already exist and
ship today. What is missing is the file metadata on them, the CTA tap, and job attribution.

| S2 item | Live status (verified 2026-07-20) | Work remaining |
|---|---|---|
| `score_screen_signin_tapped` | **Absent.** No sign-in event exists except `sign_in_completed`. | Build it. |
| File-picker outcome events | **Mostly present**: `resume_file_picker_opened`, `resume_file_picker_cancelled` (both carry `source`: `home` / `tailor`), `resume_upload_preflight_rejected` (carries `reason`), `resume_upload_started`, `resume_upload_succeeded`. | Add file type + size bucket to the picker events. |
| File type / size properties | **Absent on picker events.** `resume_file_picker_cancelled` carries only envelope fields. `resume_file_selected` already carries `fileType` + `sizeBucket` (`TailorViewModel.swift:86-89`). | Propagate the existing bucketing helper to the picker events. |
| `job_source` (url vs paste) | **Absent.** `free_ats_completed` carries `score_bucket` only. | Build it on `free_ats_completed` + `optimization_started`. |

Two items should be promoted into S2 ahead of the nice-to-haves, because without them the
2026-08-18 read is not trustworthy:

- **S2-A (blocking): fix the guest-reachability of the upload funnel step.** Either move
  `resume_upload_succeeded` out from behind the auth guard, or formally redesignate
  `resume_file_selected` as the canonical upload denominator and update the Story 10 contract.
  Redesignating is the cheaper and safer option — it is a docs + query change, no app risk.
- **S2-B (blocking): fix `is_internal_tester` for Debug/TestFlight builds** so gate runs like
  `c7494f9d` cannot enter the clean cohort.

Revised S2 estimate: still roughly half a day, but the two blocking items above come first.

---

## 7. Interpretation gates (unchanged, restated)

- Do **not** read the cohort before 2026-08-18, or before Q4 returns ≥20, whichever is later.
- Do not compare a 1.4.3 rate against the 12.5% legacy baseline. The like-for-like baseline is 10.0%.
- Any excluded person carrying an ERROR or FAILURE event is re-examined individually before any
  conclusion is published (`~/.claude/ERRORS.md`, 2026-07-19). In this read the exclusion set was
  empty of failures because the post-release window is empty.
- Monetization decisions stay blocked until a mature clean cohort passes the gate.
