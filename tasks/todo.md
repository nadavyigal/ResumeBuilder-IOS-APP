# WP-45 S0 — Measurement Contract and Baseline (2026-07-12)

Goal: establish the privacy-safe baseline and event contract needed to measure removal of the pre-optimization Fit gate without changing the user journey in this story.

## Implementation Plan
- [x] `ResumeBuilder IOS APPTests/AnalyticsServiceTests.swift` — added the red contract for `analysis_cta_tapped` and versioned Fit events.
- [x] `ResumeBuilder IOS APP/Core/Analytics/AnalyticsService.swift` — added bounded, non-PII measurement properties for the current `fit_gate_v1` flow.
- [x] `ResumeBuilder IOS APP/Features/V2/Home/HomeTabView.swift` — fires one Analyze-intent event from the real authenticated button, not retry paths.
- [x] `ResumeBuilder IOS APP/Features/Tailor/TailorView.swift` — fires the same event from the live Tailor entry.
- [x] `docs/qa/reports/wp45-s0-measurement-baseline-2026-07-12.md` — saved the founder/QA/bot-excluded baseline, cohort rules, and on-call questions.
- [x] Verification — red contract failure confirmed; focused analytics tests passed 13/13; Debug simulator build succeeded; SpyTransport smoke captured the event; `git diff --check` and privacy review passed.
- [x] Memory — updated `tasks/progress.md`, `tasks/session-log.md`, and the Swift 6 nonisolated-helper lesson.

## Out of Scope
- Removing `FitCheckView` or changing navigation.
- Scoring, extraction, API, Supabase, deployment, App Store, or production PostHog configuration changes.

---

# Story: Supabase + PostHog post-live current-state review (2026-07-06)

Decision: do not make paid acquisition, monetization, or export-UX calls from the current data; production usage is too small and too QA-heavy, while backend optimization completion is healthy once reached.

## Findings
- [x] Supabase backend path since App Store live: 23/23 completed optimizations, 0 failed optimizations, 36 review runs, 23 applied review runs.
- [x] Backend activity is highly concentrated: one user/tester accounts for 22 of 23 optimizations and all saved applications/resumes.
- [x] Clean PostHog iOS read: 51 launchers, 9 upload CTA tappers, 4 file selectors, 7 uploaders, 4 job-added users, 1 optimization completer, 0 clean export successes.
- [x] v1.3 export-view instrumentation is verified but not yet backed by real production completer volume.

## Next
- [x] Harden analytics identity and test filtering: stable app/build/environment properties, internal tester flag, PostHog aliasing after Supabase auth, and backend optimization id correlation.
- [ ] Focus the next product pass on first-session upload/job activation before export/paywall changes.
- [ ] Re-run the clean funnel after v1.3 (8) or later is live for a real user cohort.

## Story 1 Implementation Plan — Analytics Identity Hardening
- [x] `Core/Analytics/AnalyticsService.swift` — add stable anonymous session id, `app=resumely_ios`, `marketing_version`, `build_number`, `is_internal_tester`, and PostHog `$create_alias` / `$identify` support.
- [x] `App/AppState.swift` — identify/alias immediately after Supabase auth succeeds and rehydrate analytics identity after restored sessions.
- [x] `Features/Tailor/TailorViewModel.swift`, `ViewModels/ImproveViewModel.swift`, `Features/V2/History/OptimizationReviewView.swift` — include non-content `optimization_id` / `review_id` properties where optimization start/completion events are emitted.
- [x] `Config/Info.plist`, `Secrets.xcconfig.template` — add an optional internal tester user-id allowlist without committing private values.
- [x] `ResumeBuilder IOS APPTests/AnalyticsServiceTests.swift` — cover global properties, stable anonymous identity, alias/identify payloads, and optimization id properties.
- [x] Verification — focused analytics tests, full simulator tests, Debug build, simulator launch, PostHog launch-property read, and manual sign-in identity evidence passed. Fresh rows on 2026-07-08: `$create_alias` at `2026-07-08T07:49:02.112Z` from anonymous `7AB71271-C87B-461C-948D-B1923A0454B2` to user alias `9fa6c1f5-9aba-439e-9e4e-5760d516ce6e`; `$identify` at `2026-07-08T07:49:02.275Z` with `app=resumely_ios`, build `8`, marketing version `1.3`, `is_internal_tester=true`, and the same anonymous session id.

## Story 2 — Canonical Activation Metric
- [x] Updated PostHog insight `3NiBhRDP` in place: `Resumely — Canonical Activation Status (clean iOS 60d)`.
- [x] Primary activation is now `optimization_completed`, labeled `PRIMARY_ACTIVATION`.
- [x] `export_success` remains present but is labeled `SECONDARY_EXPORT_DIAGNOSTIC`.
- [x] Query filters to iOS `$lib=resumely-ios-urlsession` and keeps founder/QA/bot person-prefix exclusions: `067544b5`, `761e5b1b`, `a6441489`, `712cf425`.
- [x] Evidence from refreshed insight run: 68 launched, 11 upload CTA tapped, 10 file picker opened, 5 file selected, 12 resume uploaded, 7 job added, 3 optimization completed, 1 export success.

## Story 3 — Launch to Upload CTA Wall
- [x] Reproduced fresh-launch Home: upload CTA is above the fold after the app settles; early 2s screenshot can still catch a blank startup frame.
- [x] Queried PostHog clean iOS data and found historical launch → CTA loss is partly contaminated by pre-instrumentation/alternate-path users with downstream activity but no CTA event.
- [x] Isolated the focused product friction: Home's primary "Choose a file" CTA opened an intermediate upload sheet before the system file picker.
- [x] Added `resume_upload_cta_seen` so future reads can separate CTA exposure from CTA tap.
- [x] Changed Home upload CTA, upload retry, and FitCheck need-resume paths to open the system file picker directly.
- [x] Verification: `AnalyticsServiceTests` 12/12 passed; PostHog confirmed fresh `resume_upload_cta_seen`, `resume_upload_cta_tapped`, and `resume_file_picker_opened` rows with `is_internal_tester=True`; XcodeBuildMCP tap smoke opened Files directly.
- [ ] Next cohort read: compare post-fix `resume_upload_cta_seen` → `resume_upload_cta_tapped` → `resume_file_picker_opened` on non-founder users once enough production traffic exists.

## Story 4 — File Picker to File Selected Loss
- [x] Queried clean iOS 60d funnel: 10 picker openers → 5 file selectors; no production `resume_file_picker_cancelled` rows existed.
- [x] Queried recent non-selectors: users repeatedly opened the picker/tapped upload but had no file selected or upload events.
- [x] Reproduced likely friction: iOS Files opens on an empty Recents screen, with Browse only available in the bottom tab bar.
- [x] Replaced inactive "Paste text / Try sample" Home copy with real file-location cues: `Files · iCloud Drive · Downloads`.
- [x] Added fallback cancellation tracking when Home's importer dismisses without a result.
- [x] Verification: `AnalyticsServiceTests` 12/12 passed; patched Home screenshot looked clean; CTA opened Files directly; PostHog confirmed fresh QA `resume_upload_cta_seen`, `resume_upload_cta_tapped`, and `resume_file_picker_opened` rows with `is_internal_tester=True`.
- [ ] Manual or next-real-user verification: confirm `resume_file_picker_cancelled` lands after the user closes the system picker without selecting a file.

## Report
- [x] `docs/qa/reports/supabase-post-live-current-state-2026-07-06.md`

---

# Story: Submit Package reopened-from-Me persistence fix (2026-06-28)

Decision: saved packages reopened from Me must reconstruct the full internal package even when the backend list/detail omits `source_url` or returns no saved expert reports.

## Fixed
- [x] Persist Submit Package metadata locally by optimization id after Save to Me succeeds.
- [x] Include Submit Package metadata in the application create `job_extraction` payload: job link, optimization id, cover letter text, and screening answers.
- [x] Decode job links from top-level and nested `job_extraction.submit_package` aliases.
- [x] Decode expert-report envelopes from `reports`, `expert_reports`, `data`, or a bare array.
- [x] Reopened Me detail now falls back through backend reports, job extraction, remembered job URL, and local Submit Package cache for Job Link, Cover Letter, and Interview Q&A.

## Validation
- [x] `git diff --check` — passed.
- [x] Targeted Submit Package persistence tests — 4 executed, 0 failures.
- [x] Debug simulator build on iPhone 17 Pro — **BUILD SUCCEEDED**.
- [x] Release generic iOS build with `CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED**.
- [ ] Founder physical-phone smoke: LinkedIn URL optimize → Submit Package → Save to Me → open from Me and verify Job Link, Cover Letter, and Interview Q&A.

## Note
- A full `OptimizedResumeViewModelTests` run reached the new passing tests but also hit 4 pre-existing locale-sensitive assertions because the active simulator language was Hebrew; targeted package tests and both builds passed.

---

# Story: Me application detail package UI + Home language switcher (2026-06-28)

Decision: saved applications opened from Me should present as the same internal Submit Package surface, and language selection belongs at the top of Home instead of inside Me.

## Fixed
- [x] Rebuilt `ApplicationDetailView` as a dark package-style ScrollView with package ready header, role/company card, internal tracking note, contents, share/copy/open actions, cover-letter preview, secondary actions, and overview.
- [x] Kept package actions internal: share resume PDF, copy cover letter, and open the job link, with copy that says nothing is sent automatically.
- [x] Removed the language section from Me/Profile.
- [x] Added a compact EN/HE language switcher to the top of Home and moved the step badge under the Home header.
- [x] Added Hebrew translations for the new package copy.

## Validation
- [x] `git diff --check` — passed.
- [x] Debug simulator build on iPhone 17 Pro — **BUILD SUCCEEDED**.
- [x] Release generic iOS build with `CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED**.
- [ ] Founder physical-phone smoke: save a Submit Package, open it from Me, confirm it looks/behaves like the package screen and Home language switching still works.

---

# Story: Fit-First LinkedIn URL carry-forward fix (2026-06-28)

Decision: Fit-First must preserve URL-only job input from Home/Tailor instead of forcing a second pasted job description.

## Fixed
- [x] `FitCheckViewModel` now stores `jobDescriptionURL` and allows URL-only checks.
- [x] Fit check requests now send `jobDescriptionUrl` when a URL exists.
- [x] Home and Tailor seed the Fit view-model with the URL the user already entered.
- [x] `FitCheckView` shows the carried job link and makes pasted description optional when a URL is present.
- [x] Added focused regression coverage that URL-only input is valid and reaches `FitCheckService`.

## Validation
- [x] `git diff --check` — passed.
- [x] Focused `FitCheckViewModelTests` on iPhone 17 simulator — 17 executed, 1 skipped live fixture, 0 failures.
- [x] Debug simulator build on iPhone 17 — **BUILD SUCCEEDED**.
- [ ] Founder physical-phone smoke: LinkedIn URL-only flow should no longer require paste.

---

# Story: Fit-First Home smoke quick fix (2026-06-28)

Decision: the V2 Home Analyze path must route through Fit-First when `BackendConfig.isFitCheckEnabled = true`; Tailor-only wiring was insufficient for build 1.1 (7) smoke.

## Fixed
- [x] `HomeTabView.runAnalysis()` now prepares the saved server resume, opens `FitCheckView`, and only continues to optimize from the Fit verdict CTA.
- [x] The Home Fit check passes `resumeId`, bearer token, and job description to `FitCheckViewModel`.
- [x] Direct optimize/review apply save prompts now use the optimization id rather than the uploaded resume id, avoiding the observed save 404.

## Validation
- [x] `git diff --check` — passed.
- [x] Debug simulator build on iPhone 17 — **BUILD SUCCEEDED**.
- [x] Focused `FitCheckServiceTests` + `FitCheckViewModelTests` on iPhone 17 simulator — 21 executed, 1 skipped live fixture, 0 failures.
- [x] Release generic iOS build with `CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED**.
- [ ] Founder physical-phone smoke after rebuild: Home Analyze should show Fit check and log `/api/public/ats-check` before `/api/optimize`.

# Story: Submit Package job-link carryover for build 1.1 (7) (2026-06-28)

Decision: Submit Package is an internal tracking/share package. It must carry the original optimize job link and cover letter, but never imply auto-submit to a recruiter.

## Fixed
- [x] Remember job URL by optimization id after Home/Tailor/Improve optimize success.
- [x] Seed Optimized/Expert/Profile/Application Detail submit flows with remembered/backend job URL.
- [x] Submit Package preview now shows package contents: Resume PDF, Cover Letter, and Job Link.
- [x] Submit Package copy now says saving/sharing is internal and nothing is sent automatically.
- [x] Covered provider URL fallback when the form starts empty.

## Validation
- [x] `git diff --check` — passed.
- [x] Focused Submit Package tests on iPhone 17 Pro simulator — 4 executed, 0 failures.
- [x] Debug simulator build/run on iPhone 17 Pro — **BUILD SUCCEEDED**.
- [x] Release generic iOS build with `CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED**.
- [ ] Founder physical-phone smoke: LinkedIn URL optimize → Submit Package form prefilled with Job Link → Create Package shows Cover Letter and Job Link → Save to Me.

---

# Story: Fit-First resume_id swap (2026-06-28)

Decision: the authenticated iOS Fit-First check now sends the stored server `resumeId` to the existing `POST /api/public/ats-check` instead of re-uploading a PDF. The anonymous PDF-upload contract remains available through the original `APIClient.runPublicATSCheck(resumeURL:...)` overload.

## Fixed
- [x] Added an authenticated fields-only public ATS check path in `APIClient` with `resume_id`, job fields, bearer token, and optional `x-session-id`.
- [x] Changed `FitCheckService`/`FitCheckViewModel` to require `resumeId` and `accessToken` for the iOS Fit check.
- [x] Reused Tailor's existing deferred upload path to get the server `resumeId` before opening Fit check.
- [x] Prevented stale upload reuse by keying the cached upload response to selected resume path + trimmed job description + trimmed job URL.
- [x] Reused the same upload response for optimize after Fit check so the app does not upload twice.
- [x] Updated focused Fit check tests for the resume-id contract and missing-token guard.

## Validation
- [x] Focused `FitCheckServiceTests` + `FitCheckViewModelTests` on iPhone 17 simulator — 21 executed, 1 skipped live fixture, 0 failures.
- [x] Debug simulator build on iPhone 17 — **BUILD SUCCEEDED**.
- [x] `git diff --check` — passed.
- [ ] Real authenticated saved-resume Fit-check simulator smoke on iPhone 17/iPhone SE — blocked by no authenticated saved-resume fixture/credentials in this session.

---

# Story: v1.1 Build 7 ASC Submission Handoff (2026-06-27)

Decision: code on `main` is locally archive-ready for v1.1 (7) after resolving the string-catalog extraction diff; App Store Connect submission remains founder-only because this machine does not have an Apple Distribution signing identity.

## Fixed
- [x] Inspected the uncommitted `ResumeBuilder IOS APP/Resources/Localizable.xcstrings` diff.
- [x] Kept the legitimate extracted recovery string: "This review was already applied. Open the optimized resume from the Optimized tab."
- [x] Added Hebrew translation for that recovery string so HE/RTL runtime language mode does not fall back to English.

## Confirmed
- [x] `MARKETING_VERSION = 1.1`
- [x] `CURRENT_PROJECT_VERSION = 7`
- [x] Bundle ID: `Resumebuilder-IOS.ResumeBuilder-IOS-APP`
- [x] `BackendConfig.isFitCheckEnabled = true`
- [x] Production API base URL in project settings: `https://www.resumelybuilderai.com`
- [x] Entitlements contain Sign in with Apple and no additional unexpected entitlement.
- [x] Local signing blocker remains: keychain has Apple Development only, no Apple Distribution identity.

## Validation
- [x] `jq empty "ResumeBuilder IOS APP/Resources/Localizable.xcstrings"`
- [x] Full Debug simulator tests on iPhone 17 iOS 26.5 — 107 XCTest + 5 Swift Testing, 0 failures.
- [x] Release `iphoneos` compile/store-validation proxy — `xcodebuild build ... -configuration Release -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED**.

## Founder-only ASC steps
- [ ] Open Xcode on `main`, resolve Apple Distribution signing for team `8VC4R5M425`.
- [ ] Product → Archive.
- [ ] Organizer → Validate App.
- [ ] Organizer → Distribute App → App Store Connect.
- [ ] In ASC, select/upload build `1.1 (7)`, fill release notes, and submit for review.
- [ ] After approval and App Store live availability, verify production PostHog project `270848` receives WP-18 upload-funnel events: `resume_upload_cta_tapped`, `resume_file_picker_opened`, `resume_file_selected`, `resume_upload_succeeded`.

---

# Story: Optimization Review Apply Timeout Recovery (2026-06-26)

Decision: fix the real-device apply failure as an iOS recovery gap around a non-idempotent backend mutation. The apply endpoint can finish server-side after the client times out; iOS must reload review state and continue to the optimized resume instead of surfacing the retry's already-applied error.

## Fixed
- [x] `OptimizationReviewViewModel` uses a 120s timeout for apply.
- [x] Timeout and already-applied failures reload `/api/v1/optimization-reviews/{id}` and recover `optimization_id`.
- [x] `OptimizationReviewRunDTO` decodes applied optimization ids from snake_case and camelCase keys.
- [x] `APIClient` supports injecting the long-running URLSession so timeout recovery is testable without live network.
- [x] Regression test covers timeout-after-server-success recovery.

## Validation
- [x] Focused `ResumeOptimizationParsingTests` — 7/7 passed.
- [x] Debug build on iPhone 17 simulator — **BUILD SUCCEEDED**.
- [ ] Physical phone smoke retry of the same apply path after pulling/rebuilding this fix.

---

# Story: Resumely Activation Redesign — QA fix pass (2026-06-25)

Decision: the implementation pass below was QA'd before being committed. 8 issues found, all fixed in this pass — see the top entry in `tasks/progress.md` for full detail. Summary:

## Fixed
- [x] WP-18 `.doc` regression in `HomeTabView.resumeImportContentTypes` (was silently dropped) — restored, plus fixed the underlying preflight gap so `.doc` actually works (`UploadFilePreflight.mimeType(for:)` now recognizes `application/msword`)
- [x] Upload sheet had zero analytics (reopened the WP-18 measurement black box) — added `resume_upload_sheet_dismissed`, `resume_upload_coming_soon_tapped`
- [x] `ScoreResultView` showed fake duplicate Keywords/Format/Impact tiles (all the same number) — replaced with real-data stats (issues found / quick wins / checks remaining)
- [x] `ProfileView` RTL fix only covered the hero header, not the full screen — fixed scope
- [x] Ad-hoc `localized(en:he:)` helper bypassing `Localizable.xcstrings` — migrated 9 strings into the catalog, removed the helper
- [x] **Critical:** `TargetReachedView`/`SaveAccountSheetView` were wired into `ImproveView`, which is never instantiated anywhere in the app (dead code) — rewired into the live `OptimizedResumeView` via `onChange(of: viewModel.atsScoreAfter)`
- [x] E1/E3 funnel screens (parsing/analyzing) were never built as separate mockups — updated `ResumeOptimizationLoadingView.atsCheck` copy to the recruiter-framed language instead, since a separate full-screen flow would conflict with the already-shipped Home upload-first IA (documented decision, not a silent drop)
- [x] R3 (connection-lost) was never built — added `ConnectionLostView` + `TailorViewModel.isConnectionError` (real `URLError` classification), manual retry only (no fake auto-resume claim)

## Still not done (honest, unchanged from the original pass)
- [ ] E2 (separate full-screen "match to job" step) — deliberately not built; job input stays inline on Home per Story 1's shipped IA
- [x] iPhone SE simulator visual smoke (2026-06-26) — created fresh `Resumely Build7 iPhone SE` simulator on iOS 26.5; checked Home EN/HE, upload hero, locked Optimized/Design/Expert teasers, and Me language/RTL surfaces. Fixed visible Hebrew fallback strings found during smoke.
- [ ] Deeper manual tap-through QA on-device/in-simulator for every redesigned screen (this pass verified via code review + build + full test suite, not interactive UI smoke)
- [ ] All backend/state flags listed in the original pass below (paste-text, sample diagnosis, parser-stage events, true point deltas, resumable analysis, etc.)

## Validation (this pass)
- [x] Fresh Debug build after all fixes — **BUILD SUCCEEDED**
- [x] Full test suite — **110 tests passed (105 XCTest + 5 Swift Testing), 0 failures**

---

# Story: Resumely Activation Redesign — CodeRabbit review fix pass on PR #83 (2026-06-25)

Decision: fix CodeRabbit's real findings on the open PR, skip verified false positives, rebuild/retest before pushing again.

## Fixed
- [x] Locked-tab checklists always showed `isComplete: false` (bound to `latestOptimizationId != nil` inside the branch where it's always nil) — added `AppState.hasUploadedResumeThisSession`/`hasAddedJobThisSession`, wired from `HomeTabView`
- [x] Target-reached celebration could false-fire on initial load of an already-high-scoring resume — `onChange` now requires a real non-nil prior score
- [x] `ProfileView` "ATS checks" label paired with a percentage value — renamed to "ATS score"
- [x] `TailorViewModel` preflight-rejection analytics lost per-reason granularity (`type(of: error)`) — switched to `UploadFailureReason.analyticsValue`
- [x] `redesign-notes.md` R3 section didn't note the manual-retry-only implementation vs the bold auto-resume spec — added amendment
- [x] Reconciled "105/105" wording to accurate "110 tests (105 XCTest + 5 Swift Testing)"

## Skipped (verified false positive)
- [ ] `@MainActor` on `SaveAccountSheetView`/`TargetReachedView` — project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` build-wide; every other new View in this PR also omits the explicit annotation

---

# Story: Resumely Activation Redesign — implementation pass (2026-06-25)

Decision: implement the work-pack as a buildable native SwiftUI pass without faking backend/state capabilities that do not exist yet. Activation-critical Home/upload/recovery, locked teasers, Me/RTL trust polish, first-score restyle, and target/save-account surfaces are in code; deeper backend-dependent items are flagged.

## Files
- [x] `Core/DesignSystem/Tokens/AppColors.swift` — apply touched-screen contrast bump for secondary/tertiary text
- [x] `Features/V2/Home/HomeTabView.swift` — upload-first hero, progress path, upload sheet handoff, inline failure recovery, PDF/DOCX picker sync
- [x] `Features/V2/Home/UploadSheetView.swift` — app-level pre-picker guidance sheet
- [x] `Features/V2/Home/UploadFailureView.swift` — shared scanned/wrong-type/too-large/generic upload recovery
- [x] `Core/API/UploadFilePreflight.swift` — classify 5 MB failures and keep accepted types honest
- [x] `Features/Tailor/TailorViewModel.swift` — expose preflight failure reason/name to Home recovery UI
- [x] `Core/DesignSystem/Components/LockedTabTeaser.swift` — shared locked tab teaser + preview slots
- [x] `Features/V2/Improve/OptimizedResumeTabView.swift`, `Features/V2/Design/DesignTabView.swift`, `Features/V2/Expert/ExpertTabView.swift` — replace generic locked states
- [x] `Features/Profile/ProfileView.swift` — trust-first guest account redesign, EN/HE explicit copy, custom language segments
- [x] `Features/Score/ScoreResultView.swift` — first-score reveal restyle using existing data only
- [x] `Features/V2/Improve/TargetReachedView.swift`, `SaveAccountSheetView.swift`, `ImproveView.swift` — target celebration/save-account surfaces wired to real `rescanATS` threshold crossing
- [x] `tasks/lessons.md`, `tasks/progress.md`, `tasks/session-log.md` — record completion, validation, and flags

## Checklist
- [x] Reuse existing tokens/components; no new dependencies
- [x] Keep all new screens in `Features/V2/` or shared `Core/DesignSystem/Components/`
- [x] Respect 100pt tab clearance on redesigned scroll surfaces
- [x] Disable/stub paste text and sample résumé routes honestly
- [x] Avoid fake parser progress, fake point deltas, fake resumable offline analysis, and fake backend claims
- [x] Preserve existing file importer/cache/upload pipeline
- [x] Build succeeds
- [x] Focused tests pass
- [x] iPhone 17 simulator install/launch Home smoke
- [ ] Deeper simulator visual smoke for upload sheet/failure states/locked tabs/Me EN+HE/free score reveal
- [x] iPhone SE simulator smoke (2026-06-26) — fresh iPhone SE 3rd gen simulator created and used for build 7 smoke; screenshots saved under `/tmp/resumely-build7-se-smoke/`.
- [x] Full test suite

## Backend/state flags left
- Paste résumé text → diagnosis endpoint
- Bundled sample résumé + no-auth demo diagnosis path
- Real parser-stage progress callbacks
- Global pre-optimization `hasResume`/`hasJob` state for locked tabs
- Generic no-JD scoring path from the Home flow
- Backend sub-scores, ranked fixes, point deltas, apply-all/undo model
- Resumable offline analysis/checkpointing
- Verified guest-session restart guarantee for “Maybe later” copy

## Validation
- [x] `xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build` — **BUILD SUCCEEDED**
- [x] Focused tests: `AnalyticsServiceTests` 9/9 and `FitCheckViewModelTests` 14/14 — **TEST SUCCEEDED**
- [x] Full tests: 105 XCTest tests + 5 Swift Testing tests — **TEST SUCCEEDED**

---

# Story: Fit-First Triage Story 1 — FitCheckService (2026-06-23)

Decision: implement only the iOS service/model story for the Fit-First Triage wedge. Verdict bands are server-owned (>=75 Strong / 50-74 Stretch / <50 Skip as fallback only), resume input stays PDF re-upload, and the endpoint is the existing `POST /api/public/ats-check`.

## Files
- [x] `ResumeBuilder IOS APP/Core/API/Models/FitVerdict.swift` — create `FitVerdict` + `FitBand` with flexible Codable decoding, score clamping, and existing `ResumeGap`/`ResumeKeyword` reuse
- [x] `ResumeBuilder IOS APP/Core/API/FitCheckService.swift` — create protocol, live implementation on `APIClient.runPublicATSCheck`, and injectable mock
- [x] `ResumeBuilder IOS APP/Core/API/Models/DomainModels.swift` — add additive optional `fit` decode to `ATSScoreResult`
- [x] `ResumeBuilder IOS APP/Core/API/RuntimeServices.swift` — expose the live `FitCheckService`
- [x] `ResumeBuilder IOS APPTests/FitCheckServiceTests.swift` — cover payload shapes, band fallback derivation, service/mock behavior, and error mapping
- [x] `ResumeBuilder IOS APP.xcodeproj/project.pbxproj` — add the new test file to the explicit test target
- [x] `tasks/progress.md`, `tasks/MEMORY.md`, `tasks/session-log.md` — update completion memory

## Checklist
- [x] Decode `fit.verdict` when present; derive band from `score.overall` only when verdict is absent
- [x] Decode snake_case and camelCase response keys
- [x] Clamp scores to `0...100`
- [x] Follow the safe Codable pattern: decode candidates into locals before `??`
- [x] Reuse `ResumeGap` and `ResumeKeyword`; do not duplicate gap/keyword model types
- [x] Reuse `APIEndpoint.publicATSCheck`/`APIClient`; do not hardcode endpoint URLs
- [x] Keep Story 1 service-only; no UI screens and no optimize/diagnosis behavior changes

## Validation
- [x] Xcode build succeeds
- [x] Focused `FitCheckServiceTests` run with a non-zero executed test count
- [x] Live `/api/public/ats-check` response decode attempted against reachable Story-0 endpoint; production responded with the existing ATS payload but no additive `fit` block, so the single remaining gate is: deploy Story 0 with `fit`, then rerun the same live call and confirm `FitVerdict` decoding.

---

# Story: Resumely ATS Claim Defensibility (2026-06-20)

Decision: the displayed score is a self-defined "Resumely Match Score", NOT an external ATS vendor's score. ATS copy must be process-descriptive, never outcome-guaranteeing. Copy/labels only — no scoring logic changes.

Canonical strings:
- Score name (room): "Resumely Match Score" / he "ציון ההתאמה של Resumely"
- Score name (constrained): "Match Score" / he "ציון התאמה"
- Explainer: "Based on formatting + keyword match vs the job you paste. Not affiliated with any ATS vendor." / he "מבוסס על עיצוב והתאמת מילות מפתח למשרה שהדבקת. לא מזוהה עם אף ספק ATS."

## Tasks
- [x] ScoreResultView.swift — "ATS Score" → "Resumely Match Score" + explainer microcopy
- [x] OptimizedResumeView.swift — score-card explainer + footer "ATS score" → "Match Score"
- [x] ExpertOutputViews.swift — "ATS Score" → "Match Score"
- [x] ImproveView.swift — metric card "ATS Score" → "Match Score"
- [x] ApplicationDetailView.swift — LabeledContent "ATS score" → "Match Score"
- [x] ApplicationCompareView.swift — ring caption "ATS"→"Match", a11y "ATS score …" → "Match Score …"
- [x] HomeActivationState.swift — "Your free ATS score is in" → "Your free Resumely Match Score is in"
- [x] MarketingScreenshotView.swift — "ATS score" label → "Match Score"; "ATS scores every section" → "Scores every section"; "Templates that pass ATS…" → "ATS-friendly templates…"
- [x] MetricCard.swift — #Preview label aligned to "Match Score"
- [x] OptimizedResumeViewModel.swift — error "ATS score" → "Match Score"
- [x] LinkedInShareComposer.swift — EN + HE: frame number as Resumely match score
- [x] Localizable.xcstrings — renamed keys + Hebrew values; added explainer + "Match" keys
- [x] docs/app-store/he-metadata.md — fixed "ATS score שלך", "ציון ATS", interview-outcome promo line
- [x] Build succeeds (iPhone 17 Pro simulator, Debug) — ** BUILD SUCCEEDED **
- [x] Kept "ATS" only in descriptive contexts (ATS check / ATS insights / ATS match / ATS-friendly / template ATS attribute)

## Deliberately kept (descriptive/feature ATS usage, allowed by decision)
- "Ready for a free ATS check" (HomeActivationState) — a check, not a possessive score
- "ATS insights" / "Improve ATS" / "ATS match" / "ATS-friendly" — process/feature language
- OptimizationDesignSheet template "ATS" badge — template's ATS-friendliness attribute, not user's resume score
- ResumeDiagnosis "More aligned, not guaranteed to pass any ATS." — explicit disclaimer (good)
- DomainModels DecodingError debug strings — developer-only, never user-facing

## Flagged (generated artifacts, not source) — screenshot manifests still say "Templates that pass ATS":
- dist/app-store-screenshots/rb-aso-002/upload-manifest.md
- dist/app-store-screenshots/app-store-v1/upload-manifest.md
