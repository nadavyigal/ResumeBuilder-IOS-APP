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

### 2026-05-31
**Task:** PostHog integration — import credentials from web project and wire 3 analytics events
**Files Changed:**
- `Core/API/BackendConfig.swift` — added `posthogAPIKey` and `posthogHost` from web `.env.local` (NEXT_PUBLIC_POSTHOG_KEY, Project ID 270848)
- `Core/Analytics/AnalyticsService.swift` — NEW: URLSession-based PostHog HTTP capture service; no SDK/SPM required
- `Features/Tailor/TailorViewModel.swift` — wired `upload_resume_started` at optimize start; `optimization_completed` when optimizationId is set
- `ViewModels/OptimizedResumeViewModel.swift` — wired `export_triggered` in `downloadPDF(appState:)`
**Decisions Made:**
- Used URLSession + PostHog HTTP API directly instead of PostHog iOS SDK to avoid SPM dependency (project rule: system frameworks only)
- PostHog key is `NEXT_PUBLIC_*` on the web — safe to ship in the iOS binary per PostHog's design
- distinct_id uses `appState.session?.userId ?? "anonymous"` so authenticated events are linkable across web and iOS
- `AnalyticsService` is a singleton with fire-and-forget async sends; analytics failures are non-fatal
**Validation:**
- Files created/edited; Xcode project uses PBXFileSystemSynchronizedRootGroup so AnalyticsService.swift is auto-included
- Build check via XcodeBuildMCP required before declaring done
**Next Recommended Action:** Run `xcode_build` in XcodeBuildMCP to confirm zero build errors, then run simulator and check PostHog Live Events for the 3 required events

---

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
