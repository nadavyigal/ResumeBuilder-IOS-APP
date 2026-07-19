# Resumely Activation Cliff: Evidence and Fix Plan

Date: 2026-07-19
Source: live PostHog reads, project 270848 ("ResumeBuilder AI", web + iOS), 90-day window, read 2026-07-19. All numbers founder/QA/bot-excluded unless labeled RAW. Investigation only; no code changed this session.

## The headline number

**14 of 16 real uploaders (87.5%) never start an optimization.** Clean 90d funnel: 145 reached the app -> 20 tapped upload (13.8%) -> 16 uploaded -> 8 added a job -> 4 got a free ATS score -> 2 started optimization -> 1 completed -> 1 exported (0.7%). D7 activation for the mature cohort: 0% (consistent with the 2026-07-12 read), with one ambiguity noted below.

## Cohort construction (measured)

Raw 90d: 246 people, 116 iOS `app_launched`, 89 web `$pageview`, 21 uploaded, 26 optimization_completed, 5 export_success. Raw matches the 2026-07-19 dashboard read. Exclusions applied:

- Founder identified: `a6441489` (nadav.yigal@gmail.com; 1,697 events, 82 launches, 15 exports).
- QA emails: `+fable-qa-jul03` (`57726857`), `+export-wall-qa-jul10` (`d88d6675`).
- `is_internal_tester = true`: **45 persons, 1,216 events.** This flag catches people the email heuristic misses; it must be in every future funnel query.
- Automated QA/bot chains (>=3 events/second, person lifetimes of seconds, each person's last event at the same millisecond the next person's first event fires): the 06-23 to 06-27 fit-check army and a July suite that re-ran 07-06, 07-08, 07-10, 07-15, 07-16, 07-18. These chains generate nearly all raw `fit_check_*` volume (317 raw starts vs ~5 human starts), all 15 `save_failed` people, and all `optimization_apply_*` events (07-18).
- Founder-suspect anonymous iOS devices: `761e5b1b` (7 of the 5-person raw export count, 06-09 to 06-14, the day iOS v1.1 events first shipped), `57d4c850` (11 launches, 6 submit_package_saved, nothing else).

## Where real users die (measured, with code path)

Two-thirds of upload loss is structural, not motivational:

1. **The guest journey dead-ends by design.** `HomeTabView.swift:347-363` (`runAnalysis()`): unauthenticated users are routed to the free ATS check only; `optimization_started` is only reachable when `appState.isAuthenticated`. The free-score screen's single forward path is a **non-tappable caption**: "Sign in to unlock full resume optimization." (`ScoreResultView.swift:111-116`). No button, no sheet, no navigation. All 16 clean uploaders were guests; `signup_popup_viewed` for them: 0.
2. Users are motivated and keep trying: `19fe1fac` uploaded 8 times, added 6 jobs, ran 6 free ATS checks across 3 weeks (06-16 to 07-09) and never optimized. `70d0e0e5`, `2903d322`, `aa75dbca`, `cffe1217` all did upload + job + score, then quit. That is not acquisition quality; that is a wall.
3. **Picker sub-cliff:** 20 tapped upload -> ~10 ever fired `resume_file_selected`. Several opened the file picker repeatedly and never selected a file (`6597b727` 4x, `3c33bf71` 3 taps, `0bcc0c9c`, `8d4b7346`, `84ebf277` ended on `resume_file_picker_cancelled`).
4. Upload -> job_added loses 50% (16 -> 8): after a successful upload, half never provide a job.

## Verdict on the open question (scrape vs UX vs acquisition)

**Primarily a UX/auth-gate problem; scrape/scoring quality is a real but second-order contributor; acquisition quality is not the blocker.**

- Evidence for auth-gate: the code path above; plus every clean uploader was a guest and optimization is unreachable for guests without a screen-change detour (sign-in lives in Profile, not on the score screen).
- Evidence against acquisition-quality as primary: 14% of reachers tap upload (RunSmart comparison: 4% even start onboarding); users retry for weeks.
- Scrape/scoring scope: real job input splits 4 people via URL scrape vs 4 via paste (`job_added` has_url/has_paste), so the thin LinkedIn scrape (og:description ~200-char snippets, `new-ResumeBuilder-ai-` `src/lib/scraper/jobExtractor.ts:212-217`) can affect at most half of job-adders. It plausibly deflates scores and repels the users who DO see a score (the `19fe1fac` 6-retry loop smells like unsatisfying output), but we cannot see the scores users faced: `free_ats_completed` carries **no score property** in live data (checked; all null). The `scoreBucket` param exists in code (`HomeTabView.swift:358`), so either the score arrives null at that call site or an older build is live; verify.
- D7 ambiguity: one clean person (`712cf425`, first seen 06-14, active to 07-15) did complete upload -> optimize -> export once and also hit `save_failed` 4x. If it is a real user, lifetime organic activation is 1, not 0. Either way the rate rounds to zero.

## We know vs we suspect

We KNOW: the funnel numbers above; the guest gate and dead-end caption in code; the picker abandonment counts; the bot/internal contamination scale (45 internal persons; bot chains).

We SUSPECT: score quality/legibility discourages the few who see it (no score telemetry to confirm); iCloud/file-provider friction or format anxiety explains picker abandonment; the WP-29 S5 anonymous-session carryover gap means even a user who signs in loses their uploaded context (empty first dashboard) and has to start over.

## Fix backlog (ranked by expected activation lift per unit effort)

Top 2 (do these, in this order):

1. **S1. Make the free-score screen convert (S/M, 1-2 days).** Replace the passive caption in `ScoreResultView` with a primary "Sign in & get the optimized version" button presenting Sign-in-with-Apple inline, and carry the anonymous upload + job + score through signup so the user lands back on THEIR result, not an empty dashboard (WP-29 S5 carryover). Hypothesis: motivated guests fail to convert because the next step is not tappable where the motivation peaks. Metric moved: uploaded -> optimization_started (12.5% now; target 40%+). Measurement: pre/post funnel by app version; at ~4-5 real uploaders/week a 3x jump is detectable within 3-4 weeks; instrument `score_screen_signin_tapped` for the intermediate signal.
2. **S2. Score + picker telemetry (S, half day).** Fix `free_ats_completed` to actually carry the score bucket (it is null in live data), add file-picker outcome events (selected / cancelled / error, file type, size), add `signin_from_score` source property. Metric: none directly; it arbitrates the scrape-vs-score-quality question with real distributions and sizes the picker sub-cliff.

Then:

3. S3. Paste-first job input (S). Default the job field to paste with URL as secondary, or auto-fallback to paste when the scrape returns under ~500 chars. Metric: job_added -> free_ats/optimization rate for URL users vs paste users (S2 gives the split).
4. S4. Picker friction pass (M). Support "Choose from Files + recent documents", show accepted formats up front, and surface upload preflight errors verbatim. Metric: resume_upload_cta_tapped -> resume_uploaded (currently 16/20 tap-to-upload but only ~10 select a file on first attempt).
5. S5. Upload -> job handoff (S/M). After upload success, auto-advance to the job step with one example chip. Metric: uploaded -> job_added (50% now).

Explicitly NOT prioritized now: more scrape sophistication (headless browser etc.). Fix the gate first; S2 data decides whether scrape quality deserves the next slot.

## Hygiene findings for every future readout

- Always exclude: founder email, `+fable-qa*`/`+export-wall*` aliases, `is_internal_tester = true` persons, and burst chains (>=3 events/sec). The QA suites run on prod repeatedly (latest 07-18) and will keep poisoning raw counts.
- `save_failed`, `optimization_apply_failed`, `optimization_state_recovery_failed` volume on 07-18 is all QA-chain traffic, not a user-facing incident.
