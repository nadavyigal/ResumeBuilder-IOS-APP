# CLAUDE.md — ResumeBuilder iOS

> Claude Code-specific instructions. AGENTS.md is the primary router — read it first.

## Session Start
1. Read `tasks/lessons.md`
2. Read `tasks/progress.md`
3. Read `tasks/todo.md` if implementing a story
4. State objective in one sentence before planning

## Planning
- Use plan mode for any task touching >2 files
- Read only the workflow file relevant to your task (see AGENTS.md routing table)
- Write the plan to `tasks/todo.md` before writing code
- Follow `.agent-os/workflows/feature-planning.md` for new features

## Implementation
- One story at a time — implement, verify, report, then ask before the next
- Follow `.agent-os/workflows/story-implementation.md`
- All new screens go in `Features/V2/` — not the older `Features/` folder
- Use `@Observable` + `@MainActor` — not `ObservableObject`/`@Published`
- Use `Endpoint` enum via `APIClient` — never hardcode URLs
- No new dependencies without asking
- No unrelated file changes (scope gate: >3 unexpected files → stop and surface)

## After Implementation
- Xcode build check required before "done"
- Run relevant tests in `ResumeBuilder IOS APPTests/`
- Simulator smoke test for any UI change
- Mark `tasks/todo.md` items done
- Update `tasks/progress.md`
- Add lesson to `tasks/lessons.md` if a mistake was caught

## Session End
- Update `tasks/session-log.md` with: files changed, decisions made, next action
- Ensure `tasks/progress.md` reflects current state

## Memory
- `tasks/lessons.md` — corrections, bad patterns, failed approaches (add immediately)
- `tasks/todo.md` — current story plan and checklist
- `tasks/progress.md` — project-level dashboard
- `tasks/session-log.md` — end-of-session summary
