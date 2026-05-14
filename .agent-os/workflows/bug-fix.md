# Workflow: Bug Fix

> Use when fixing a bug, crash, or unexpected behavior.
> Iron Law: no fix without understanding the root cause first.

---

## Steps

### 1. Load Context
Read:
- `tasks/lessons.md` — has this bug been seen before?
- Relevant error logs, crash reports, or reproduction steps

### 2. Reproduce the Bug
Before touching code:
- Identify exact steps to reproduce
- Confirm the bug is reproducible on simulator or device
- Note: which screen, which action, what happens vs. what should happen

### 3. Find the Root Cause
Read the relevant source files. Understand why this is happening:
- Is it a Swift 6 concurrency issue? (`@MainActor` missing, non-Sendable type)
- Is it a state management issue? (VM not reset, stale state)
- Is it an API parsing issue? (missing field, wrong key)
- Is it a layout issue? (overflow, safe area, font size)
- Is it a navigation issue? (stack not cleared, sheet not dismissed)

**Do not write a fix until you can state the root cause in one sentence.**

### 4. Write the Minimal Fix
Fix only what is broken. Do not:
- Refactor surrounding code
- Add features
- Change unrelated behavior

The fix should be the smallest possible change that eliminates the bug.

### 5. Xcode Build Check
Build must succeed before proceeding.

### 6. Test the Fix
- Reproduce the original bug steps — confirm it no longer triggers
- Run all tests — confirm no regressions
- Test on iPhone SE if it's a UI bug

### 7. Add a Lesson
In `tasks/lessons.md`, add:
```
**Date:** [today]
**Category:** [Build/SwiftUI/API/UX/etc.]
**Rule:** [One sentence rule to prevent this in future]
**Why:** [What the root cause was]
```

### 8. Update Progress
Update `tasks/progress.md` and `tasks/session-log.md`.

---

## Common Bug Categories

| Symptom | Likely cause | Where to look |
|---------|-------------|---------------|
| Crash on appear | Missing `@MainActor`, nil force-unwrap | ViewModel init, `task {}` handler |
| Empty screen | `sections` array not loaded, API returns no data | OptimizedResumeViewModel, API response |
| Navigation stuck | `.sheet` not dismissed, NavigationStack not popped | View presentation code |
| Build error (Sendable) | Type crosses actor boundary | New model struct missing `Sendable` |
| Build error (MainActor) | Async call from non-isolated context | ViewModel method, Task creation |
| Blank WebView | WKWebView load failed silently | ResumePreviewWebView, network request |
| Wrong data shown | VM not reset between uses | ViewModel state on tab switch |
