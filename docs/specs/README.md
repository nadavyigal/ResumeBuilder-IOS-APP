# Feature Specs Index

> All approved feature specs live here (or are linked from here).
> Only specs that have been reviewed and approved should be listed.
> Specs in progress that have not been approved should be in `docs/specs/drafts/`.

## Spec Format

Each spec should use `.agent-os/templates/feature-spec-template.md` and be saved as:
`docs/specs/[feature-slug].md`

---

## Active Specs

| Spec | Status | File |
|------|--------|------|
| Optimization detail — phases 3, 5, 6 | In Progress | `plan-phases-3-5-6.md` (root) |

---

## Completed Specs

| Spec | Shipped | Notes |
|------|---------|-------|
| Optimization detail — phases 1, 2, 4 | 2026-05 | Merged to main |

---

## How to Add a New Spec

1. Use `.agent-os/templates/feature-spec-template.md`
2. Fill in: objective, user story, scope, API changes, iOS changes, stories, acceptance criteria
3. Get approval from Nadav before moving to implementation
4. Move the approved spec to `docs/specs/[feature-slug].md`
5. Add it to the Active Specs table above
6. Update `tasks/progress.md` → Active Spec field
