# UI/Copy Improvement Plan — 2026-07-20 (7 stories, branch claude/session-ec92e2)

Decision: execute the 2026-07-20 UI/copy audit plan story by story. Grounding: PROMPTS/ios-ui-copy-followup-audit.md, executive-os/research/2026-07-19-resumely-copy-rewrite-v2.md, .agents/product-marketing.md, DECISIONS.md (Resumely Match Score), GLOBAL-TASTE.md. Analytics event names, API fields, and internal ATS identifiers stay unchanged.

## Stories

- [x] Story 1 — Replace user-facing ATS terminology with Match language (Resumely Match Score, Match, Match estimate, Match insights, Improve match, ATS-friendly, simple-to-parse). ~40 strings across 24 files + catalog migration with Hebrew parity. Red-first CopyClaimsTests added (banned-fragment guard). Focused 2/2 green; Home simulator smoke shows Upload · Add job · Match.
- [x] Story 2 — Share strings rebranded (Resumely Match Score line, tailored-export fallback), share/App Store URLs now point at the real listing (id6776752349), marketing screenshot slots rewritten per rewrite v2 §13, Ambassador banner/success softened. Focused 4/4 green; marketing slot 1 smoke verified.
- [x] Story 3 — OnboardingViewModel takes startInSignUp; Me-tab Create free account opens sign-up, both Sign in entries open sign-in; auth sheet links live Terms/Privacy pages (locale-aware, derived from API_BASE_URL, verified 200 on resumelybuilderai.com). AuthEntryTests added; 6/6 focused green.
- [x] Story 4 — LockedTabTeaser simplified: removed the blurred mock preview with fabricated scores (68/100, fake sub-scores, fake deep-report lines) per GLOBAL-TASTE (no fake confidence scores) and the 2026-06-25 honesty lesson. Locked tabs now show headline, subtitle, real-state unlock checklist, and one CTA; tab bar untouched. Orphaned strings and keys cleaned. Build green. Named limitation: no simulator tap tooling in this session, so locked-tab screenshots deferred to the physical/QA gate.
- [x] Story 5 — All 41 post-FTUX keys translated (catalog now 900/900 Hebrew, 0 fallbacks). HebrewParityTests added red-first (exact 41 failures observed -> green). Language switcher: full 44pt touch target at every Dynamic Type size, container marked .accessibilityElement(children: .contain) so each language button keeps its own localized VoiceOver name. Placeholder parity verified across all 900 keys; 3 pre-existing plural-suffix mismatches confirmed unchanged from base (out of scope, no crash risk).
- [ ] Story 6 — Small-device, Dynamic Type, VoiceOver, contrast, RTL, tab-bar overlap fixes.
- [ ] Story 7 — Full-suite QA on iOS 26.5, Debug + Release builds, EN/HE smokes, banned-claim checks, Taste Review, PR.

---

# WP-48: First post-1.4.3 activation cohort read (2026-07-20)

Decision: the cohort is NOT mature (0 of 20 clean uploaders, 9 hours post-release). Projected maturity **2026-08-18**. Two blocking measurement defects were found that must be fixed before that read, not after. Full evidence: `docs/qa/reports/wp48-post-1.4.3-cohort-read-2026-07-20.md`.

## Read (done)

- [x] Confirm post-release traffic exists — **zero** iOS events in the 9h since 1.4.3 went live; last event of any kind predates the release by ~5.5h.
- [x] Confirm Stories 10-12 events fire on 1.4.3 — **partially**: pre-selection telemetry confirmed on the one pre-release gate session; `resume_file_selected` / `resume_upload_succeeded` / `optimization_completed` / `export_success` remain unconfirmed (that session never selected a file). Not a failure — not yet observable.
- [x] Measure the clean arrival rate: 4.7 file-selectors/week → 20 uploaders ≈ 2026-08-18.
- [x] Reconcile against Portfolio HQ — agrees (read is calendar-blocked, not broken).

## Blocking fixes before the 2026-08-18 read

- [x] **S2-A.** `resume_upload_succeeded` is emitted after the sign-in guard (`TailorViewModel.swift:146` vs `:172`), so it is unreachable for guests and cannot measure S1. Redesignate `resume_file_selected` as the canonical upload denominator and update the Story 10 contract + canonical HogQL. (Docs/query change, no app risk — preferred over moving the call site.)
- [ ] **S2-B.** `is_internal_tester` reported `false` on a pre-release 1.4.3 Debug/TestFlight build (person `c7494f9d`). Fix the classifier so gate runs cannot enter the clean cohort.
- [x] Re-baseline: the 12.5% figure came from the legacy `resume_uploaded` event that 1.4.3 no longer emits. Like-for-like baseline on `resume_file_selected` is **10.0% (1/10)**. Win threshold stays ≥6 of 20.

## S2 instrumentation for 1.4.4 (after the blocking items)

- [ ] `score_screen_signin_tapped` — absent, build it.
- [ ] File type + size bucket on `resume_file_picker_opened` / `_cancelled` (outcome events already ship; reuse the `fileSizeBucket` helper at `TailorViewModel.swift:93`).
- [ ] `job_source` (url vs paste) on `free_ats_completed` and `optimization_started`.

## Hand back to Portfolio HQ

- [ ] HQ's next action still says "re-run on `marketing_version=1.4.1` on 2026-07-25" — stale on both build and date. Retarget to 1.4.3 / 2026-08-18.

---

# Story 13: Release-candidate journey audit (Release C, 2026-07-18)

Decision: release certification requires direct physical preview/export/relaunch/RTL/file-picker/second-job evidence; code and simulator evidence cannot substitute for those taps, and monetization remains deferred until both the journey and clean-cohort gate pass.

## Audit and validation

- [x] Start from merged Stories 1–12 on `main` (`ca64329`) and read the original 20-checkpoint audit from `origin/docs/ftux-audit-rescue`.
- [x] Erase and freshly boot the dedicated iPhone 17 on iOS 26.5; install/launch the exact candidate and verify clean Home.
- [x] Pass the exact candidate full suite: 202 total, 1 intentional skip, 0 failures.
- [x] Confirm Debug simulator and exact-tree generic-device Release builds are green.
- [x] Detect the connected physical iPhone, compile/link for it, open the project in Xcode, and record the Keychain signing gate accurately.
- [x] Publish the 20-checkpoint delta, added export/return-loop gates, physical checklist, and monetization decision in the Story 13 QA report.
- [ ] Founder authorizes signing in Xcode and completes the physical preview, export/share, relaunch, Hebrew/RTL PDF, file-picker, and second-job checklist.
- [ ] Update the report with pass/fail observations; confirm no critical/high defect remains; complete the final PR review, and merge Story 13.
- [x] Commit and publish the automated evidence as a draft Story 13 PR while the physical gate remains pending.

---

# Story 12: Optimize another job retention loop (Release C, 2026-07-18)

Decision: the completed-preview action carries the saved optimized résumé into a fresh job match, while AppState keeps the prior optimization recoverable and analytics carries no content properties.

## Implementation and validation

- [x] Add red-first state and analytics contract tests for another-job preparation, saved-résumé association, prior optimization preservation, and `second_job_started`.
- [x] Replace the post-export “New job” action with “Optimize for another job” and route one explicit request back to Home.
- [x] Reuse the saved optimized résumé when available, retain the in-memory résumé as a safe fallback, and clear only job-derived analysis/review/upload state.
- [x] Scroll and focus the fresh job description input with visible résumé context; localize the new path in Hebrew.
- [x] Pass focused tests, the full iOS 26.5 suite, Debug build, and iPhone 17 + iPhone SE launch/render smokes.
- [x] Pass the exact final-tree unsigned generic-iOS Release build and final diff/privacy/version checks.
- [x] Commit, push, open Story 12 PR #107, address both review findings, pass the updated gates, and merge before Story 13.

---

# Story 11: Touched-screen localization and accessibility (Release C, 2026-07-18)

Decision: close Hebrew fallback at the catalog boundary and make the upgraded journey adapt through semantic typography and explicit accessibility behavior; keep rendered résumé/PDF RTL as a separate physical-device gate.

## Implementation and validation

- [x] Observe the red catalog gate with 99 missing Hebrew localizations; add compiled-bundle regression coverage for touched FTUX strings.
- [x] Translate every catalog entry with no Hebrew value and verify placeholder parity.
- [x] Keep visible signup labels outside placeholders; add Email → Password focus order and keyboard dismissal.
- [x] Add explicit job-field names, preserve actionable recovery controls in VoiceOver order, and expose tab labels/selected state.
- [x] Move shared app typography to semantic Dynamic Type styles; reflow Home progress at accessibility sizes.
- [x] Honor Reduce Motion across Home entrance, signup mode, tab selection, and recovery state.
- [x] Remove the RTL matched-geometry tab-pill ghost found during Hebrew simulator QA.
- [x] Document contrast, VoiceOver, keyboard, Dynamic Type, Reduce Motion, and the separate physical PDF RTL gate.
- [x] Complete final post-fix Debug/Release builds, dual-simulator screenshots, and diff/privacy/version review.
- [ ] Commit/push/open and review-gate the Story 11 PR.

---

# Story 10: Canonical activation and failure instrumentation (Release B, 2026-07-18)

Decision: activation is measured only after WebKit reports a successful visible preview render; every lifecycle event uses bounded non-content categories plus the stable session/review/optimization IDs already returned by the product contracts.

## Implementation plan

- [x] Reconcile the WP-45 `analysis_cta_tapped` baseline and versioned Fit properties against current Story 9 analytics.
- [x] Add red-first contract coverage for apply, validation, recovery, recommendation, save, export, upload semantics, correlation IDs, and visible-preview activation.
- [x] Wire the lifecycle call sites; stop emitting ambiguous legacy `resume_uploaded` completion events.
- [x] Add a reproducible PostHog funnel query and document internal-tester exclusion without reading content fields.
- [x] Pass focused tests, the full iOS 26.5 suite, Debug and generic-device Release builds, dual-simulator smokes, and diff/privacy review.
- [x] Address PR #105 review findings with red-first coverage: reachable validation transitions, feature-flag route versioning, and active optimization/tab visibility deduplication.

---

# Story 9: Evidence-backed review with Accept and Skip (Release B, 2026-07-16)

Decision: v1 evidence is extracted on-device as bounded verbatim substrings of the delivered job and résumé text; the approved additive backend schema remains the v2 upgrade path. Evidence informs the user but never changes recommendation safety defaults or the group-ID-only apply contract.

## Implementation and validation

- [x] Add additive evidence/job-text DTO decoding and deterministic `RecommendationEvidence` extraction with backend preference, version gating, verbatim re-validation, deduplication, and quote bounds.
- [x] Render read-only job/résumé evidence per review group when available; rename the normal Include action to Accept; preserve Skip and explicit factual confirmation.
- [x] Add content-free analytics using fixed `evidence_state` values and evidence quote counts only.
- [x] Confirm red state, then pass focused evidence tests 16/16, focused evidence + analytics + safety tests 35/35, and the full iOS 26.5 suite 188/1 skip/0 failures.
- [x] Pass Debug simulator build and launch smokes on iPhone 17 and Resumely Build7 iPhone SE, both iOS 26.5.
- [x] Pass generic-device Release build with `CODE_SIGNING_ALLOWED=NO`; exclude one earlier manually interrupted run from validation evidence.
- [x] Pass `git diff --check` and final review for unrelated changes, version drift, secrets, credentials, and content-bearing analytics.
- [x] Open draft PR #104 to `main`.
- [x] Complete the PR review gate: CodeRabbit reviewed all 10 remote files with no actionable comments and 5/5 pre-merge checks passed; PR #104 marked ready.

---

# Story 8: Merge Fit into the diagnosis continuation (Release B, 2026-07-16)

Decision: a job the user already entered on Home is not a question to ask again. Fit runs on the carried target directly; the target stays editable right up to the moment of optimizing.

## Implementation plan

- [x] Write focused red-to-green coverage first (11 tests); red state observed by removing the implementation and rebuilding.
- [x] Add `FitContinuation` — a `nonisolated Sendable` policy resolving runAutomatically / askForJob / editTarget / showVerdict / showFailure, with editing taking precedence.
- [x] `FitCheckViewModel`: `beginCarriedFitCheck()` (guarded, runs once), `editTarget()`, `applyEditedTarget()`; `resetToEntry()` clears the new guards.
- [x] `FitCheckView`: drive presentation from `continuationStep`; auto-run via `.task`; add an in-place failure state instead of falling back to the entry form.
- [x] `FitVerdictView`: add "Edit target job" so the target is changeable before optimization.
- [x] Verify: 11 focused tests, full suite 172/1 skip/0 failures, Debug + generic-device Release builds (both succeeded), iPhone 17 + SE smokes.

## Remaining manual acceptance

- [ ] Drive the real authenticated Home → Fit continuation with a live résumé, job, and credentials, and confirm no second Check Fit form appears. Simulator tooling cannot supply these.

---

# Story 7: Preserve guest context through authentication (Release B, 2026-07-16)

Decision: a diagnosis describes the résumé and job it was computed from, not the auth state. Signing in changes neither, so the diagnosis survives; changing an input invalidates the diagnosis alone, never the user's own selections.

## Implementation plan

- [x] Confirm the Release B branch point: #97 is the Release A merge point, so Release B branches from `main`.
- [x] Write focused red-to-green coverage first: 11 policy tests + 4 view-model tests.
- [x] Add `GuestDiagnosisContinuity` — pure fingerprint of (résumé path + normalized job input), carrying no résumé or job content.
- [x] Pair `atsResult` with its fingerprint in `TailorViewModel`; make `atsResult` `private(set)` so the two cannot drift.
- [x] Stop Home gating the diagnosis on `!isAuthenticated`; re-check continuity on every auth transition and input edit.
- [x] Relabel the optimize CTA to "Continue to optimize" when a carried diagnosis stands; never auto-start optimization.
- [x] Verify: 15 focused tests, full suite 161/1 skip/0 failures, Debug + generic Release builds, iPhone 17 + SE smokes.

## Remaining manual acceptance

- [ ] Drive the real guest → ATS → sign-in → continue path with a live résumé, job, and credentials. The available simulator tooling cannot supply these, so the end-to-end continuity is proven by tests and not yet by observation.

## Out of scope (flagged, not fixed)

- `ScoreResultView`'s authenticated copy still says "Use Tailor to generate the full optimized resume" — legacy wording for a tab the V2 flow no longer has. `ScoreResultView` is outside Story 7's file scope; belongs to the Release C copy/localization pass.
- New Home strings ("Optimize", "Continue from the diagnosis you already ran", "Continue to optimize") have no Hebrew translation yet and will fall back to English. Release C Story 11 is the localization pass.

---

# Bug: Optimized résumé appears missing after rebuild (2026-07-14)

Decision: the résumé is the primary deliverable and must be visible in the initial Optimized viewport; supporting insights follow it.

- [x] Read the supplied log in full and separate API failures from unrelated simulator warnings.
- [x] Reproduce the missing-looking state on iPhone 17 and confirm the document renders below the fold.
- [x] Move the existing preview directly below the score without changing optimization/review state or analytics payloads.
- [x] Pass focused tests and Debug build; smoke iPhone 17 and the smallest supported iPhone SE.
- [x] Complete Release build, commit, push, and update PR #94.

---

# Bug: Optimization Review renders blank after successful review fetch (2026-07-14)

Decision: navigation destinations retain their review model across parent refreshes and only replace it for a different review ID.

- [x] Read the physical-device logs in full and confirm the review response succeeds and decodes.
- [x] Add a focused model-lifetime regression test and confirm the missing state owner is red first.
- [x] Add a stable state-owned review destination across Home, Tailor, Improve, and History.
- [x] Pass focused tests, Debug iPhone 17 + smallest supported iPhone SE smoke, and generic-device Release build.
- [x] Update project memory, commit, push, and open a focused follow-up PR.

---

# Story 6: Preview-owned save, export, and relaunch continuity (Release A, 2026-07-14)

Decision: the optimized preview owns saved-résumé state; successful saves persist the live API response locally by optimization ID, failures keep the preview visible and retryable, and every shared PDF must contain an extractable text layer.

## Implementation plan
- [x] Add focused save/retry/relaunch/text-layer tests to the real test target and confirm red first.
- [x] Add preview-owned save state using the verified live fields (`filename`, `display_name`, `size_bytes`, `created_at`) and safe lifecycle analytics.
- [x] Persist the saved-résumé link across relaunch and expose it consistently in the saved picker/account history.
- [x] Validate backend, styled, and local PDFs for an extractable text layer before sharing.
- [ ] Run focused tests, Debug + Release builds, iPhone 17 + smallest supported simulator smoke, and physical-device smoke if a device is available. Tests/builds/simulators plus physical build/install/launch/relaunch passed; physical preview/save/export taps remain manual because device UI automation is unavailable.
- [x] Update project memory, commit, push, update PR #94, and stop before Story 7 / Release B.

---

# Story 5: Recommendation presentation safety gate (Release A, 2026-07-14)

Decision: when backend evidence metadata is absent, the iOS client applies a conservative local safety policy; placeholders are hidden, factual changes require explicit inclusion, and non-improving reviews start with no selected changes.

## Implementation plan
- [x] Add focused fixtures for placeholders, title inflation, removed dates, factual metrics, and a 53 → 52 score regression; confirm red first.
- [x] Add a pure Sendable recommendation safety policy with safe analytics categories only.
- [x] Gate optimization-review and diagnosis rendering, default factual changes off, and require deliberate inclusion when the score does not improve.
- [x] Run focused tests, Debug + Release builds, then smoke iPhone 17 and the smallest supported simulator.
- [x] Update project memory, commit, push, update PR #94, and stop before Story 6.

---

# Story 4: Shared job-input policy and friendly errors (Release A, 2026-07-14)

Decision: Home, guest ATS, and Fit use one local 100-word fallback for pasted descriptions while a valid HTTP(S) job URL remains independently sufficient.

## Implementation plan
- [x] Add focused policy/view-model tests for whitespace, URL-only, 99/100-word boundaries, API blocking, and friendly input errors; confirm red first.
- [x] Add a pure Sendable `JobInputPolicy` with normalized text/URL readiness and localized guidance.
- [x] Drive Home, Fit, and Tailor submission gates from the shared policy and show live word-count guidance before submission.
- [x] Run focused tests, Debug + Release builds, then smoke iPhone 17 and the smallest supported simulator.
- [x] Update project memory, commit, push, update PR #94, and stop before Story 5.

---

# Story 3: One optimization source of truth (Release A, 2026-07-14)

Decision: `AppState` owns the only valid optimization ID and reconciles it with authenticated `GET /api/optimizations` history before every tab derives its completion state.

## Implementation plan
- [x] Add focused recovery/source-of-truth tests and confirm the missing recovery API fails first.
- [x] Add Sendable recovery state and authenticated history reconciliation to `AppState`, including rejection of blank/mock/stale IDs and a PII-safe recovery event.
- [x] Make Main, Optimized, Design, Expert, and Account render from the same AppState ID, with loading, restored, empty, and retryable failure UI.
- [x] Run focused tests, Debug + Release builds, then smoke iPhone 17 and the smallest supported simulator.
- [x] Update project memory, commit, push, update PR #94, and stop before Story 4.

---

# Story 2: Deterministic Apply-to-preview route (Release A, 2026-07-14)

Decision: Home owns one Sendable first-session destination; a successful Apply persists the optimization ID before requesting one Optimized-tab preview, while failures remain on the review.

## Implementation plan
- [x] Add focused route/transition tests and confirm the missing production route fails first.
- [x] Add `Features/V2/Home/FirstSessionJourneyRoute.swift` with one Sendable destination model and an ordered Apply transition.
- [x] Replace Home's competing review/diagnosis booleans and wire Main to one optimized-preview handoff; make review completion idempotent.
- [x] Run focused tests, Debug + Release builds, then smoke iPhone 17 and the smallest supported simulator.
- [x] Update project memory, commit, push, update the open PR, and stop before Story 3.

---

# Story 1: Golden-path regression harness (Release A, 2026-07-14)

Decision: pin the existing first-session state transitions and competing-navigation precondition before Story 2 changes production routing.

## Implementation plan
- [x] Add a synthetic, no-network first-session fixture covering guest check → auth → review → apply → preview.
- [x] Confirm a focused red test before adding the harness implementation.
- [x] Assert the current two-destination Apply transition and one optimization ID across Home, Optimized, Design, Expert, and Account wrappers.
- [x] Run focused tests, Debug + Release builds, then launch smoke on iPhone 17 and the smallest supported simulator.
- [x] Update project memory and report Story 1 only; do not begin Story 2 without confirmation.

---

# Story: Trustworthy first-time journey upgrade planning (2026-07-13)

Decision: ship completion and trust repairs before continuity polish, reach experiments, or monetization.

## Planning completed
- [x] Draft product brief: `docs/specs/drafts/first-time-user-journey-upgrade-brief.md`.
- [x] Draft feature spec: `docs/specs/drafts/first-time-user-journey-upgrade-spec.md`.
- [x] Thirteen independently testable development stories: `docs/specs/drafts/first-time-user-journey-upgrade-stories.md`.
- [x] FigJam board created with the audit journey, failures, proposed flow, roadmap, and 20-screen evidence sheet.
- [x] No production code or dependencies changed.

## Approval gate
- [x] Founder approved Release A and its story order on 2026-07-14; Q1 backend evidence ownership and Q4 fallback simulator availability remain open only if a story blocks on them.
- [ ] After approval, move the spec to `docs/specs/`, add it to `docs/specs/README.md`, and set it as Active Spec.
- [x] Implement Story 1 golden-path regression harness.
- [x] Implement Story 2 deterministic Apply-to-preview route.
- [x] Implement Story 3 optimization source-of-truth reconciliation.
- [x] Implement Story 4 shared job-input policy and friendly errors.

---

# Story: First-time-user product and UX audit (2026-07-13)

Decision: keep monetization disabled and prioritize a deterministic, credible completion path before scaling acquisition.

## Completed
- [x] Fresh-install iPhone 17 Pro simulator walkthrough with synthetic résumé and job content.
- [x] Evidence captured for Home, upload/job input, guest diagnosis, signup, fit, optimization review, broken completion, return state, and Hebrew localization.
- [x] Relevant implementation inspected to separate observed behavior from likely causes.
- [x] Audit saved to `docs/audits/first-time-user-journey-audit.md` with prioritized risks, bugs, instrumentation gaps, experiments, and scorecard.
- [x] Debug simulator build succeeded; no production code changed.

## Next
- [ ] P0: replace the post-Apply competing navigation states with one deterministic optimized-preview route.
- [ ] P0: recover the latest optimization consistently across Optimized, Design, Expert, Account, and Saved Résumés.
- [ ] P0: reject placeholder, fact-changing, and non-improving AI output before it reaches users.
- [ ] P0: unify client/server job-description validation and replace technical 400 copy with inline guidance.

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
