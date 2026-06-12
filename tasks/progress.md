# Project Progress

**Submit Package save-to-Me fix (2026-06-12):** Submit Package now refreshes optimization context before generation, creates a reviewable draft with optimized resume PDF, job link, cover letter, and screening answers, then persists the package to Me only after the user taps "Save Package to Me." Focused iPhone 17 `OptimizedResumeViewModelTests` passed, simulator launch smoke succeeded, and PR #57 is open.

Project: ResumeBuilder iOS
Status: In Progress
Current Phase: App Store submission readiness
Active Story: Submit Package save-to-Me package confirmation
Last Completed Story: Fixed Submit Package so Create Package does not immediately create/mark an application. The generated draft includes the optimized resume PDF, job link from optimization detail, Expert cover letter, and screening answers. The sheet now asks the user to save the package to Me; saving creates a saved application, attaches the optimized resume, saves Expert reports, refreshes Me, and exposes share/copy/submit-at-link actions.
Next Recommended Story: Rebuild on real device, sign in, smoke optimize → Improve ATS → Preview & Export PDF → Submit Package → Save Package to Me → open package in Me → share resume PDF/copy cover letter/tap Submit at Job Link.
Estimated Completion: 90%
Blockers: Device smoke and PostHog live-event verification require founder to run on real authenticated device; ASC export requires local Keychain unlock for Apple Distribution key (71915959D76E14CED4D4153118972F034D338A50); `/api/v1/resumes` returns Next.js 404 HTML (Resume Library stays disabled)
Risks: Swift 6 concurrency strictness; PDF render via WKWebView (fragile on real device); no Hebrew/RTL support; live backend endpoint gaps now surface real user-visible errors; ExpertSavedReportDetailView's run-id mapping depends on backend returning run IDs in /expert-reports (not yet verified against live backend)
Last Validation: Submit Package save-to-Me fix (2026-06-12): `git diff --check` passed. Focused iPhone 17 run `xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"ResumeBuilder IOS APPTests/OptimizedResumeViewModelTests" -derivedDataPath /tmp/resumebuilder-submit-package-derived` succeeded: 21 tests passed. Simulator launch smoke on iPhone 17 succeeded and screenshot saved to `/tmp/resumebuilder-submit-package-smoke.png`.
Last Updated: 2026-06-12
Current Branch: codex/fix-submit-package-save-package
Latest Base Commit: 2338ea4 — Merge pull request #54 from nadavyigal/codex/fix-pdf-export-submit-package
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
- PDF export retains its off-screen WKWebView, times out stalled client-side PDF rendering, writes share files to stable Caches export URLs, falls back to backend download, then generates a local text-layer PDF from loaded optimization sections/contact data before surfacing an export failure
- Expert workflows accept user evidence input from iOS, parse backend-real structured outputs (summary options, quantified bullets, ATS keyword analysis, cover letters, screening answers), preserve selected variants for apply, let full rewrites apply selected sections, save applied reports to linked applications, and force no-cache optimized-section reload plus ATS score refresh when the backend returns a new score
- Expert tab links saved reports to Me applications by matching either `optimization_id` or `optimized_resume_id` from `/api/v1/applications`
- rb-aso-002 screenshot mode is launch-argument-only (`--marketing-screenshot --screenshot-slot N`) and renders App Store screenshot slots without changing the normal `RootView` path
- Home/Tailor optimize waits now use an inline SwiftUI resume-scanning animation with optimization and free-ATS copy variants; no backend progress contract is implied
- Optimized resume now supports manual section edits from the Improve bottom bar. Manual saves reuse `/api/v1/refine-section/apply`, update the local section body/status to `edited`, clear stale optimization-detail cache for that optimization, and refresh headline ATS scores via `/api/ats/rescan`.
- Optimized resume now supports an assisted Submit Package flow. It refreshes optimization detail before package generation, downloads the optimized resume PDF, runs Cover Letter Architect and Screening Answer Studio, previews a draft package, then saves it to Me only after user confirmation. Saving creates a saved application, attaches the optimized resume, saves Expert reports, and presents share/copy/submit-at-link actions without attempting third-party auto-submit.
- Submit Package now allows missing role/company context with visible fallback copy and safe placeholders (`Target Role`, `Company not specified`) so live job parsing gaps do not make the primary action look broken.
- Optimized resume now has a normal in-app ATS insight panel that maps App Store screenshot claims to a reachable product surface: headline score, before/after delta, score signals, top blockers/actions, Improve ATS, and an explicit low-score explanation when the optimized score remains below 55.
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
