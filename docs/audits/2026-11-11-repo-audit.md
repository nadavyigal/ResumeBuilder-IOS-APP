# Repo audit: Resumely iOS, 2026-11-11

Branch `claude/project-audit-cleanup-cacbdb`, from `main` at f9c5475.
Baseline: 750 XCTest (11 skipped, 0 failures) + 5 Swift Testing, iPhone 17 / iOS 26.5.

## Fixed in this branch

| What | Why it was safe |
|------|-----------------|
| Deleted 22 app files no screen can reach: `TailorView`, `OptimizingView`, `HomeView` + `HomeViewModel`, `UploadSheetView`, `ImproveView`, `ScanResumeView`, `ATSBreakdownView`, `IssuesSummaryView`, `HistoryView`, `ImportResumeView`, `MetricCard`, `ResumeFileCard`, `WaveDecoration`, `PushService`, the SwiftData `ModelContainer` + `CachedApplication` + `CachedResume`, `ProfileViewModel`, `ResumeManagementViewModel`, `ResumeDocument`, `Secrets.swift.example` | Reachability walk from `@main` plus word grep: no references outside their own file or other dead files, no test references. Agents were still editing two of them (`ImproveView` on 2026-10-28, `ScanResumeView` on 2026-11-05), which is wasted work. |
| Removed 8 unused API structs (`OptimizationSummary`, `TailorRequest`, `TailorResponse`, `IAPVerifyResponse`, `ChatMessagesPageEnvelope`, `ExpertWorkflowReportEnvelope`, `OptimizationListResponse`, `ATSScoreRequest`), the `GlassCard` wrapper view (the `.glassCard()` modifier stays), the `AppTypography` enum and two unused `Font` tokens | Zero references |
| Removed `BackendConfig.isMonetizationEnabled` | Never read. Its comment said "Stage 1 ships without monetization" while 1.6.0 sells credit packs. Three comments that cited it now state the real rule (server-side credit gate). |
| Moved 11 debugging write-ups out of the app source folder to `docs/archive/preview-debug-2026-05/` and dropped their 12 project-file exclusions | They were excluded from the build by hand; any new `.md` dropped there next would have shipped inside the app bundle. |
| `@discardableResult` on `DesignViewModel.loadCurrentAssignment(optimizationId:token:shouldSyncCategory:)` | Cleared the 3 app-target compiler warnings; callers already ignore the result on purpose. |
| `Secrets.xcconfig.template` now lists `INTERNAL_TESTER_EMAILS` | The README says not to skip it; the template left it out. |
| `README.md` run steps and branch note, `docs/architecture/current-ios-architecture.md` | Both described screens and a tab layout that no longer exist. |

## For your review (not changed)

Ordered by value. Each has my recommendation.

1. **Dead code that still has tests.** `ImproveViewModel`, `ScanViewModel`, the chat screen (`ChatView`, `ChatViewModel`, `PendingChangeCard`; `ChatService` itself is live, used by `OptimizedResumeViewModel`), `OptimizationDesignSheet` + `TemplateThumbnail`. Nothing in the app opens them; their tests keep them compiled. Recommend: delete with their tests unless the chat screen is coming back.
2. **Fit-check screens** (`FitCheckView`, `FitVerdictView`, `OptimizeFitCheckView`, `FitCheckViewModel`, `FitCheckService`). Still referenced from `HomeTabView`, but only behind `isFitCheckEnabled = false` (off since 2026-07-24; the flag comment says remove after WP-45 S10). `FitBaselineStore` is live and stays. Recommend: confirm WP-45 S10 is closed, then remove the screens and the flag branch in one PR.
3. **Ambassador skeleton** (`Ambassador/`, 4 files of TODO stubs since 2026-06-07). Never wired. Recommend: delete unless the ambassador program is on the roadmap.
4. **`tasks/progress.md` is 345 KB with 58 dated entries**; `session-log.md` 145 KB, `lessons.md` 109 KB, `todo.md` 87 KB. Every session that reads them burns context. Recommend: keep the top entry in `progress.md` (the six-field rule) and move history to `tasks/archive/`. I did not do it because open branches prepend to the same file.
5. **101 stale remote branches** (57 unmerged, 44 merged and not deleted, oldest 2026-06-22). Recommend: delete the 44 merged ones; review the unmerged list.
6. **52 MB `dist/` and 14 MB `audit/` screenshots in git** make clones slow. Recommend: move to Git LFS or an external folder.
7. **115 stale strings** in `Localizable.xcstrings` (more after this cleanup). Do not bulk-delete: strings built from variables also show as stale. Recommend: a reviewed pass.
8. **Test target Swift 6 warnings** (`AIConsentTests`, `ExportCreditsTests`, `FitJourneyTests`, `PasswordFlowsTests`): main-actor and sendable-capture warnings. The test target lacks `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` that the app has, and links a `Foundation.framework` pinned to the iOS 18.0 SDK path. Recommend: align the test target settings in one small PR.
9. **`MockResumeServices.swift` (465 lines) ships in Release.** Recommend: leave it; wrapping in `#if DEBUG` breaks `#Preview` blocks in Release (see lesson 2026-10-30).
10. **Stale docs:** `docs/qa/app-store-readiness-checklist.md` still says IAP is N/A; `plan-phases-3-5-6.md` (root, 2026-07-11) and `tasks/work-pack-*` are finished plans; `.build-benchmark/` is from 2026-05-24. Recommend: move to `docs/archive/`.
11. **`DeepLinkRouter.parseSharedJobURL`** accepts any URL whose host is `share` (`||` where `&&` looks intended). Low risk: the app only registers the `resumebuilder` scheme. Recommend: tighten with a test.
12. **`Config/Info.plist`** has a nested `UILaunchScreen` key and legacy `CFBundleIconFiles`. Harmless. Recommend: leave.
