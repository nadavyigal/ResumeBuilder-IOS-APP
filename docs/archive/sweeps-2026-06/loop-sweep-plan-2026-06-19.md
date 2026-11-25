# Loop Sweep Plan — Resumely iOS (2026-06-19)

Two single-run agent loops from the Forward Future Loop Library, tailored to this repo. Run each in its own fresh session opened in this repo. Mirrors the RunSmart iOS sweep.

## Repo facts (verified 2026-06-19)
- **Live build: v1.0 (4)** on the App Store (live since 2026-06-17). **v1.1 (5) is in Apple review** (submitted 2026-06-18) — NOT yet live.
- **EXD-011 (their own rule): no code or ASC changes during review. Do not touch ASC or build.** Error Sweep is report-only (safe). Docs Sweep must be docs-only (no source/build/ASC) or deferred until after approval.
- Thick native app: ~23K LOC Swift, 146 files, SwiftUI 5-tab (Tailor/Optimized/Design/Expert/Me), MVVM. WKWebView used ONLY for resume preview (`Features/V2/Preview/ResumePreviewWebView.swift`) and PDF export (`Core/Export/HTMLPDFExporter.swift`).
- Telemetry: **PostHog only, no Sentry/Crashlytics.** Project **270848 ("ResumeBuilder AI")**, dashboard **1720819**, `$lib=resumely-ios-urlsession`. Crashes live only in App Store Connect / Xcode Organizer (not reachable from a terminal session).
- Backend: Supabase project **brtdyamysfmctrhuankn**, edge functions `delete_account` and `storekit-verify`.
- StoreKit/monetization and Apple Sign-In are GATED OFF in the live build (`BackendConfig.isMonetizationEnabled = false`, `isAppleSignInEnabled = false`) — those native error paths are not active in production; do not over-prioritize them.
- Build: `xcodebuild` (no Fastlane). Scheme `ResumeBuilder IOS APP`. iOS 17+, Swift 6 (strict concurrency).
- D7 Gate A readout scheduled 2026-06-24.

## Priority
- **Run A (Error Sweep) now** — report-only, safe during review, real funnel data available.
- **Hold B (Docs Sweep)** until after the 2026-06-24 D7 readout, OR run strictly docs-only if you want it sooner.

## Cross-project note
RunSmart's error sweep reported "pollution" by `resume_uploaded`/`ats_*`/`optimization_*` events — those are THIS app's events in project 270848. That means RunSmart's PostHog MCP was bound to project 270848, not RunSmart's project. Fix the RunSmart MCP project binding before trusting RunSmart funnel reads.

---

# PROMPT 1 — Production Error Sweep (report-only)

```
You are running a single-pass "Production Error Sweep" on the Resumely iOS app (native SwiftUI + Supabase + PostHog-ios, with WKWebView used only for resume preview/PDF export). This is a REPORT-ONLY run: do NOT change any Swift code, do NOT open a PR, and do NOT touch the build or App Store Connect. Produce a triaged error/risk report only.

Repo: /Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP
Live build: v1.0 (4) on the App Store (live since 2026-06-17). v1.1 (5) is in Apple review. RULE EXD-011: no code/build/ASC changes during review — report-only honors this; do not violate it.

Telemetry reality: NO Sentry/Crashlytics. PostHog-ios captures analytics events, not crashes. Crash data lives in App Store Connect / Xcode Organizer, which you cannot query from here — treat that as a documented gap, do not fabricate crash numbers.

Read first (so you don't re-surface known items):
- ~/.claude/ERRORS.md
- this repo's tasks/lessons.md, tasks/progress.md, tasks/ERRORS.md (if present), docs/qa/posthog-gate-a-baseline-2026-06-18.md

Signals to pull (use what you can reach; note what you can't):
1. PostHog (use PostHog MCP tools): CONFIRM you are querying project 270848 ("ResumeBuilder AI"), $lib=resumely-ios-urlsession, dashboard 1720819. Last 7 days: look for $exception events, error/failure events, and drop-offs across the activation funnel (app_launched -> resume_uploaded -> optimization_started -> free_ats_completed/diagnosis_viewed -> ats_improve_tapped -> export_pdf_tapped). Note which wired events (free_ats_completed, diagnosis_viewed, ats_improve_tapped, export_pdf_tapped, submit_package_saved) are NOT appearing in production. Also note whether any RunSmart-specific events (sign_in_completed, run_started, plan_generated) appear here — if so, the two apps share this project (report it).
2. Supabase (use Supabase MCP tools) for project brtdyamysfmctrhuankn: run get_logs (api / postgres / auth / edge-function) and get_advisors (security + performance). Capture recurring 4xx/5xx, RLS denials, slow queries, and any errors from edge functions delete_account and storekit-verify.
3. Static Swift error-handling audit. Focus on:
   - Core/API/APIClient.swift — error parsing/handling, swallowed catches, stale error messages
   - Core/Auth/ (AuthService, KeychainStore, JWTDecoder) — auth failure paths
   - Core/Export/HTMLPDFExporter.swift — 20s render timeout has no recovery logging; confirm failures are surfaced
   - Features/V2/Preview/ResumePreviewWebView.swift — has NO WKNavigationDelegate, so HTML render failures are fire-and-forget (silent). Flag this.
   - Services/ (ResumeOptimizationService, upload, analysis) — silent nil/empty fallbacks
   - Look for force-unwraps (!) and force-tries (try!) on network/Supabase/file paths. Cite file:line.
   NOTE: StoreKit/monetization (Core/Payments) and Apple Sign-In are GATED OFF in the live build — flag issues but mark them as "not active in production v1.0(4)".

Steps:
1. Pull the signals above, recording raw counts.
2. Cluster into distinct issues by root cause (not message string).
3. Triage each cluster: severity = frequency x distinct-users x flow-criticality (resume upload -> optimization -> export is the core conversion path; auth is critical). Assign Critical/High/Medium/Low.
4. For each High/Critical, trace to a probable root cause in Swift and cite file:line. Do NOT fix.
5. Write the report (below). Include a "telemetry gaps" section (App Store Connect crashes not reachable, Supabase log window limits, etc.).

Stop condition: every reachable error cluster is triaged and the top items are root-caused — or state explicitly that no actionable errors were found. No code/build/ASC changes.

Output: write to tasks/error-sweep-2026-06-19.md in this repo, with:
- Summary: errors seen, # distinct clusters, # actionable, time window, sources queried, PostHog project confirmed.
- Ranked table: Severity | Issue | Count(7d) | Users affected | Source | Root cause (file:line) | Suggested fix (one line).
- Static-audit findings: silent catches / force-unwraps / missing nav-delegate (file:line).
- Telemetry gaps: what you could not reach and what it blinds you to.
- Recommended next action: the single issue to fix first (post-approval), and why.

Guardrails:
- Read-only against production. Never run write/delete queries against Supabase or PostHog.
- No secrets in the report (no keys/tokens/connection strings, no raw PII — aggregate counts only).
- Do NOT modify source, build, or App Store Connect (EXD-011).
- Verify at the end that no source files changed: `git status --short` should show only the new tasks/error-sweep-*.md. Do not commit or push unless I explicitly ask.
```

---

# PROMPT 2 — Docs Sweep (docs-only PR) — HOLD until after 2026-06-24 unless needed

```
You are running a single-pass "Docs Sweep" on the Resumely iOS app. Goal: bring the highest-value docs in line with the current code and ship as ONE reviewable PR. CONSTRAINT EXD-011: the app is in Apple review — this PR must be DOCS-ONLY. Do NOT change any source, build settings, or App Store Connect. If a correction would require touching code, STOP and report it instead.

Repo: /Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP

Read first: tasks/lessons.md, tasks/progress.md, CLAUDE.md, AGENTS.md.

Priority targets (verify each claim against code BEFORE editing):
1. docs/architecture/current-ios-architecture.md — dated 2026-05-13, ~5 weeks stale. Update to reflect what landed since: Hebrew/RTL localization (LocalizationManager, he locale), monetization/ambassador scaffolding (GATED OFF behind BackendConfig.isMonetizationEnabled=false — say "parked/scaffolded, not live"), the Expert tab, and the PostHog analytics layer. Clarify WKWebView SCOPE: it is used ONLY for resume preview (Features/V2/Preview/ResumePreviewWebView.swift) and PDF export (Core/Export/HTMLPDFExporter.swift), NOT as an app wrapper.
2. tasks/progress.md status line — confirm it matches reality: v1.0 (4) live, v1.1 (5) in Apple review (do not claim v1.1 live unless ASC/git confirms approval).
3. PostHog event contract — verify the 16 events defined in Core/Analytics/AnalyticsService.swift match what docs/qa/posthog-gate-a-baseline-2026-06-18.md lists. Flag any drift.
4. (Optional) Add a short lesson index to the top of tasks/lessons.md if it is long and unindexed — a 5-10 line quick-reference table by category. Do NOT rewrite existing lessons.

Ground-truth sources to check against:
- iOS target / Swift version: ResumeBuilder IOS APP.xcodeproj/project.pbxproj (IPHONEOS_DEPLOYMENT_TARGET=17.0, SWIFT_VERSION=6.0)
- Feature flags: Core/Config/BackendConfig.swift (isMonetizationEnabled, isAppleSignInEnabled)
- Analytics events: Core/Analytics/AnalyticsService.swift
- Backend: Supabase project brtdyamysfmctrhuankn, edge functions delete_account + storekit-verify
- Live build status: git log (authoritative)

Scope gate (honors my global rules + EXD-011): edit ONLY docs whose claims you have PROVEN stale. Do NOT edit source code, build settings, or these history/record files: tasks/MEMORY.md, tasks/session-log.md, docs/qa/reports/*, docs/specs/* (unless a spec is provably wrong). If the sweep wants to touch more than ~6 files, STOP and surface it.

Steps:
1. For each target doc, verify the specific claim against the ground-truth source above.
2. Edit ONLY wrong claims. Match each doc's voice/structure; no unsolicited restructuring.
3. Add "Last verified: 2026-06-19" where the doc uses a date/header convention.
4. Confirm the change is docs-only: `git status --short` must show ONLY .md files. Do NOT build or run xcodebuild (avoid touching the project during review).
5. Create a branch, commit, push, open a PR. Update tasks/progress.md per the global commit rule.

Stop condition: target docs match implementation and the change is one docs-only PR. Anything beyond proven-stale docs is listed in the PR description as "follow-up, not done in this PR".

Suggested branch: claude/ios-docs-sweep-2026-06-19
PR title: docs: sweep stale Resumely iOS architecture/analytics docs to match current code
PR body: bullet each correction (before -> after), plus "Not changed (out of scope)" and "Follow-ups". State explicitly that the PR is docs-only and makes no source/build/ASC changes (EXD-011 safe).

Verification:
- `git status --short` shows only .md files (+ tasks/progress.md).
- The PR diff is reviewable in minutes — fact corrections only.
- End by reporting push state: `git status --short --branch` and `git log --oneline @{u}..`. If you cannot push/open a PR, end with exactly: "N commits are local-only on branch X - you need to push and open a PR."

Guardrails:
- DOCS ONLY. No source, build, or ASC changes (EXD-011). No new dependencies. No secrets added to docs.
```

---

## How to run
1. **Session 1** — open in this repo, paste **Prompt 1** (Error Sweep). Report-only; review `tasks/error-sweep-2026-06-19.md`. Safe to run during Apple review.
2. **Session 2** (separate, ideally after 2026-06-24) — paste **Prompt 2** (Docs Sweep). Review the docs-only PR.
3. This plan file can be committed or deleted — it is a one-off working note.
