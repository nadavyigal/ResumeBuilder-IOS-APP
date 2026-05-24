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
