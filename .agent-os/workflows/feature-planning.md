# Workflow: Feature Planning

> Use this when planning a new feature, major improvement, or multi-story task.
> Output: a product brief + feature spec + story list in `docs/specs/`.

---

## Steps

### 1. Load Context (Required)
Read these files before planning:
- `tasks/lessons.md` — known constraints and past mistakes
- `tasks/progress.md` — current active stories, blockers
- `docs/product/current-product-state.md` — what exists now
- `docs/architecture/current-ios-architecture.md` — technical constraints
- `docs/architecture/technical-risks.md` — risks to account for

### 2. State the Objective
Write one sentence: "We are building [what] so that [who] can [outcome]."

If you cannot write this sentence clearly, the feature is not well-defined — ask for clarification.

### 3. Write a Product Brief
Use `.agent-os/templates/product-brief-template.md`.
Keep it short: problem, solution, scope, out-of-scope, success metrics.
Save to `docs/specs/drafts/[feature-slug]-brief.md`.

### 4. Identify Affected Code
Before writing a spec, identify:
- Which Swift files will change
- Which API endpoints are needed (new or existing)
- Which ViewModels are involved
- What new files need to be created
- Are all new screens going in `Features/V2/`?

### 5. Write the Feature Spec
Use `.agent-os/templates/feature-spec-template.md`.
Include: user story, acceptance criteria, API changes, iOS changes, open questions.
Save to `docs/specs/drafts/[feature-slug]-spec.md`.

### 6. Break Into Dev Stories
Use `.agent-os/templates/dev-story-template.md`.
Each story should be implementable in one session (< 4 hours of focused work).
Each story should have clear acceptance criteria and be independently testable.

Order stories so each one builds on the previous and produces a working build.

### 7. Get Approval
Present the spec and story list. Do not start coding until approval.

### 8. Save Approved Spec
Move approved spec to `docs/specs/[feature-slug].md`.
Add to the index in `docs/specs/README.md`.
Update `tasks/progress.md` → Active Spec field.

---

## Quality Gate
Before calling planning done:
- [ ] Product brief is clear and scoped
- [ ] Feature spec has acceptance criteria
- [ ] Stories are small and independently testable
- [ ] Technical approach does not violate any standard in `.agent-os/standards/`
- [ ] No unapproved new dependencies introduced
