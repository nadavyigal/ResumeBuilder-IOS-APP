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
