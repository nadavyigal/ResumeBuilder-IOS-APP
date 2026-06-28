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
