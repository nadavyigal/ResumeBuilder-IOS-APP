## 2026-06-23 — WP-13 Fit-First Release + Flip Decision

**Worked on:** Shipping Fit-First Triage dark in v1.1 build 6; internal flag-on validation; flip decision gate.

**Completed:**
- Pre-flight: `origin/main` clean at `f87807a`; WP-12 MEMORY/progress committed; Finder duplicate junk deleted (`dist/app-store-screenshots/` + docs plans).
- Build 6 bump on `release/wp-13-v1.1-build-6` (`63dcad0`) — MARKETING_VERSION 1.1, CURRENT_PROJECT_VERSION 6, `isFitCheckEnabled=false`.
- Internal branch `feat/wp-13-fit-check-internal` (`f20f8bc`): flag ON + live smoke tests.
- Live smoke PASS: production `/api/public/ats-check` HTTP 200, verdict + optimize handoff, 4 analytics events, Hebrew RTL. Report: `docs/qa/reports/wp-13-fit-check-live-smoke-2026-06-23.md`.
- Flip decision logged: **defer to D7 readout 2026-06-24** in Agentic OS `DECISIONS.md`.

**Blocked (founder action):** CLI archive failed (provisioning profile doesn't include signing cert). Upload + App Store review submission require Xcode Organizer manual path (same as v1.1 build 5).

**Decisions:** Do not flip flag in public build 6. No percentage rollout exists — flip is binary via `BackendConfig.isFitCheckEnabled`. Re-evaluate flip after D7 Gate A readout tomorrow.

**Next session:** Upload build 6 via Organizer → submit for review (flag OFF). After D7 readout, open flip PR if gate is stable.

---

## 2026-06-23 — WP-12 Fit-First Triage FULLY DONE — merged to main (#75)

**Worked on:** Landing the complete Fit-First Triage wedge — E2E gate, Stories 2-4 — onto main.

**Completed:**
- E2E gate confirmed: prod endpoint returns `fit` block; FitVerdict decodes band=stretch, score=62, topGaps/missingKeywords via string-array fallback (`decodeGapsOrStrings`/`decodeKeywordsOrStrings` helpers).
- DomainModels.swift union: preserves #72's `KeywordSuggestionPreviewDTO` + `JSONValue.displayString` AND branch's `ATSScoreResult.fit` + custom decoder.
- Story 2: `FitCheckViewModel`, `FitCheckView`, `FitVerdictView` under `Features/V2/Fit/`; `BackendConfig.isFitCheckEnabled=false`.
- Story 3: `TailorView` routes through `FitCheckView` when flag on; flag-off path unchanged.
- Story 4: 4 analytics events (20 total), 20 EN+HE strings (HE xliff confirmed 40 matches), `FitCheckViewModelTests` registered.
- Rebase onto main was clean (Story 1 auto-skipped as already applied). BUILD SUCCEEDED. 27 tests pass.
- PR #75 squash-merged to main as `17d2122`. Branch deleted.

**Decisions:** `isFitCheckEnabled=false` on main (ships dark). Decoder uses `(try? decodeIfPresent(...)) ?? nil` pattern to avoid double-binding error on `Optional<Optional<T>>`.

**Next session:** D7 readout (first complete D7 window from 2026-06-17 launch anchor ends 2026-06-24). Then decide next priority after WP-12.

---

## 2026-06-23 — Fit-First Triage Story 1 FitCheckService

**Worked on:** Implementing the iOS model/service layer for the Fit-First Triage wedge without adding UI or changing the existing optimize/diagnosis flow.

**Completed:** Added `FitVerdict`/`FitBand` under `Core/API/Models/`, flexible snake/camel decoding with clamped scores, optional additive `fit` decoding on `ATSScoreResult`, `FitCheckServiceProtocol`, live `FitCheckService` through `APIClient.runPublicATSCheck`, `RuntimeServices.fitCheckService()`, and an injectable `MockFitCheckService`. Reused the existing `ResumeGap` and `ResumeKeyword` types and kept the endpoint on `APIEndpoint.publicATSCheck`.

**Validation:** Clean temp-copy Debug build passed on iPhone 17 simulator. Focused `FitCheckServiceTests` ran 6 tests with 0 failures. Production `/api/public/ats-check` was reachable and returned HTTP 200 for a sample PDF + 100+ word JD, but the response still lacked the Story-0 additive `fit` block.

**Decisions:** Reconciled the spec's `Models/FitVerdict.swift` location to the real app layout at `Core/API/Models/FitVerdict.swift`. Server verdict wins when present; the iOS fallback derives Strong/Stretch/Skip from `score.overall` only when `fit.verdict` is absent.

**Next session:** Deploy or verify Story 0 on web so `/api/public/ats-check` returns `fit`, then rerun the same live call and confirm it decodes into `FitVerdict` with verdict, gaps, and missing keywords populated before enabling Story 2 UI work.

---

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
