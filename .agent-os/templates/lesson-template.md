# Lesson Template

> Copy this block into `tasks/lessons.md` when adding a new lesson.

---

### YYYY-MM-DD
**Category:** Build | SwiftUI | API | Resume Output | PDF | Template | UX | Auth | TestFlight | General
**Rule:** _One sentence: what to DO (or NOT do) in future._
**Why:** _What went wrong, what was corrected, or what was discovered._

---

## Categories Reference

| Category | Use for |
|----------|---------|
| Build | Swift 6 concurrency errors, Xcode build failures, missing imports |
| SwiftUI | Wrong state wrappers, layout bugs, navigation issues, view patterns |
| API | Wrong endpoint, missing header, bad JSON key, auth not attached, response parsing |
| Resume Output | Hallucinated content, poor tone, missing sections, bad bullet quality |
| PDF | WKWebView rendering, export failures, layout overflow |
| Template | Broken thumbnails, rendering issues, wrong styling |
| UX | Missing loading/empty/error state, bad tap target, clipped text |
| Auth | Session not restored, token not sent, sign-out incomplete |
| TestFlight | Wrong bundle ID, missing entitlement, localhost URL, version not incremented |
| General | Scope creep, missed requirement, bad assumption, overengineering |

## Good Rule Examples

- "Always use `@Observable @MainActor` for ViewModels — never `ObservableObject`."
- "New screens go in `Features/V2/`, not top-level `Features/`."
- "Test PDF export on a real device, not just simulator — WKWebView behaves differently."
- "Never hardcode API URLs. Use the `Endpoint` enum in `Core/API/Endpoints.swift`."
- "Check `tasks/lessons.md` before starting any task to avoid repeating past mistakes."
