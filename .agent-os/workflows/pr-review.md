# Workflow: PR Summary

> Use when preparing a pull request summary after completing a story or feature.
> Use `.agent-os/templates/pr-summary-template.md` for the output.

---

## Steps

### 1. List Changed Files
```bash
git diff --name-only main...HEAD
```
List all changed files. Note which are new vs. modified.

### 2. Summarize the Changes
For each changed file (or logical group):
- What was changed
- Why it was changed
- What it enables

Keep it factual — the PR description is for reviewers, not marketing.

### 3. Note Tests Run
- Which tests were run
- Result (pass/fail/skipped)
- Any new tests added

### 4. Note QA Status
- Was the iOS QA checklist run? Result?
- Was simulator smoke test done? On which devices?
- Any known issues or regressions?

### 5. Write the PR Summary
Use `.agent-os/templates/pr-summary-template.md`.
The PR title should follow the commit convention: `feat(ios):`, `fix(ios):`, `chore(ios):`.

### 6. Update Progress
Update `tasks/progress.md` → Last Completed Story field.

---

## PR Title Convention

```
feat(ios): [brief description]       ← new feature or new user-visible behavior
fix(ios): [brief description]        ← bug fix
chore(ios): [brief description]      ← maintenance, docs, non-user-facing change
refactor(ios): [brief description]   ← code restructure, no behavior change
test(ios): [brief description]       ← adding or fixing tests
```

---

## PR Quality Gate
- [ ] PR title follows convention
- [ ] Description explains what and why (not just what)
- [ ] Tests listed and passing
- [ ] QA status noted
- [ ] No secrets or test credentials in changed files
- [ ] No unintended file changes (check the diff carefully)
