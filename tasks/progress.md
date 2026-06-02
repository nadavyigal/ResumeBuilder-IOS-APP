# Project Progress

Project: ResumeBuilder iOS
Status: In Progress
Current Phase: Pre-release (TestFlight prep)
Active Story: Phase 2 submit package complete; next planned story is authenticated real-device package smoke
Last Completed Story: Phase 2 submit optimized resume + cover letter package (2026-06-02)
Next Recommended Story: Authenticated device smoke for submit package and Track/Me application asset visibility
Estimated Completion: 75%
Blockers: `/api/v1/resumes` returns production Next.js 404 HTML; backend route must ship before Resume Library can be re-enabled
Risks: Swift 6 concurrency strictness; PDF render via WKWebView (fragile on real device); no Hebrew/RTL support; live backend endpoint gaps now surface real user-visible errors instead of mock fallback content; ExpertSavedReportDetailView's run-id mapping depends on backend returning run IDs in /expert-reports (not yet verified against live backend)
Last Validation: Phase 2 submit package: focused `OptimizedResumeViewModelTests` passed 11/11; `xcodebuild build` succeeded on iPhone 17 simulator using `/tmp/resumebuilder-derived`; full `xcodebuild test` passed 66 XCTest + 5 Swift Testing tests; `simctl` install/launch smoke succeeded on booted iPhone 17 with Home screenshot checked at `/tmp/resumebuilder-smoke/phase2-submit-package-launch-late.png` (2026-06-02). Default project-local `.derivedData` codesign is blocked by FileProvider/Finder extended attributes, but signed build/test passes from `/tmp` DerivedData.
Last Updated: 2026-06-02
Current Branch: main
Latest Base Commit: 9f8012c — Merge pull request #27 from nadavyigal/codex/live-upload-end-to-end
Active Spec: docs/specs/resumely-pre-submission-ux-ui-transformation.md
Latest QA Report: —

## Tab Structure (as of 2026-05-20)
| Tab | Index | View | VM |
|-----|-------|------|----|
| Tailor | 0 | TailorView | TailorViewModel (stable @State) |
| Optimized | 1 | OptimizedResumeTabView → OptimizedResumeView | OptimizedResumeViewModel (built from appState.latestOptimizationId) |
| Design | 2 | RedesignResumeView | DesignViewModel (stable @State) |
| Expert | 3 | ExpertTabView → ExpertModesView | ExpertModesViewModel (built from appState.latestOptimizationId) |
| Me | 4 | ProfileView (with inline applications) | — |

## Key Shared State
- `AppState.latestOptimizationId: String?` — persisted via UserDefaults; set on optimize success AND when opening Latest Resume from Me tab or View Optimized Resume from Application Detail; drives Optimized+Expert+Design tabs
- `AppState.bootstrap()` clears stale persisted `mock-` optimization IDs so old local state cannot call live endpoints with mock identifiers
- Runtime service defaults are live-only via `RuntimeServices`; mocks remain available only through explicit tests/previews
- `RuntimeFeatures.isResumeLibraryEnabled = false` until the backend ships `/api/v1/resumes`; app shows saved resumes as unavailable instead of surfacing HTML 404s
- Design history is not loaded automatically because `/api/v1/styles/history` currently returns 500; Apply/Undo use the stable design endpoints without blocking normal preview/design navigation
- Upload preflight rejects missing, empty, unsupported, malformed, and no-readable-text PDFs before calling `/api/upload-resume`; readable PDFs are re-emitted as simple text-layer PDFs and multipart includes `resumeText` so the backend can fall back when parser internals fail
- Optimization detail now carries `contact`; iOS preview/copy uses real candidate identity and local fallback no longer fabricates placeholder contact values
- Design render/preview/export resolves backend template UUIDs to category+slug and iOS reloads current design assignment after Apply/Undo so Optimized reflects the applied template
- Design apply treats assignment as the stable source of truth when the secondary customize endpoint returns the live "Optimization not found" 404 after assignment succeeds
- Design category switching is user-owned after the initial assignment load; subsequent category changes do not reload current assignment and cannot reset the UI back to the applied Traditional template
- Optimized preview starts rendering immediately from `optimizationId`; local section/contact HTML replaces the spinner as soon as details load, and cached backend design HTML can still upgrade the web view asynchronously
- Optimized/Design preview now resets stale design state on optimization changes, pauses preview network work when hidden behind another tab, debounces Design preview customization changes, and avoids redundant WKWebView reloads for unchanged HTML
- PDF export retains its off-screen WKWebView, times out stalled client-side PDF rendering, writes share files to stable Caches export URLs, and falls back to backend download before surfacing an export failure
- Expert workflows accept user evidence input from iOS, parse backend-real structured outputs (summary options, quantified bullets, ATS keyword analysis, cover letters, screening answers), preserve selected variants for apply, let full rewrites apply selected sections, save applied reports to linked applications, and force no-cache optimized-section reload plus ATS score refresh when the backend returns a new score
- Expert tab links saved reports to Me applications by matching either `optimization_id` or `optimized_resume_id` from `/api/v1/applications`
- rb-aso-002 screenshot mode is launch-argument-only (`--marketing-screenshot --screenshot-slot N`) and renders App Store screenshot slots without changing the normal `RootView` path
- Home/Tailor optimize waits now use an inline SwiftUI resume-scanning animation with optimization and free-ATS copy variants; no backend progress contract is implied
- Optimized resume now supports manual section edits from the Improve bottom bar. Manual saves reuse `/api/v1/refine-section/apply`, update the local section body/status to `edited`, clear stale optimization-detail cache for that optimization, and refresh headline ATS scores via `/api/ats/rescan`.
- Optimized resume now supports an assisted Submit Package flow. It downloads the optimized resume PDF, creates an application via `/api/v1/applications`, attaches the optimized resume, marks the application applied, runs Cover Letter Architect, saves the expert report to the application, and presents share/copy/open-link actions without attempting third-party auto-submit.

## Key Wiring (2026-05-20)
- `ProfileView` now accepts `onSwitchTab` from `MainTabViewV2.switchTab` — "Send to Expert" / "Open Design" buttons in preview work from Me tab
- `ApplicationDetailView` now accepts `onSwitchTab` — passed through to `OptimizedResumeView` opened from application rows
- `ExpertModesViewModel` now takes `applicationId` — loads saved expert reports via `ApplicationTrackingService`; `ExpertSavedReportDetailView` fetches and renders individual saved runs

## Files Deleted This Spec
- `Features/Score/ScoreView.swift`
- `Features/Score/ScoreViewModel.swift`
- `Features/V2/Profile/ProfileViewV2.swift`
- `Features/Track/ApplicationsListView.swift`

Notes: App is pre-release v1.0 build 1. V2 folder is active target for all new screens. Dark mode only. No App Store submission yet.
