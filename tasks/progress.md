# Project Progress

**Fit-First Triage Story 1 — FitCheckService (2026-06-23):** Implemented the iOS service/model wedge for the existing anonymous `POST /api/public/ats-check` path. Added `FitVerdict`/`FitBand` under `Core/API/Models/` (path reconciled from the spec's `Models/FitVerdict.swift` to the actual API models layout), flexible snake/camel decoding, score clamping, and fallback band derivation from `score.overall` only when the server omits `fit.verdict`. Added `FitCheckServiceProtocol`, live `FitCheckService` on `APIClient.runPublicATSCheck`, an injectable mock, and `RuntimeServices.fitCheckService()`. `ATSScoreResult` now decodes optional additive `fit` without changing existing `score`/`preview`/`quickWins` fields. Validation passed: Debug iPhone 17 simulator build succeeded from a clean temp copy, and focused `FitCheckServiceTests` executed 6 tests with 0 failures. Live production `/api/public/ats-check` was reachable and returned HTTP 200 for a sample PDF + 100+ word JD, but the deployed response did not yet include `fit`; final external gate is to deploy Story 0 with the additive `fit` block and rerun the same live decode check.

**Resumely ATS Claim Defensibility (2026-06-20):** Implemented the approved positioning decision — the displayed score is a self-defined "Resumely Match Score", not an external ATS vendor's score. Copy/label-only changes (no scoring logic touched). Renamed user-facing "ATS Score/score" labels to "Resumely Match Score" (primary surfaces) or "Match Score" (constrained) across ScoreResultView, OptimizedResumeView, ExpertOutputViews, ImproveView, ApplicationDetailView, ApplicationCompareView, HomeActivationState, MarketingScreenshotView, MetricCard. Added explainer microcopy ("Based on formatting + keyword match vs the job you paste. Not affiliated with any ATS vendor.") near the score in ScoreResultView and the OptimizedResumeView score card (EN + HE). Reframed LinkedInShareComposer EN+HE share post to "Resumely match score". Updated Localizable.xcstrings (renamed keys + Hebrew). Audited App Store metadata: fixed docs/app-store/he-metadata.md ("ראה את ציון ההתאמה שלך ב-Resumely", "ציון התאמה של Resumely", removed "תתקבל לראיונות יותר" interview-outcome promo). Removed outcome-guarantee "Templates that pass ATS" → "ATS-friendly templates". Kept "ATS" only in descriptive contexts (ATS check / ATS insights / ATS match / ATS-friendly / template ATS attribute). Build: iPhone 17 Pro simulator Debug ** BUILD SUCCEEDED **. Flagged (generated artifacts, not fixed): dist/app-store-screenshots/{rb-aso-002,app-store-v1}/upload-manifest.md still say "Templates that pass ATS". PR #70 merged into `main` 2026-06-20 — **not yet released**; v1.1 (5) is the live App Store build and does not contain this copy. Fold into next build (1.1 (6)) before next submission. No App Store Connect submission made.

**PostHog Findings Remediation (2026-06-19):** Resolved the first actionable error-sweep findings in code: `ResumePreviewWebView` now installs a `WKNavigationDelegate`, surfaces non-cancelled WebKit preview load failures, and logs them via OSLog; `HTMLPDFExporter` now logs timeout, navigation, `createPDF`, and write failures; preview-toolbar export now emits `export_pdf_tapped`, `export_started`, `export_success`, and detailed `export_failed` codes when both styled HTML export and backend fallback fail. Validation passed: Debug simulator build on iPhone 17, focused `AnalyticsServiceTests` (9/9), and iPhone 17 Pro simulator install/launch smoke. PostHog connector refresh on 2026-06-19 appeared pointed at a different/current project context: last-7-day `$lib` values showed only `posthog-ios`, not the expected `$lib=resumely-ios-urlsession`, so production funnel counts were not refreshed from the 2026-06-18 baseline in this remediation session.

**v5 / 1.1 (5) Submitted for App Store Review (2026-06-18):** Version 1.1 build 5 submitted to Apple for review. Bumped CURRENT_PROJECT_VERSION to 5 and MARKETING_VERSION to 1.1 (required because version 1.0 is locked after approval). Archived and uploaded via Xcode Organizer. PostHog analytics confirmed live during smoke: app_launched, resume_uploaded, optimization_started, ats_improve_tapped all firing. Promotional Text and "What's New in This Version" filled in ASC. Apple review window: ~48h, expected approval before 2026-06-21 D7 Gate A deadline. PR #68 (docs: v5 spec + plan) is open.

Status: LIVE on the App Store — v1.1 (5), confirmed live by founder 2026-06-21. ATS claim defensibility copy fix (PR #70) merged to `main` but not yet shipped — pending build 1.1 (6).
Current Phase: Post-launch — D7 Gate A monitoring. App is live; no approval pending. Next build (1.1 (6)) pending to carry ATS copy fix.
Active Story: D7 activation readout once 7 days of live data exist (~2026-06-28).
Last Completed Story: v1.1 (5) approved and live on the App Store (founder-confirmed 2026-06-21).
Next Recommended Story: (1) D7 readout ~7 days after go-live (~2026-06-28) — pull 7-day activation funnel from PostHog dashboard 1720819. (2) Bump to 1.1 (6), archive, and submit to carry PR #70 ATS copy fix. (3) Regenerate App Store screenshots before next submission. (4) Monitor reviews + crash/error events.
Blockers: None. App is live.
Last Validation: 2026-06-21 founder confirmed v1.1 (5) live on the App Store. PR #70 build verified on iPhone 17 Pro simulator (Debug) — BUILD SUCCEEDED.
Last Updated: 2026-06-21

**D7 Gate A PR Merge Closeout (2026-06-18):** PR #63 (Hebrew/RTL) and PR #61 (Monetization/Ambassador scaffolding) were reviewed, repaired where needed, marked ready, and merged into `main`. Local validation after both merges passed with `xcodebuild -scheme "ResumeBuilder IOS APP" -destination "platform=iOS Simulator,name=iPhone 17" -configuration Debug build`. Remaining follow-up: real-device Hebrew preview/PDF QA, manual App Store Connect Hebrew metadata submission, and future monetization implementation behind `BackendConfig.isMonetizationEnabled`.

**Monetization/Ambassador Scaffolding (reviewed 2026-06-18):** PR #61 adds parked StoreKit purchase-tier, credit-cache, paywall-draft, and ambassador-flow scaffolding for future monetization work. It is not live-gated into export or Profile flows; existing `BackendConfig.isMonetizationEnabled = false` remains the release guard. During review, the draft StoreKit paywall view and file were renamed to avoid colliding with the existing gated Profile `PaywallView`.

**Hebrew / RTL (2026-06-16, reviewed 2026-06-18):** PR #63 adds Hebrew app localization support: `he` region and `CFBundleLocalizations`, runtime language selection via `LocalizationManager`, localized bundle override, app-root locale/layout-direction injection, Hebrew String Catalog coverage, a Me-tab language picker, RTL resume preview/PDF handling based on resume content, and Hebrew App Store metadata in `docs/app-store/he-metadata.md`. Remaining after merge: real-device Hebrew resume preview/PDF QA and manual App Store Connect Hebrew metadata submission.

**PostHog Real-Device QA (2026-06-17):** Connected PostHog plugin was switched to project 270848 ("ResumeBuilder AI") and dashboard 1720819 resolved. `AnalyticsEvent` contract tests now cover all 16 app-defined event names/properties, including `account_deleted`. Physical iPhone 13 Debug build/install/launch passed, focused `AnalyticsServiceTests` passed 8/8 on device, and PostHog showed fresh device-QA events after `2026-06-17T12:25:25Z`: `app_launched`, `resume_uploaded`, `job_added`, and `optimization_started`. Remaining live-observation gap: `free_ats_completed`, `diagnosis_viewed`, `ats_improve_tapped`, `export_pdf_tapped`, `submit_package_saved` are wired/test-covered but still need an authenticated manual smoke to appear in production data. Report: `docs/qa/reports/posthog-real-device-qa-2026-06-17.md`.

**D7 Gate A Build 4 Check (2026-06-18):** `main` was synced and analytics/QA work was committed/pushed. Release archive and App Store export for version 1.0 build 4 succeeded locally. CLI upload reached App Store Connect but was rejected because bundle version `4` had already been uploaded, indicating build 4 is already present in App Store Connect. App Store Connect review submission still needs UI/API confirmation.

**D7 Gate A PostHog Baseline (2026-06-18):** PostHog project 270848 shows fresh iOS `$lib = resumely-ios-urlsession` activity since 2026-06-18T00:00:00Z, including `app_launched`, `resume_uploaded`, `job_added`, `optimization_started`, `optimization_completed`, and `diagnosis_viewed`. Seven-day counts also include `ats_improve_tapped`. Remaining gaps: `export_pdf_tapped`, `submit_package_saved`, and `free_ats_completed` are not yet in PostHog taxonomy; local iPhone 17 simulator launch screenshot was blocked by a wedged simulator install/launch. Report: `docs/qa/posthog-gate-a-baseline-2026-06-18.md`.

**D7 Gate A Stranded Work Cleanup (2026-06-18):** Reopened draft PR #63 for the Hebrew/RTL localization branch and draft PR #61 for the monetization/Ambassador/StoreKit branch before deleting their local branches. Deleted superseded docs-only `feat/localization-updates` after confirming its work-pack file matches `main`. Agentic OS janitor removed all Resumely agent worktrees; non-agent `version-2` worktree remains intentionally untouched.

**App Store Live + Launch Analytics (2026-06-17):** Founder reported Resumely iOS is live in the App Store. Live PostHog QA for project 270848 verified iOS analytics are healthy: `$lib=resumely-ios-urlsession`, 190 events / 18 users in the last 7 days, last event 2026-06-17. D7 dashboard is the iOS north-star dashboard: [ResumeBuilder iOS - D7 Activation](https://us.posthog.com/project/270848/dashboard/1720819).

**Post-Live D7 Readout Pre-Read (2026-06-17):** Connected PostHog plugin source access is verified for project 270848 and dashboard 1720819. Live HogQL read: `$lib=resumely-ios-urlsession`, 188 events / 18 users over the trailing 7 days, last event 2026-06-17T03:06:44.021Z. Since the App Store-live anchor of 2026-06-17T00:00:00Z, PostHog shows 2 `app_launched` events / 2 users and 2 `guest_mode_started` events / 2 users. This is a Day 0 / D7-pre-read; the first complete D7 window from the 2026-06-17 launch anchor ends on 2026-06-24. Report: `docs/qa/reports/post-live-d7-readout-2026-06-17.md`.

**PostHog Analytics Integration (2026-06-16):** Wired 8 core funnel events for D7 activation data: app_launched (pre-existing), resume_uploaded (file_type), optimization_started (pre-existing), optimization_completed (pre-existing), diagnosis_viewed (match_score), ats_improve_tapped (current_score), export_pdf_tapped, submit_package_saved (has_cover_letter). PR #60 merged.

**Resume Aha Moments (2026-06-12):** Implemented the diagnosis-first resume/job flow in V2: grounded match guidance, top gaps, missing keywords, recruiter-eye review, before/after rewrite, confidence checklist, smart empty/loading copy, backend-diagnosis decode hook, and conservative mocked/fallback diagnosis data.

Project: ResumeBuilder iOS
Status: v1.1 (5) in Apple review (submitted 2026-06-18). v1.0 (4) live.
Current Phase: Awaiting Apple review — passive monitoring only (EXD-011). D7 readout scheduled 2026-06-24.
Active Story: None — no code or ASC changes during review per EXD-011.
Last Completed Story: v1.1 (5) submitted 2026-06-18 — Hebrew localization, monetization scaffolding, analytics events wired.
Next Recommended Story: D7 readout on or after 2026-06-24 via PostHog plugin (dashboard 1720819). Then decide on post-D7 ASO packet.
Estimated Completion: Awaiting Apple approval (~48h from 2026-06-18).
Blockers: None. Waiting on Apple review. Do not touch ASC or build during review.
Risks: Apple rejection resets D7 metrics window. Hebrew/RTL real-device PDF QA still pending.
Last Validation: 2026-06-19 observability fix passed Debug iPhone 17 simulator build, focused AnalyticsServiceTests 9/9, and iPhone 17 Pro simulator install/launch smoke. v1.1 (5) remains in Apple review from 2026-06-18.
Last Updated: 2026-06-20
Current Branch: main
Latest Base Commit: current `main` after D7 Gate A closeout cleanup
Active Spec: docs/specs/resume-aha-moments.md
Latest QA Report: docs/qa/posthog-gate-a-baseline-2026-06-18.md

## Tab Structure (as of 2026-05-20)
| Tab | Index | View | VM |
|-----|-------|------|----|
| Tailor | 0 | TailorView | TailorViewModel (stable @State) |
| Optimized | 1 | OptimizedResumeTabView → OptimizedResumeView | OptimizedResumeViewModel (built from appState.latestOptimizationId) |
| Design | 2 | RedesignResumeView | DesignViewModel (stable @State) |
| Expert | 3 | ExpertTabView → ExpertModesView | ExpertModesViewModel (built from appState.latestOptimizationId) |
| Me | 4 | ProfileView (with inline applications) | — |

## Key Shared State
- `AppState.latestOptimizationId: String?` — persisted via UserDefaults; set on optimize success AND when opening Latest Resume from Me tab or View Optimized Resume from Application Detail; drives Optimized+Expert+Design tabs
- `AppState.bootstrap()` clears stale persisted `mock-` optimization IDs so old local state cannot call live endpoints with mock identifiers
- Runtime service defaults are live-only via `RuntimeServices`; mocks remain available only through explicit tests/previews
- `RuntimeFeatures.isResumeLibraryEnabled = true` on current `main` because `/api/v1/resumes` was confirmed live; saved-resume UI is available again.
- Design history is not loaded automatically because `/api/v1/styles/history` currently returns 500; Apply/Undo use the stable design endpoints without blocking normal preview/design navigation
- Upload preflight rejects missing, empty, unsupported, malformed, and no-readable-text PDFs before calling `/api/upload-resume`; readable PDFs are re-emitted as simple text-layer PDFs and multipart includes `resumeText` so the backend can fall back when parser internals fail
- Optimization detail now carries `contact`; iOS preview/copy uses real candidate identity and local fallback no longer fabricates placeholder contact values
- Design render/preview/export resolves backend template UUIDs to category+slug and iOS reloads current design assignment after Apply/Undo so Optimized reflects the applied template
- Design apply treats assignment as the stable source of truth when the secondary customize endpoint returns the live "Optimization not found" 404 after assignment succeeds
- Design category switching is user-owned after the initial assignment load; subsequent category changes do not reload current assignment and cannot reset the UI back to the applied Traditional template
- Optimized preview starts rendering immediately from `optimizationId`; local section/contact HTML replaces the spinner as soon as details load, and cached backend design HTML can still upgrade the web view asynchronously
- Optimized/Design preview now resets stale design state on optimization changes, pauses preview network work when hidden behind another tab, debounces Design preview customization changes, and avoids redundant WKWebView reloads for unchanged HTML
- PDF export retains its off-screen WKWebView, times out stalled client-side PDF rendering, writes share files to stable Caches export URLs, falls back to backend download, then generates a local text-layer PDF from loaded optimization sections/contact data before surfacing an export failure
- Expert workflows accept user evidence input from iOS, parse backend-real structured outputs (summary options, quantified bullets, ATS keyword analysis, cover letters, screening answers), preserve selected variants for apply, let full rewrites apply selected sections, save applied reports to linked applications, and force no-cache optimized-section reload plus ATS score refresh when the backend returns a new score
- Expert tab links saved reports to Me applications by matching either `optimization_id` or `optimized_resume_id` from `/api/v1/applications`
- rb-aso-002 screenshot mode is launch-argument-only (`--marketing-screenshot --screenshot-slot N`) and renders App Store screenshot slots without changing the normal `RootView` path
- Home/Tailor optimize waits now use an inline SwiftUI resume-scanning animation with optimization and free-ATS copy variants; no backend progress contract is implied
- Optimized resume now supports manual section edits from the Improve bottom bar. Manual saves reuse `/api/v1/refine-section/apply`, update the local section body/status to `edited`, clear stale optimization-detail cache for that optimization, and refresh headline ATS scores via `/api/ats/rescan`.
- Optimized resume now supports an assisted Submit Package flow. It refreshes optimization detail before package generation, downloads the optimized resume PDF, runs Cover Letter Architect and Screening Answer Studio, previews a draft package, then saves it to Me only after user confirmation. Saving creates a saved application, attaches the optimized resume, saves Expert reports, and presents share/copy/submit-at-link actions without attempting third-party auto-submit.
- Submit Package now allows missing role/company context with visible fallback copy and safe placeholders (`Target Role`, `Company not specified`) so live job parsing gaps do not make the primary action look broken.
- Optimized resume now has a normal in-app ATS insight panel that maps App Store screenshot claims to a reachable product surface: headline score, before/after delta, score signals, top blockers/actions, Improve ATS, and an explicit low-score explanation when the optimized score remains below 55.
- Home/Tailor now route successful resume/job optimization into a V2 Resume Diagnosis screen before the full Improve tab. Diagnosis shows estimated match guidance, potential score, top gaps, missing keywords, recruiter-eye review, before/after rewrite, and grounded CTAs to improve or edit the target job.
- Optimized resume now reuses the diagnosis mapper for a compact recruiter snapshot and confidence checklist so the user sees why the resume is stronger before export/payment.
- iOS optimize requests now ask for `optimization_mode: strong_faithful` with a substantial-but-factual quality profile. The Optimized tab surfaces ATS status/blockers when returned by optimization detail, offers an Improve ATS action through the existing Expert ATS workflow/apply path, and uses a focused section-editor sheet with empty-section validation and dirty-state discard protection for manual amendments.
- Me/Application Detail now acts as a package hub when application rows include an optimization, resume link, job link, or saved cover-letter report: users can share/download the optimized resume PDF, copy the cover letter, open the job link, and see ATS status. Submit Package bumps an app-wide applications refresh token so Me reloads when active.

## Key Wiring (2026-05-20)
- `ProfileView` now accepts `onSwitchTab` from `MainTabViewV2.switchTab` — "Send to Expert" / "Open Design" buttons in preview work from Me tab
- `ApplicationDetailView` now accepts `onSwitchTab` — passed through to `OptimizedResumeView` opened from application rows
- `ExpertModesViewModel` now takes `applicationId` — loads saved expert reports via `ApplicationTrackingService`; `ExpertSavedReportDetailView` fetches and renders individual saved runs

## Files Deleted This Spec
- `Features/Score/ScoreView.swift`
- `Features/Score/ScoreViewModel.swift`
- `Features/V2/Profile/ProfileViewV2.swift`
- `Features/Track/ApplicationsListView.swift`

Notes: App is v1.0 build 4 (resubmission). Archive from `main`. V2 folder is active target for all new screens. Dark mode only.
