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
