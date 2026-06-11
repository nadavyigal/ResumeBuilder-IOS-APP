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
