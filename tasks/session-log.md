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

### 2026-06-05
**Task:** Resumely 1.0 build 1 submitted to App Store review
**Files Changed:** `tasks/progress.md`, `tasks/todo.md`, `tasks/session-log.md`
**Decisions Made:** Treat the founder-confirmed App Store Connect status as the
release source of truth. Keep the Resume Library backend gap separate from the
submission status.
**Validation:** Founder confirmed submission on 2026-06-05. No approval,
rejection, or live-store status is claimed.
**Next Recommended Action:** Monitor App Store Connect and respond only to the
review outcome before starting post-launch scope.

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
## 2026-06-05 — App Store Screenshot Generator

**Task:** Replace the five duplicated App Store concepts with 10 unique upload-ready screenshots for every required device family.

**Completed:**
- Expanded marketing screenshot mode to 10 deterministic scenes.
- Added screenshot-mode app startup that bypasses API/auth initialization.
- Added automated generation and validation scripts.
- Generated 10 iPhone 6.9-inch PNGs at 1320x2868.
- Corrected the App Store upload set after portal rejection: normalized all iPhone screenshots to 1290x2796 opaque RGB PNGs and all iPad screenshots to opaque RGB PNGs, then revalidated count, dimensions, uniqueness, and alpha absence.
- Replaced the iPhone set again after App Store Connect identified the active 6.5-inch screenshot well: captured all 10 screens natively on the dedicated iPhone 11 Pro Max simulator at 1242x2688, converted them to opaque RGB PNGs without resizing, and visually inspected screenshots 1, 6, and 10.
- Generated 10 iPad 13-inch PNGs at 2064x2752.
- Corrected the truncated ATS summary in slot 2.
- Added upload manifest and drag-and-drop folder documentation.

**Verification:**
- Xcode simulator build succeeded without warnings.
- 77 tests passed.
- Both screenshot sets passed count, dimension, and duplicate-hash validation.
- Final phone and tablet images were visually inspected.
