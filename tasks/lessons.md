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
