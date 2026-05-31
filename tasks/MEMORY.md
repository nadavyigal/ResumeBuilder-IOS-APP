## 2026-05-24 — Live upload parser follow-up after stale main rebuild

**Worked on:** Investigating phone logs that still showed `/api/v1/styles/history` and PDF upload 422 after PR #26 was merged.

**Completed:** Confirmed local `main` was two commits behind `origin/main`; pulled merged PR #26 into local `main` so Xcode can build the correct branch. Added upload normalization: iOS now extracts readable text with PDFKit, rejects unreadable/scanned PDFs, and sends a simple generated text-layer PDF to `/api/upload-resume` so the backend parser receives a predictable PDF. XcodeBuildMCP build passed and tests passed 25/25.

**In progress:** Needs physical-device smoke after merging this follow-up branch. Backend `/api/v1/resumes` remains disabled in iOS until the backend route exists.

**Decisions:** Fix app-side parser mismatch by normalizing upload PDFs in iOS. Do not reintroduce mocks. Treat the WebKit/keyboard/RunningBoard logs as non-blocking unless UI visibly fails.

**Next session:** Merge/rebuild this branch on device, confirm no style-history request appears, upload a text-based PDF, and verify the optimize call returns `reviewId` or `optimizationId`.

---

## 2026-05-24 — Live upload/style follow-up after main merge

**Worked on:** Investigating phone logs after the live endpoint stabilization PR was merged and rebuilt.

**Completed:** Confirmed the local checkout was back on `main` at merged PR #25 (`cfb3afc`) before creating `codex/live-upload-style-followup`; removed automatic `/api/v1/styles/history` loading from Design screens and Apply/Undo refreshes because the backend route returns 500 while normal design endpoints work; added PDFKit-based upload preflight that rejects malformed or no-readable-text PDFs locally with clearer guidance. XcodeBuildMCP build passed and tests passed 25/25.

**In progress:** Physical iPhone smoke needs a known-good text PDF exported from a word processor. Backend `/api/v1/resumes` remains unavailable and `/api/v1/styles/history` remains a backend gap.

**Decisions:** Treat style history as optional audit data, not a blocker for design navigation. Fail scanned/image-only PDFs before upload instead of letting `/api/upload-resume` return 422 after a long optimize attempt.

**Next session:** Rebuild this follow-up branch on device, upload a text-based PDF, and verify optimize navigates to Optimized with a real UUID and no style-history 500 log.

---

## 2026-05-24 — Live endpoint stabilization after physical-device smoke logs

**Worked on:** Stabilizing the live-only app after phone logs exposed a missing Resume Library endpoint, PDF upload read failures, preview cancellation noise, and duplicate initial optimization preview work.

**Completed:** Added a runtime Resume Library availability gate with graceful disabled UI; added PDF upload preflight and PDF MIME handling; treated preview cancellation (`CancellationError` and `NSURLErrorCancelled`) as benign; delayed optimized preview rendering until initial section load is attempted; added regression tests. XcodeBuildMCP build passed and tests passed 24/24.

**In progress:** Backend `/api/v1/resumes` still returns a production Next.js 404 HTML page. Resume Library remains disabled in runtime until that backend route exists and returns JSON.

**Decisions:** Keep runtime live-only and disable unavailable backend-dependent UI instead of reintroducing mocks. Treat WebKit/RunningBoard/keyboard logs as noise unless visible UI breaks.

**Next session:** Implement/verify backend Resume Library routes, then re-enable `RuntimeFeatures.isResumeLibraryEnabled` and run a real-device smoke test with a known-good text PDF.

---

## 2026-05-24 — Runtime app switched to live-only endpoints

**Worked on:** Removing runtime mock service routing after Xcode logs showed `mock-opt-001` reaching live optimization endpoints and causing UUID parse errors.

**Completed:** Added `RuntimeServices` as the live-only runtime dependency factory; removed `BackendConfig.useMockServices`, `useMockLibraryService`, and `useMockDesignService`; removed Tailor's mock library optimize branch and `AppState.pendingMockSections`; `AppState.bootstrap()` now clears persisted `mock-` optimization IDs. Mock services remain available only for explicit tests and SwiftUI previews.

**In progress:** Real-device smoke test with a real account/PDF/job description still needs to verify all live endpoint behavior.

**Decisions:** Runtime app never falls back to mock resume data or mock preview HTML. Missing backend endpoints should surface real errors instead of showing placeholder content.

**Next session:** Smoke test optimize on device, confirm the Optimized tab receives a real optimization UUID, and capture any live backend failures as backend/API issues rather than reintroducing mocks.

---

## 2026-05-20 — Bug-fix pass: Tailor errors, Me tab wiring, Application resume, Expert reports

**Worked on:** Fixing four interrelated bugs that made the app feel broken end-to-end — Tailor error surfacing, Me tab Send to Expert / Open Design buttons being silent no-ops, Application Detail missing optimized resume preview, and Expert saved reports counter showing a number but never revealing content.

**Completed:** All 5 stories implemented, reviewed (spec + code quality), and merged to main via PR #19. 12/12 tests passing. Xcode opened on device for manual smoke testing.

**In progress:** Manual smoke test on physical iPhone — user is building and running now.

**Decisions:**
- `navigationDestination` must go on `ZStack`/`ScrollView`, not on `List` (SwiftUI reliability)
- `ExpertSavedReportDetailView` uses `getStatus(runId:)` to fetch saved run; graceful fallback to Re-run if 404
- `BackendConfig.useMockLibraryService` left unchanged — blocked on backend

**Next session:** Confirm smoke test results on device. If saved expert reports section is empty (no prior runs), that's expected — needs a live backend run first. Key risk: `ApplicationExpertReportItem.id` mapping to a valid run ID on the backend — verify this with a real application that has expert reports.

---

## 2026-05-20 — Post-PR-19 Device Bug Fix Pass (PR #20)

**Worked on:** 4 device bug fixes identified from physical iPhone smoke test after PR #19 merge.

**Completed:**
- Story 1: Added `template_id` to `.designCustomize` POST body in `ResumeDesignService.swift` (fixes 400 error on Apply Design)
- Story 2: Per-template accent colors in `MiniResumeCanvas` via djb2 hash of `templateId` — 8-color palette, all 4 callers updated
- Story 3: `AppState.resumeSectionsNeedRefresh` flag wires Expert apply → Optimized tab force-reload (1.5s delay for backend commit)
- Story 4: `enhancedError()` in `TailorViewModel` appends actionable tip when server error contains "read"+"pdf"
- Build succeeds, all unit tests pass (iPhone 17 simulator)
- Note: `MockResumeLibraryService.downloadResumePDF()` already had text layer from PR #19 — Part A of Story 4 was pre-done

**Decisions:** Used djb2 hash (not Swift's `hashValue`) for stable per-template color; `resumeSectionsNeedRefresh` fires unconditionally from expert apply (also works from Track tab).

---

## 2026-05-20 — Four root-cause bugs: mock PDF path, design category switch, apply design error, expert preview (PR #21)

**Worked on:** Four persistent bugs that remained after PRs #18-20 despite earlier fix attempts.

**Completed:**
- Bug 1 (Mock library PDF "Could not read"): Added `isUsingMockLibraryResume` flag to `TailorViewModel`; `optimize()` short-circuits to `optimizeMock()` which calls `MockResumeOptimizationService` directly, stores sections in `AppState.pendingMockSections`, and sets `optimizationId`. `OptimizedResumeTabView.syncVM()` consumes `pendingMockSections` BEFORE the early-return guard.
- Bug 2 (Design category switch no-op): `DesignViewModel.loadTemplates` now tracks `lastLoadedCategory` and resets `selectedTemplateId` only on category change (not every load). `MockResumeDesignService.templates()` now filters by category from 8 distinct templates (2 per category: trad/modern/creative/corporate).
- Bug 3 (Apply Design error): `DesignViewModel.init` now checks `BackendConfig.useMockServices || BackendConfig.useMockDesignService` (was only checking `useMockServices`).
- Bug 4 (Expert changes not in preview): Added content-keyed `.id()` modifier to `ResumePreviewWebView` in `OptimizedResumeView` — forces SwiftUI to recreate the WebView (and re-run `.task`) when sections change.
- PR #21 merged to main on GitHub. Local main directory pulled via `git pull origin main` (was 2 commits behind — root cause of "nothing changed after rebuild" complaint).

**Decisions:**
- `pendingMockSections` consumed BEFORE early-return guard in `syncVM()` to prevent stale value on repeated same-ID optimize
- `lastLoadedCategory` tracker (not unconditional reset) preserves in-category user selection across tab switches
- `tasks/MEMORY.md` was untracked in main dir and blocked the pull — moved to `/tmp/memory_local.md` temporarily, then restored and merged

**Files changed:** `AppState.swift`, `TailorViewModel.swift`, `OptimizedResumeTabView.swift`, `DesignViewModel.swift`, `MockResumeServices.swift`, `OptimizedResumeView.swift`

**Next session:** Confirm all four bugs are fixed on device after clean Xcode build (Product → Clean Build Folder, then Run). If any bug persists, check `BackendConfig.swift` for flag values before investigating further.

## 2026-05-27 — Distribution OS installed for ResumeBuilder iOS
Worked on: Distribution OS install + GTM v0
Completed: scaffold installed (17 files in .agent-os/distribution/), positioning mirrored to .agents/product-marketing.md, app-store-program.md audited with current state, metrics.md wired with analytics audit, lifecycle-program.md audited, directories.md updated, assets-needed.md expanded with 5 new gaps, competitors.md audited, gtm-plan.md v0 drafted from ResumeBuilder Web GTM (canonical-90-day-plan.md)
In progress: open questions below — see gtm-plan.md section 16 for full list
Decisions captured in gtm-plan.md section 17:
  - App Store status: pre-submission (TestFlight prep, 62% complete, no submission yet)
  - iOS pricing: credit packs one-time IAP (credits_basic/saver/super); monetization parked
  - Hebrew on iOS: not implemented (no .lproj, no RTL, progress.md flags as risk)
  - ATS parser parity: iOS calls same backend endpoints; defensible claims
  - Apple attribution at=/ct=: NOT wired; Tier A pre-launch blocker
  - Free ATS tool App Store CTA: not confirmed wired; founder to verify
  - Apple Search Ads: out of scope confirmed from distribution-context.md
Next session: run first weekly distribution cycle
  Prompt to use: Read and execute: /Users/nadavyigal/Documents/Projects /Agentic OS/distribution-os/prompts/weekly-distribution-run.md
  Suggested theme for first week: ASO listing setup + rewrite (English) — write app name (confirm Resumely), subtitle, keywords, description v1
  Pre-work the founder should do before the cycle:
    - Confirm app name: "Resumely" or alternate?
    - Confirm web pricing model (subscription or credits?) and price points — needed to resolve cross-platform policy
    - Set iOS credit pack prices in App Store Connect (credits_basic, credits_saver, credits_super)
    - Confirm App Store Connect account region (US? Israel?)
    - Export App Store Connect data to Drive 05 Metrics Exports/App Store Connect/ if listing exists
    - Check free ATS tool result page on web — does it have an App Store CTA on mobile?

## 2026-05-28 — Distribution OS open questions resolved (7/7)
Worked on: Founder confirmation of all 7 step-4c open questions from install prompt
Completed: All 7 questions answered; gtm-plan.md section 16 + 17 updated; app-store-program.md, hebrew-program.md, assets-needed.md updated with confirmed answers
Confirmed decisions:
  1. App Store status: PRE-SUBMISSION (confirmed)
  2. iOS pricing: credit packs / one-time IAP (confirmed); credits_basic, credits_saver, credits_super
  3. Web pricing: freemium + paid upgrade via Stripe (confirmed)
  4. Cross-platform: shared — same account unlocks both web and iOS (confirmed); iapVerify must be implemented
  5. App name: NOT DECIDED — blocks all ASO copy; must be resolved before weekly cycle 1
  6. Hebrew App Store: single listing + Hebrew locale (confirmed); in-app RTL not yet built
  7. Free ATS tool result page: web signup CTA only — App Store CTA missing (confirmed blocker)
  8. Apple Search Ads: out of scope (confirmed)
Still blocking before weekly cycle 1 can start:
  - App name decision (hard blocker)
  - iOS credit pack prices set in App Store Connect
  - Web paid tier price points (check Stripe dashboard)
  - iapVerify restore mechanism implemented
  - Free ATS tool result page: add App Store CTA with ct=ats-tool-result
Next session: run first weekly distribution cycle
  Prompt: Read and execute: /Users/nadavyigal/Documents/Projects /Agentic OS/distribution-os/prompts/weekly-distribution-run.md
  Suggested theme: App name decision workshop + ASO listing v1 (English) — subtitle, keywords, description draft
  Pre-work: decide app name; set credit pack prices in App Store Connect

## 2026-05-28 — Final two decisions confirmed; proceeding to weekly cycle 1
Decisions:
  - App name: RESUMELY (confirmed)
  - iOS launch pricing: FREE (no IAP, no paywall at launch; pricing deferred to next stage)
  - These two decisions unblock all ASO copy work
Next: Weekly distribution cycle 1 — theme: ASO listing v1 (English)

## 2026-05-28 — Weekly distribution cycle 1 complete
Worked on: First weekly distribution run for Resumely iOS
Produced:
  - rb-aso-001: App Store listing copy v1 (subtitle 3 options, keywords 99/100 chars, description 1350 chars, promotional text, what's new)
  - rb-aso-002: Screenshot brief v1 (5-slot sequence, copy overlays, caption keywords, device specs)
  - rb-dir-001: Directory submission pack v1 (Futurepedia, TAAFT, Toolify, AI Tool Hunt, Launching Next)
All three assets are DRAFT — awaiting founder review before any action
Confirmed this session: app name = Resumely, iOS launch = Free (no IAP)
Critical path to App Store submission:
  1. Founder approves listing copy (rb-aso-001)
  2. Screenshots rendered (rb-aso-002)
  3. Privacy policy URL confirmed live
  4. Support URL confirmed live
  5. Submit to App Store review
Next session: receive founder feedback on rb-aso-001 → revise → approve → file in App Store Connect
  Prompt: Read and execute: /Users/nadavyigal/Documents/Projects /Agentic OS/distribution-os/prompts/weekly-distribution-run.md

## 2026-05-31 — PostHog integration (Story 2 partial)
Worked on: Importing PostHog credentials from web project and wiring 3 analytics events
Completed:
  - `BackendConfig.swift` updated with posthogAPIKey + posthogHost from web NEXT_PUBLIC_POSTHOG_KEY
  - `Core/Analytics/AnalyticsService.swift` created — URLSession-based PostHog HTTP capture, no SDK
  - 3 events wired: upload_resume_started (TailorViewModel), optimization_completed (TailorViewModel), export_triggered (OptimizedResumeViewModel)
Decisions:
  - URLSession + PostHog HTTP API instead of SPM SDK (system frameworks only rule)
  - distinct_id = session.userId or "anonymous" — enables web+iOS user linking in PostHog
In progress: Build verification and live event smoke test still needed
Next session: Run XcodeBuildMCP build, confirm 0 errors; run simulator smoke test and check PostHog Live Events dashboard for the 3 events
