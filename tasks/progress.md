# Project Progress

Project: ResumeBuilder iOS
Status: In Progress
Current Phase: Pre-release (TestFlight prep)
Active Story: WP-1 in progress — PostHog key fix shipped; device smoke blocked on founder unlocking device
Last Completed Story: WP-1 PostHog fix: Run Script build phase now injects POSTHOG_API_KEY into Info.plist; all tests pass; device binary built (2026-06-03)
Next Recommended Story: Founder unlocks iPhone 13, installs the WP-1 device build, runs optimize→design→expert→export smoke, screenshots PostHog Live Events
Estimated Completion: 78%
Blockers: `/api/v1/resumes` returns production Next.js 404 HTML; backend route must ship before Resume Library can be re-enabled
Risks: Swift 6 concurrency strictness; PDF render via WKWebView (fragile on real device); no Hebrew/RTL support; live backend endpoint gaps now surface real user-visible errors instead of mock fallback content; ExpertSavedReportDetailView's run-id mapping depends on backend returning run IDs in /expert-reports (not yet verified against live backend)
Last Validation: WP-1 session (2026-06-03): PostHog Run Script fix verified — POSTHOG_API_KEY and POSTHOG_HOST appear in both simulator and iphoneos Debug Info.plist. Full test suite passed: 70 XCTest + 5 Swift Testing (all pass after analytics test update). Simulator launch screenshot confirmed Home renders at /var/tmp/resumebuilder-smoke/wp1-launch.png. Device build (iphoneos Debug) compiled and signed successfully at /var/tmp/resumebuilder-device-derived/Build/Products/Debug-iphoneos/. iPhone 13 UDID 00008110-00192DDA2143801E was unavailable (locked) during install attempt — founder must unlock and install manually.
Last Updated: 2026-06-03
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
- iOS optimize requests now ask for `optimization_mode: strong_faithful` with a substantial-but-factual quality profile. The Optimized tab surfaces ATS status/blockers when returned by optimization detail, offers an Improve ATS action through the existing Expert ATS workflow/apply path, and uses a focused section-editor sheet with empty-section validation and dirty-state discard protection for manual amendments.
- Me/Application Detail now acts as a package hub when application rows include an optimization, resume link, job link, or saved cover-letter report: users can share/download the optimized resume PDF, copy the cover letter, open the job link, and see ATS status. Submit Package bumps an app-wide applications refresh token so Me reloads when active.

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
