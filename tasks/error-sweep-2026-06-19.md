# Production Error Sweep — Resumely iOS

**Date:** 2026-06-19  
**Live build:** v1.0 (4) on App Store (since 2026-06-17)  
**In review:** v1.1 (5) (submitted 2026-06-18) — EXD-011: no code/build/ASC changes during this sweep  
**Sweep mode:** Report-only (no Swift, build, or ASC modifications)

---

## Summary

| Metric | Value |
|--------|------:|
| Time window (target) | Last 7 days ending 2026-06-19 |
| Distinct error/risk clusters | 12 |
| Actionable clusters (High/Critical) | 5 |
| Sources successfully queried | Static Swift audit; repo QA baselines (`docs/qa/posthog-gate-a-baseline-2026-06-18.md`, `docs/qa/reports/post-live-d7-readout-2026-06-17.md`); `tasks/lessons.md`, `tasks/progress.md` |
| Sources attempted but blocked | PostHog HogQL API (403 — project capture key cannot query); PostHog MCP tools (not exposed in this agent session); Supabase MCP / CLI logs (not available in session) |
| PostHog project confirmed | **270848** ("ResumeBuilder AI"), filter `$lib=resumely-ios-urlsession`, dashboard **1720819** (confirmed via repo QA docs and plugin reads on 2026-06-17/18) |
| `$exception` events (7d) | **Not refreshed live** — prior reads found **0** iOS `$exception` events; PostHog-ios does not auto-capture crashes |
| App Store Connect crashes | **Not queried** (documented gap) |

**Headline:** No crash telemetry and no live HogQL refresh in this session, but the **activation funnel shows a steep drop after upload** (9 uploaders → 3 optimizers → 1 diagnosis viewer in the 7d baseline), **export failures are rare but real** (2 `export_failed` / 1 user in trailing 7d per 2026-06-17 readout), and **static audit found silent WKWebView preview failures** plus several swallowed error paths on the export and auth edges.

---

## Ranked issue table

Severity uses **frequency × distinct users × flow-criticality** (upload → optimize → export is core; auth is critical).

| Severity | Issue | Count (7d) | Users affected | Source | Root cause (file:line) | Suggested fix (one line) |
|----------|-------|----------:|---------------:|--------|------------------------|--------------------------|
| **High** | Activation funnel collapse after resume upload (optimize → diagnosis) | `resume_uploaded` 27 / 9 users → `optimization_started` 16 / **3** → `diagnosis_viewed` 2 / **1** (baseline 2026-06-18) | 9 uploaders; only 3 reached optimize; 1 saw diagnosis | PostHog baseline 2026-06-18 (`$lib=resumely-ios-urlsession`) | Product + telemetry: diagnosis CTA depends on authenticated optimize path (`TailorViewModel` / `HomeTabView`); guest `free_ats_completed` not observed on live taxonomy | After v1.1 approval, run authenticated device smoke through Diagnosis → Improve → Export; compare funnel before blaming instrumentation |
| **High** | WKWebView preview HTML load failures are silent (no `WKNavigationDelegate`) | Unknown (no telemetry) | All preview users | Static audit | `ResumePreviewWebView.swift` `WebKitHTMLView` (lines 301–327): `loadHTMLString` with no `navigationDelegate`, no `didFail` handler | Add `WKNavigationDelegate` to surface load/provisional failures and log or set `errorMessage` |
| **High** | PDF export failures (`export_failed`) | 2 events / 1 user (7d through 2026-06-17; none newer in baseline) | 1 | PostHog D7 readout 2026-06-17 | Chain: `ResumeExportAction.swift:36–49` → `HTMLPDFExporter.swift:42–45` (20s timeout, no OSLog) → `OptimizedResumeViewModel.swift:279–297` (backend PDF fallback) | Log timeout/navigation/PDF-create failures with optimizationId; include `error_code` detail in `export_failed` payload |
| **Medium** | Wired funnel events missing on **live v1.0(4)** taxonomy | `export_pdf_tapped`, `free_ats_completed`, `submit_package_saved`: **0** in 7d baseline; `diagnosis_viewed` 2 / 1; `ats_improve_tapped` 2 / 1 | N/A (instrumentation visibility) | PostHog baseline 2026-06-18; code vs build version | Events wired in `AnalyticsService.swift` but likely ship in **v1.1(5)** review build, not store v1.0(4); `export_pdf_tapped` only on Optimized tab (`OptimizedResumeView.swift:892`) | Post-approval: confirm v1.1 events in PostHog; backfill dashboard tiles that expect PR #60 names |
| **Medium** | `export_started` / `export_success` without `export_pdf_tapped` (split analytics) | `export_success` 11 / 3 users (7d readout 2026-06-17) vs `export_pdf_tapped` 0 | 3 | PostHog + static | `export_*` only via `ResumeExportAction.swift:19–49`; `export_pdf_tapped` only if user taps Optimized export (`OptimizedResumeView.swift:892`); Me/History/Preview paths use `PDFExporter` with **no** export analytics | Track `export_pdf_tapped` (or unified export event) on all PDF download entry points |
| **Medium** | HTML PDF export timeout has no recovery logging | Unknown | Export users | Static audit | `HTMLPDFExporter.swift:42–45` — timeout calls `complete(.failure(.timedOut))` with no `Logger` | Add `Logger` on timeout and navigation failures before surfacing `HTMLPDFExporterError.timedOut` |
| **Medium** | Preview toolbar PDF export swallows styled-HTML failure | Unknown | Preview export users | Static audit | `ResumePreviewWebView.swift:225–229` — empty `catch` before backend fallback | Log failure reason; optionally surface non-blocking toast when HTML→PDF fails |
| **Medium** | Shared PostHog project — cross-app event pollution risk | `sign_in_completed` 5 / 4 users (7d readout); Resumely events visible in RunSmart sweep | 4+ | PostHog D7 readout; `tasks/loop-sweep-plan-2026-06-19.md` | Both apps may share project **270848**; RunSmart-specific `run_started` / `plan_generated` **not** in iOS-filtered baseline but unfiltered pollution possible | Bind each app's MCP/plugin to the correct project or add `$app` / bundle-id property filter on dashboards |
| **Low** | Auth session restore fails silently on corrupt keychain JSON | Unknown | Returning users | Static audit | `AuthService.swift:48–50` — `try? JSONDecoder().decode` returns `nil` without log | Log decode failure and clear corrupt keychain entry |
| **Low** | Anonymous ATS session conversion failure is silent | Unknown | Guest → sign-in users | Static audit | `AppState.swift:145–147` — sets pending flag only, no user message | Surface retry or log conversion failure for support |
| **Low** | Stale monetization error copy on HTTP 402 | 0 prod (gated off) | N/A | Static audit | `APIClient.swift:15–16`, `268–270` — "optimization credits" message while `BackendConfig.isMonetizationEnabled = false` | Gate 402 copy behind `isMonetizationEnabled` or generic message (**not active in production v1.0(4)**) |
| **Low** | Apple Sign-In / StoreKit error paths not live | N/A | N/A | `BackendConfig.swift:7–13` | `isAppleSignInEnabled = false`, `isMonetizationEnabled = false` | Defer fixes in `Core/Payments/` and Apple auth until flags flip (**not active in production v1.0(4)**) |

---

## PostHog funnel snapshot (7 days, verified baseline)

**Source:** `docs/qa/posthog-gate-a-baseline-2026-06-18.md` (HogQL via connected PostHog plugin, UTC). **Live refresh on 2026-06-19 failed** (HogQL API 403 with project capture key; personal API key / MCP not available in this session). Treat counts below as **last verified 2026-06-18 06:50 UTC**, not same-day refreshed.

Filter: `properties['$lib'] = 'resumely-ios-urlsession'`

| Funnel step | Events | Users | Latest (UTC) |
|-------------|-------:|------:|--------------|
| `app_launched` | 62 | 15 | 2026-06-18T04:17:53Z |
| `guest_mode_started` | 44 | 13 | 2026-06-17T23:14:19Z |
| `resume_uploaded` | 27 | 9 | 2026-06-18T04:23:20Z |
| `job_added` | 19 | 7 | 2026-06-18T04:19:30Z |
| `optimization_started` | 16 | 3 | 2026-06-18T04:23:19Z |
| `optimization_completed` | 11 | 3 | 2026-06-18T04:21:05Z |
| `diagnosis_viewed` | 2 | 1 | 2026-06-18T04:21:06Z |
| `ats_improve_tapped` | 2 | 1 | 2026-06-17T12:31:18Z |
| `export_started` / `export_success` | 11 each / 3 users | (from 2026-06-17 readout) | 2026-06-15T18:20:30Z |
| `export_failed` | 2 | 1 | 2026-06-11T10:47:05Z |
| `free_ats_completed` | **0** | **0** | not in taxonomy |
| `export_pdf_tapped` | **0** | **0** | not in taxonomy |
| `submit_package_saved` | **0** | **0** | not in taxonomy |
| `$exception` | **0** | **0** | (no iOS exception capture configured) |

**Drop-off notes (ordered funnel, approximate):**

- Launch → upload: 9/15 users (60%) uploaded at least once.
- Upload → optimize start: 3/9 uploaders (33%) started optimization — largest relative drop.
- Optimize start → complete: 11/16 events (69%) among the 3-user cohort.
- Complete → diagnosis view: 2 views / 1 user — diagnosis instrumentation sparse on live build.
- Export: 11 successes vs 2 failures (failure rate ~15% among users who triggered export analytics).

**RunSmart-specific events:** `run_started`, `plan_generated` — **not observed** under `$lib=resumely-ios-urlsession` in baselines. `sign_in_completed` (5 events / 4 users) appears in project 270848 but is **ambiguous** (Resumely defines it in `AnalyticsService.swift:67`; RunSmart may share the project — see `tasks/loop-sweep-plan-2026-06-19.md`).

---

## Supabase (project `brtdyamysfmctrhuankn`)

**Status:** `get_logs` and `get_advisors` **not executed** — Supabase MCP tools were not available in this agent session; `supabase` CLI not installed; management API credentials not present.

**Code-level edge functions in repo:**

| Function | File | Notes |
|----------|------|-------|
| `delete_account` | `supabase/functions/delete_account/index.ts` | JWT validation; partial wipe logs `console.error`; returns 500 JSON on failure |
| `storekit-verify` | Not in repo tree | Referenced in sweep plan only — logs not reachable here |

**Known backend issues from project memory (not re-verified live):**

- `/api/v1/styles/history` returns 500 (documented in `tasks/progress.md`; design history intentionally not auto-loaded).
- iOS snake_case vs backend camelCase on applications route caused 400s (fixed per `tasks/lessons.md` 2026-06-09) — watch for regression if backend redeploys without alias.

---

## Static-audit findings

### Silent or swallowed catches (network / export / auth)

| Location | Behavior | Risk |
|----------|----------|------|
| `ResumePreviewWebView.swift:201–202` | Benign cancellation swallowed (intentional) | Low |
| `ResumePreviewWebView.swift:225–229` | HTML→PDF failure swallowed; falls through to backend | Medium — hides root cause |
| `ResumePreviewWebView.swift:92–94` | Debounce sleep cancellation returns silently | Low |
| `OptimizedResumeViewModel.swift:237–239` | `refreshSubmitPackageContext` load failure swallowed | Medium — stale sections in Submit Package |
| `AppState.swift:145–147` | Anonymous session conversion failure → flag only | Low |
| `AppState.swift:217–219` | Credits refresh failure swallowed | Low (**monetization gated off**) |
| `AuthService.swift:48–50` | Corrupt session decode → `nil` session, no log | Medium |
| `AuthService.swift:58–59` | `try? keychain.save` on persist | Medium |
| `AnalyticsService.swift:181–186` | PostHog transport failure swallowed (by design) | Low — blinds analytics, not UX |
| `ApplicationDetailViewModel.swift:47–50` | Expert reports fetch failure → empty array | Low |
| `ExpertModesViewModel.swift:86–88` | Saved report count load ignored | Low |
| `ResumeManagementViewModel.swift:105–107` | Preview thumbnail failure ignored | Low |
| `SubmitApplicationViewModel.swift:245–248` | Screening persistence failure swallowed | Low |

### Force-unwraps / force-tries on hot paths

| Location | Note |
|----------|------|
| `APIClient.swift:307–318` | `.data(using: .utf8)!` on multipart boundary assembly — safe for ASCII literals |
| `BackendConfig.swift:15` | `URL(string: "...supabase.co")!` — static URL |
| `ResumeDesignService.swift:81` | `URLComponents(...)!` on known `apiBaseURL` |
| `OptimizedResumeViewModel.swift:250` | `URLComponents(...)!` on download URL |
| `TailorView.swift:57`, `HomeTabView.swift:65` | `selectedResumeName!` guarded by `isEmpty == false` |
| `ResumePreviewExportView.swift:116` | `viewModel.errorMessage!` — UI-only when error present |
| **No `try!`** found on network/Supabase/file paths in app target |

### WKWebView — missing navigation delegate (flagged)

| Component | Delegate? | Failure handling |
|-----------|-----------|------------------|
| `ResumePreviewWebView.swift` `WebKitHTMLView` (301–327) | **No** | HTML load failures are fire-and-forget; user may see blank web view while `html` state is set |
| `HTMLPDFExporter.swift` (29–71) | **Yes** (`WKNavigationDelegate`) | Failures and 20s timeout propagate to caller; **no OSLog** on timeout |

### Stale / misleading error messages

| Location | Issue |
|----------|-------|
| `APIClient.swift:15–16` | HTTP 402 → credit upsell copy while monetization disabled in live build |
| `APIClientError.localizedDescription` | `serverError` prefixes status code — UI should use `userFacingMessage` (lesson 2026-05-20); most ViewModels comply |

### Analytics wiring gaps (code vs production)

| Event | Wired at | Why missing in prod baseline |
|-------|----------|------------------------------|
| `free_ats_completed` | `HomeTabView.swift:537–539` | Only when guest ATS returns `score.overall`; likely v1.1 + infrequent guest completion |
| `diagnosis_viewed` | `ResumeDiagnosisView.swift:37` | Fires after load even if diagnosis nil (match_score 0) — sparse v1.0 traffic |
| `export_pdf_tapped` | `OptimizedResumeView.swift:892` | Likely not in App Store v1.0(4) binary |
| `submit_package_saved` | `SubmitApplicationViewModel.swift:254` | Deep flow; 0 production observations |

---

## Telemetry gaps

| Gap | What it blinds you to |
|-----|----------------------|
| **App Store Connect / Xcode Organizer crashes** | Native crashes, OOM, watchdog kills — no Sentry/Crashlytics in app |
| **PostHog `$exception` / crash events** | PostHog-ios sends custom events only; no automatic stack traces |
| **Live HogQL in this session** | Personal API key required for `/api/projects/270848/query/`; project capture key returned 403 on 2026-06-19 |
| **PostHog MCP tools** | Plugin tools exist under Cursor project cache but were **not callable** in this agent session — counts rely on 2026-06-18 baseline |
| **Supabase logs (api/postgres/auth/edge-function)** | Recurring 4xx/5xx, RLS denials, `delete_account` / `storekit-verify` runtime errors — **not queried** |
| **Supabase advisors (security/performance)** | RLS/policy and slow-query recommendations — **not queried** |
| **Backend Vercel/API logs** | `/api/upload-resume`, `/api/download`, optimize timeouts — outside iOS repo |
| **Supabase log retention window** | Even with MCP, edge logs are typically short-lived (~24h on many plans) |

---

## Recommended next action (post-Apple approval)

**Fix first:** Add `WKNavigationDelegate` to `ResumePreviewWebView`’s `WebKitHTMLView` and surface/log HTML load failures (`ResumePreviewWebView.swift:301–327`).

**Why this one:** Preview is on the critical path to styled PDF export (`renderedHTML` → `HTMLPDFExporter` → `ResumeExportAction`). Silent WKWebView failures explain “blank preview” and degraded exports with **no PostHog signal** and **no crash report**. It is a small, isolated change that improves observability and UX on the highest-value conversion step without touching ASC or monetization gates.

**Immediately after (same PR or follow-up):** Add `Logger` to `HTMLPDFExporter` timeout path (`HTMLPDFExporter.swift:42–45`) and unify export analytics across Me/History/Preview download paths.

**Operational:** Re-run this sweep with PostHog MCP + personal API key and Supabase MCP after v1.1 (5) ships, and pull App Store Connect crash logs for the first 7d live window (through 2026-06-24 D7 readout).

---

## Verification

- **EXD-011 honored:** No Swift, build, or ASC changes.
- **Secrets:** No keys/tokens printed in this report.
- **Git status after sweep:** Only `tasks/error-sweep-2026-06-19.md` should appear as a new/modified file (verify with `git status --short`).
