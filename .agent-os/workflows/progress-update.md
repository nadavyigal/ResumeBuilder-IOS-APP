# Workflow: Progress Update

> Run after any meaningful story, bug fix, QA review, or milestone.
> `tasks/progress.md` must be kept current for the Global Agentic OS dashboard to be useful.

---

## Steps

### 1. Get the Latest Git Info
```bash
git log --oneline -1
git branch --show-current
```

### 2. Update `tasks/progress.md`

Update these fields:

| Field | What to write |
|-------|--------------|
| Status | Planning / In Progress / Blocked / QA / Ready for TestFlight / Released |
| Current Phase | e.g., "Pre-release (TestFlight prep)", "Feature: optimization detail" |
| Active Story | The story currently in progress (or "—") |
| Last Completed Story | The story just finished |
| Next Recommended Story | The logical next story based on specs and priorities |
| Estimated Completion | Rough % towards TestFlight or current phase goal |
| Blockers | Any hard blocks (missing API, design decision needed) |
| Risks | Current technical or product risks |
| Last Validation | Date and result of last build/test/QA run |
| Last Updated | Today's date (YYYY-MM-DD) |
| Current Branch | Output of `git branch --show-current` |
| Latest Commit | Output of `git log --oneline -1` |
| Active Spec | Path to current approved spec |
| Latest QA Report | Path to latest QA report (or "—") |

### 3. Keep It Short
The progress file should be scannable in 30 seconds. Do not write paragraphs. One value per field.

### 4. Update Session Log
Add an entry to `tasks/session-log.md` with:
- Date
- What was done
- Files changed
- Decisions made
- Next recommended action

---

## Format Reference

```
Project: ResumeBuilder iOS
Status: In Progress
Current Phase: Pre-release (TestFlight prep)
Active Story: —
Last Completed Story: Phase 3 — load sections in OptimizedResumeView
Next Recommended Story: Phase 5 — wire PDF preview button
Estimated Completion: 25%
Blockers: —
Risks: WKWebView PDF fragile on real device
Last Validation: 2026-05-14 — build pass, tests pass
Last Updated: 2026-05-14
Current Branch: main
Latest Commit: abc1234 feat(ios): load sections after review apply
Active Spec: plan-phases-3-5-6.md
Latest QA Report: docs/qa/reports/ios-qa-2026-05-14.md
Notes: Phases 5 and 6 still pending
```
