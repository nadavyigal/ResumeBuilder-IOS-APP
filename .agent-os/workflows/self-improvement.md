# Workflow: Self-Improvement

> Run after any mistake, user correction, failed build, bad assumption, or repeated error.
> This workflow builds the self-learning memory that makes future sessions better.

---

## When to Run

Trigger this workflow after:
- User corrects an approach or output
- Build fails due to a pattern mistake (wrong Swift API, missing actor annotation)
- Test fails that should have passed
- Bad assumption about the codebase
- Poor AI resume output (hallucination, bad tone, missing section)
- Broken PDF export or template rendering
- A mistake is made more than once
- An overengineered approach is simplified
- A missed requirement is discovered

---

## Steps

### 1. Identify the Root Pattern
Ask: "What assumption, rule, or habit led to this mistake?"

Be specific:
- ❌ "I made a SwiftUI mistake" — too vague
- ✅ "I used `@StateObject` instead of `@State` with `@Observable` ViewModel" — actionable

### 2. Write the Rule
The rule should be:
- One sentence
- Actionable (tells you what TO DO, not just what not to do)
- Generalizable (applies beyond just this one case)

Example: "When creating a new ViewModel in this project, always use `@Observable @MainActor final class`, never `ObservableObject`."

### 3. Add the Lesson
Add to `tasks/lessons.md` using the lesson template:

```markdown
### [Date]
**Category:** [Build | SwiftUI | API | Resume Output | PDF | Template | UX | Auth | TestFlight | General]
**Rule:** [One sentence rule]
**Why:** [What went wrong]
```

### 4. Apply the Rule Now
Check: does the current work already violate this rule?
If yes, fix it before continuing.

### 5. Note It in the Session Log
In `tasks/session-log.md`, under the current session, note that a lesson was added.

---

## Lesson Categories

| Category | Examples |
|----------|---------|
| Build | Swift 6 concurrency errors, missing @MainActor, bad Sendable |
| SwiftUI | Wrong state wrapper, NavigationView vs NavigationStack, layout issues |
| API | Wrong endpoint, missing header, bad JSON key, auth not attached |
| Resume Output | Hallucinated content, missing sections, bad tone |
| PDF | WKWebView blank, layout overflow, wrong file format |
| Template | Missing thumbnail, broken render, overflow |
| UX | Missing loading state, bad empty state, clipped text |
| Auth | Session not restored, token not sent, sign-out incomplete |
| TestFlight | Wrong bundle ID, missing entitlement, localhost URL |
| General | Scoped too large, missed requirement, bad assumption |
