# Project Progress

Project: ResumeBuilder iOS
Status: In Progress
Current Phase: Pre-release (TestFlight prep)
Active Story: —
Last Completed Story: Live upload end-to-end follow-up — pulled merged main locally, generated backend-readable upload PDFs from extracted text (2026-05-24)
Next Recommended Story: Backend `/api/v1/resumes` route implementation + real-device smoke test with a known-good text-based PDF
Estimated Completion: 45%
Blockers: `/api/v1/resumes` returns production Next.js 404 HTML; backend route must ship before Resume Library can be re-enabled; `/api/v1/styles/history` returns 500 and is now avoided in normal design flows
Risks: Swift 6 concurrency strictness; PDF render via WKWebView (fragile on real device); no Hebrew/RTL support; live backend endpoint gaps now surface real user-visible errors instead of mock fallback content; ExpertSavedReportDetailView's run-id mapping depends on backend returning run IDs in /expert-reports (not yet verified against live backend)
Last Validation: XcodeBuildMCP `build_sim` succeeded and `test_sim` passed 25/25 on iPhone 17 Pro simulator (2026-05-24)
Last Updated: 2026-05-24
Current Branch: codex/live-upload-end-to-end
Latest Base Commit: 88bc805 — Merge pull request #26 from nadavyigal/codex/live-upload-style-followup
Active Spec: —
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
- Upload preflight rejects missing, empty, unsupported, malformed, and no-readable-text PDFs before calling `/api/upload-resume`; readable PDFs are re-emitted as simple text-layer PDFs to avoid backend parser failures

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
