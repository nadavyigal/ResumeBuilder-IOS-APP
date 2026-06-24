# WP-16 Resumely Activation Attribution + Funnel Diagnostic - 2026-06-24

## Verdict

Real-organic D7 activation remains **0 confirmed users**.

The unresolved person `067544b5` is excluded from organic activation. PostHog project
270848 shows that person as:

- `067544b5-dbb4-589f-988b-a146f794f184`
- first event: `optimization_review_created`, 2026-06-10T02:40:10Z
- activation event: `optimization_completed`, 2026-06-10T02:40:27Z
- later event: `sign_in_completed`, 2026-06-15T14:43:22Z
- libraries: `posthog-node`, then `resumely-ios-urlsession`
- geo on sign-in: US / CA / San Jose
- PostHog virtual classifier on all three events: `Automation`, `is_bot=true`

Classification: **automation / bot-like backend traffic, not real organic**.

## Sources

- PostHog project 270848, "ResumeBuilder AI", timezone UTC.
- Saved insight `VH410GF1`, "iOS Activation Funnel", dashboard 1720819.
- Live HogQL reads on 2026-06-24.
- Agentic OS WP-16 and EXD-013.
- iOS repo `docs/qa/reports/post-live-d7-readout-2026-06-17.md`.

## Reconciliation

The executive prompt readout said **3/35 raw completers**, with all three
founder-attributed and `067544b5` unresolved. The live source now shows:

| Read | Window / definition | Raw result | Clean organic result | Caveat |
|---|---:|---:|---:|---|
| Prior executive readout | D7 readout referenced by WP-16 | 3/35 | 0/35 or 1/35 pending `067544b5` | `067544b5` now resolved as automation |
| Current all-product re-query | First product event 2026-06-10 through 2026-06-24 | 4/37 optimization_completed users | 0 confirmed organic | Includes later/current activity and founder/test traffic |
| Current saved iOS funnel | `app_launched` -> export, `$lib=resumely-ios-urlsession`, 2026-06-10 through 2026-06-24 | 1/30 ordered completion | 0 confirmed organic | Saved funnel is iOS-only and has `filterTestAccounts=false` |

The denominator mismatch is real. It comes from different definitions: the prior
readout used the executive D7 cohort, the saved dashboard currently uses an iOS-only
ordered 14-day funnel, and the all-product diagnostic includes web, backend, and iOS
events. The decision does not depend on forcing these to match because every observed
completion is founder/test/automation-attributed.

## Funnel Stage Table

Current all-product diagnostic, 2026-06-10T00:00Z through 2026-06-24T23:59Z:

| Stage | Users | Step conversion | Main unknown |
|---|---:|---:|---|
| first_seen / app open / web visit | 37 first-seen, 34 opened | baseline | Exact App Store install denominator requires App Store Connect |
| resume upload or import started | 12 | 35% of opened | Whether failed/abandoned file picker attempts are tracked |
| resume parsed | unknown | unknown | No separate `resume_parsed` event in taxonomy |
| job pasted or selected | 10 | 83% of uploaders | URL paste vs manual paste quality not fully separated |
| optimization started | 4 | 40% of job-added users | Start failures/errors need backend/iOS error pairing |
| optimization completed | 4 raw, 0 confirmed organic | 100% of starters raw, 0 organic | Raw completers are excluded from organic claim |
| export or copy result | 6 | Not sequence-safe | Export can occur in founder/test flows and is not cleanly tied to organic activation |

Saved iOS ordered funnel, same date range:

| Stage | Users | Drop-off from previous |
|---|---:|---:|
| `app_launched` | 30 | baseline |
| `guest_mode_started` | 26 | -4 |
| `resume_uploaded` | 5 | -21 |
| `job_added` | 4 | -1 |
| `optimization_completed` | 1 | -3 |
| `export_success` | 1 | 0 |

Largest measurable drop-off: **guest/app-open to resume upload**. On the saved iOS
funnel, 26 guest users become 5 resume uploaders, an 81% drop-off. This is earlier
than Fit-First, score copy, or metric nudges.

## Recommendation

Do not reopen monetization, paid acquisition, or GTM volume from this readout.

Next packet should target **upload/import friction before optimization**:

- instrument or inspect file-picker start, file selected, preflight rejection, upload
  success, parser fallback, and upload error;
- review Home/Tailor first-action copy and empty states for resume import;
- only then measure whether users who upload also add a job and reach optimize.

Fit-First can remain shipped per the existing founder decision, but it should not be
treated as the primary activation fix until more real users reach `job_added`.
