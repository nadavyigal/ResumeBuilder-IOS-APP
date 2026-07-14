# Lessons — ResumeBuilder iOS

> Self-learning memory. Read at the start of every task.
> Add a lesson immediately after any: mistake, user correction, failed build, bad pattern,
> broken test, poor AI output, broken PDF, bad template render, repeated mistake.

## Lesson Format

**Date:** YYYY-MM-DD
**Category:** Build | SwiftUI | API | Resume Output | PDF | Template | UX | Auth | TestFlight | General
**Rule:** _One sentence rule to follow in future tasks._
**Why:** _What went wrong or what the user corrected._

---

## Lessons

**Date:** 2026-07-14
**Category:** General
**Rule:** If `gh pr edit` fails while querying deprecated Projects Classic cards, update the pull request title/body with the REST `repos/{owner}/{repo}/pulls/{number}` endpoint instead.
**Why:** Story 2 was pushed successfully, but `gh pr edit 94` aborted on the Projects Classic GraphQL deprecation before changing the PR metadata.

**Date:** 2026-07-14
**Category:** Test
**Rule:** Capture simulator screenshots with `xcrun simctl io <device> screenshot <path>`; `simctl screenshot` is not a valid top-level command.
**Why:** Story 2's first smoke evidence command used the obsolete command shape, so no screenshot was produced until the operation was routed through `simctl io`.

**Date:** 2026-07-14
**Category:** Test
**Rule:** When a Swift test harness has private stored state but tests need to construct it, provide an explicit initializer for the fixture inputs instead of relying on the synthesized memberwise initializer.
**Why:** Story 1's first green attempt failed to compile because private navigation flags made `FirstSessionJourneyHarness`'s synthesized initializer inaccessible, which also erased contextual typing in the stage assertion.

**Date:** 2026-07-14
**Category:** Build
**Rule:** If a focused build stalls at `ValidateCAS` while another repository owns a long-running `xcodebuild -list`, stop only the current build and retry after Xcode project coordination clears; do not terminate unrelated workspace processes.
**Why:** Story 1's first red test run reached `ValidateCAS` but never compiled while a separate RunSmart worktree held an `xcodebuild -list` process, so it could not provide valid red-state evidence.

**Date:** 2026-07-13
**Category:** General
**Rule:** On Figma's free FigJam plan, keep audit evidence and the roadmap on one page, use a single labeled contact sheet for large screenshot sets, and verify creation through the file URL/selection state when canvas capture times out.
**Why:** The direct new-board navigation completed despite a navigation timeout, canvas screenshots repeatedly timed out, and attempting a second page triggered the plan-upgrade gate; a one-page roadmap plus a 20-screen contact sheet remained reliable.

**Date:** 2026-07-11
**Category:** General
**Rule:** When the connected PostHog plugin advertises `read-data-warehouse-schema` but returns `Tool read-data-warehouse-schema not found`, use verified narrow `events`/`system.*` HogQL probes and `read-data-schema` rather than guessing columns.
**Why:** WP-41's required warehouse-schema discovery call was unavailable at runtime even though the tool appeared in the connected capability list.

**Date:** 2026-07-08
**Category:** Test
**Rule:** When verifying `.fileImporter`, pair runtime accessibility snapshots with a simulator screenshot because the system Files picker may be presented outside the app-scoped snapshot tree.
**Why:** Story 3's XcodeBuildMCP tap fired `resume_upload_cta_tapped` and `resume_file_picker_opened`, but `snapshot_ui` still showed Home; the simulator screenshot confirmed the iOS Files picker was actually open.

**Date:** 2026-07-08
**Category:** General
**Rule:** When updating PostHog `DataVisualizationNode` table insights through MCP, keep `tableSettings` to accepted keys like `columns`; `showTotalRow` is rejected.
**Why:** The first Story 2 insight update failed with a PostHog schema error because the payload included `tableSettings.showTotalRow`.

**Date:** 2026-07-06
**Category:** Test
**Rule:** Use the Xcode test target's displayed name in `-only-testing` selectors, including spaces, such as `ResumeBuilder IOS APPTests/...`.
**Why:** A focused MCP test run failed before compiling when invoked with the Swift module-style target name `ResumeBuilder_IOS_APPTests/...`; rerunning with `ResumeBuilder IOS APPTests/...` executed the intended analytics tests.

**Date:** 2026-07-05
**Category:** UX
**Rule:** When instrumenting "viewed" events on a tab kept alive but hidden via `opacity: 0`, fire on `isActive` (or tab selection), not `onAppear` alone — hidden tabs may never appear.
**Why:** WP-36 `optimized_viewed` / `export_cta_seen` did not fire in simulator smoke until the Optimized tab was actually selected; `MainTabViewV2` keeps all tabs mounted but only the active tab is visible.

**Date:** 2026-06-28
**Category:** Build
**Rule:** When broadening a response envelope for decode-only API use, make the envelope `Decodable` unless the app actually encodes it.
**Why:** Submit Package expert-report loading needed to decode `reports`, `expert_reports`, `data`, or a bare array. Leaving the envelope as `Codable` forced Swift to synthesize an encoder for alias-only keys and broke the build.

**Date:** 2026-06-25
**Category:** Build
**Rule:** The full test suite intermittently crashes the test host with `malloc: *** error for object 0x7ffd41cb7680: pointer being freed was not allocated`, always at the SAME memory address but in a DIFFERENT test each run (seen in `ResumeDiagnosisViewModelTests.testViewModelStartsEmptyWithoutOptimizationId` and separately in `OptimizedResumeViewModelTests.testATSInsightsExplainLowScoreAndExposeActions`) — this is a host-process-level instability, not a bug in any specific test or the app code under test. `xcodebuild -only-testing`/`-skip-testing` doesn't avoid it since it isn't tied to one test. The Debug build itself always succeeds clean, and every test that completes always passes. Don't chase this as a code bug; if it blocks a full-suite run, fall back to confirming the build is green plus spot-checking the relevant suites individually.
**Why:** Found while QA'ing PR #83's CodeRabbit fixes, after an unusually heavy run of back-to-back `xcodebuild` test invocations in one session (multiple full builds + test runs in under an hour). Verified pre-existing and non-deterministic by reproducing identically with the session's changes stashed out (against the already-committed PR #83 state) and by watching it hit a different, unrelated test on a later run.

**Date:** 2026-06-25
**Category:** SwiftUI
**Rule:** Before wiring new UI into an existing screen, `grep -rn "StructName("` across the whole app to confirm it's actually instantiated somewhere live — don't assume a file under `Features/V2/` is the live screen just because its name matches the tab.
**Why:** The redesign's target-reached/save-account celebration was wired into `ImproveView.swift`, which is never instantiated anywhere in the app (confirmed via repo-wide grep) — the live Optimized tab renders `OptimizedResumeView.swift` instead. The feature built correctly, compiled, and passed review of the diff, but no user would ever see it. Caught only by checking call sites, not by reading the diff.

**Date:** 2026-06-25
**Category:** UX
**Rule:** When implementing redesign screens that reference future backend/state capabilities, keep the UI honest by disabling or simplifying those affordances and recording the flag instead of presenting fake progress, fake point deltas, resumable jobs, paste-text diagnosis, or demo diagnoses as real.
**Why:** The Resumely activation redesign includes paste-resume, sample diagnosis, parser-stage progress, precise locked-tab hasResume/hasJob state, point-delta fixes, resumable offline analysis, and guest persistence claims that are not fully backed by current iOS/backend contracts.

**Date:** 2026-06-25
**Category:** Build
**Rule:** When the file picker and `UploadFilePreflight.mimeType(for:)` disagree on a type, widen preflight to match the picker's WP-18 intent — do not narrow the picker to match preflight. Check which direction actually serves the activation goal before "fixing" a mismatch.
**Why:** The redesign pass found this exact mismatch (picker allowed `.doc`, preflight rejected it) and "fixed" it by removing `.doc` from the picker — silently re-blocking Word `.doc` users, the precise WP-18 regression it was trying to prevent for `.docx`. The correct fix (applied in the 2026-06-25 QA pass) was to add `application/msword` recognition to `mimeType(for:)` so `.doc` actually works end-to-end, completing WP-18's intent instead of reverting it.

**Date:** 2026-06-24
**Category:** UX
**Rule:** Instrument the whole journey, not just the success terminal — a funnel that only fires the terminal event (e.g. `resume_uploaded`) makes every upstream drop-off unattributable.
**Why:** WP-16 showed an 81% guest→`resume_uploaded` drop with zero events in between, so the cause (never-tapped vs cancelled vs preflight-rejected vs upload-failed) was unknowable until WP-18 added the granular pick/upload events.

**Date:** 2026-06-24
**Category:** UX
**Rule:** Keep `.fileImporter allowedContentTypes` in sync with what preflight/backend actually accept — a picker narrower than the parser silently blocks valid users with no analytics signal.
**Why:** The picker was `[.pdf]` while `UploadFilePreflight` already accepted `.docx` (proven by `ScanViewModelTests.testDocxMimeTypeRecognizedByPreflight`), so Word-resume users couldn't even select their file and dropped invisibly.

### 2026-06-23 (WP-12 Stories 2-4)
**Category:** Build
**Rule:** `try? decodeIfPresent(T.self, forKey:)` returns `Optional<Optional<T>>`; flatten with `(try? ...) ?? nil` before `if let`, not the double-binding pattern `if let x = ..., let x`.
**Why:** Using the pattern `if let x = try? decodeIfPresent(...), let x` caused the compiler error "initializer for conditional binding must have Optional type" because the inner unwrap target was already non-Optional. The correct pattern is `if let x = (try? decodeIfPresent(...)) ?? nil`.

**Category:** Build
**Rule:** Before adding a private `FlowLayout` (or any Layout type) to a new view, search the project for existing definitions — duplicating a non-private `struct FlowLayout` causes a redeclaration error.
**Why:** `FlowLayout` was already defined (non-private) in `RecruiterEyeViewCard.swift`. Adding `private struct FlowLayout` in `FitVerdictView.swift` caused a "invalid redeclaration" compile error.

**Category:** SwiftUI
**Rule:** `GradientButton(title:)` takes `LocalizedStringKey`, not `String`. Pass a string literal directly, not `NSLocalizedString(...)`.
**Why:** Passing `NSLocalizedString("Check Fit", comment: "")` (which returns `String`) to `GradientButton(title:)` caused "cannot convert value of type 'String' to expected argument type 'LocalizedStringKey'".

### 2026-06-23
**Category:** Build
**Rule:** When adding a new fallback key to an existing Codable decoder, decode the primary and alias values into local optionals before nil-coalescing.
**Why:** While adding `ResumeGap.detail` as an alias for the Fit payload, the first patch repeated the throwing-decode-inside-`??` pattern that has broken Swift builds before.

### 2026-06-23
**Category:** Build
**Rule:** If XcodeBuildMCP times out during scheme listing, check for and stop the leftover `xcodebuild -list` process before running manual `xcodebuild`.
**Why:** A timed-out scheme lookup left a stale Xcode project reader running, and subsequent manual builds hung before Swift compilation while coordinating project reads.

### 2026-06-23
**Category:** Test
**Rule:** In flexible decoders that probe a key as both scalar and nested object, wrap the nested-object probe in `try?` after scalar probes so a type mismatch does not abort the whole decode.
**Why:** `FitVerdict` decoded numeric `score` first, but the follow-up nested `score.overall` probe still threw a type mismatch and failed the snake-case payload test.

### 2026-06-19
**Category:** PDF
**Rule:** Any `WKWebView` used for resume preview or PDF export must have a `WKNavigationDelegate` and OSLog/analytics coverage for timeout, provisional, navigation, and PDF creation failures.
**Why:** The PostHog/error sweep found preview HTML could fail after `html` state was set, leaving a blank WebKit surface and no failure signal on the styled PDF export path.

### 2026-06-17
**Category:** General
**Rule:** To verify localization coverage authoritatively, run `xcodebuild -exportLocalizations -project X -localizationPath /tmp/loc -exportLanguage he`, then parse `/tmp/loc/he.xcloc/Localized Contents/he.xliff`: every `trans-unit` is a localizable string the build extracts (Text literals, LocalizedStringKey, String(localized:), NSLocalizedString). Units with an empty `<target>` are untranslated. This is the ground truth — far more reliable than grepping. Note: multi-argument format keys appear in the xliff `<source>` in POSITIONAL form (`%1$lld…%2$@`) but the catalog KEY is the literal as written in code (`%lld…%@`); translate under the literal key, give the value positional specifiers.
**Why:** During the 100% Hebrew sweep, grep kept missing strings; exportLocalizations gave the exact 190-string gap list and a 688/688 final coverage number.

### 2026-06-17
**Category:** SwiftUI
**Rule:** For UI strings produced in model/view-model/enum code that are consumed in MULTIPLE contexts (SwiftUI Text AND HTML/PDF/analytics/string-interpolation), localize at the String level with `NSLocalizedString(key, comment: "")` rather than `LocalizedStringKey`. NSLocalizedString routes through `Bundle.main.localizedString(forKey:)`, which the runtime language-override swizzle intercepts, so it returns the selected language everywhere. Use `LocalizedStringKey` only for params/returns consumed solely by `Text`/`Button`/`navigationTitle` (SwiftUI environment-driven). Keep dynamic/server data as plain String.
**Why:** `ResumeSectionType.displayName` is used in both `Text(...)` and the resume HTML builder (`.uppercased()` interpolation); LocalizedStringKey would break the HTML path, so NSLocalizedString is the correct uniform fix.

### 2026-06-16
**Category:** Test
**Rule:** `xcodebuild test` ending in `** TEST FAILED **` with an empty "Failing tests:" list and `malloc: *** error for object 0x...: pointer being freed was not allocated` plus "Restarting after unexpected exit" can be the pre-existing test-host teardown crash; confirm every suite reports 0 failures and the total test count matches baseline before treating it as a regression.
**Why:** During Hebrew localization work, the full suite reported all 88 tests passing with 0 failures yet still ended in the known teardown crash, and the unmodified base commit crashed identically.

### 2026-06-16
**Category:** SwiftUI
**Rule:** To localize UI text that reaches `Text` through a reusable component parameter or enum/view-model computed property, use `LocalizedStringKey` for static UI labels and keep dynamic/server data as `String`.
**Why:** Translating `Localizable.xcstrings` alone left tab bar, home hero, and component labels in English because plain `String` values rendered by `Text(variable)` do not resolve through the String Catalog.

### 2026-06-16
**Category:** Build
**Rule:** Under Swift 6 default MainActor isolation, a `Bundle` subclass used for runtime language override must be `nonisolated final class`, and associated-object storage it uses should be `nonisolated(unsafe)`.
**Why:** The localized bundle override first failed to build because its implicit initializer isolation did not match `Bundle`'s nonisolated designated initializers.

### 2026-06-18
**Category:** Build
**Rule:** In `@MainActor @Observable` reference types, private task handles cancelled from `deinit` should be `@ObservationIgnored` and `nonisolated(unsafe)` when they are only cancellation tokens.
**Why:** PR #61's `StoreManager` build failed under Swift 6 because `deinit` tried to read a main actor-isolated `transactionListenerTask`; plain `nonisolated` then failed under the Observation macro for a mutable stored property.

### 2026-06-18
**Category:** Build
**Rule:** In file-system-synchronized Xcode targets, avoid adding a Swift file with the same basename as an existing Swift file even if the type name differs, because Swift localized strings extraction can emit duplicate `*.stringsdata` outputs.
**Why:** PR #61 renamed the draft StoreKit paywall type but left the file as `Payments/PaywallView.swift`, causing a duplicate `PaywallView.stringsdata` build output alongside `Features/Profile/PaywallView.swift`.

### 2026-06-18
**Category:** Test
**Rule:** If `simctl bootstatus` reaches a terminal failure or `simctl install/launch` hangs during deadline smoke testing, switch to a fresh simulator or erase the runtime before continuing the smoke.
**Why:** A D7 Gate A iPhone 17 simulator boot reached a failed terminal bootstatus and subsequent install/launch hung, blocking manual analytics flow verification.

### 2026-06-14
**Category:** Test
**Rule:** If `xcodebuild test` reaches "Testing started" then hangs at "waiting for workers to materialize", restart the target simulator and rerun with a fresh derived-data path before treating it as an app test failure.
**Why:** A focused ResumeDiagnosis test build compiled successfully, but the simulator test host wedged during worker launch and had to be interrupted.

### 2026-06-12
**Category:** Build
**Rule:** When adding flexible Swift `Codable` decoders with multiple possible keys, decode each throwing candidate into local optionals before nil-coalescing and keep custom decoding-key enums separate from synthesized encode keys.
**Why:** A backend-diagnosis decoder patch failed to compile because throwing `decodeIfPresent` calls were chained inside `??`, one nested type referenced a missing decoding-key enum, and a custom key enum name collided with Codable synthesis expectations.

### 2026-06-12
**Category:** Test
**Rule:** In this project, add new Swift test files to the explicit Xcode test target in `project.pbxproj`; do not trust a focused `xcodebuild` run that reports success with 0 executed tests.
**Why:** `ResumeDiagnosisViewModelTests.swift` existed on disk, but the focused diagnosis test command initially ran zero tests until the PBX file and build phase entries were added.

### 2026-06-12
**Category:** UX
**Rule:** Submit Package must generate a reviewable draft first, then save to Me only after the user explicitly confirms; do not mark the application applied during package creation.
**Why:** The package flow was persisting too early and could miss the job link or saved cover letter context, leaving users without a reliable Me-tab package to export or submit from.

### 2026-06-12
**Category:** Build
**Rule:** Before Xcode builds in this file-system synchronized project, move untracked duplicate `* 2.swift` artifacts out of app and test source folders because Xcode will compile them automatically.
**Why:** A focused iPhone 17 test build failed with `Invalid redeclaration of 'JWTDecoder'` because the untracked `JWTDecoder 2.swift` file was auto-included alongside the tracked source.

### 2026-06-12
**Category:** Build
**Rule:** Under project-wide default MainActor isolation, do not wrap a mutable helper struct inside an actor unless the helper's methods are explicitly nonisolated; put the mutable storage directly in the actor or the actor will fail to call the helper synchronously.
**Why:** A PR #56 cache-race remediation first introduced `OptimizationDetailCacheActor` that delegated to `OptimizationDetailCache`, but Swift 6 treated the helper's methods as MainActor-isolated and the build failed.

### 2026-06-11
**Category:** UX
**Rule:** App Store screenshot claims must map to reachable in-app product surfaces, even when the screenshot itself is generated by launch-argument-only marketing views.
**Why:** The ATS screenshots existed only in `MarketingScreenshotView`, while the normal Optimized flow had only a compact score card; smoke testing made the live product feel inconsistent with the submission assets until a normal ATS insight panel was added.

### 2026-06-11
**Category:** UX
**Rule:** Submit Package must not disable the primary action solely because backend/job parsing missed company or role context; allow submission with visible fallback copy and safe placeholders.
**Why:** A real-device smoke showed no submit/download/application network calls after tapping Submit Package. The sheet's `canSubmit` required `companyName`, but the live optimization detail can omit company, so the user saw a non-working flow with no actionable explanation.

### 2026-06-11
**Category:** PDF
**Rule:** PDF export and Submit Package must not depend solely on `/api/download`; after WKWebView or backend download failure, generate a valid local text-layer PDF from loaded optimization sections and contact data.
**Why:** A real-device smoke showed both Preview & Export PDF and Submit Package failing because Submit Package calls the same PDF download path first. The backend fallback returned a non-usable/invalid response, so the shared PDF dependency blocked both flows.

### 2026-06-10
**Category:** Build
**Rule:** Before running local `xcodebuild` in a fresh worktree, copy `Secrets.xcconfig.template` to the gitignored `Secrets.xcconfig`; the project references that file as a base configuration and the build fails before compilation if it is missing.
**Why:** A PR update verification build failed with "Unable to open base configuration reference file 'Secrets.xcconfig'" until the ignored local config file was created from the committed template.

### 2026-06-09
**Category:** API
**Rule:** iOS `Codable`-style request bodies use snake_case keys by default; Next.js backend destructuring uses camelCase. Always add both aliases (`jobTitle || job_title`, `company || company_name`) on the backend side — fixing one end is fragile since web clients also call the same route.
**Why:** `POST /api/v1/applications` validated against `jobTitle`/`company` (camelCase) while iOS sent `job_title`/`company_name` (snake_case). The backend saw all fields as `undefined` and returned 400 "Missing required fields", silently failing every Submit Package call. Smoke test logs revealed the mismatch. Fix: destructure both forms on the backend and merge them before validation.

### 2026-06-09
**Category:** Build
**Rule:** A Run Script phase that modifies the generated Info.plist via PlistBuddy MUST declare `$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)` as an `inputPath` AND a sentinel stamp file (e.g. `$(DERIVED_FILE_DIR)/inject-runtime-config.stamp`) as its `outputPath`; without the inputPath, Xcode's parallel build system schedules `ProcessInfoPlistFile` AFTER the script, silently overwriting every custom key the script injects.
**Why:** `ProcessInfoPlistFile` (the `GENERATE_INFOPLIST_FILE = YES` plist generation step) ran at log line 52 while the script ran at log line 48 on a parallel build. The script succeeded, the build succeeded, but the generated plist wiped `API_BASE_URL`, `POSTHOG_API_KEY`, and `POSTHOG_HOST` before code signing. Adding the Info.plist as an `inputPath` creates an explicit dependency edge that forces `ProcessInfoPlistFile` to complete first. Adding the stamp file as `outputPath` satisfies Xcode's new build system requirement that mutable-output scripts also declare a virtual output node.

### 2026-06-04
**Category:** Build
**Rule:** When `xcodebuild test` uses a `-derivedDataPath` that contains a stale build without custom Info.plist keys, the "Inject Runtime Config" script will not re-run unless you first `rm -rf` that derived data path; always do a clean build after applying the runtime config patch to avoid a confusing runtime `preconditionFailure` crash that looks like a code bug.
**Why:** After applying the Inject Runtime Config patch, the first test run used stale derived data. The stale Info.plist lacked `API_BASE_URL`, causing a runtime crash (`Fatal error: Missing or invalid API_BASE_URL in Info.plist`) and `** TEST FAILED **` even though the build settings were correct. A clean `rm -rf /tmp/derived && xcodebuild test` resolved it immediately.

### 2026-06-03
**Category:** Build
**Rule:** `INFOPLIST_KEY_*` build settings only inject predefined system keys (NSCamera, UILaunch, etc.) into a generated Info.plist — arbitrary custom keys like `POSTHOG_API_KEY` are silently omitted. Use a Run Script build phase with PlistBuddy to inject custom Info.plist keys after GENERATE_INFOPLIST_FILE runs.
**Why:** The POSTHOG_API_KEY build setting appeared correctly in `-showBuildSettings` output but never reached the app's Info.plist, silently disabling all analytics. Xcode 26.5 confirmed: custom INFOPLIST_KEY_* values are dropped.

### 2026-06-03
**Category:** Build
**Rule:** When GENERATE_INFOPLIST_FILE=YES is active and a project uses `fileSystemSynchronizedGroups`, do NOT place a file named `Info.plist` in the app source directory — the auto-sync mechanism picks it up as a resource AND the build system processes it as the INFOPLIST_FILE, producing a "Multiple commands produce" conflict.
**Why:** Creating Info.plist in the app folder triggered two build commands writing to the same output path; the file system synchronized group auto-includes all files in the folder without needing explicit project references.

### 2026-06-02
**Category:** SwiftUI
**Rule:** When chaining throwing decoder helpers with nil-coalescing, assign each `try` result to local optional values before using `??`.
**Why:** A focused build failed because Swift does not allow `try` directly to the right of a non-assignment `??` expression in the ATS blocker decoder.

### 2026-06-02
**Category:** Test
**Rule:** In Swift XCTest, avoid asserting arrays of tuples directly and keep string fixtures exactly aligned with expected parsed output.
**Why:** The first Phase 2 focused test run failed first on tuple-array equality, then on a cover-letter fixture missing the comma expected by the assertion; element-wise tuple assertions and matching fixtures made the test intent clear.

### 2026-06-02
**Category:** Test
**Rule:** Test spies that construct MainActor-isolated app DTOs under Swift 6 should be `@MainActor` when used from `@MainActor` XCTest classes.
**Why:** A manual-edit test spy initialized `ATSRescanResponse` from a nonisolated helper context, causing the focused test build to fail with a MainActor-isolated initializer error until the spy classes were actor-bound.

### 2026-06-01
**Category:** Build
**Rule:** If simulator codesign fails with "resource fork, Finder information, or similar detritus not allowed" inside `.derivedData`, clear extended attributes from DerivedData before changing source code.
**Why:** A verification build compiled and linked successfully but failed when codesigning the generated simulator `.app` because local DerivedData carried disallowed filesystem metadata.

### 2026-06-01
**Category:** Build
**Rule:** Under Swift 6 default MainActor isolation, do not add nonisolated JSON encoding helpers for app models unless the model conformance is explicitly safe from that isolation context.
**Why:** A design assignment helper tried to encode `DesignCustomization` from a nonisolated static function, causing the build to fail with a MainActor-isolated `Encodable` conformance error.

### 2026-06-01
**Category:** Test
**Rule:** In a `@MainActor` XCTest class, every test function that creates or accesses an `@Observable @MainActor` object must be declared `async` — even when the test body contains no `await` expressions.
**Why:** XCTest dispatches synchronous `@MainActor` test methods via the Objective-C runtime, bypassing Swift's actor isolation. This causes the `@Observable` observation registrar to see a stack-allocated pointer freed from the wrong context, producing `malloc: *** error for object 0x7ffd...: pointer being freed was not allocated` and crashing the test runner. Making the function `async` forces XCTest to use the Swift Concurrency path, which correctly enforces `@MainActor` isolation. This affected `ExpertReportParsingTests` (22 tests), `OptimizedResumeViewModelTests` (2 sync tests), and `RuntimeServicesTests` (2 sync tests) on iOS 26.3.1 / Xcode beta.

### 2026-05-31
**Category:** Git
**Rule:** When using `git diff -G` for literal parentheses, prefer a character class such as `-G'print[(]'` instead of backslash-heavy shell quoting.
**Why:** A malformed diff regex failed with "parentheses not balanced" during PR QA.

### 2026-05-31
**Category:** Build
**Rule:** Under Swift 6 default MainActor isolation, pure enum metadata used by nonisolated helpers must be marked `nonisolated`, and Codable persistence helpers should stay actor-isolated unless they truly need cross-actor access.
**Why:** PR #36 failed to build because a nonisolated export-completion loader decoded a MainActor-isolated Codable type, and a nonisolated analytics payload helper read MainActor-isolated computed properties.

### 2026-05-31
**Category:** SwiftUI
**Rule:** When pattern-matching a conditionally cast error, match the optional enum case (`case .serverError(...)?`) or unwrap before switching.
**Why:** PR #36's export error handling used a non-optional enum pattern against `error as? APIClientError`, causing a Swift compile failure.

### 2026-05-28
**Category:** Build
**Rule:** For launch-argument screenshot captures, verify the raw simulator PNG after each launch; manual `simctl launch` can leave the app on the generated launch screen even when XcodeBuildMCP `build_run_sim` renders correctly.
**Why:** rb-aso-002 initially produced blank white raw screenshots from manual `simctl launch`; using the Build iOS Apps plugin launch before each capture produced the correct SwiftUI screenshot views.

### 2026-05-26
**Category:** UX
**Rule:** Expert asset workflows must say where the asset was saved and save to an application report when an application is linked.
**Why:** Cover Letter could report “saved” while the top-level Expert tab had no application context, leaving users unable to find the asset from Me.

### 2026-05-26
**Category:** API
**Rule:** iOS optimize uploads should store resume/job inputs first and run heavy AI optimization in the dedicated optimize route, with URL scraping bounded by server timeouts.
**Why:** Live LinkedIn job URL scraping plus PDF parsing plus AI optimization could exceed the deployment function window and surface raw `FUNCTION_INVOCATION_TIMEOUT`.

### 2026-05-26
**Category:** UX
**Rule:** Never block the optimized resume preview on the optimization-detail section fetch when the render-preview endpoint can render from the optimization ID.
**Why:** Gating the whole preview behind `loadSections` left users stuck on “Loading resume…” whenever the detail route was slow, empty, or failing, even though backend preview rendering could still produce the resume.

### 2026-05-25
**Category:** Template
**Rule:** Load the current design assignment only as an initial/apply/undo synchronization step, never as part of every category change.
**Why:** Reloading assignment inside `loadTemplates` reset `activeCategory` back to the already-applied Traditional template whenever the user tapped Modern, Creative, or Corporate.

### 2026-05-25
**Category:** UX
**Rule:** Resume previews with loaded sections must paint local HTML immediately and let backend design rendering update the web view asynchronously.
**Why:** Blocking the entire optimized preview on repeated backend render-preview calls made loading feel slow even though optimization and section fetches were already complete.

### 2026-05-25
**Category:** Test
**Rule:** After editing Swift test doubles, confirm every async protocol method explicitly returns the constructed DTO before running the full simulator suite.
**Why:** A spy `currentAssignment` method built a `DesignAssignmentDTO` without `return`, causing the test target to fail compilation.

### 2026-05-25
**Category:** Resume Output
**Rule:** Optimized resume preview fallbacks must render real contact data from the optimization detail and must never fabricate placeholder name, email, phone, or profile values.
**Why:** The iOS local HTML fallback hardcoded `Your Name` and `email@example.com`, making optimized resumes look like they lost the candidate's identity even when sections existed.

### 2026-05-25
**Category:** Template
**Rule:** Design preview/export rendering must resolve backend template UUIDs to template category/slug/default config before selecting a visual layout.
**Why:** iOS sends `template.id`, but the backend renderer branched on slug-like strings, so traditional, modern, creative, and corporate templates collapsed into the same preview style.

### 2026-05-25
**Category:** API
**Rule:** Force refreshes after server-side Expert or design apply must bypass optimization detail caches and reload current assignment/style state.
**Why:** Expert apply and design apply could succeed on the server while iOS continued showing stale sections, stale ATS score, or the previous template assignment.

### 2026-05-24
**Category:** API
**Rule:** When iOS can extract readable resume text, send it with the upload and let the backend use it as a parser fallback instead of treating PDF parser failures as terminal.
**Why:** Some live PDFs are readable by PDFKit on device but still fail backend parsing; without a `resumeText` fallback the user sees a 422 and optimization cannot continue.

### 2026-05-24
**Category:** API
**Rule:** Confirm backend JSON field casing from the live route before wiring an iOS request body.
**Why:** Design Apply posted `template_id`, but the backend assignment route required `templateId`, causing live 400 responses.

### 2026-05-24
**Category:** Build
**Rule:** After merging a PR, fetch and pull `main` in the local Xcode working copy before rebuilding, then confirm Xcode's branch popover shows `main`.
**Why:** The app was rebuilt from local `main` while it was still two commits behind `origin/main`, so the installed binary still contained code removed by the merged PR.

### 2026-06-26
**Category:** API
**Rule:** Non-idempotent apply mutations must use a long timeout and recover timeout/already-applied responses by reloading server state before surfacing an error.
**Why:** Real-device smoke showed optimization review apply could time out after the server had already applied changes; retry then returned "This review has already been applied" and stranded the user instead of opening the optimized resume.

### 2026-05-24
**Category:** PDF
**Rule:** For live optimize uploads, send a backend-readable text-layer PDF generated from iOS-extracted text instead of trusting the original PDF internals.
**Why:** PDFKit could read selected PDFs locally, but the backend `pdfjs-dist` parser still returned 422 for some device-selected PDFs.

### 2026-05-24
**Category:** API
**Rule:** Do not auto-load nonessential audit/history endpoints on screen open when the primary user flow can work without them; load them lazily or use the stable fallback action.
**Why:** `/api/v1/styles/history` returned 500 on device and made the app look broken even though templates, preview rendering, and design apply were working.

### 2026-05-24
**Category:** PDF
**Rule:** Validate that selected PDFs contain extractable text before upload so scanned/image-only files fail locally with clear guidance.
**Why:** The live upload endpoint rejected the user's selected PDF with 422 after upload; local PDFKit preflight gives faster, clearer feedback and avoids a failed optimize attempt.

### 2026-05-24
**Category:** Build
**Rule:** Pure helper APIs used from URLSession/background tasks should be explicitly `nonisolated` under Swift 6 when the surrounding app uses `@MainActor` heavily.
**Why:** The first build after adding upload preflight helpers failed because Swift treated helper calls as main actor-isolated from a detached task and synchronous error formatter.

### 2026-05-24
**Category:** API
**Rule:** Runtime service defaults must always resolve to live services; mocks are allowed only through explicit test or preview injection.
**Why:** Global mock flags let `mock-opt-001` and placeholder HTML enter user-facing flows, which then produced live backend UUID errors and made the app look broken after a rebuild.

### 2026-05-20
**Category:** SwiftUI
**Rule:** Place `.navigationDestination(isPresented:)` on the `ZStack` or `ScrollView` inside the enclosing `NavigationStack` — NOT on a `List` or a nested subview inside a `List`.
**Why:** When attached to a `List`, SwiftUI may silently fail to navigate or emit "outside NavigationStack" runtime warnings. Moving the modifier to the outermost container inside the `NavigationStack` (e.g., the `ZStack` wrapping the `List`) resolves this.

### 2026-05-20
**Category:** API
**Rule:** When surfacing API errors in UI banners, pattern-match `APIClientError.serverError(_, let message)` and display `message` directly — not `error.localizedDescription` (which wraps it in "Server error (500): …" prefix).
**Why:** The `localizedDescription` for `serverError` includes the status code prefix, which is noise for end users. The raw `message` from the server is more actionable and was already extracted from the JSON `error` field.

### 2026-05-20
**Category:** SwiftUI
**Rule:** When a `View` has a custom `init`, all callback properties (`var onSwitchTab: (Tab) -> Void`) must be assigned in the `init` body — they are NOT auto-synthesized. Forgetting this causes the default `{ _ in }` to be used even when a non-default is passed.
**Why:** Swift's memberwise init is suppressed when a custom `init` exists. All stored properties including closure callbacks must be explicitly set.

### 2026-05-18
**Category:** API
**Rule:** Never write hand-crafted PDF byte strings with XRef offsets — the offsets will be wrong and the backend pdf-parse will throw "bad XRef entry" → 422. Use `UIGraphicsPDFRenderer` to generate mock PDFs in iOS, and use `pdfjs-dist` (not `pdf-parse`) on the backend.
**Why:** `MockResumeLibraryService.downloadResumePDF` had a minimal PDF string where object 2 was declared at offset 58 but actually started at offset 52 (and similar drift for obj 3 and startxref). This is impossible to get right by eye. `UIGraphicsPDFRenderer` generates valid PDFs automatically. On the backend, `pdf-parse` v1.1.1 uses pdf.js v1.9.426 which has no XRef recovery; `pdfjs-dist` v5 falls back to a full linear scan.

### 2026-05-18
**Category:** SwiftUI
**Rule:** Never call `onSelect` or any selection callback from a Cancel button in a sheet. Use `@Environment(\.dismiss)` instead.
**Why:** `SavedResumePickerSheet` Cancel was calling `onSelect(URL(fileURLWithPath: "/dev/null"), "")`, which set `selectedResumeURL` to `/dev/null` and `selectedResumeName` to empty string. The optimize flow then tried to read `/dev/null` and iOS returned "The file 'null' couldn't be opened because you don't have permission to view it."

### 2026-05-18
**Category:** SwiftUI
**Rule:** Check `someStringOptional?.isEmpty == false` (not `!= nil`) when a non-empty string is required to guard a UI state.
**Why:** An empty string `""` passes `!= nil`. When `selectedResumeName = ""`, the step-1 card showed a blue checkmark and `canOptimize` was true, letting the user hit Optimize with no real file selected.

### 2026-05-13
**Category:** SwiftUI
**Rule:** Always use `@Observable` + `@MainActor` for ViewModels, never `ObservableObject`/`@Published` — the project is on Swift Observation (iOS 17+).
**Why:** This project uses Swift 6 + the Observation framework. Using `ObservableObject` will cause build errors and is inconsistent with the existing codebase.

### 2026-05-13
**Category:** SwiftUI
**Rule:** New screens and features go in `Features/V2/` — never in the top-level `Features/` folder.
**Why:** The project is in the middle of a V2 migration. The old `Features/` folder is legacy. Extending it would create confusion and drift.

### 2026-05-13
**Category:** Build
**Rule:** Swift 6 strict concurrency is enabled. Every new type must be either `@MainActor`-bound or marked `Sendable`. Missing conformances will fail the build.
**Why:** The project sets SWIFT_VERSION = 6.0. Concurrency violations are build errors, not warnings.

### 2026-05-13
**Category:** API
**Rule:** Never hardcode API URLs in source code. Always use the `Endpoint` enum in `Core/API/Endpoints.swift` via `APIClient`.
**Why:** The API base URL is configured via the `API_BASE_URL` Info.plist key to support different environments. Hardcoding breaks this.

### 2026-05-13
**Category:** Build
**Rule:** Do not add Swift Package Manager dependencies without explicit approval. The project uses only system frameworks.
**Why:** There is no Package.swift in this project. Adding SPM packages requires Xcode project changes and team sign-off.
### 2026-07-14
**Category:** Repository navigation
**Rule:** Resolve source paths with `rg --files` before opening files in this repository; the filesystem source root is `ResumeBuilder IOS APP/`, not the Xcode product name `ResumeBuilder/`.
**Why:** Story 3 inspection initially used logical Xcode paths and failed to find the files, creating an avoidable tool round trip.

### 2026-07-14
**Category:** Simulator testing
**Rule:** When multiple simulator runtimes contain a device with the same name, target the already-booted simulator by UDID instead of using `destination name=...`.
**Why:** Story 3's focused test built successfully but stalled before launching tests because `name=iPhone 17` was ambiguous across installed iOS runtimes.

### 2026-07-14
**Category:** Xcode testing
**Rule:** Reuse a built test bundle only with a simulator on the same runtime; switching an existing DerivedData directory from iOS 26.5 to 26.3 can force a new thinned asset compile that stalls in `actool`.
**Why:** Story 3's retry targeted the older booted iPhone 17 runtime with a 26.5-derived bundle and hung rebuilding device-thinned assets; using the exact 26.5 simulator with `test-without-building` avoids that mismatch.

### 2026-07-14
**Category:** Simulator testing
**Rule:** If an exact-UDID `test-without-building` never starts XCTest and `simctl bootstatus` also stops responding, restart the simulator fleet before retrying.
**Why:** Story 3's already-built focused bundle could not launch on the booted iPhone SE because CoreSimulator was wedged, not because the test binary failed.

### 2026-07-14
**Category:** Swift concurrency tests
**Rule:** Read actor-isolated values into a local variable before passing them to XCTest assertion autoclosures.
**Why:** `XCTAssertNil(await actor.value)` is invalid because XCTest autoclosures are synchronous and do not support `await`.

### 2026-07-14
**Category:** Shared validation
**Rule:** When replacing an input-readiness Boolean with a shared policy, search every derived UI state—not only the submit button and API guard—and route all completion/progress state through the policy.
**Why:** Story 4 initially updated Home cards and submission but left `HomeActivationState` deriving job readiness from raw nonempty input, which could mark an invalid job as complete.

### 2026-07-14
**Category:** Shell commands
**Rule:** Prefer separate command invocations when reading multiple paths containing spaces; avoid composing long, mixed-quote shell commands.
**Why:** Story 5 inspection used an unmatched quote in a combined read command, causing an avoidable interruption before any source changes occurred.

### 2026-07-14
**Category:** Simulator testing
**Rule:** Re-read Xcode's available destinations at the start of each story instead of carrying a simulator UDID forward from an earlier story.
**Why:** Story 5's first red-test attempt used an iPhone 17 identifier that Xcode had replaced, so destination resolution failed before compilation.

### 2026-07-14
**Category:** Xcode test targets
**Rule:** After adding a test file, verify it is explicitly present in the test target's group and Sources build phase; treat “Executed 0 tests” as a failed verification, never a pass.
**Why:** The test folder is a manual PBX group, so Story 5's new file was not auto-enrolled and the first focused invocation ran no fixtures.

### 2026-07-14
**Category:** SwiftUI cleanup
**Rule:** When moving derived display data into a view model, replace conditional value bindings with Boolean presence checks if the bound model is no longer read.
**Why:** Story 5 moved the review footer count behind `selectableGroupCount` but initially left an unused `env` binding, producing a new compiler warning.

### 2026-07-14
**Category:** Release builds
**Rule:** For this project’s first optimized simulator build, use direct `xcodebuild` when the XcodeBuildMCP call approaches its fixed 300-second tool timeout.
**Why:** Story 5's Release build produced no source error but the MCP transport timed out before returning a result, so the run could not be counted as verification.
