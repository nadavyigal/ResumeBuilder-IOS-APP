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
