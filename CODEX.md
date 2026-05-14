# CODEX.md — ResumeBuilder iOS

> Codex-specific instructions. AGENTS.md is the primary router — read it first.

## Session Start
1. Read `tasks/lessons.md`
2. Read `tasks/progress.md`
3. State the objective before acting

## Rules
- Plan first for any task touching >2 files
- Work one story at a time
- Load only the workflow file relevant to your task — not the entire Agent OS
- All new screens go in `Features/V2/` — not the older `Features/` folder
- Use `@Observable`/`@MainActor` — not `ObservableObject`/`@Published`
- Swift 6 strict concurrency is on — handle `Sendable` and actors correctly
- No new SPM packages without asking

## Verify Before Done
- Xcode build must succeed
- Relevant tests must pass
- Update `tasks/progress.md` after each story
- Add lesson to `tasks/lessons.md` if a mistake occurred
