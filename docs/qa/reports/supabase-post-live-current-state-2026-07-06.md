# Supabase + PostHog Post-Live Current State - 2026-07-06

## Verdict

The app is technically live and the backend optimization path is working, but the current production signal is still too small and too QA/founder-heavy to justify paid acquisition or monetization work.

Best interpretation: **activation is blocked before clean users reach a complete upload -> job -> fit -> optimize -> view/export path**. Supabase shows reliable completed backend work, while PostHog shows many app opens and very few clean end-to-end journeys.

## Sources

- Supabase project `brtdyamysfmctrhuankn` / "ResumeBuilder AI".
- PostHog project `270848`, iOS filter `properties.$lib = 'resumely-ios-urlsession'`.
- Window: `2026-06-17T00:00:00Z` through `2026-07-06`.
- Clean PostHog excludes known QA/founder/bot person prefixes: `067544b5`, `761e5b1b`, `a6441489`, `712cf425`.
- Project state from `tasks/progress.md`: v1.2 (7) live, v1.3 (8) uploaded to App Store Connect on 2026-07-05 with `optimized_viewed` / `export_cta_seen` instrumentation verified in simulator.

## Supabase Operational State

Since App Store live:

| Metric | Rows | Distinct backend users |
|---|---:|---:|
| Profiles | 3 | 3 |
| Resumes | 39 | 3 |
| Job descriptions | 42 | 3 |
| Optimizations | 23 | 2 |
| Completed optimizations | 23 | 2 |
| Failed optimizations | 0 | 0 |
| Optimization review runs | 36 | 3 |
| Applied review runs | 23 | 2 |
| Saved resumes | 6 | 1 |
| Applications | 6 | 1 |
| Expert workflow runs | 32 | 1 |
| Anonymous ATS scores | 39 | 0 |

Optimization health looks good once a user reaches the backend:

- `23 / 23` optimizations completed.
- `0` failed optimizations.
- Average original ATS score: `28.8`.
- Average optimized ATS score: `38.0`.
- Average ATS delta: `+9.2`.
- Review apply rate: `23 / 36` runs, `63.9%`.

Concentration risk is high:

| Backend user rank | Resumes | Jobs | Optimizations | Applications | Saved resumes |
|---:|---:|---:|---:|---:|---:|
| 1 | 35 | 38 | 22 | 6 | 6 |
| 2 | 3 | 3 | 1 | 0 | 0 |
| 3 | 1 | 1 | 0 | 0 | 0 |

So almost all deep backend activity is one heavy user/tester. Treat bottom-funnel success as product capability evidence, not market evidence.

## PostHog Event State

Raw iOS events since launch:

| Event | Events | People |
|---|---:|---:|
| `app_launched` | 131 | 53 |
| `guest_mode_started` | 90 | 52 |
| `resume_uploaded` | 71 | 8 |
| `job_added` | 33 | 5 |
| `optimization_started` | 33 | 1 |
| `optimization_completed` | 22 | 2 |
| `diagnosis_viewed` | 21 | 1 |
| `export_pdf_tapped` | 8 | 1 |
| `export_success` | 8 | 1 |
| `submit_package_saved` | 38 | 12 |
| `optimized_viewed` | 2 | 2 |
| `export_cta_seen` | 2 | 2 |

Clean iOS event presence after excluding known QA/founder prefixes:

| Event | Events | People |
|---|---:|---:|
| `app_launched` | 86 | 51 |
| `guest_mode_started` | 85 | 50 |
| `resume_upload_cta_tapped` | 15 | 9 |
| `resume_file_picker_opened` | 9 | 8 |
| `resume_file_selected` | 4 | 4 |
| `resume_uploaded` | 10 | 7 |
| `job_added` | 5 | 4 |
| `free_ats_completed` | 6 | 3 |
| `optimization_completed` | 1 | 1 |
| `optimized_viewed` | 1 | 1 |
| `export_cta_seen` | 1 | 1 |
| `export_pdf_tapped` | 0 | 0 |
| `export_success` | 0 | 0 |
| `sign_in_completed` | 1 | 1 |

The clean loose funnel says:

- 51 launched.
- 9 tapped upload CTA.
- 8 opened the file picker.
- 4 selected a file.
- 7 had `resume_uploaded` at least once.
- 4 added a job.
- 1 completed optimization.
- 0 clean users tapped/exported PDF.

The ordered funnel is even stricter: no clean user produced a reliable upload -> job -> fit -> optimize-complete chain after the launch/user filters. This likely reflects a mix of true drop-off, event identity breaks, and QA traffic that is not fully tagged.

## Current State

1. **Backend reliability is not the main blocker.** Supabase has 23 completed optimizations and no failed optimizations since launch.
2. **Acquisition/activation volume is tiny.** PostHog shows 51 clean iOS launchers in about 20 days.
3. **The biggest measurable loss is early.** Only 9 clean launchers tap upload CTA, 4 select a file, and 4 add a job.
4. **Bottom-funnel evidence is mostly founder/tester behavior.** One backend user accounts for 22 of 23 completed optimizations and all saved applications/resumes.
5. **Export friction remains unproven in production.** The new 1.3 instrumentation (`optimized_viewed`, `export_cta_seen`) is working, but current events are only smoke/test-scale.
6. **Analytics identity needs hardening.** Supabase says completed optimizations exist; clean PostHog has inconsistent `optimization_started` / `optimization_completed` continuity. This makes funnel reads less trustworthy than they should be.

## Recommendations

Priority 1: **Fix measurement before changing monetization or running paid traffic.**

- Add an explicit app/build/environment/actor property to every analytics event, for example `app = resumely_ios`, `build_number`, `marketing_version`, `is_internal_tester`.
- Identify or alias PostHog users after Supabase auth and carry a stable anonymous session id before auth.
- Create an internal-test exclusion rule that does not rely on ad hoc person-id prefixes.
- Ensure `optimization_started`, `optimization_completed`, and Supabase optimization ids can be reconciled without exposing private resume contents.

Priority 2: **Improve the first-session upload path.**

- Treat upload as the primary activation problem: 51 launchers -> 9 upload CTA tappers -> 4 file selectors is the clearest loss.
- Make the first screen more directly action-oriented: "Upload resume" and "Paste job link" should feel like one guided task, not separate exploration.
- Keep `.pdf`, `.doc`, `.docx` acceptance visible before the picker.
- Add post-picker states that distinguish cancel, unsupported file, parser no text, upload network failure, and success.

Priority 3: **Do not invest in export/paywall changes yet.**

- There is not enough clean production data after `optimized_viewed` / `export_cta_seen`.
- Re-read after v1.3 (8) or newer is truly live and at least 20-30 non-internal users have reached `optimization_completed`.
- If completers get `optimized_viewed` but no `export_cta_seen`, improve Optimized tab layout. If they do not get `optimized_viewed`, fix routing after optimize first.

Priority 4: **Use Supabase evidence to improve product quality messaging.**

- The average optimized score is only 38.0 with a +9.2 delta. That is progress, but not a "high score" story.
- Frame the result as concrete recruiter-facing improvements and next actions, not as a promised ATS/pass outcome.
- Consider surfacing "what improved" immediately after review apply, because review apply behavior is one of the stronger backend signals.

Priority 5: **Delay paid acquisition.**

- Organic/clean activation is still not proven.
- The next useful growth action is a small targeted founder outreach wave or TestFlight/live cohort where every participant is tagged, not broad spend.

## Next Read

After v1.3 (8) or later is live for real users, rerun:

- Clean iOS funnel from `app_launched` -> `resume_upload_cta_tapped` -> `resume_file_selected` -> `resume_uploaded` -> `job_added` -> `fit_check_completed` -> `optimization_completed` -> `optimized_viewed` -> `export_cta_seen` -> `export_success`.
- Supabase operational counts for `resumes`, `job_descriptions`, `optimizations`, `optimization_review_runs`, `saved_resumes`, and `applications`.
- A reconciliation check joining PostHog event properties to backend optimization ids if/when that property is available.
