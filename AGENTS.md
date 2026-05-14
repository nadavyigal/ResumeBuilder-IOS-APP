# AGENTS.md — ResumeBuilder iOS

> Thin router. Read this first, then load only what you need.
> Do not load every Agent OS file — use the routing table below.

## Always Start With
1. Read `tasks/lessons.md` — known bugs, rules, past corrections
2. Read `tasks/progress.md` — current state, active story, blockers
3. State the objective in one sentence before planning or coding

## Workflow Routing

| Task type | Files to read |
|-----------|--------------|
| Planning a feature | `tasks/lessons.md` → `tasks/progress.md` → `.agent-os/workflows/feature-planning.md` → `docs/product/current-product-state.md` → `docs/architecture/current-ios-architecture.md` → relevant template |
| Implementing a story | `tasks/lessons.md` → `tasks/todo.md` → `.agent-os/workflows/story-implementation.md` → approved spec in `docs/specs/` |
| Fixing a bug | `tasks/lessons.md` → `.agent-os/workflows/bug-fix.md` → relevant error/log/file |
| iOS QA review | `tasks/lessons.md` → `.agent-os/workflows/ios-qa-review.md` → `docs/qa/ios-qa-checklist.md` |
| Resume output review | `.agent-os/workflows/resume-output-review.md` → `docs/qa/resume-output-quality-checklist.md` |
| TestFlight readiness | `.agent-os/workflows/testflight-review.md` → `docs/qa/testflight-checklist.md` |
| PR summary | `.agent-os/workflows/pr-review.md` → `.agent-os/templates/pr-summary-template.md` |
| Progress update | `.agent-os/workflows/progress-update.md` |
| Self-improvement | `.agent-os/workflows/self-improvement.md` |

## Verification Before Done
- Xcode build must succeed (no errors)
- Relevant tests must pass
- Simulator smoke test for any UI change
- Update `tasks/todo.md` and `tasks/progress.md`

## Self-Learning Rule
After any mistake, correction, failed build, or bad pattern: add a lesson to `tasks/lessons.md` immediately using the lesson template.

## Progress Update Rule
After any meaningful task or story completion: update `tasks/progress.md`.

## Critical iOS Rules (always apply)
- Extend `Features/V2/` — not the older `Features/` folder
- Use `@Observable` + `@MainActor`, not `ObservableObject`/`@Published`
- Swift 6 strict concurrency is on — every new type must be `Sendable` or `@MainActor`
- Never hardcode API URLs — use the `Endpoint` enum via `APIClient`
- No new SPM packages without asking
- Dark mode only — do not change `.preferredColorScheme(.dark)`
- API_BASE_URL comes from Info.plist, not from source code

## Example Prompts
- "Plan the resume section editing feature" → feature-planning workflow
- "Implement story: add PDF share button" → story-implementation workflow
- "Fix crash in TailorView on upload" → bug-fix workflow
- "Run iOS QA for Score tab" → ios-qa-review workflow
- "Review resume output quality" → resume-output-review workflow
- "Is the app TestFlight-ready?" → testflight-review workflow
- "Write a PR summary" → pr-review workflow
- "Update project progress" → progress-update workflow
