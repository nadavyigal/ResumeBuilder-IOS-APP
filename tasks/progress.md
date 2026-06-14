# Project Progress

**Resume Aha Moments (2026-06-12):** Implemented the diagnosis-first resume/job flow in V2: grounded match guidance, top gaps, missing keywords, recruiter-eye review, before/after rewrite, confidence checklist, smart empty/loading copy, backend-diagnosis decode hook, and conservative mocked/fallback diagnosis data.

Project: ResumeBuilder iOS
Status: PR #58 review remediated; archive build succeeds; live simulator smoke blocked
Current Phase: Product experience polish
Active Story: Resume Aha Moments PR #58 validation and handoff
Last Completed Story: Added diagnosis screen/components and routed Home/Tailor optimization completion through recruiter-style diagnosis before Improve.
Next Recommended Story: Complete an authenticated real-device smoke with delete-account/re-register, upload a real resume/job, optimize through diagnosis, export/share PDF, then validate/upload the archive from Xcode Organizer with App Store distribution signing.
Estimated Completion: 94%
Blockers: CoreSimulator is currently hanging on app install/screenshot/container commands, so interactive simulator smoke and live delete-account/re-register verification could not be completed in this session.
Risks: Swift 6 concurrency strictness; PDF render via WKWebView (fragile on real device); no Hebrew/RTL support; live backend endpoint gaps now surface real user-visible errors; ExpertSavedReportDetailView's run-id mapping depends on backend returning run IDs in /expert-reports (not yet verified against live backend); App Store export still needs distribution signing because the CLI archive used an Apple Development team provisioning profile.
Last Validation: PR #58 review remediation (2026-06-14): `git diff --check` passed. Focused iPhone 17 diagnosis tests passed 7/7. Full iPhone 17 test suite passed with 83 XCTest tests plus 5 Swift Testing tests, 0 failures. Release archive to `/tmp/ResumeBuilder-PR58.xcarchive` succeeded. Account deletion/register paths were source-reviewed, but live simulator smoke was blocked by CoreSimulator hangs on install/screenshot/container operations.
Last Updated: 2026-06-14
Current Branch: codex/resume-aha-moments
Latest Base Commit: PR #57 merge — Submit Package save-to-Me + build 4 resubmission prep
Active Spec: docs/specs/resume-aha-moments.md
Latest QA Report: docs/qa/reports/ios-qa-pr58-2026-06-14.md

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
- Home/Tailor now route successful resume/job optimization into a V2 Resume Diagnosis screen before the full Improve tab. Diagnosis shows estimated match guidance, potential score, top gaps, missing keywords, recruiter-eye review, before/after rewrite, and grounded CTAs to improve or edit the target job.
- Optimized resume now reuses the diagnosis mapper for a compact recruiter snapshot and confidence checklist so the user sees why the resume is stronger before export/payment.
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

Notes: App is v1.0 build 4 (resubmission). Archive from `main`. V2 folder is active target for all new screens. Dark mode only.
