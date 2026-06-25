# Session Log — ResumeBuilder iOS

> One entry per work session. Most recent first.
> Update at the end of every session before closing.

## Entry Format

**Date:** YYYY-MM-DD
**Task:** _What was worked on_
**Files Changed:** _List of changed files_
**Decisions Made:** _Key decisions or tradeoffs_
**Next Recommended Action:** _What to do next session_

---

## Sessions

**Date:** 2026-06-25
**Task:** QA the uncommitted Resumely activation redesign pass against the work-pack, fix everything found, commit and push.
**Files Changed:** `Core/API/UploadFilePreflight.swift`, `Core/Analytics/AnalyticsService.swift`, `Features/Profile/ProfileView.swift`, `Features/Score/ScoreResultView.swift`, `Features/Tailor/TailorViewModel.swift`, `Features/V2/Design/DesignTabView.swift`, `Features/V2/Expert/ExpertTabView.swift`, `Features/V2/Home/HomeTabView.swift`, `Features/V2/Home/ResumeOptimizationLoadingView.swift`, `Features/V2/Home/ConnectionLostView.swift` (new), `Features/V2/Improve/OptimizedResumeTabView.swift`, `Features/V2/Improve/OptimizedResumeView.swift`, `Features/V2/Improve/ImproveView.swift` (dead wiring removed), `Resources/Localizable.xcstrings`, `tasks/todo.md`, `tasks/progress.md`, `tasks/lessons.md`, `tasks/session-log.md`.
**Decisions Made:** Fixed the WP-18 `.doc` regression by completing preflight support rather than re-narrowing the picker; instrumented the new upload sheet rather than leaving a fresh measurement blind spot; replaced fake duplicate sub-scores with real-data stats rather than hiding the discrepancy; rewired target-reached/save-account from the dead `ImproveView` into the live `OptimizedResumeView`; chose not to build a separate E2 "match job" screen since it would conflict with the shipped Home IA, and documented that as a deliberate call rather than a silent gap; added connection-lost recovery with manual-only retry since no `NWPathMonitor` infrastructure exists.
**Next Recommended Action:** Founder: resolve Apple Distribution signing and submit 1.1 (7) — it now contains Fit-First, WP-18, and the full QA'd redesign. Manual simulator/device visual QA still recommended before submission since this pass verified via code + build + test, not interactive UI smoke.

**Date:** 2026-06-25
**Task:** Implement buildable first pass of the Resumely activation redesign work-pack.
**Files Changed:** `Core/DesignSystem/Tokens/AppColors.swift`, `Core/API/UploadFilePreflight.swift`, `Features/Tailor/TailorViewModel.swift`, `Features/V2/Home/HomeTabView.swift`, `Features/V2/Home/UploadSheetView.swift`, `Features/V2/Home/UploadFailureView.swift`, `Core/DesignSystem/Components/LockedTabTeaser.swift`, `Features/V2/Improve/OptimizedResumeTabView.swift`, `Features/V2/Design/DesignTabView.swift`, `Features/V2/Expert/ExpertTabView.swift`, `Features/Profile/ProfileView.swift`, `Features/Score/ScoreResultView.swift`, `Features/V2/Improve/ImproveView.swift`, `Features/V2/Improve/TargetReachedView.swift`, `Features/V2/Improve/SaveAccountSheetView.swift`, `tasks/todo.md`, `tasks/progress.md`, `tasks/lessons.md`, `tasks/session-log.md`.
**Decisions Made:** Kept paste-text/sample résumé disabled because backend/demo paths are not present; tightened Home picker to PDF/DOCX because preflight rejects `.doc`; used completed-only locked-tab checklist state because pre-optimization resume/job state is still local to Home; restyled first-score without fake sub-scores or point deltas; wired target celebration only when a real ATS rescan crosses 80.
**Next Recommended Action:** Run deeper tap-through visual QA across upload sheet/failure states/locked tabs/Me EN+HE/free score reveal; add an iPhone SE simulator or equivalent compact device smoke; then scope backend/state follow-ups for the remaining flags.

**Date:** 2026-06-25
**Task:** Review + merge PR #80 (WP-18 upload/import instrumentation + docx picker).
**Files Changed:** `Features/Tailor/TailorViewModel.swift`, `Features/V2/Home/HomeTabView.swift`, `tasks/progress.md`, `tasks/session-log.md`.
**Decisions Made:** Found docx picker regression — sandbox copy always used `picked_resume.pdf`, breaking preflight for Word files; fixed by preserving extension. Home `resume_uploaded` on pick now uses actual file type. Merged with merge commit (`0e38ce1`), branch deleted.
**Next Recommended Action:** After organic traffic, read PostHog funnel `guest_mode_started → resume_upload_cta_tapped → resume_file_selected → resume_upload_succeeded → job_added`; instrument Scan flow as fast-follow.

**Date:** 2026-06-24
**Task:** WP-18 — diagnose + instrument Resumely upload/import friction (the WP-16 guest→resume_uploaded leak); widen file picker to DOCX.
**Files Changed:** `Core/Analytics/AnalyticsService.swift`, `Features/Tailor/TailorViewModel.swift`, `Features/Tailor/TailorView.swift`, `Features/V2/Home/HomeTabView.swift`, `ResumeBuilder IOS APPTests/AnalyticsServiceTests.swift`.
**Decisions Made:** Instrumented the shared `TailorViewModel` (Home + Tailor share it) so both surfaces are covered; placed file_selected/preflight in `cachePickedFile`, upload started/succeeded/failed in `optimize()`. Widened both `.fileImporter`s to PDF+DOCX+DOC since preflight/backend already accept docx. Deferred the separate Scan flow. Error events kept precise (picker-level only) to avoid misattributing non-upload errorMessage changes.
**Next Recommended Action:** Open PR + merge; after a clean cohort, read `guest_mode_started → resume_upload_cta_tapped → resume_file_selected → resume_upload_succeeded → job_added` to name the real drop. Then consider instrumenting the Scan flow.

### 2026-06-24 (WP-16 Activation Attribution + Funnel Diagnostic)
**Task:** Classify `067544b5`, recompute Resumely activation attribution, and name the measurable funnel drop-off.
**Files Changed:**
- `docs/qa/reports/wp-16-activation-attribution-funnel-2026-06-24.md` — source-backed attribution and funnel diagnostic.
- `tasks/progress.md` — recorded cleaned activation state and next recommended story.
- `tasks/session-log.md` — this entry.
**Decisions Made:**
- `067544b5` is excluded from organic activation. PostHog shows backend completion on 2026-06-10 followed by later iOS sign-in, all classified as Automation / bot-like traffic.
- Real-organic activation remains 0 confirmed users. The prior 3/35 raw readout should not be treated as a success signal.
- Largest measurable drop-off is before optimization: saved iOS funnel drops from 26 `guest_mode_started` users to 5 `resume_uploaded` users.
- Next packet should target upload/import friction and missing preflight/error instrumentation. This does not reverse the founder decision to ship Fit-First visible; it says the next new fix should address the earlier funnel loss.
**Validation:**
- PostHog project 270848 verified as "ResumeBuilder AI" in UTC.
- Saved insight `VH410GF1` read and run for 2026-06-10 through 2026-06-24.
- Live HogQL person and cohort reads completed without selecting full event property blobs.
- `git diff --check` passed in Agentic OS, Resumely iOS, and ResumeBuilder Web.
**Next Recommended Action:** Scope a focused upload/import friction packet before monetization, paid acquisition, score-copy nudges, or more GTM volume.

### 2026-06-23 (WP-13 Fit-First Release)
**Task:** Ship Fit-First Triage dark in v1.1 build 6; internal flag-on validation; flip decision
**Files Changed:**
- `ResumeBuilder IOS APP.xcodeproj/project.pbxproj` — CURRENT_PROJECT_VERSION 6 (release branch)
- `ResumeBuilder IOS APP/Core/API/BackendConfig.swift` — flag ON on internal branch only
- `ResumeBuilder IOS APPTests/FitCheckViewModelTests.swift` — live production smoke + Hebrew RTL tests
- `docs/qa/reports/wp-13-fit-check-live-smoke-2026-06-23.md` — smoke evidence
- `tasks/progress.md`, `tasks/MEMORY.md`, `tasks/session-log.md` — WP-13 status
- Agentic OS `DECISIONS.md` — flip defer to 2026-06-24 D7 readout
**Decisions Made:**
- Public build 6 ships dark (`isFitCheckEnabled=false`)
- Flip deferred to D7 readout 2026-06-24 (no percentage rollout gate exists)
- Internal validation branch: `feat/wp-13-fit-check-internal`
**Next Recommended Action:** Founder: Xcode Organizer → archive `release/wp-13-v1.1-build-6` → upload build 6 → submit for App Store review. After D7 readout 2026-06-24, open flip PR if Gate A stable.

### 2026-06-23 (Fit-First Triage Story 1)
**Task:** Implement FitCheckService model/service layer for the Fit-First Triage wedge
**Files Changed:**
- `ResumeBuilder IOS APP/Core/API/Models/FitVerdict.swift` — added `FitVerdict` + `FitBand` with flexible decoding, score clamping, and fallback band derivation.
- `ResumeBuilder IOS APP/Core/API/FitCheckService.swift` — added protocol, live APIClient-backed service, mapping error, and injectable mock.
- `ResumeBuilder IOS APP/Core/API/Models/DomainModels.swift` — added additive optional `fit` decode to `ATSScoreResult` while preserving existing public ATS fields.
- `ResumeBuilder IOS APP/Core/API/RuntimeServices.swift` — exposed the live fit-check service factory.
- `ResumeBuilder IOS APP/Models/ResumeDiagnosis.swift` — accepted `detail` as a backend alias for gap explanations.
- `ResumeBuilder IOS APPTests/FitCheckServiceTests.swift`, `ResumeBuilder IOS APP.xcodeproj/project.pbxproj` — added focused test coverage and explicit test-target membership.
- `tasks/todo.md`, `tasks/progress.md`, `tasks/MEMORY.md`, `tasks/lessons.md`, `tasks/session-log.md` — recorded story status, validation, and lessons.
**Decisions Made:**
- Placed `FitVerdict.swift` in `Core/API/Models/` instead of the spec's generic `Models/` path to match the app's actual API model layout.
- The server verdict wins when present; iOS derives Strong/Stretch/Skip from `score.overall` only if the additive `fit` block omits `verdict`.
- Kept the live implementation on existing `APIEndpoint.publicATSCheck`/`APIClient.runPublicATSCheck` and did not add a parallel endpoint, URL, package, or UI.
**Validation:**
- Debug iPhone 17 simulator build passed from a clean temp copy.
- Focused `FitCheckServiceTests` passed: 6 executed, 0 failures.
- Production `/api/public/ats-check` returned HTTP 200 for a sample PDF + 100+ word JD through `x-session-id`, but the deployed payload still lacked `fit`; Story 0 deployment is the remaining external verification gate.
**Next Recommended Action:** Deploy/verify Story 0 so `/api/public/ats-check` returns additive `fit`, rerun the live decode check, then begin Story 2 UI work behind the feature flag.

### 2026-06-19 (PostHog findings remediation)
**Task:** Resolve actionable PostHog/error-sweep findings for silent preview and PDF export failures
**Files Changed:**
- `ResumeBuilder IOS APP/Features/V2/Preview/ResumePreviewWebView.swift` — added `WKNavigationDelegate` to the HTML preview wrapper, surfaced non-cancelled WebKit load failures, logged preview/PDF fallback failures, and tracked preview-toolbar export events.
- `ResumeBuilder IOS APP/Core/Export/HTMLPDFExporter.swift` — added OSLog breadcrumbs for timeout, navigation, provisional navigation, `createPDF`, and file-write failures.
- `ResumeBuilder IOS APP/Core/Export/ResumeExportAction.swift` — added shared export failure-code mapping and preserved styled-HTML failure context when backend fallback also fails.
- `tasks/lessons.md`, `tasks/progress.md`, `tasks/session-log.md` — updated project memory.
**Decisions Made:**
- Kept the fix scoped to observability and existing fallback behavior; styled HTML export failures still fall through to backend download before surfacing failure.
- Used OSLog for local failure diagnostics and existing PostHog `export_failed.error_code` for analytics, avoiding new event names during App Store review.
- Today's connected PostHog context did not show `$lib=resumely-ios-urlsession`; it showed only `$lib=posthog-ios` in the last 7 days, so production counts remain based on the 2026-06-18 baseline.
**Validation:**
- `xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination "platform=iOS Simulator,name=iPhone 17" -configuration Debug build` — passed.
- `xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination "platform=iOS Simulator,name=iPhone 17" -configuration Debug -only-testing:"ResumeBuilder IOS APPTests/AnalyticsServiceTests"` — passed 9/9.
- iPhone 17 Pro simulator install/launch smoke — passed; app launched as process 41533.
- `git diff --check` — passed.
**Next Recommended Action:** After Apple approval, switch/confirm PostHog project 270848 and rerun the D7 dashboard 1720819 funnel readout for `$lib=resumely-ios-urlsession`.

### 2026-06-18 (v5 build-and-ship)
**Task:** Build and submit version 1.1 (5) for App Store review before D7 Gate A deadline (2026-06-21)
**Files Changed:**
- `ResumeBuilder IOS APP.xcodeproj/project.pbxproj` — bumped CURRENT_PROJECT_VERSION 4→5 and MARKETING_VERSION 1.0→1.1 (version 1.0 was locked after approval; Apple requires higher CFBundleShortVersionString for new submissions)
- `docs/superpowers/specs/2026-06-18-v5-build-ship-design.md` — v5 design spec (Approach B: bump → archive → smoke → submit)
- `docs/superpowers/plans/2026-06-18-v5-build-ship.md` — 4-task implementation plan
- `tasks/progress.md` — updated with v5 submission record
- `tasks/session-log.md` — this entry
**Decisions Made:**
- MARKETING_VERSION bumped to 1.1 (not 2.0) — minor version is appropriate for analytics, localization, and library updates with no major new user-facing feature.
- Used Xcode Organizer for archive/upload (no ExportOptions.plist exists in the project).
- Promotional Text set to: "Land more interviews. AI-powered ATS optimization, expert resume tools, and your full Resume Library — now with Hebrew support."
- PostHog analytics verified live via MCP query during session — all core funnel events firing.
**Validation:**
- `project.pbxproj` diff shows exactly 4 changed lines (2× CURRENT_PROJECT_VERSION, 2× MARKETING_VERSION).
- Xcode Organizer confirmed "Uploaded to Apple" for 1.1 (5) at 12:30.
- PostHog trends query (last 24h, hourly) shows app_launched, resume_uploaded, optimization_started, ats_improve_tapped all firing today.
- ASC version 1.1 shows "Prepare for Submission" → user confirmed submitted for review.
**Next Recommended Action:** Monitor Apple review (expected ~48h). If rejected, check rejection notes in ASC and address. On or after 2026-06-24, run D7 readout via PostHog plugin against dashboard 1720819.

### 2026-06-17 (PostHog real-device QA)
**Task:** Verify PostHog analytics coverage and run real-device QA
**Files Changed:**
- `ResumeBuilder IOS APPTests/AnalyticsServiceTests.swift` — added exact PostHog event-name/property contract coverage for all 16 app-defined analytics events.
- `docs/qa/reports/posthog-real-device-qa-2026-06-17.md` — documented PostHog plugin context, live coverage, real-device build/install/launch, device test result, and remaining live-observation gap.
- `tasks/progress.md` — recorded PostHog/device QA status and latest validation.
- `tasks/session-log.md` — recorded this session.
**Decisions Made:**
- Treated project 270848 as authoritative after detecting the PostHog plugin had drifted to project 171597.
- Classified five events as wired/test-covered but not production-observed: `free_ats_completed`, `diagnosis_viewed`, `ats_improve_tapped`, `export_pdf_tapped`, and `submit_package_saved`.
- Did not mutate PostHog dashboards, App Store Connect, Vercel, or backend state.
**Validation:**
- Connected PostHog plugin resolved dashboard 1720819 in project 270848.
- Physical iPhone 13 Debug build, install, and launch passed.
- Built app Info.plist had `API_BASE_URL`, `POSTHOG_API_KEY`, and `POSTHOG_HOST` set.
- Focused physical-device test run passed: `AnalyticsServiceTests` 8/8, 0 failures.
- PostHog query after `2026-06-17T12:25:25Z` showed fresh iOS events for `app_launched`, `resume_uploaded`, `job_added`, and `optimization_started`.
**Next Recommended Action:** Run an authenticated manual device smoke through Diagnosis, Improve ATS, Export PDF, and Submit Package to make the five remaining wired events appear in live PostHog data.

### 2026-06-17 (post-live D7 plugin pre-read)
**Task:** Post-Live D7 Readout
**Files Changed:**
- `docs/qa/reports/post-live-d7-readout-2026-06-17.md` — updated the D7 readout from source-blocked to PostHog-plugin verified, with live 7-day event counts, launch-anchor traffic, dashboard health, timing gate, dashboard hygiene, and monetization implication.
- `tasks/progress.md` — recorded that PostHog source access is verified and D7 readout is now pending only a complete 7-day live window.
- `tasks/session-log.md` — recorded this packet.
- `tasks/todo.md` — updated current task to the D7 plugin pre-read and its remaining D7-window validation status.
**Decisions Made:**
- Did not report mature D7 activation, retention, App Store downloads, conversion, or revenue because the App Store-live anchor is 2026-06-17 and the first complete D7 window is 2026-06-24.
- Kept D7 Activation dashboard 1720819 as the iOS north star.
- Classified Activation Funnel 1345375, Week 1 Launch Metrics 1285341, and My App Dashboard 932305 as archive-review candidates only using live PostHog dashboard metadata; no dashboard edits or deletions were made.
- Kept monetization/paywall decisions blocked until dashboard 1720819 is read after the first complete D7 window.
**Validation:**
- Connected PostHog plugin resolved dashboard 1720819 in project 270848.
- Live HogQL confirmed iOS `$lib=resumely-ios-urlsession`: 188 events / 18 users over 7 days, last event 2026-06-17T03:06:44.021Z.
- Launch-anchor read from 2026-06-17T00:00:00Z showed 2 `app_launched` events / 2 users and 2 `guest_mode_started` events / 2 users.
- `git diff --check` passed on the D7 readout branch.
**Next Recommended Action:** Re-run D7 source read through the connected PostHog plugin on or after 2026-06-24, or replace the launch anchor if App Store Connect provides a more precise Ready-for-Sale timestamp.

### 2026-06-17
**Task:** Resumely post-live analytics and release-state reconciliation
**Files Changed:**
- `tasks/progress.md` — changed launch status from App Store review to App Store live, recorded live PostHog iOS evidence, pinned D7 Activation dashboard 1720819 as the iOS north star, and corrected Resume Library status on current `main`.
- `tasks/session-log.md` — recorded this reconciliation session and evidence sources.
- `tasks/todo.md` — replaced stale Resume Aha task tracker with the post-live reconciliation checklist.
**Decisions Made:**
- Treated the founder/App Store-live statement and 2026-06-17 live PostHog QA packet as trusted evidence for launch-gate reconciliation; did not invent App Store downloads, revenue, conversion, or retention numbers.
- Closed the launch gate on iOS health: `$lib=resumely-ios-urlsession` showed 190 events / 18 users over 7 days, with the last event on 2026-06-17.
- Web analytics configuration is not broken: Vercel production has `NEXT_PUBLIC_POSTHOG_KEY` and `NEXT_PUBLIC_POSTHOG_HOST`, the code reads those names, and live PostHog saw `$lib=web` events. The current web issue is low traffic, not missing env.
- D7 Activation dashboard 1720819 is the iOS north star. Week 1 Launch Metrics 1285341 is web/legacy-oriented based on local config event names; My App Dashboard 932305 was last refreshed 2026-02-18 per the QA packet, so both should be reviewed for archive, not deleted.
**Validation:**
- `git diff --check` passed for the reconciliation branch.
- Targeted reads of `tasks/progress.md`, `tasks/session-log.md`, and `tasks/todo.md` confirmed the updated status/evidence.
- Vercel CLI read-only check confirmed production env vars: `NEXT_PUBLIC_POSTHOG_HOST` scoped to Production and `NEXT_PUBLIC_POSTHOG_KEY` scoped to Development, Preview, Production.
**Next Recommended Action:** Run the first post-live packet after the D7 window: read dashboard 1720819, summarize activation/retention honestly, review archive candidates 1285341 and 932305 in PostHog, and only then decide on monetization/paywall timing.

### 2026-06-14 (resubmission)
**Task:** App Store resubmission — resolve compliance, fill reviewer info, reply to rejection, submit build 4
**Files Changed:**
- `Config/Info.plist` — added `ITSAppUsesNonExemptEncryption = false` (future builds auto-pass compliance)
**Decisions Made:**
- Missing Compliance answered: "None of the algorithms mentioned above" (app uses only Apple URLSession/Keychain — no custom crypto)
- Apple Sign In correctly disabled via `BackendConfig.isAppleSignInEnabled = false` — this was the root cause of the Jun 5 rejection
- Delete Account confirmed present: Me tab → Account section → Delete Account (calls Supabase delete_account edge function)
- Register confirmed present: Onboarding → "Don't have an account? Sign Up"
- Demo credentials set in ASC: nadav.yigal@gmail.com / test123456
- Replied to Jun 5 "Unresolved Issues" rejection explaining the Apple Sign In fix
- Clicked "Update Review" — build 4 is now in Apple review
**Next Recommended Action:** Wait for Apple review result (1-3 days). If approved: publish. If rejected: open new session with Apple's feedback. Merge open PR (branch claude/gracious-curie-fcd112) to main before building v5.

### 2026-06-14
**Task:** Review PR #58 Resume Aha Moments before merge and prepare archive readiness
**Files Changed:**
- `Features/Tailor/TailorView.swift` and `Features/V2/Home/HomeTabView.swift` — keep diagnosis view models stable across navigation.
- `Features/V2/Diagnosis/*` — add main-actor isolation, duplicate-safe chip IDs, and hide Improve CTA when no optimization id exists.
- `Features/V2/Improve/OptimizedResumeView.swift` — gate diagnosis panels until optimization details finish loading.
- `Models/ResumeDiagnosis.swift` and `ViewModels/OptimizedResumeViewModel.swift` — merge backend diagnosis with live ATS/section context and clear stale backend diagnosis after local mutations.
- `ResumeBuilder IOS APPTests/ResumeDiagnosisViewModelTests.swift` — cover nested DTO decoding and backend/live-context merge behavior.
- `tasks/lessons.md`, `tasks/progress.md`, `tasks/todo.md`, `docs/qa/reports/ios-qa-pr58-2026-06-14.md` — record validation and remaining blocker.
**Validation:** `git diff --check` passed. Focused iPhone 17 diagnosis tests passed 7/7. Full iPhone 17 suite passed: 83 XCTest tests plus 5 Swift Testing tests, 0 failures. Release archive succeeded at `/tmp/ResumeBuilder-PR58.xcarchive`.
**Decisions Made:** Treat the archive as proof the project is archiveable, but keep App Store submission blocked until a live smoke passes because CoreSimulator hung on install/screenshot/container commands. Source-reviewed account deletion/register wiring, but did not claim live compliance verification without a working simulator/device.
**Next Recommended Action:** Run the authenticated smoke on a real device or reset Simulator/CoreSimulator, then validate/distribute the archive from Xcode Organizer with App Store distribution signing.

### 2026-06-12
**Task:** Implement Resume Aha Moments diagnosis-first flow
**Files Changed:** `Models/ResumeDiagnosis.swift`, `Features/V2/Diagnosis/*`, `Features/V2/Home/HomeTabView.swift`, `Features/V2/Home/HomeActivationState.swift`, `Features/V2/Home/ResumeOptimizationLoadingView.swift`, `Features/Tailor/TailorView.swift`, `Features/V2/Improve/OptimizedResumeView.swift`, `ViewModels/OptimizedResumeViewModel.swift`, `Core/API/Models/DomainModels.swift`, `ResumeBuilder IOS APPTests/ResumeDiagnosisViewModelTests.swift`, `project.pbxproj`, `docs/specs/resume-aha-moments.md`, `docs/specs/README.md`, `tasks/todo.md`, `tasks/progress.md`, `tasks/lessons.md`, `tasks/session-log.md`
**Decisions Made:** Kept the first aha after real resume/job optimization, not a tutorial. Added backend diagnosis as an optional decode hook, but used a conservative local mapper from ATS scores/blockers/sections when backend data is absent. Avoided fabricating original bullets: before/after cards gracefully show the improved bullet when original text is unavailable. Routed Home and Tailor optimize success to Diagnosis before Improve, then reused confidence cues inside Improve before export/payment.
**Validation:** `git diff --check` passed. Focused diagnosis tests passed 6/6 on iPhone 17, including snake_case backend diagnosis decoding. Debug build succeeded on iPhone 17. Full test suite passed before the decoder hardening: 81 XCTest tests plus 5 Swift Testing tests, 0 failures. Simulator install/launch smoke succeeded on iPhone 17; Home aha copy rendered at `/tmp/resumebuilder-aha-smoke-iphone17-late.png`.
**Next Recommended Action:** Run an authenticated live smoke on device or signed-in simulator: upload/paste resume, paste job description, complete optimization, verify Diagnosis copy and CTAs with real backend data, then adjust backend diagnosis decoding if the API ships a different payload shape.

### 2026-06-12
**Task:** Clear four App Store archive gates (branch hygiene, build number, review notes, screenshot handoff)
**Files Changed:** `project.pbxproj`, `Localizable.xcstrings`, `docs/qa/app-store-readiness-checklist.md`, `dist/app-store-screenshots/rb-aso-002/upload-manifest.md`, `tasks/todo.md`, `tasks/progress.md`
**Decisions Made:** Merged PR #57 to `main`. Bumped to build 4 for fresh ASC upload. Documented email-only App Review path after 2026-06-10 Apple Sign In rejection. iPad 13" screenshot paths added to upload manifest.
**Next Recommended Action:** Archive v1.0 (4) from `main` in Xcode → upload → paste review notes from checklist → Submit for Review.

### 2026-06-11
**Task:** Fix Submit Package missing-company startup failure and implement first ATS/screenshot alignment slice
**Files Changed:**
- `ResumeBuilder IOS APP/Features/V2/Improve/SubmitApplicationViewModel.swift` — relaxed `canSubmit`, added safe role/company fallbacks, user-facing missing-context copy, and submit-stage OSLog markers.
- `ResumeBuilder IOS APP/ViewModels/OptimizedResumeViewModel.swift` — added ATS insight rows, before/after delta, recommended actions, and explicit low-score explanation data.
- `ResumeBuilder IOS APP/Features/V2/Improve/OptimizedResumeView.swift` — shows missing-context guidance in the Submit Package sheet and adds a live ATS insight panel with score signals, top blockers/actions, and Improve ATS.
- `ResumeBuilder IOS APPTests/OptimizedResumeViewModelTests.swift` — added missing-company Submit Package coverage and low-score ATS insight coverage.
- `docs/superpowers/plans/2026-06-11-smoke-test-ats-submit-and-screenshot-plan.md` — documented the ATS-score and App Store screenshot alignment plan, then marked the Submit Package fix and ATS panel MVP implemented.
- `tasks/lessons.md`, `tasks/todo.md`, `tasks/progress.md`, `tasks/session-log.md` — recorded root cause, validation, implemented plan slice, and next action.
- `tasks/lessons.md`, `tasks/todo.md`, `tasks/progress.md`, `tasks/session-log.md` — recorded root cause, validation, and next action.
**Decisions Made:**
- Root cause: rerun smoke logs had no PDF/application/expert calls after Submit Package; the package flow was blocked before it started because the live optimization detail can omit company and `canSubmit` required it.
- Missing company/role should be a recoverable context gap, not a disabled action. The sheet now explains the fallback and submits with safe placeholders.
- The low ATS score is treated as a product-quality/guidance issue, not a UI score bug; the App Store screenshots are launch-argument-only marketing scenes, so the matching claim needs to exist in normal `Features/V2` product UI too.
**Validation:**
- `git diff --check` passed.
- Focused tests succeeded on iPhone 17: `xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/resumebuilder-ats-insights-derived -only-testing:'ResumeBuilder IOS APPTests/OptimizedResumeViewModelTests'` passed 20/20 tests.
- Simulator launch smoke succeeded on iPhone 17; normal Home screen rendered at `/tmp/resumebuilder-ats-insights-smoke-2.png`.
**Next Recommended Action:** Publish/merge the PR update, then founder rebuilds on real device and confirms Xcode logs show `Submit package ready`; after that add backend QA fixtures for strong/weak ATS match quality.

### 2026-06-11
**Task:** Fix real-device smoke failures for Preview & Export PDF and Submit Package
**Files Changed:**
- `ResumeBuilder IOS APP/Core/Export/HTMLPDFExporter.swift` — added `LocalResumePDFExporter`, which creates a valid text-layer PDF from loaded optimization sections/contact data and stores it through the existing export file store.
- `ResumeBuilder IOS APP/ViewModels/OptimizedResumeViewModel.swift` — routes PDF downloads through a local fallback, validates backend download payloads begin with `%PDF-`, preserves auth/payment failures, and surfaces backend error bodies in logs instead of generic invalid responses.
- `ResumeBuilder IOS APPTests/OptimizedResumeViewModelTests.swift` — added coverage that the local PDF fallback writes real PDF data.
- `tasks/lessons.md`, `tasks/todo.md`, `tasks/progress.md`, `tasks/session-log.md` — recorded root cause, current status, and next smoke action.
**Decisions Made:**
- Root cause: Submit Package and Preview & Export PDF share the same PDF dependency; when WKWebView/backend download failed, Submit Package stopped before creating the application/expert package.
- Kept the existing preferred order: styled WKWebView PDF first, backend `/api/download` second, local text-layer fallback third.
- Treated unauthorized and payment-required as terminal so the local fallback cannot bypass account/payment gating.
**Validation:**
- Debug simulator build succeeded on iPhone 17: `xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/resumebuilder-pdf-fix-derived build`
- Focused tests succeeded on iPhone 17: `xcodebuild test ... -only-testing:'ResumeBuilder IOS APPTests/OptimizedResumeViewModelTests'` passed 18/18 tests.
**Next Recommended Action:** Founder pulls latest `main`, rebuilds/runs on real device, signs in, smokes optimize → Improve ATS → Preview & Export PDF → Submit Package, then confirms the exported/shared PDF opens and screenshots PostHog `export_success`.

### 2026-06-04
**Task:** WP-1 continuation — Apply App Store readiness changes, verify clean build with all Info.plist keys, run 72-test suite, smoke simulator, build signed device binary
**Files Changed:**
- `ResumeBuilder IOS APP.xcodeproj/project.pbxproj` — upgraded "Inject PostHog API Key" → "Inject Runtime Config": script now injects API_BASE_URL (required, build fails if missing) + POSTHOG_API_KEY + POSTHOG_HOST; added `alwaysOutOfDate = 1`; added API_BASE_URL = https://www.resumelybuilderai.com to Debug + Release build settings; added Secrets.swift.example to PBXFileSystemSynchronizedBuildFileExceptionSet (excluded from app bundle)
- `ResumeBuilder IOS APP/Core/API/BackendConfig.swift` — removed hardcoded production URL fallback; now uses preconditionFailure if API_BASE_URL is missing or invalid
- `ResumeBuilder IOS APP/Features/Tailor/TailorView.swift` — fixed deprecated two-argument `.onChange(of:)` to three-argument form
- `ResumeBuilder IOS APP/ViewModels/ImproveViewModel.swift` — fixed three `guard let` warnings to `guard ... != nil` where the unwrapped value was unused
- `tasks/progress.md`, `tasks/todo.md`, `tasks/session-log.md` — updated WP-1 status and founder action items
**Decisions Made:**
- Previous session's readiness changes were in the project root as uncommitted modifications; applied them via git patch to this worktree so they can be committed to a PR branch
- Test failure on first run was caused by stale derived data (API_BASE_URL was absent from cached Info.plist); clean build resolves it
- Device binary built at `/var/tmp/resumebuilder-device-wt/Build/Products/Debug-iphoneos/` — all three runtime keys confirmed in Info.plist
- ASC upload path: Fastlane NOT installed, no .p8 key → manual Xcode Organizer (Distribute App → App Store Connect → Upload)
**Validation:**
- Clean build (INFO.plist injection): API_BASE_URL, POSTHOG_API_KEY=phc_***, POSTHOG_HOST all present in simulator and device Debug Info.plist
- 72 XCTest tests passed (0 failures) on iPhone 17 simulator
- Simulator smoke: app installed and launched; Home screen rendered cleanly (screenshot: /var/tmp/resumebuilder-smoke-wt/wp1-home.png)
- Device binary (iphoneos Debug) compiled and signed successfully; all 3 Info.plist keys confirmed
**Next Recommended Action:** Founder: install device binary → sign in → run optimize→design→expert→export on real device → screenshot PostHog Live Events for app_launched + optimization_completed + export_success → archive via Xcode Organizer (Product → Archive → Distribute App → App Store Connect)

### 2026-06-03
**Task:** WP-1 — Pre-submission device smoke and PostHog live-event verification
**Files Changed:**
- `ResumeBuilder IOS APP.xcodeproj/project.pbxproj` — removed dead INFOPLIST_KEY_POSTHOG_* settings; added PBXShellScriptBuildPhase "Inject PostHog API Key" (UUID AABB1122CCDD3344EEFF5566AABB1122) that uses PlistBuddy to inject POSTHOG_API_KEY and POSTHOG_HOST into the generated Info.plist at build time; wired the phase into the main target's buildPhases
- `ResumeBuilder IOS APPTests/AnalyticsServiceTests.swift` — updated `testDisabledAnalyticsDoesNotRequireTransport` to `testServiceIsEnabledWhenTransportIsProvided` since the PostHog key is now always present in builds
**Decisions Made:**
- `INFOPLIST_KEY_*` does not inject custom keys in Xcode 26.5; Run Script + PlistBuddy is the correct path for custom Info.plist keys when GENERATE_INFOPLIST_FILE=YES
- Creating a source Info.plist in the app folder conflicts with fileSystemSynchronizedGroups auto-inclusion
- Fastlane is NOT installed and no ASC API key (.p8) is present; manual Xcode Organizer upload is the App Store Connect path (EXD-006 resolved)
- Device smoke blocked: iPhone 13 (UDID 00008110-00192DDA2143801E) was locked/unavailable during session; device binary IS built and ready at `/var/tmp/resumebuilder-device-derived/Build/Products/Debug-iphoneos/`
**Validation:**
- POSTHOG_API_KEY confirmed in simulator Debug Info.plist: phc_*** (see Secrets.xcconfig)
- POSTHOG_API_KEY confirmed in iphoneos Debug Info.plist: phc_*** (see Secrets.xcconfig)
- Full test suite: all XCTest + 5 Swift Testing tests pass (70+ tests, 0 failures)
- Simulator launch screenshot: Home screen renders correctly at /var/tmp/resumebuilder-smoke/wp1-launch.png
- Analytics call sites verified: app_launched (App entry), optimization_completed (TailorViewModel + OptimizationReviewView), export_success (ResumeExportAction)
- ASC upload path: Fastlane NOT installed, no .p8 key found → manual Xcode Organizer path confirmed
**Next Recommended Action:** Founder: unlock iPhone 13 → run `xcrun devicectl device install app --device 4A1D6EF2-8945-55B8-931A-46980B2A27E2 "/var/tmp/resumebuilder-device-derived/Build/Products/Debug-iphoneos/ResumeBuilder IOS APP.app"` → sign in → run optimize→design→expert→export → screenshot PostHog Live Events for app_launched + optimization_completed + export_success → archive via Xcode Organizer for App Store Connect upload

### 2026-06-02
**Task:** Implement post-optimization upgrade: strong optimization contract, focused manual amend, ATS uplift, and Me package hub
**Files Changed:**
- `Services/ResumeOptimizationService.swift` — sends `optimization_mode: strong_faithful` plus a substantial/factual quality profile on optimize.
- `Core/API/Models/DomainModels.swift` — decodes ATS blockers, job/application context, application source URLs, embedded expert reports, and cover-letter text.
- `ViewModels/OptimizedResumeViewModel.swift` — tracks ATS status/blockers and adds an Improve ATS action through the existing Expert ATS workflow/apply path.
- `Features/V2/Improve/OptimizedResumeView.swift` — replaces the inline all-section edit panel with a focused section-editor sheet, adds empty validation/dirty discard protection, and surfaces ATS status/blockers/uplift.
- `Features/Track/ApplicationDetailView.swift`, `Features/Track/ApplicationDetailViewModel.swift`, `Features/Profile/ProfileView.swift`, `App/AppState.swift` — turn application detail into a submission package hub and refresh Me after package creation.
- `ResumeBuilder IOS APPTests/OptimizedResumeViewModelTests.swift` — adds strong-mode request, ATS blocker, embedded cover-letter report, and ATS uplift coverage.
- `tasks/todo.md`, `tasks/progress.md`, `tasks/lessons.md`, `tasks/session-log.md` — recorded scope, validation, progress, and Swift decoder lesson.
**Decisions Made:**
- Kept true third-party auto-apply out of scope; this remains assisted submit with resume share, cover-letter copy, job-link open, and application tracking.
- Represented backend quality work as iOS request/decoder contracts because this workspace contains only the iOS app.
- Reused Expert ATS Optimization Report apply for the ATS uplift loop rather than adding an unshipped endpoint.
**Validation:**
- Focused `OptimizedResumeViewModelTests` passed 15/15 on iPhone 17 simulator.
- `xcodebuild build` succeeded on iPhone 17 simulator using `/tmp/resumebuilder-derived`.
- Full `xcodebuild test` passed 70 XCTest tests plus 5 Swift Testing tests using `/tmp/resumebuilder-derived`.
- `simctl` install/launch smoke succeeded on booted iPhone 17; late Home screenshot rendered cleanly at `/tmp/resumebuilder-smoke/post-optimization-upgrade-iphone17-late.png`.
- iPhone SE simulator and authenticated live optimize/package smoke were not available in this environment.
**Next Recommended Action:** Run an authenticated real-device smoke: optimize with a real resume/job, apply the review, use focused manual edit, run Improve ATS, create Submit Package, then verify Me shows resume share, cover-letter copy, job-link open, saved report, and refreshed application status.

### 2026-06-02
**Task:** Implement Phase 2 assisted submit package from Optimized resume
**Files Changed:**
- `Core/API/Models/DomainModels.swift` — added application-create request/body helpers and flexible create-envelope decoding
- `Core/API/ApplicationTrackingService.swift` — added `ApplicationTrackingServiceProtocol` and `createApplication`
- `Core/API/ExpertWorkflowService.swift` — added `ExpertWorkflowServiceProtocol` for submit-package orchestration tests
- `Features/V2/Improve/SubmitApplicationViewModel.swift` — added `@Observable @MainActor` package flow that downloads the PDF, creates/links/marks an application, runs Cover Letter Architect, saves the report, and exposes package artifacts
- `Features/V2/Improve/OptimizedResumeView.swift` — added Submit Package button and assisted package sheet with resume sharing, cover-letter copy, and job-link open actions
- `ResumeBuilder IOS APPTests/OptimizedResumeViewModelTests.swift` — added application create body/envelope tests and submit-package orchestration coverage
- `tasks/todo.md`, `tasks/progress.md`, `tasks/lessons.md`, `tasks/session-log.md` — recorded scope, validation, progress, and test assertion lesson
**Decisions Made:**
- Kept the flow assisted-only: iOS prepares the resume PDF, cover letter, application record, and job link, but does not auto-submit to third-party job sites.
- Reused existing backend contracts for optimized PDF download, Expert Cover Letter Architect run/apply, application attachment, mark-applied, and saved expert reports.
- Created application status as `saved`, then explicitly called `markApplied` so Track/Me status follows the existing tracking path.
**Validation:**
- Focused `OptimizedResumeViewModelTests` passed 11/11 on iPhone 17 simulator.
- `xcodebuild build` succeeded on iPhone 17 simulator using `/tmp/resumebuilder-derived`.
- Full `xcodebuild test` passed 66 XCTest tests plus 5 Swift Testing tests using `/tmp/resumebuilder-derived`.
- `simctl` install/launch smoke succeeded on booted iPhone 17; Home screenshot rendered cleanly at `/tmp/resumebuilder-smoke/phase2-submit-package-launch-late.png`.
- Live package sheet submit was not smoked end-to-end because the local simulator was unauthenticated and had no persisted real optimization id.
**Next Recommended Action:** Run an authenticated real-device smoke: optimize a resume, open Submit Package, create the package, confirm the resume share link and cover-letter copy action, then verify the application appears in Me/Track as applied with linked optimized resume and saved expert report.

### 2026-06-02
**Task:** Implement Phase 1 manual amend on optimized resume
**Files Changed:**
- `Features/V2/Improve/OptimizedResumeView.swift` — added Edit/Done affordance, manual section editors, per-section Save/Cancel, preview refresh trigger, and ATS refresh spinner
- `ViewModels/OptimizedResumeViewModel.swift` — added injected `ResumeAnalysisServiceProtocol`, `saveManualEdit`, `rescanATS`, edit status update, and optimization-detail cache invalidation after manual saves
- `ResumeBuilder IOS APPTests/OptimizedResumeViewModelTests.swift` — added focused manual edit success/failure and ATS rescan tests with actor-bound spies
- `tasks/todo.md`, `tasks/progress.md`, `tasks/lessons.md`, `tasks/session-log.md` — recorded scope, validation, progress, and Swift 6 test-spy lesson
**Decisions Made:**
- Reused the existing `/api/v1/refine-section/apply` path for manual edits instead of adding an endpoint.
- Refreshed headline ATS scores through the existing `ResumeAnalysisService.rescan` / `/api/ats/rescan` path after successful saves.
- Kept Phase 2 submit + cover letter out of this story, matching the pasted plan's sequence.
**Validation:**
- Focused `OptimizedResumeViewModelTests` passed 8/8 on iPhone 17 simulator.
- `xcodebuild build` succeeded on iPhone 17 simulator using `/tmp/resumebuilder-derived`.
- Full `xcodebuild test` passed 63 XCTest tests plus 5 Swift Testing tests using `/tmp/resumebuilder-derived`.
- `simctl` install/launch smoke succeeded on booted iPhone 17; Home screenshot rendered cleanly at `/tmp/resumebuilder-smoke/manual-edit-launch.png`.
- Live manual edit UI save was not smoked end-to-end because the local simulator was unauthenticated and had no persisted real optimization id.
**Next Recommended Action:** Implement Phase 2 — submit optimized resume + cover letter from Track/Me tab, including application create/linking and assisted package presentation.

### 2026-06-01
**Task:** Validate and fix Cursor bug-review report
**Files Changed:**
- `App/MainTabViewV2.swift`, `Features/V2/Design/DesignTabView.swift`, `Features/V2/Design/RedesignResumeView.swift` — pass active-tab state into Design preview and debounce live customization renders
- `Features/V2/Improve/OptimizedResumeTabView.swift`, `Features/V2/Improve/OptimizedResumeView.swift` — recreate Optimized view/design state when the optimization id changes and pause preview work while hidden
- `Features/V2/Preview/ResumePreviewWebView.swift` — skips inactive renders, coalesces duplicate render keys, debounces Design preview tasks, avoids redundant WKWebView reloads, and gates preview logs behind `#if DEBUG`
- `Core/Export/HTMLPDFExporter.swift`, `ViewModels/OptimizedResumeViewModel.swift` — write generated/downloaded PDFs to stable Caches export URLs before sharing
- `Features/V2/History/OptimizationReviewView.swift`, `Features/V2/Home/HomeTabView.swift`, `Features/Tailor/TailorViewModel.swift` — fire review-apply optimization analytics once and gate Tailor hot-path logs
- `ResumeBuilder IOS APPTests/LiveEndpointStabilizationTests.swift` — added preview-policy retry and stable export-file regression tests
- `tasks/lessons.md`, `tasks/progress.md`, `tasks/todo.md`, `tasks/session-log.md` — recorded validation and local codesign metadata lesson
**Decisions Made:**
- Treated backend customize 404, review-based `success=false`, legacy history payload size, and system WebKit/network chatter as non-iOS bugs or expected noise.
- Used `/tmp/resumebuilder-derived` for signed simulator verification because project-local `.derivedData` inherits FileProvider/Finder extended attributes that break codesign.
**Validation:**
- Signed `xcodebuild build` succeeded on iPhone 17 simulator with DerivedData at `/tmp/resumebuilder-derived`.
- Full `xcodebuild test` passed 53 XCTest tests plus 5 Swift Testing tests.
- XcodeBuildMCP `build_run_sim` succeeded on iPhone 17; Home screenshot rendered cleanly.
**Next Recommended Action:** Run one authenticated device smoke that switches between two optimizations, drags the Design spacing slider, applies a design, and exports/shares the PDF while watching that preview logs stay quiet and use the latest optimization id.

### 2026-06-01
**Task:** Fix live design apply, PDF export hang, and Expert-to-Me application asset linking
**Files Changed:**
- `Services/ResumeDesignService.swift` — treats the stable design assignment as success when the secondary customize route returns the live "Optimization not found" 404, so Apply Design no longer fails after assignment succeeds
- `Core/Export/HTMLPDFExporter.swift` and `Core/Export/ResumeExportAction.swift` — retain the off-screen WKWebView, add a 20-second timeout, and fall back to backend PDF download if client-side styled PDF generation fails
- `Features/V2/Expert/ExpertTabView.swift` — links Expert runs to applications when the app row exposes either `optimization_id` or `optimized_resume_id`
- `Services/ResumeOptimizationService.swift` and `ResumeBuilder IOS APPTests/ResumeOptimizationParsingTests.swift` — support both `reviewId` and `review_id` optimize responses
- `tasks/lessons.md`, `tasks/progress.md`, `tasks/todo.md`, `tasks/session-log.md` — recorded the fix and validation
**Decisions Made:**
- Optimized resumes appear automatically as the latest resume via `AppState.latestOptimizationId`; application attachment in Me remains explicit unless the backend application row is already linked.
- Do not block design apply on the customize endpoint when assignment/render-preview are already working for the optimization id.
**Validation:**
- `xcodebuild build` succeeded on iPhone 17 simulator.
- Focused `xcodebuild test` passed 17/17 tests across `LiveEndpointStabilizationTests`, `ResumeOptimizationParsingTests`, and `ExportCompletionTests`.
- Simulator install/launch smoke succeeded on iPhone 17 and Home screenshot rendered cleanly at `/tmp/resumebuilder-smoke/home.png`.
**Next Recommended Action:** Run one real authenticated device smoke: apply a design, export PDF from Optimized, then create a Cover Letter from Expert and confirm it appears under the linked application in Me.

### 2026-06-01
**Task:** Add resume optimization waiting animation
**Files Changed:**
- `Features/V2/Home/ResumeOptimizationLoadingView.swift` — added reusable SwiftUI scan animation with optimization and ATS-check copy modes
- `Features/V2/Home/HomeTabView.swift` — shows the scan loader during optimize/free ATS waiting states
- `Features/Tailor/TailorView.swift` and `Features/Tailor/OptimizingView.swift` — replaced the old spinner with the V2 loader while keeping the legacy wrapper compatible
- `tasks/todo.md`, `tasks/progress.md`, `tasks/session-log.md` — recorded completion and validation
**Decisions Made:**
- Kept the loader inline so users stay anchored in the Home/Tailor flow.
- Treated the scan animation as decorative waiting feedback only; it does not claim real backend progress.
**Validation:**
- `xcodebuild build` succeeded on iPhone 17 simulator.
- `xcodebuild test` passed 50 XCTest tests plus 5 Swift Testing tests.
- XcodeBuildMCP `build_run_sim` succeeded on iPhone 17 and iPhone 17e compact proxy; Home launch screenshot looked clean. iPhone SE was not configured in the simulator list.
**Next Recommended Action:** Run a real authenticated optimize smoke with a text-based PDF to see the animation during a live backend wait, then confirm navigation to Optimized or review still feels smooth.

### 2026-05-31
**Task:** PR #36 QA fixes for pre-submission UX/UI transformation
**Files Changed:**
- `App/AppState.swift` — kept export-completion decode on MainActor to satisfy Swift 6 isolation
- `Core/Analytics/AnalyticsService.swift` — marked pure analytics event metadata nonisolated for payload construction
- `Features/V2/Home/HomeTabView.swift` — dismisses auth sheet after sign-in and uses accurate secure-upload privacy copy
- `Features/Profile/ProfileView.swift` — dismisses auth sheet after sign-in from Me
- `Features/V2/Improve/OptimizedResumeView.swift` — fixed optional `APIClientError` pattern match in export error handling
- `ResumeBuilder IOS APP.xcodeproj/project.pbxproj` — adds generated `POSTHOG_HOST` Info.plist build setting
- `tasks/lessons.md`, `tasks/todo.md`, `tasks/progress.md`, `tasks/session-log.md` — recorded QA fixes and validation
**Decisions Made:**
- Do not commit a PostHog API key; `POSTHOG_API_KEY` remains an external build setting/client key input.
- Treat existing Improve/Tailor warnings as pre-existing non-blocking cleanup, not PR #36 merge blockers.
**Validation:**
- `xcodebuild build` succeeded on iPhone 17 simulator.
- `xcodebuild test` passed 55/55 on iPhone 17 simulator.
- XcodeBuildMCP `build_run_sim` succeeded.
- Simulator screenshots verified Home guest launch, locked Design, locked Expert, and Me guest state.
- Removed plain debug `print(...)` traces from Optimized tab/view during final PR review.
- `xcodebuild build` succeeded again on iPhone 17 simulator after release-log cleanup.
**Next Recommended Action:** Push the QA fix commit to PR #36, then verify PostHog Live Events from a build that provides `POSTHOG_API_KEY`; after merge, run a real-device authenticated optimize/export smoke before App Store submission.

### 2026-05-26
**Task:** Fix optimized preview stuck on resume loading
**Files Changed:**
- `Features/V2/Improve/OptimizedResumeView.swift` — shows `ResumePreviewWebView` immediately when an optimization ID exists, so render-preview can load from the ID while section/contact detail loading runs independently
- `tasks/lessons.md`, `tasks/progress.md`, `tasks/todo.md`, `tasks/session-log.md` — updated preview loading lesson and status
**Validation:**
- XcodeBuildMCP `build_run_sim` succeeded on iPhone 17 Pro Max simulator
- XcodeBuildMCP `test_sim` passed 33/33
**Decisions Made:**
- The optimized preview must not use section-detail loading as a hard gate because backend render-preview already supports `optimizationId`.
**Next Recommended Action:** Real-device smoke test optimize → Optimized tab and confirm the preview renders even if `/api/v1/optimizations/:id` is slow or empty.

---

### 2026-05-25
**Task:** Follow up on live preview slowness and Design category switching
**Files Changed:**
- `Features/V2/Preview/ResumePreviewWebView.swift` — paints local HTML immediately when sections exist, caches backend render HTML, and keeps backend rendering as a background upgrade
- `ViewModels/DesignViewModel.swift` — loads current assignment once initially and after Apply/Undo, but category changes no longer reload assignment or reset user selection
- `Features/V2/Design/RedesignResumeView.swift`, `Features/V2/Improve/OptimizationDesignSheet.swift` — route category/template taps through explicit selection methods
- `Features/V2/Improve/OptimizedResumeView.swift` — removed forced preview view recreation on section changes
- `ResumeBuilder IOS APPTests/LiveEndpointStabilizationTests.swift` — added regression coverage for category selection not being overwritten
- `tasks/lessons.md`, `tasks/progress.md`, `tasks/todo.md`, `tasks/session-log.md` — updated notes and validation
**Validation:**
- XcodeBuildMCP `build_run_sim` succeeded on iPhone 17 Pro Max simulator
- XcodeBuildMCP `test_sim` passed 33/33 after fixing the test spy return bug
**Decisions Made:**
- The optimized preview should never wait on the backend render-preview route once local sections/contact are available; backend design HTML can replace the local rendering when it returns.
- Current design assignment is a synchronization event, not something to run on every category change.
**Next Recommended Action:** Rebuild on the physical device and repeat the live smoke: optimize a resume, confirm preview appears quickly, switch Traditional/Modern/Creative/Corporate, apply one design, return to Optimized, then run/apply Expert and confirm ATS refresh.

### 2026-05-25
**Task:** Repair optimize/design/expert live data flow after rebuild issues
**Files Changed:**
- iOS: optimization detail/contact decoding, real-contact preview fallback, design assignment reload, Expert evidence input, no-cache Expert/ATS refresh, and focused regression tests
- Backend: optimization detail contact response, UUID-backed design preview/export template resolution, iOS customization normalization, Jest setup resilience, and focused contract tests
- `tasks/lessons.md`, `tasks/progress.md`, `tasks/todo.md`, `tasks/session-log.md` — updated status and lessons
**Validation:**
- XcodeBuildMCP `build_sim` succeeded on iPhone 17 Pro Max simulator
- XcodeBuildMCP `test_sim` passed 32/32
- Backend focused Jest contracts passed 7/7 for iOS optimization/design and Expert run/apply
**Decisions Made:**
- Backend preview/export resolves template UUIDs to `category-slug` so the renderer can choose distinct traditional/modern/creative/corporate layouts.
- iOS now treats backend preview as the primary optimized resume renderer when an optimization id exists; local HTML is only a real-data fallback.
- Expert user input is sent as `evidence_inputs.user_context` and successful applies trigger no-cache section/design/ATS refresh.
**Next Recommended Action:** Deploy the backend repair branch and rebuild iOS, then run a physical-device smoke test: optimize a resume with known contact info, apply each design category, run Expert with evidence, apply changes, and confirm preview/PDF/contact/ATS refresh.

### 2026-05-24
**Task:** Live upload end-to-end follow-up after stale main rebuild
**Files Changed:**
- `Core/API/UploadFilePreflight.swift` — generates a simple backend-readable text-layer PDF from extracted PDF text before upload
- `ResumeBuilder IOS APPTests/LiveEndpointStabilizationTests.swift` — verifies uploaded PDF data still contains extractable resume text
- `tasks/MEMORY.md`, `tasks/lessons.md`, `tasks/progress.md`, `tasks/todo.md`, `tasks/session-log.md` — updated status and lessons
**Validation:**
- XcodeBuildMCP `build_sim` succeeded on iPhone 17 Pro simulator
- XcodeBuildMCP `test_sim` passed 25/25
**Decisions Made:**
- Local `main` must be pulled after PR merge before rebuilding in Xcode; the previous phone logs came from a stale local `main`.
- Normalize readable PDFs in iOS before upload so the backend parser receives predictable PDF internals.
**Next Recommended Action:** Merge/rebuild this follow-up branch on physical iPhone and verify optimize returns a live `reviewId` or `optimizationId`.

### 2026-05-24
**Task:** Follow-up stabilization after merged live endpoint PR and phone logs
**Files Changed:**
- `ViewModels/DesignViewModel.swift` — no longer auto-refreshes style history after apply/undo; uses stable design undo fallback when no history exists
- `Features/V2/Design/RedesignResumeView.swift` — removed automatic style-history load on screen open
- `Features/V2/Improve/OptimizationDesignSheet.swift` — removed automatic style-history load on sheet open
- `Core/API/UploadFilePreflight.swift` — added PDFKit readability validation for malformed/scanned/no-text PDFs
- `ResumeBuilder IOS APPTests/LiveEndpointStabilizationTests.swift` — added real text PDF fixture generation and unreadable PDF regression coverage
- `tasks/MEMORY.md`, `tasks/lessons.md`, `tasks/progress.md`, `tasks/todo.md`, `tasks/session-log.md` — updated live endpoint status
**Validation:**
- XcodeBuildMCP `build_sim` succeeded on iPhone 17 Pro simulator
- XcodeBuildMCP `test_sim` passed 25/25
**Decisions Made:**
- `/api/v1/styles/history` is optional audit data and should not run on normal design navigation while it returns 500.
- Local upload preflight should reject PDFs without extractable text before `/api/upload-resume`.
**Next Recommended Action:** Rebuild on physical iPhone from `codex/live-upload-style-followup`, test with a known-good text-based PDF, then fix backend `/api/v1/resumes` and style-history route gaps.

---

### 2026-05-24
**Task:** Live endpoint stabilization after phone smoke logs
**Files Changed:**
- `Core/API/RuntimeServices.swift` — added runtime Resume Library availability gate
- `Core/API/APIClient.swift`, `Core/API/UploadFilePreflight.swift` — added user-facing API error cleanup, upload file validation, and PDF MIME handling
- `Features/Tailor/TailorView.swift`, `Features/Tailor/TailorViewModel.swift`, `ViewModels/ResumeLibraryViewModel.swift` — disabled broken Resume Library UI gracefully and improved PDF upload guidance
- `ViewModels/OptimizedResumeViewModel.swift`, `Features/V2/Improve/OptimizedResumeView.swift`, `Features/V2/Preview/ResumePreviewWebView.swift` — reduced duplicate initial loads/renders and ignored benign cancellation
- `ResumeBuilder IOS APPTests/LiveEndpointStabilizationTests.swift` and Xcode project — added regression tests
### 2026-05-28
**Task:** rb-aso-002 — render App Store screenshots for Resumely iOS
**Files Changed:**
- `ContentView.swift` — routes to screenshot mode only when `--marketing-screenshot` is passed
- `Features/V2/Marketing/MarketingScreenshotView.swift` — new launch-argument-only renderer for 5 English App Store screenshot slots
- `dist/app-store-screenshots/rb-aso-002/` — exported source captures, 6.7" PNGs, 6.5" PNGs, and upload manifest
- `tasks/todo.md`, `tasks/progress.md`, `tasks/session-log.md` — updated task status
**Decisions Made:**
- Screenshot mode is not reachable in normal app launches and does not alter production navigation.
- Captured real SwiftUI renders using the Build iOS Apps plugin, then exported exact App Store dimensions with `sips`.
- App Store Connect upload remains blocked locally because no Fastlane config, ASC API key, or active ASC session is available in the workspace.
**Validation:**
- XcodeBuildMCP `build_run_sim` succeeded for the screenshot renderer.
- XcodeBuildMCP `test_sim` passed 33/33.
**Next Recommended Action:** Provide/enable App Store Connect upload credentials or upload the files from `dist/app-store-screenshots/rb-aso-002/iphone-6.7/` and `iphone-6.5/` manually in slot order.

- `tasks/MEMORY.md`, `tasks/lessons.md`, `tasks/progress.md`, `tasks/todo.md`, `tasks/session-log.md` — updated roadmap/status
**Decisions Made:**
- Runtime stays live-only; missing Resume Library backend is disabled, not mocked.
- `/api/v1/resumes` is a backend blocker and must return JSON before iOS re-enables saved resumes.
- PDF upload should fail early for missing/empty/unsupported files and send real PDFs as `application/pdf`.
**Next Recommended Action:** Implement backend Resume Library routes, flip `RuntimeFeatures.isResumeLibraryEnabled`, then run real-device smoke with a known-good text PDF.

---

### 2026-05-24
**Task:** Make runtime app live-only; remove user-facing mock services, mock optimize path, and stale `mock-opt-001` persistence
**Files Changed:**
- `Core/API/RuntimeServices.swift` — new live-only runtime service factory
- `Core/API/BackendConfig.swift` — removed runtime mock flags
- `App/AppState.swift` — clears persisted `mock-` optimization ids during bootstrap
- `Features/Tailor/TailorViewModel.swift` — removed mock library optimize branch and `pendingMockSections` write path
- `Features/V2/Improve/OptimizedResumeTabView.swift` — builds optimized VM from real optimization id only
- Runtime VM/service defaults — switched default dependencies to `RuntimeServices`
- `Features/V2/Preview/ResumePreviewWebView.swift` — live design render service by default; ignores normal SwiftUI cancellation
- `ResumeBuilder IOS APPTests/RuntimeServicesTests.swift` and Xcode project — added live-only runtime and stale mock-id regression coverage; included existing optimized VM tests in the test target
- `tasks/lessons.md`, `tasks/progress.md`, `tasks/todo.md`, `tasks/session-log.md` — updated project memory
**Decisions Made:**
- Runtime app never falls back to mock data; backend gaps now surface real errors.
- Mock services remain in the app target only for explicit test and SwiftUI preview injection.
- `RuntimeServices` is the single source for live runtime default dependencies.
**Next Recommended Action:** Real-device smoke test: sign in, upload a real PDF, paste a job description, optimize, confirm a real optimization id reaches Optimized/Design/Expert flows, and capture any backend errors as live endpoint issues.

---

### 2026-05-17
**Task:** Fix preview not rendering — add mock design service flag, proper HTML, client-side fallback, Design tab live preview
**Files Changed:**
- `Core/API/BackendConfig.swift` — added `useMockDesignService = true`
- `Features/V2/Preview/ResumePreviewWebView.swift` — wired new flag; added client-side fallback via `ResumeHTMLBuilder`; added `ResumeHTMLBuilder` enum
- `Services/MockResumeServices.swift` — replaced trivial mock HTML with full resume template; added `MockResumeHTMLBuilder` enum with accent-color support
- `Features/V2/Design/RedesignResumeView.swift` — replaced static placeholder `previewCard` with `ResumePreviewWebView` when `optimizationId` is set
- `App/MainTabViewV2.swift` — added `@Environment(AppState.self)`; syncs `designViewModel.setOptimizationId` on appear + onChange
**Decisions Made:**
- Granular `useMockDesignService` flag (mirrors `useMockLibraryService`) — independent of `useMockServices` so design preview works without touching other services
- Client-side `ResumeHTMLBuilder` fallback: when backend returns empty `preview_html` and sections are loaded, generates HTML from section data client-side — ensures preview always shows something
- Design tab preview uses `.id(templateId + accentColor)` to force re-render when customization changes
**Next Recommended Action:** Simulator smoke test — optimize → check Optimized tab preview shows HTML resume → tap Open Design → check Design tab preview matches → flip `useMockDesignService = false` once backend `/api/v1/design/render-preview` ships

---

### 2026-05-15
**Task:** Implement full spec "Merge Track→Me, Redesign Optimised Resume, Real Resume Library" — Stories 1, 3, 2, 5, 4 (in execution order)
**Files Changed:**
- `Core/DesignSystem/Components/ResumlyTabBar.swift` — new `ResumlyTab` enum (tailor/optimized/design/expert/me)
- `App/AppState.swift` — added `latestOptimizationId` with UserDefaults persistence
- `App/MainTabViewV2.swift` — full rewrite: 5-tab layout, stable VMs, `onSwitchTab` closure
- `Features/V2/Improve/OptimizedResumeTabView.swift` — NEW: wrapper that syncs OptimizedResumeViewModel from AppState
- `Features/V2/Expert/ExpertTabView.swift` — NEW: wrapper that syncs ExpertModesViewModel from AppState
- `Features/Tailor/TailorViewModel.swift` — ported runFreeATS, removed single-slot cache, added pendingSaveResumeId
- `Features/Tailor/TailorView.swift` — branched optimize/ATS, save prompt, library picker, onSwitchTab
- `Features/V2/Improve/OptimizedResumeView.swift` — rewritten: preview-first with ResumePreviewWebView, new bottom bar
- `Features/Profile/ProfileView.swift` — applications section inline, compare sheet
- `Models/SavedResume.swift` — NEW
- `Core/API/Endpoints.swift` — added savedResumes/saveResume/deleteResume/renameResume cases
- `Core/API/BackendConfig.swift` — added useMockLibraryService flag
- `Services/ResumeLibraryService.swift` — NEW: protocol + real + mock implementations
- `ViewModels/ResumeLibraryViewModel.swift` — NEW: @Observable VM for library
- `Features/Tailor/SavedResumePickerSheet.swift` — NEW: library picker sheet
- `Features/Home/MainTabView.swift` (legacy) — removed deleted type references
- DELETED: `Features/Score/ScoreView.swift`, `Features/Score/ScoreViewModel.swift`, `Features/V2/Profile/ProfileViewV2.swift`, `Features/Track/ApplicationsListView.swift`
**Decisions Made:**
- `onSwitchTab: (ResumlyTab) -> Void` closure pattern for cross-tab navigation (no NotificationCenter)
- `latestOptimizationId` on AppState as shared carrier for current optimization across Optimized/Expert tabs
- Resume library shipped with `useMockLibraryService = true`; flip flag once web backend ships `/api/v1/resumes`
- `OptimizedResumeView` now preview-first (inline WebView, no section cards)
- Applications merged into ProfileView; dedicated track tab dropped
**Next Recommended Action:** Simulator smoke test all 5 tabs → create PR `claude/hungry-chatelet-a86030` → `main` → flip `useMockLibraryService` once web API ships

---

### 2026-05-13
**Task:** Install Agent OS infrastructure (AGENTS.md, CLAUDE.md, CODEX.md, tasks/, docs/, .agent-os/)
**Files Changed:** 49 new markdown files created. No Swift files changed.
**Decisions Made:** Thin router design — AGENTS.md/CLAUDE.md/CODEX.md route to detail files in .agent-os/. Task memory lives in tasks/. Product + architecture docs in docs/.
**Next Recommended Action:** Read `tasks/lessons.md` + `tasks/progress.md`, then plan the next story from `plan-phases-3-5-6.md` using the feature-planning workflow.
