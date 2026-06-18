# PostHog iOS Analytics Audit — 2026-06-16

**Objective:** Verify custom `resumely-ios-urlsession` transport ingests events and stand up D7 activation dashboards.

## MCP baseline (30-day HogQL)

Filter: `properties.$lib = 'resumely-ios-urlsession'`

| Event | Count (30d) | Notes |
|-------|-------------|-------|
| app_launched | 68 | Core funnel |
| guest_mode_started | 51 | Core funnel |
| resume_uploaded | 19 | Core funnel |
| job_added | 16 | PR #60 — may be low in older builds |
| export_started | 14 | Export sub-funnel |
| optimization_started | 14 | Core funnel |
| export_success | 12 | Core funnel |
| optimization_completed | 11 | Core funnel |
| sign_in_completed | 5 | Auth |
| export_failed | 2 | Export health |
| account_deleted | 1 | Auth |

**Zero volume in 30d (wired in code, not yet in shipped traffic):** `free_ats_completed`, `diagnosis_viewed`, `ats_improve_tapped`, `export_pdf_tapped`, `submit_package_saved`. Expect these after next App Store build with PR #60.

**Totals:** ~213 events, ~19 distinct users. Last iOS event seen: 2026-06-16.

## Live ingestion verification

1. **Release build Info.plist** (`Release-iphonesimulator`): `POSTHOG_API_KEY` non-empty (`phc_…`), `POSTHOG_HOST` = `https://us.i.posthog.com`.
2. **Direct capture test** (2026-06-16): POST to `/capture` using Release plist credentials returned **HTTP 200** with `platform: ios`, `$os: iOS`, `$lib: resumely-ios-urlsession`.
3. **Unit tests:** `AnalyticsServiceTests` — 8/8 passed (payload shape, PII guard, `resetDistinctId`, platform properties).

Full simulator smoke (all 16 events in Live Events UI) remains recommended before TestFlight; ingestion pipeline is confirmed.

## Dashboard

**ResumeBuilder iOS — D7 Activation**

- URL: https://us.posthog.com/project/270848/dashboard/1720819
- Insights attached:
  - iOS Daily Active Users
  - iOS Activation Funnel (7-step)
  - iOS Export Conversion
  - iOS Diagnosis to Improve
  - iOS Submit Package Saves
  - iOS Free ATS Score Buckets
  - iOS Auth Mix
  - iOS Export Failures

All tiles filter `$lib = resumely-ios-urlsession`.

## Code fixes shipped (custom transport)

- `platform: ios` and `$os: iOS` on every capture via `AnalyticsService.baseProperties`
- `resetDistinctId()` on `AppState.signOut()` — prevents guest sessions inheriting authenticated distinct_id
- DEBUG-only transport failure logging in `AnalyticsService.track`

## Gate A (2026-06-21)

Dashboard is ready. Funnel will under-report `free_ats_completed` and diagnosis/export-tap events until build with PR #60 ships to App Store users.
